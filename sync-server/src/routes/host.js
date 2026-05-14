const express = require('express');
const { getState } = require('../utils/cloudflared');

const router = express.Router();

function isLocal(req) {
  const ip = req.ip || req.connection?.remoteAddress || '';
  return ip === '127.0.0.1' || ip === '::1' || ip === '::ffff:127.0.0.1';
}

router.get('/tunnel', (req, res) => {
  if (!isLocal(req)) {
    return res.status(403).json({ error: 'forbidden' });
  }
  return res.json(getState());
});

module.exports = router;
