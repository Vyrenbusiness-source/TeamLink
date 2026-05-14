const express = require('express');
const { getDb } = require('../db/schema');
const { requireUser } = require('../middleware/auth');
const { broadcastToProject } = require('../utils/broadcast');

const router = express.Router();

const VALID_STATUSES = ['open', 'taken', 'done'];

router.patch('/:taskId', requireUser, (req, res) => {
  const { status, assignee_id } = req.body;

  if (status !== undefined && !VALID_STATUSES.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${VALID_STATUSES.join(', ')}` });
  }

  const db = getDb();
  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.taskId);
  if (!task) return res.status(404).json({ error: 'task not found' });

  const membership = db
    .prepare(
      'SELECT user_id FROM users_projects WHERE user_id = ? AND project_id = ?',
    )
    .get(req.userId, task.project_id);
  if (!membership) return res.status(403).json({ error: 'not a project member' });

  const newStatus = status ?? task.status;
  const newAssignee = assignee_id !== undefined ? assignee_id : task.assignee_id;

  db.prepare(
    'UPDATE tasks SET status = ?, assignee_id = ?, updated_at = unixepoch() WHERE id = ?',
  ).run(newStatus, newAssignee, req.params.taskId);

  const updated = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.taskId);

  broadcastToProject(req.app.get('wss'), task.project_id, {
    type: 'task_updated',
    task: updated,
  });

  return res.json(updated);
});

module.exports = router;
