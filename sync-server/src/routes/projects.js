const express = require('express');
const crypto = require('crypto');
const { getDb } = require('../db/schema');
const {
  requireUser,
  requireMembership,
  requireLead,
} = require('../middleware/auth');
const { broadcastToProject } = require('../utils/broadcast');

const router = express.Router();

router.get('/', requireUser, (req, res) => {
  const db = getDb();
  const projects = db
    .prepare(
      `SELECT p.id, p.name, p.created_at, up.role
       FROM projects p
       JOIN users_projects up ON up.project_id = p.id
       WHERE up.user_id = ?
       ORDER BY p.created_at DESC`,
    )
    .all(req.userId);
  return res.json(projects);
});

router.get('/:projectId/members', requireUser, requireMembership, (req, res) => {
  const db = getDb();
  const members = db
    .prepare(
      `SELECT u.id, u.name, u.email, up.role
       FROM users u
       JOIN users_projects up ON up.user_id = u.id
       WHERE up.project_id = ?`,
    )
    .all(req.params.projectId);
  return res.json(members);
});

const VALID_ROLES = ['lead', 'member', 'observer'];

router.post('/:projectId/members', requireUser, requireLead, (req, res) => {
  const { email, username, role = 'member' } = req.body;
  if (!email && !username) {
    return res.status(400).json({ error: 'email or username required' });
  }
  if (!VALID_ROLES.includes(role)) {
    return res
      .status(400)
      .json({ error: `role must be one of: ${VALID_ROLES.join(', ')}` });
  }

  const db = getDb();
  const project = db
    .prepare('SELECT id FROM projects WHERE id = ?')
    .get(req.params.projectId);
  if (!project) return res.status(404).json({ error: 'project not found' });

  const user = email
    ? db
        .prepare('SELECT id, name, email FROM users WHERE email = ?')
        .get(email)
    : db
        .prepare('SELECT id, name, email FROM users WHERE name = ?')
        .get(username);
  if (!user) return res.status(404).json({ error: 'user not found' });

  try {
    db.prepare(
      'INSERT INTO users_projects (user_id, project_id, role) VALUES (?, ?, ?)',
    ).run(user.id, req.params.projectId, role);
  } catch (err) {
    if (err.message.includes('UNIQUE constraint failed')) {
      return res.status(409).json({ error: 'user is already a member' });
    }
    throw err;
  }

  return res.status(201).json({
    user_id: user.id,
    project_id: req.params.projectId,
    role,
    user,
  });
});

router.post('/', requireUser, (req, res) => {
  const { name } = req.body;
  if (!name) return res.status(400).json({ error: 'name required' });

  const db = getDb();
  const id = crypto.randomUUID();

  db.prepare('INSERT INTO projects (id, name, owner_id) VALUES (?, ?, ?)').run(id, name, req.userId);
  db.prepare(
    'INSERT INTO users_projects (user_id, project_id, role) VALUES (?, ?, ?)',
  ).run(req.userId, id, 'lead');

  const project = db.prepare('SELECT * FROM projects WHERE id = ?').get(id);
  return res.status(201).json(project);
});

router.get('/:projectId', requireUser, requireMembership, (req, res) => {
  const db = getDb();
  const project = db
    .prepare(
      `SELECT p.*, up.role AS my_role
       FROM projects p
       JOIN users_projects up ON up.project_id = p.id
       WHERE p.id = ? AND up.user_id = ?`,
    )
    .get(req.params.projectId, req.userId);
  if (!project) return res.status(404).json({ error: 'project not found' });
  return res.json(project);
});

router.patch('/:projectId', requireUser, requireLead, (req, res) => {
  const { name, description, updated_at: clientUpdatedAt } = req.body;
  if (name === undefined && description === undefined) {
    return res.status(400).json({ error: 'name or description required' });
  }

  const db = getDb();
  const project = db.prepare('SELECT * FROM projects WHERE id = ?').get(req.params.projectId);
  if (!project) return res.status(404).json({ error: 'project not found' });

  // LWW: reject stale writes
  if (clientUpdatedAt !== undefined && project.updated_at > clientUpdatedAt) {
    return res.status(409).json({ error: 'conflict', current: project });
  }

  db.prepare(
    `UPDATE projects SET name = ?, description = ?, updated_at = unixepoch() * 1000 WHERE id = ?`,
  ).run(
    name ?? project.name,
    description !== undefined ? description : project.description,
    req.params.projectId,
  );

  const updated = db.prepare('SELECT * FROM projects WHERE id = ?').get(req.params.projectId);
  return res.json(updated);
});

router.delete('/:projectId', requireUser, requireLead, (req, res) => {
  const db = getDb();
  const project = db.prepare('SELECT id FROM projects WHERE id = ?').get(req.params.projectId);
  if (!project) return res.status(404).json({ error: 'project not found' });

  db.transaction(() => {
    db.prepare('DELETE FROM tasks WHERE project_id = ?').run(req.params.projectId);
    db.prepare('DELETE FROM notes WHERE project_id = ?').run(req.params.projectId);
    db.prepare('DELETE FROM users_projects WHERE project_id = ?').run(req.params.projectId);
    db.prepare('DELETE FROM projects WHERE id = ?').run(req.params.projectId);
  })();

  return res.status(204).end();
});

