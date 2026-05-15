const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const { getDb } = require('../db/schema');

const router = express.Router();

const BCRYPT_ROUNDS = 12;
const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL_DAYS = 30;

const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too many requests' },
  skip: () => process.env.NODE_ENV === 'test',
});

router.use(['/login', '/register', '/refresh'], authLimiter);

function getSecrets() {
  const access = process.env.JWT_ACCESS_SECRET;
  const refresh = process.env.JWT_REFRESH_SECRET;
  if (!access) throw new Error('JWT_ACCESS_SECRET is not set');
  if (!refresh) throw new Error('JWT_REFRESH_SECRET is not set');
  return { access, refresh };
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function issueTokenPair(userId) {
  const { access, refresh } = getSecrets();
  const jti = crypto.randomUUID();

  const accessToken = jwt.sign({ sub: userId }, access, {
    expiresIn: ACCESS_TOKEN_TTL,
    algorithm: 'HS256',
  });

  const refreshToken = jwt.sign({ sub: userId, jti }, refresh, {
    expiresIn: `${REFRESH_TOKEN_TTL_DAYS}d`,
    algorithm: 'HS256',
  });

  const expiresAt =
    Math.floor(Date.now() / 1000) + REFRESH_TOKEN_TTL_DAYS * 86400;

  const db = getDb();
  db.prepare(
    `INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at)
     VALUES (?, ?, ?, ?)`,
  ).run(jti, userId, hashToken(refreshToken), expiresAt);

  return { accessToken, refreshToken };
}

function publicUser(user) {
  // Must match shared-models/schemas/user.json. The dart client uses
  // freezed's `required int updatedAt` cast, so omitting updated_at
  // crashes the login flow with "type 'Null' is not a subtype of 'num'".
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    avatar_url: user.avatar_url ?? null,
    created_at: user.created_at,
    updated_at: user.updated_at,
  };
}

// POST /auth/register
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
      .prepare('SELECT id, name, email, avatar_url, created_at, updated_at FROM users WHERE id = ?')
      .get(id);

    const { accessToken, refreshToken } = issueTokenPair(id);

    // Also set session for backward compat with WebSocket upgrade.
    return req.session.regenerate((err) => {
      if (err) return res.status(500).json({ error: 'session error' });
      req.session.userId = id;
      req.session.save(() =>
        res.status(201).json({
          user: publicUser(user),
          access_token: accessToken,
          refresh_token: refreshToken,
          token_type: 'Bearer',
          expires_in: 900,
        }),
      );
    });
  } catch (err) {
    if (err.message.includes('UNIQUE constraint failed')) {
      return res.status(409).json({ error: 'email already in use' });
    }
    throw err;
  }
});

// POST /auth/login
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

  const { accessToken, refreshToken } = issueTokenPair(user.id);

  return req.session.regenerate((err) => {
    if (err) return res.status(500).json({ error: 'session error' });
    req.session.userId = user.id;
    req.session.save(() =>
      res.json({
        user: publicUser(user),
        access_token: accessToken,
        refresh_token: refreshToken,
        token_type: 'Bearer',
        expires_in: 900,
      }),
    );
  });
});

// POST /auth/refresh — rotate refresh token, issue new access token
router.post('/refresh', (req, res) => {
  const { refresh_token } = req.body;
  if (!refresh_token) {
    return res.status(400).json({ error: 'refresh_token required' });
  }

  const { refresh } = getSecrets();
  let payload;
  try {
    payload = jwt.verify(refresh_token, refresh);
  } catch {
    return res.status(401).json({ error: 'invalid or expired refresh token' });
  }

  const db = getDb();
  const stored = db
    .prepare(
      `SELECT id, user_id, expires_at, revoked_at
       FROM refresh_tokens
       WHERE id = ? AND token_hash = ?`,
    )
    .get(payload.jti, hashToken(refresh_token));

  if (!stored) {
    return res.status(401).json({ error: 'refresh token not found' });
  }
  if (stored.revoked_at !== null) {
    return res.status(401).json({ error: 'refresh token has been revoked' });
  }
  if (stored.expires_at < Math.floor(Date.now() / 1000)) {
    return res.status(401).json({ error: 'refresh token expired' });
  }

  // Revoke old token, issue new pair (rotation).
  db.prepare(
    `UPDATE refresh_tokens SET revoked_at = unixepoch() WHERE id = ?`,
  ).run(stored.id);

  const { accessToken, refreshToken: newRefreshToken } = issueTokenPair(stored.user_id);

  return res.json({
    access_token: accessToken,
    refresh_token: newRefreshToken,
    token_type: 'Bearer',
    expires_in: 900,
  });
});

// POST /auth/revoke — invalidate a refresh token (explicit logout)
router.post('/revoke', (req, res) => {
  const { refresh_token } = req.body;
  if (!refresh_token) {
    return res.status(400).json({ error: 'refresh_token required' });
  }

  const { refresh } = getSecrets();
  let payload;
  try {
    payload = jwt.verify(refresh_token, refresh, { ignoreExpiration: true });
  } catch {
    return res.status(400).json({ error: 'invalid token' });
  }

  const db = getDb();
  db.prepare(
    `UPDATE refresh_tokens SET revoked_at = unixepoch()
     WHERE id = ? AND token_hash = ? AND revoked_at IS NULL`,
  ).run(payload.jti, hashToken(refresh_token));

  // Also destroy session if present.
  if (req.session && req.session.userId) {
    req.session.destroy(() => {});
  }

  return res.json({ ok: true });
});

// POST /auth/logout — session logout + revoke all refresh tokens for user
router.post('/logout', (req, res) => {
  const userId = (req.session && req.session.userId) || req.userId;

  if (userId) {
    const db = getDb();
    db.prepare(
      `UPDATE refresh_tokens SET revoked_at = unixepoch()
       WHERE user_id = ? AND revoked_at IS NULL`,
    ).run(userId);
  }

  req.session.destroy((err) => {
    if (err) return res.status(500).json({ error: 'logout failed' });
    res.clearCookie('connect.sid');
    return res.json({ ok: true });
  });
});

// GET /auth/me
router.get('/me', (req, res) => {
  const userId =
    (req.session && req.session.userId) || req.userId;
  if (!userId) {
    return res.status(401).json({ error: 'not authenticated' });
  }
  const db = getDb();
  const user = db
    .prepare('SELECT id, name, email, avatar_url, created_at, updated_at FROM users WHERE id = ?')
    .get(userId);
  if (!user) return res.status(401).json({ error: 'not authenticated' });
  return res.json(user);
});

module.exports = router;
