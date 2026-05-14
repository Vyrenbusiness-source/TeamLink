const jwt = require('jsonwebtoken');
const { getDb } = require('../db/schema');

const ACCESS_SECRET = () => {
  const s = process.env.JWT_ACCESS_SECRET;
  if (!s) throw new Error('JWT_ACCESS_SECRET is not set');
  return s;
};

// Extract userId from JWT Bearer token or fall back to session/dev-header.
function requireUser(req, res, next) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    try {
      const payload = jwt.verify(token, ACCESS_SECRET());
      req.userId = payload.sub;
      return next();
    } catch {
      return res.status(401).json({ error: 'invalid or expired token' });
    }
  }

  // Session fallback — keeps WebSocket upgrade path and legacy clients working.
  const sessionUserId = req.session && req.session.userId;
  const headerUserId =
    process.env.ALLOW_DEV_AUTH === '1' && req.headers['x-user-id'];
  const userId = sessionUserId || headerUserId;
  if (!userId) {
    return res.status(401).json({ error: 'authentication required' });
  }
  req.userId = userId;
  next();
}

function requireLead(req, res, next) {
  const projectId = req.params.projectId;
  if (!projectId) return res.status(400).json({ error: 'projectId required' });
  const db = getDb();
  const row = db
    .prepare(
      'SELECT role FROM users_projects WHERE user_id = ? AND project_id = ?',
    )
    .get(req.userId, projectId);
  if (!row) return res.status(403).json({ error: 'not a project member' });
  if (row.role !== 'lead') {
    return res.status(403).json({ error: 'lead role required' });
  }
  next();
}

function requireMembership(req, res, next) {
  const projectId = req.params.projectId;
  if (!projectId) {
    return res.status(400).json({ error: 'projectId required' });
  }
  const db = getDb();
  const membership = db
    .prepare(
      'SELECT user_id FROM users_projects WHERE user_id = ? AND project_id = ?',
    )
    .get(req.userId, projectId);
  if (!membership) {
    return res.status(403).json({ error: 'not a project member' });
  }
  next();
}

// Verify an access token from a WS upgrade query param (?token=...).
// Returns userId or null.
function verifyAccessToken(token) {
  try {
    const payload = jwt.verify(token, ACCESS_SECRET());
    return payload.sub;
  } catch {
    return null;
  }
}

module.exports = { requireUser, requireMembership, requireLead, verifyAccessToken };
