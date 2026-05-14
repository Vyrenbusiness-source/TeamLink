const { randomUUID } = require('crypto');
const logger = require('../utils/logger');

function requestLogger(req, res, next) {
  req.id = randomUUID();
  req.log = logger.child({ reqId: req.id });

  const start = Date.now();

  res.on('finish', () => {
    const ms = Date.now() - start;
    const level = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info';
    req.log[level](
      { method: req.method, url: req.originalUrl, status: res.statusCode, ms },
      'request',
    );
  });

  next();
}

module.exports = requestLogger;
