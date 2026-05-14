const crypto = require('crypto');
const express = require('express');
const { getDb } = require('../db/schema');
const { requireUser } = require('../middleware/auth');
const { broadcastToProject } = require('../utils/broadcast');

const router = express.Router();

const VALID_STATUSES = ['open', 'taken', 'done'];
const VALID_PRIORITIES = ['low', 'medium', 'high'];

// GET /tasks/:taskId — einzelne Task abrufen (Membership-Check via task.project_id)
router.get('/:taskId', requireUser, (req, res) => {
  const db = getDb();
  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.taskId);
  if (!task) return res.status(404).json({ error: 'task not found' });

  const membership = db
    .prepare('SELECT user_id FROM users_projects WHERE user_id = ? AND project_id = ?')
    .get(req.userId, task.project_id);
  if (!membership) return res.status(403).json({ error: 'not a project member' });

  return res.json(task);
});

// POST /tasks — neue Task anlegen (project_id im Body, Membership-Check)
router.post('/', requireUser, (req, res) => {
  const { project_id, title, description, priority, deadline, assignee_id } = req.body;
  if (!project_id) return res.status(400).json({ error: 'project_id required' });
  if (!title) return res.status(400).json({ error: 'title required' });

  if (priority !== undefined && !VALID_PRIORITIES.includes(priority)) {
    return res.status(400).json({ error: `priority must be one of: ${VALID_PRIORITIES.join(', ')}` });
  }

  const db = getDb();

  const project = db.prepare('SELECT id FROM projects WHERE id = ?').get(project_id);
  if (!project) return res.status(404).json({ error: 'project not found' });

  const membership = db
    .prepare('SELECT user_id FROM users_projects WHERE user_id = ? AND project_id = ?')
    .get(req.userId, project_id);
  if (!membership) return res.status(403).json({ error: 'not a project member' });

  if (assignee_id) {
    const assigneeMember = db
      .prepare('SELECT user_id FROM users_projects WHERE user_id = ? AND project_id = ?')
      .get(assignee_id, project_id);
    if (!assigneeMember) return res.status(400).json({ error: 'assignee not a project member' });
  }

  const id = crypto.randomUUID();
  const status = assignee_id ? 'taken' : 'open';

  db.prepare(
    `INSERT INTO tasks (id, project_id, title, description, priority, deadline, assignee_id, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(id, project_id, title, description ?? null, priority ?? null, deadline ?? null, assignee_id ?? null, status);

  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(id);

  broadcastToProject(req.app.get('wss'), project_id, { type: 'task_created', task });

  return res.status(201).json(task);
});

// PATCH /tasks/:taskId — Task aktualisieren (status, assignee, description, priority)
router.patch('/:taskId', requireUser, (req, res) => {
  const { status, assignee_id, title, description, priority, deadline, updated_at: clientUpdatedAt } = req.body;

  if (status !== undefined && !VALID_STATUSES.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${VALID_STATUSES.join(', ')}` });
  }
  if (priority !== undefined && priority !== null && !VALID_PRIORITIES.includes(priority)) {
    return res.status(400).json({ error: `priority must be one of: ${VALID_PRIORITIES.join(', ')}` });
  }

  const db = getDb();
  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.taskId);
  if (!task) return res.status(404).json({ error: 'task not found' });

  const membership = db
    .prepare('SELECT user_id FROM users_projects WHERE user_id = ? AND project_id = ?')
    .get(req.userId, task.project_id);
  if (!membership) return res.status(403).json({ error: 'not a project member' });

  // LWW: reject stale writes — client must have seen the current version
  if (clientUpdatedAt !== undefined && task.updated_at > clientUpdatedAt) {
    return res.status(409).json({ error: 'conflict', current: task });
  }

  if (assignee_id) {
    const assigneeMember = db
      .prepare('SELECT user_id FROM users_projects WHERE user_id = ? AND project_id = ?')
      .get(assignee_id, task.project_id);
    if (!assigneeMember) return res.status(400).json({ error: 'assignee not a project member' });
  }

  const newTitle = title !== undefined ? title : task.title;
  const newDescription = description !== undefined ? description : task.description;
  const newPriority = priority !== undefined ? priority : task.priority;
  const newDeadline = deadline !== undefined ? (deadline ?? null) : task.deadline;
  const newAssignee = assignee_id !== undefined ? (assignee_id ?? null) : task.assignee_id;
  const newStatus =
    status ??
    (assignee_id !== undefined && !assignee_id && task.status === 'taken'
      ? 'open'
      : task.status);

  db.prepare(
    `UPDATE tasks
     SET title = ?, description = ?, priority = ?, deadline = ?,
         assignee_id = ?, status = ?, updated_by = ?, updated_at = unixepoch() * 1000
     WHERE id = ?`,
  ).run(newTitle, newDescription, newPriority, newDeadline, newAssignee, newStatus, req.userId, req.params.taskId);

  const updated = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.taskId);

  broadcastToProject(req.app.get('wss'), task.project_id, { type: 'task_updated', task: updated });

  return res.json(updated);
});

// DELETE /tasks/:taskId — Task löschen (nur Leads oder Aufgaben-Ersteller)
router.delete('/:taskId', requireUser, (req, res) => {
  const db = getDb();
  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.taskId);
  if (!task) return res.status(404).json({ error: 'task not found' });

  const membership = db
    .prepare('SELECT role FROM users_projects WHERE user_id = ? AND project_id = ?')
    .get(req.userId, task.project_id);
  if (!membership) return res.status(403).json({ error: 'not a project member' });
  if (membership.role !== 'lead') return res.status(403).json({ error: 'only leads can delete tasks' });

  db.prepare('DELETE FROM tasks WHERE id = ?').run(req.params.taskId);

  broadcastToProject(req.app.get('wss'), task.project_id, {
    type: 'task_deleted',
    taskId: req.params.taskId,
  });

  return res.status(204).end();
});

module.exports = router;
