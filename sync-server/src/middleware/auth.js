const { getDb } = require('../db/schema');

function requireUser(req, res, next) {
  const sessionUserId = req.session && req.session.userId;
  // Header-based auth is only honored when explicitly enabled (for tests).
  // Previously this triggered on any non-"production" NODE_ENV, which is a
  // full auth bypass in any unconfigured deployment.
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
  const { getDb } = require('../db/schema');
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

module.exports = { requireUser, requireMembership, requireLead };
