'use strict';

const { WS_EVENTS } = require('./events');
const logger = require('../utils/logger');

const HEARTBEAT_INTERVAL_MS = 30_000;

function setupWsHandler(wss) {
  const heartbeat = setInterval(() => {
    wss.clients.forEach((ws) => {
      if (!ws.isAlive) {
        ws.terminate();
        return;
      }
      ws.isAlive = false;
      ws.ping();
    });
  }, HEARTBEAT_INTERVAL_MS);

  wss.on('close', () => clearInterval(heartbeat));

  wss.on('connection', (ws) => {
    ws.isAlive = true;

    ws.on('pong', () => {
      ws.isAlive = true;
    });

    ws.send(JSON.stringify({ type: WS_EVENTS.WELCOME, userId: ws.userId }));

    ws.on('message', (data) => {
      let msg;
      try {
        msg = JSON.parse(data.toString());
      } catch {
        return;
      }
      if (!msg || typeof msg !== 'object') return;

      switch (msg.type) {
        case WS_EVENTS.PING:
          ws.send(JSON.stringify({ type: WS_EVENTS.PONG }));
          break;
        case WS_EVENTS.JOIN:
          if (typeof msg.projectId === 'string') {
            ws.projectId = msg.projectId;
          }
          break;
        case WS_EVENTS.LEAVE:
          ws.projectId = undefined;
          break;
        default:
          break;
      }
    });

    ws.on('error', (err) => {
      logger.warn({ err, userId: ws.userId }, 'ws client error');
    });
  });
}

module.exports = { setupWsHandler };
