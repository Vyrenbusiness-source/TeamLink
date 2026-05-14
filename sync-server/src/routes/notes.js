const express = require('express');
const crypto = require('crypto');
const { getDb } = require('../db/schema');
const { requireUser, requireMembership } = require('../middleware/auth');

const router = express.Router();

router.get('/:projectId/notes', requireUser, requireMembership, (req, res) => {
  const db = getDb();
  let note = db
    .prepare('SELECT * FROM notes WHERE project_id = ?')
    .get(req.params.projectId);
  if (!note) {
    const id = crypto.randomUUID();
    db.prepare('INSERT INTO notes (id, project_id) VALUES (?, ?)').run(
      id,
      req.params.projectId,
    );
    note = db.prepare('SELECT * FROM notes WHERE id = ?').get(id);
  }
  return res.json(note);
});

router.patch('/:projectId/notes', requireUser, requireMembership, (req, res) => {
  const { content } = req.body;
  if (content === undefined)
    return res.status(400).json({ error: 'content required' });

  const db = getDb();
  let note = db
    .prepare('SELECT * FROM notes WHERE project_id = ?')
    .get(req.params.projectId);
  if (!note) {
    const id = crypto.randomUUID();
    db.prepare('INSERT INTO notes (id, project_id) VALUES (?, ?)').run(
      id,
      req.params.projectId,
    );
    note = { id };
  }

  db.prepare(
    'UPDATE notes SET content = ?, updated_at = unixepoch(), updated_by = ? WHERE id = ?',
  ).run(content, req.userId, note.id);

  const updated = db
    .prepare('SELECT * FROM notes WHERE id = ?')
    .get(note.id);

  const wss = req.app.get('wss');
  if (wss) {
    const msg = JSON.stringify({
      type: 'note_update',
      projectId: req.params.projectId,
      note: updated,
    });
    wss.clients.forEach((client) => {
      if (
        client.projectId === req.params.projectId &&
        client.readyState === 1
      ) {
        client.send(msg);
      }
    });
  }

  return res.json(updated);
});

module.exports = router;
