const pino = require('pino');

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  serializers: {
    err: pino.stdSerializers.err,
    req: pino.stdSerializers.req,
    res: pino.stdSerializers.res,
  },
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      '*.password',
      '*.passwordHash',
      '*.token',
      '*.refreshToken',
      '*.secret',
    ],
    censor: '[REDACTED]',
  },
});

module.exports = logger;
