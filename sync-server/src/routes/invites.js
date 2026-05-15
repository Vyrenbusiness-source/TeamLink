const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const rateLimit = require('express-rate-limit');
const { getDb } = require('../db/schema');
const { requireUser } = require('../middleware/auth');

const router = express.Router();

const BCRYPT_ROUNDS = 12;
const DEFAULT_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const MAX_TTL_HOURS = 24 * 30; // cap at 30 days to avoid eternal tokens
const VALID_ROLES = ['lead', 'member', 'observer'];

// Token-existence probes (GET /:token) and accept attempts must be limited
// to prevent enumeration / brute-force from anonymous callers.
const inviteLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too many requests' },
});

function generateToken() {
  return 'tlk_' + crypto.randomBytes(18).toString('base64url');
}

router.post('/', requireUser, (req, res) => {
  const { project_id: projectId, role = 'member', ttl_hours } = req.body || {};
  if (!VALID_ROLES.includes(role)) {
    return res
      .status(400)
      .json({ error: `role must be one of: ${VALID_ROLES.join(', ')}` });
  }

  const db = getDb();

  if (projectId) {
    const membership = db
      .prepare(
        'SELECT role FROM users_projects WHERE user_id = ? AND project_id = ?',
      )
      .get(req.userId, projectId);
    if (!membership) {
      return res.status(403).json({ error: 'not a project member' });
    }
    if (membership.role !== 'lead') {
      return res.status(403).json({ error: 'lead role required' });
    }
  }

  const token = generateToken();
  const ttlMs = Number.isFinite(ttl_hours)
    ? Math.max(1, Math.min(MAX_TTL_HOURS, ttl_hours)) * 60 * 60 * 1000
    : DEFAULT_TTL_MS;
  const expiresAt = Math.floor((Date.now() + ttlMs) / 1000);

  db.prepare(
    `INSERT INTO invite_tokens (token, project_id, role, created_by, expires_at)
     VALUES (?, ?, ?, ?, ?)`,
  ).run(token, projectId ?? null, role, req.userId, expiresAt);

  return res.status(201).json({
    token,
    project_id: projectId ?? null,
    role,
    expires_at: expiresAt,
  });
});

router.get('/:token', inviteLimiter, (req, res) => {
  const db = getDb();
  const invite = db
    .prepare(
      `SELECT it.token, it.project_id, it.role, it.expires_at, it.used_by,
              p.name AS project_name
       FROM invite_tokens it
       LEFT JOIN projects p ON p.id = it.project_id
       WHERE it.token = ?`,
    )
    .get(req.params.token);

  if (!invite) return res.status(404).json({ error: 'invite not found' });
  if (invite.used_by) return res.status(410).json({ error: 'invite already used' });
  if (invite.expires_at && invite.expires_at * 1000 < Date.now()) {
    return res.status(410).json({ error: 'invite expired' });
  }

  return res.json({
    token: invite.token,
    project_id: invite.project_id,
    project_name: invite.project_name,
    role: invite.role,
    expires_at: invite.expires_at,
  });
});

router.post('/:token/accept', inviteLimiter, async (req, res) => {
  const { name, email, password } = req.body || {};
  if (!name || !email || !password) {
    return res.status(400).json({ error: 'name, email and password required' });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: 'password must be at least 8 characters' });
  }

  const db = getDb();
  const invite = db
    .prepare('SELECT * FROM invite_tokens WHERE token = ?')
    .get(req.params.token);

  if (!invite) return res.status(404).json({ error: 'invite not found' });
  if (invite.used_by) return res.status(410).json({ error: 'invite already used' });
  if (invite.expires_at && invite.expires_at * 1000 < Date.now()) {
    return res.status(410).json({ error: 'invite expired' });
  }

  const userId = crypto.randomUUID();
  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  const normalizedEmail = String(email).trim().toLowerCase();

  const tx = db.transaction(() => {
    db.prepare(
      'INSERT INTO users (id, name, email, password_hash) VALUES (?, ?, ?, ?)',
    ).run(userId, name, normalizedEmail, passwordHash);

    if (invite.project_id) {
      db.prepare(
        'INSERT INTO users_projects (user_id, project_id, role) VALUES (?, ?, ?)',
      ).run(userId, invite.project_id, invite.role);
    }

    db.prepare(
      'UPDATE invite_tokens SET used_by = ?, used_at = unixepoch() WHERE token = ?',
    ).run(userId, req.params.token);
  });

  try {
    tx();
  } catch (err) {
    if (err.message.includes('UNIQUE constraint failed: users.email')) {
      return res.status(409).json({ error: 'email already in use' });
    }
    throw err;
  }

  const user = db
    .prepare(
      'SELECT id, name, email, avatar_url, created_at, updated_at FROM users WHERE id = ?',
    )
    .get(userId);

  // Regenerate the session id so a pre-existing (possibly attacker-fixed)
  // session cookie cannot be used to impersonate the new user.
  req.session.regenerate((err) => {
    if (err) return res.status(500).json({ error: 'session error' });
    req.session.userId = userId;
    req.session.save(() => {
      res.status(201).json({
        user,
        project_id: invite.project_id,
        role: invite.role,
      });
    });
  });
});

module.exports = router;
