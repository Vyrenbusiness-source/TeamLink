const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const session = require('express-session');
const SqliteStore = require('better-sqlite3-session-store')(session);
const { getDb } = require('./db/schema');
const logger = require('./utils/logger');
const requestLogger = require('./middleware/requestLogger');

function resolveSessionSecret() {
  const fromEnv = process.env.SESSION_SECRET;
  if (fromEnv && fromEnv.length >= 32) return fromEnv;
  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      'SESSION_SECRET must be set to a value of at least 32 characters in production',
    );
  }
  if (fromEnv) {
    throw new Error('SESSION_SECRET must be at least 32 characters long');
  }
  return crypto.randomBytes(48).toString('hex');
}

function resolveAllowedOrigins() {
  const raw = process.env.ALLOWED_ORIGINS;
  if (raw && raw.trim().length > 0) {
    return raw
      .split(',')
      .map((o) => o.trim())
      .filter((o) => o.length > 0);
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      'ALLOWED_ORIGINS must be set in production (comma-separated list of trusted origins)',
    );
  }
  return ['http://localhost:3000', 'http://127.0.0.1:3000'];
}

const TRYCLOUDFLARE_HOST_RE = /^https:\/\/[a-z0-9-]+\.trycloudflare\.com$/i;

const sessionSecret = resolveSessionSecret();
const allowedOrigins = resolveAllowedOrigins();

const app = express();

function corsOriginCheck(origin, callback) {
  if (!origin) return callback(null, true);
  if (allowedOrigins.includes(origin)) return callback(null, true);
  const { getState } = require('./utils/cloudflared');
  const tunnel = getState().url;
  if (tunnel && origin === tunnel) return callback(null, true);
  if (TRYCLOUDFLARE_HOST_RE.test(origin)) {
    // Fallback in case the tunnel URL is not yet known when the first
    // request arrives. The host part is still constrained to the
    // trycloudflare zone, which we control.
    return callback(null, true);
  }
  return callback(new Error(`Origin ${origin} not allowed by CORS`));
}

app.use(
  cors({
    origin: corsOriginCheck,
    credentials: true,
  }),
);

app.set('trust proxy', 1);
app.use(requestLogger);
app.use(express.json());

// Persistenter Session-Store auf Basis von better-sqlite3.
// Unterdrueckt die 'MemoryStore is not designed for production' Warnung,
// und ueberlebt zudem Server-Restarts (User bleiben eingeloggt).
const sessionMiddleware = session({
  store: new SqliteStore({
    client: getDb(),
    expired: {
      clear: true,
      intervalMs: 15 * 60 * 1000,
    },
  }),
  secret: sessionSecret,
  resave: false,
  saveUninitialized: false,
  proxy: true,
  cookie: {
    httpOnly: true,
    secure: 'auto',
    sameSite: 'lax',
    maxAge: 7 * 24 * 60 * 60 * 1000,
  },
});

app.use(sessionMiddleware);

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/auth', require('./routes/auth'));
app.use('/projects', require('./routes/projects'));
app.use('/projects', require('./routes/notes'));
app.use('/tasks', require('./routes/tasks'));
app.use('/messages', require('./routes/messages'));
app.use('/invites', require('./routes/invites'));
app.use('/host', require('./routes/host'));

// Central error handler — keeps the server up if a route throws.
app.use((err, req, res, _next) => {
  if (res.headersSent) return;

  const log = req.log || logger;

  if (err && err.message && /not allowed by CORS/i.test(err.message)) {
    log.warn({ err }, 'cors rejected');
    return res.status(403).json({ error: 'origin not allowed' });
  }

  const name = err && err.name;

  if (name === 'JsonWebTokenError' || name === 'NotBeforeError') {
    log.warn({ err }, 'jwt invalid');
    return res.status(401).json({ error: 'invalid token' });
  }

  if (name === 'TokenExpiredError') {
    log.warn({ err }, 'jwt expired');
    return res.status(401).json({ error: 'token expired' });
  }

  // express-json body-parser parse error
  if (err.type === 'entity.parse.failed') {
    log.warn({ err }, 'bad json body');
    return res.status(400).json({ error: 'invalid json' });
  }

  const status = (err.status || err.statusCode) >= 400 && (err.status || err.statusCode) < 600
    ? err.status || err.statusCode
    : 500;

  if (status >= 500) {
    log.error({ err }, 'unhandled error');
  } else {
    log.warn({ err }, 'client error');
  }

  res.status(status).json({ error: err.expose ? err.message : 'internal server error' });
});

app.sessionMiddleware = sessionMiddleware;
module.exports = app;