router.get('/:projectId/tasks', requireUser, requireMembership, (req, res) => {
  const db = getDb();
  const tasks = db
    .prepare(
      `SELECT t.*, u.name AS assignee_name
       FROM tasks t
       LEFT JOIN users u ON u.id = t.assignee_id
       WHERE t.project_id = ?
       ORDER BY t.created_at ASC`,
    )
    .all(req.params.projectId);
  return res.json(tasks);
});

const VALID_STATUSES = ['open', 'taken', 'done'];

router.post('/:projectId/tasks', requireUser, requireMembership, (req, res) => {
  const { title, deadline, assignee_id } = req.body;
  if (!title) return res.status(400).json({ error: 'title required' });

  const db = getDb();

  if (assignee_id) {
    const member = db
      .prepare(
        'SELECT user_id FROM users_projects WHERE user_id = ? AND project_id = ?',
      )
      .get(assignee_id, req.params.projectId);
    if (!member) return res.status(400).json({ error: 'assignee not a project member' });
  }

  const id = crypto.randomUUID();
  const status = assignee_id ? 'taken' : 'open';

  db.prepare(
    'INSERT INTO tasks (id, project_id, title, deadline, assignee_id, status) VALUES (?, ?, ?, ?, ?, ?)',
  ).run(id, req.params.projectId, title, deadline ?? null, assignee_id ?? null, status);

  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(id);

  if (assignee_id) {
    const wss = req.app.get('wss');
    if (wss) {
      const payload = JSON.stringify({
        type: 'task_assigned',
        taskId: task.id,
        taskTitle: task.title,
        assigneeId: assignee_id,
        projectId: task.project_id,
      });
      wss.clients.forEach((client) => {
        if (client.userId === assignee_id && client.readyState === 1) {
          client.send(payload);
        }
      });
    }
  }

  return res.status(201).json(task);
});

router.patch('/:projectId/tasks/:taskId', requireUser, requireMembership, (req, res) => {
  const { title, deadline, assignee_id, status, updated_at: clientUpdatedAt } = req.body;

  const db = getDb();
  const task = db
    .prepare('SELECT * FROM tasks WHERE id = ? AND project_id = ?')
    .get(req.params.taskId, req.params.projectId);
  if (!task) return res.status(404).json({ error: 'task not found' });

  if (status && !VALID_STATUSES.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${VALID_STATUSES.join(', ')}` });
  }

  // LWW: reject stale writes — client must have seen the current version
  if (clientUpdatedAt !== undefined && task.updated_at > clientUpdatedAt) {
    return res.status(409).json({ error: 'conflict', current: task });
  }

  if (assignee_id) {
    const member = db
      .prepare(
        'SELECT user_id FROM users_projects WHERE user_id = ? AND project_id = ?',
      )
      .get(assignee_id, req.params.projectId);
    if (!member) return res.status(400).json({ error: 'assignee not a project member' });
  }

  const newTitle = title ?? task.title;
  const newDeadline = deadline !== undefined ? (deadline ?? null) : task.deadline;
  const newAssignee = assignee_id !== undefined ? (assignee_id ?? null) : task.assignee_id;
  const newStatus =
    status ??
    (assignee_id !== undefined && !assignee_id && task.status === 'taken'
      ? 'open'
      : task.status);

  db.prepare(
    `UPDATE tasks SET title = ?, deadline = ?, assignee_id = ?, status = ?,
     updated_at = unixepoch() * 1000 WHERE id = ?`,
  ).run(newTitle, newDeadline, newAssignee, newStatus, req.params.taskId);

  const updated = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.taskId);

  broadcastToProject(req.app.get('wss'), req.params.projectId, { type: 'task_updated', task: updated });

  const assigneeChanged = assignee_id !== undefined && assignee_id !== task.assignee_id;
  if (assigneeChanged && newAssignee) {
    const wss = req.app.get('wss');
    if (wss) {
      const payload = JSON.stringify({
        type: 'task_assigned',
        taskId: updated.id,
        taskTitle: updated.title,
        assigneeId: newAssignee,
        projectId: updated.project_id,
      });
      wss.clients.forEach((client) => {
        if (client.userId === newAssignee && client.readyState === 1) {
          client.send(payload);
        }
      });
    }
  }

  return res.json(updated);
});

router.patch('/:projectId/members/:userId', requireUser, requireLead, (req, res) => {
  const { role } = req.body;
  if (!VALID_ROLES.includes(role)) {
    return res
      .status(400)
      .json({ error: `role must be one of: ${VALID_ROLES.join(', ')}` });
  }
  const db = getDb();
  const membership = db
    .prepare(
      'SELECT user_id FROM users_projects WHERE user_id = ? AND project_id = ?',
    )
    .get(req.params.userId, req.params.projectId);
  if (!membership) return res.status(404).json({ error: 'member not found' });

  db.prepare(
    'UPDATE users_projects SET role = ? WHERE user_id = ? AND project_id = ?',
  ).run(role, req.params.userId, req.params.projectId);

  return res.json({
    user_id: req.params.userId,
    project_id: req.params.projectId,
    role,
  });
});

router.delete('/:projectId/tasks/:taskId', requireUser, requireMembership, (req, res) => {
  const db = getDb();
  const task = db
    .prepare('SELECT id FROM tasks WHERE id = ? AND project_id = ?')
    .get(req.params.taskId, req.params.projectId);
  if (!task) return res.status(404).json({ error: 'task not found' });

  db.prepare('DELETE FROM tasks WHERE id = ?').run(req.params.taskId);
  return res.status(204).end();
});

module.exports = router;
