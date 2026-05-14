const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const rateLimit = require('express-rate-limit');
const { getDb } = require('../db/schema');

const router = express.Router();

const BCRYPT_ROUNDS = 12;

const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too many requests' },
});

router.use(['/login', '/register'], authLimiter);

router.post('/register', async (req, res) => {
  const { name, email, password } = req.body;
  if (!name || !email || !password) {
    return res.status(400).json({ error: 'name, email and password required' });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: 'password must be at least 8 characters' });
  }

  const db = getDb();
  const id = crypto.randomUUID();
  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

  try {
    db.prepare(
      'INSERT INTO users (id, name, email, password_hash) VALUES (?, ?, ?, ?)',
    ).run(id, name, email, passwordHash);

    const user = db
      .prepare('SELECT id, name, email, created_at FROM users WHERE id = ?')
      .get(id);

    return req.session.regenerate((err) => {
      if (err) return res.status(500).json({ error: 'session error' });
      req.session.userId = id;
      req.session.save(() => res.status(201).json(user));
    });
  } catch (err) {
    if (err.message.includes('UNIQUE constraint failed')) {
      return res.status(409).json({ error: 'email already in use' });
    }
    throw err;
  }
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password required' });
  }

  const db = getDb();
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
  if (!user) {
    return res.status(401).json({ error: 'invalid credentials' });
  }

  const match = await bcrypt.compare(password, user.password_hash);
  if (!match) {
    return res.status(401).json({ error: 'invalid credentials' });
  }

  return req.session.regenerate((err) => {
    if (err) return res.status(500).json({ error: 'session error' });
    req.session.userId = user.id;
    req.session.save(() =>
      res.json({
        id: user.id,
        name: user.name,
        email: user.email,
        created_at: user.created_at,
      }),
    );
  });
});

router.post('/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) return res.status(500).json({ error: 'logout failed' });
    res.clearCookie('connect.sid');
    return res.json({ ok: true });
  });
});

router.get('/me', (req, res) => {
  if (!req.session.userId) {
    return res.status(401).json({ error: 'not authenticated' });
  }
  const db = getDb();
  const user = db
    .prepare('SELECT id, name, email, created_at FROM users WHERE id = ?')
    .get(req.session.userId);
  if (!user) return res.status(401).json({ error: 'not authenticated' });
  return res.json(user);
});

module.exports = router;
