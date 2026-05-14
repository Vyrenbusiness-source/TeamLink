const express = require('express');
const crypto = require('crypto');
const { getDb } = require('../db/schema');
const { requireUser } = require('../middleware/auth');

const router = express.Router();

router.get('/conversations', requireUser, (req, res) => {
  const db = getDb();
  const rows = db
    .prepare(
      `SELECT id, name, email, last_content, last_at, last_sender_id
       FROM (
         SELECT
           u.id, u.name, u.email,
           m.content AS last_content,
           m.created_at AS last_at,
           m.sender_id AS last_sender_id,
           ROW_NUMBER() OVER (
             PARTITION BY u.id
             ORDER BY m.created_at DESC
           ) AS rn
         FROM messages m
         JOIN users u
           ON u.id = CASE WHEN m.sender_id = ? THEN m.recipient_id ELSE m.sender_id END
         WHERE m.sender_id = ? OR m.recipient_id = ?
       )
       WHERE rn = 1
       ORDER BY last_at DESC`,
    )
    .all(req.userId, req.userId, req.userId);
  return res.json(rows);
});

router.get('/users', requireUser, (req, res) => {
  const db = getDb();
  const rows = db
    .prepare(
      `SELECT DISTINCT u.id, u.name, u.email
       FROM users u
       JOIN users_projects up ON up.user_id = u.id
       WHERE up.project_id IN (
         SELECT project_id FROM users_projects WHERE user_id = ?
       )
       AND u.id != ?
       ORDER BY u.name`,
    )
    .all(req.userId, req.userId);
  return res.json(rows);
});

router.get('/:partnerId', requireUser, (req, res) => {
  const db = getDb();
  const rows = db
    .prepare(
      `SELECT * FROM messages
       WHERE (sender_id = ? AND recipient_id = ?)
          OR (sender_id = ? AND recipient_id = ?)
       ORDER BY created_at ASC
       LIMIT 100`,
    )
    .all(req.userId, req.params.partnerId, req.params.partnerId, req.userId);
  return res.json(rows);
});

router.post('/:partnerId', requireUser, (req, res) => {
  const { content } = req.body;
  if (!content || !content.trim()) {
    return res.status(400).json({ error: 'content required' });
  }

  const db = getDb();
  const partner = db.prepare('SELECT id FROM users WHERE id = ?').get(req.params.partnerId);
  if (!partner) return res.status(404).json({ error: 'user not found' });

  const id = crypto.randomUUID();
  db.prepare(
    'INSERT INTO messages (id, sender_id, recipient_id, content) VALUES (?, ?, ?, ?)',
  ).run(id, req.userId, req.params.partnerId, content.trim());

  const message = db.prepare('SELECT * FROM messages WHERE id = ?').get(id);

  const wss = req.app.get('wss');
  if (wss) {
    const payload = JSON.stringify({ type: 'dm', message });
    wss.clients.forEach((client) => {
      if (
        (client.userId === req.params.partnerId || client.userId === req.userId) &&
        client.readyState === 1
      ) {
        client.send(payload);
      }
    });
  }

  return res.status(201).json(message);
});

module.exports = router;
