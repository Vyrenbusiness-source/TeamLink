require('dotenv').config();
const { createServer } = require('http');
const { WebSocketServer } = require('ws');
const app = require('./app');
const { initDb } = require('./db/schema');
const { startTunnel, stopTunnel } = require('./utils/cloudflared');
const logger = require('./utils/logger');

const PORT = process.env.PORT || 3000;
const ENABLE_TUNNEL = process.env.ENABLE_TUNNEL !== '0';

initDb();

const httpServer = createServer(app);
// noServer mode lets us run the session middleware on the upgrade request
// before deciding whether to accept the connection.
const wss = new WebSocketServer({ noServer: true });

app.set('wss', wss);

httpServer.on('upgrade', (req, socket, head) => {
  // Run the same session middleware as on HTTP — this populates req.session
  // from the signed cookie sent by the browser/Flutter client.
  app.sessionMiddleware(req, {}, () => {
    const userId = req.session && req.session.userId;
    if (!userId) {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => {
      ws.userId = userId;
      wss.emit('connection', ws, req);
    });
  });
});

wss.on('connection', (ws) => {
  ws.on('message', (data) => {
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch {
      return; // never echo unparseable frames
    }
    if (!msg || typeof msg !== 'object') return;
    // ws.userId is set from the validated session, never from the client.
    if (msg.type === 'join' && typeof msg.projectId === 'string') {
      ws.projectId = msg.projectId;
    }
    // No generic broadcast — routes emit targeted messages via
    // wss.clients.forEach using the verified ws.userId / ws.projectId.
  });
});

httpServer.listen(PORT, () => {
  logger.info({ port: PORT }, 'TeamLink server running');
  if (ENABLE_TUNNEL) {
    startTunnel({ port: PORT });
  }
});

function shutdown() {
  stopTunnel();
  httpServer.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 2000).unref();
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
