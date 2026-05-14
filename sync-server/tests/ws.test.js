process.env.DB_PATH = ':memory:';
process.env.NODE_ENV = 'test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-mindestens-32-zeichen-lang';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-mindestens-32-zeichen-lang';
process.env.ALLOW_DEV_AUTH = '1';

const http = require('http');
const { WebSocketServer } = require('ws');
const WebSocket = require('ws');
const request = require('supertest');
const app = require('../src/app');
const { initDb, getDb } = require('../src/db/schema');
const { verifyAccessToken } = require('../src/middleware/auth');
const { setupWsHandler } = require('../src/ws/handler');
const { WS_EVENTS } = require('../src/ws/events');

let httpServer;
let wss;
let serverPort;

function wsUrl(token) {
  return `ws://127.0.0.1:${serverPort}?token=${encodeURIComponent(token)}`;
}

/**
 * Connects and augments the WebSocket with a buffered nextMsg() helper.
 *
 * The message listener is registered BEFORE the open event fires so that
 * frames arriving in the same TCP chunk as the 101 handshake are never
 * lost (open + message can fire synchronously in the same data event).
 */
function wsConnect(token) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl(token));

    // Buffer every message immediately so none are lost.
    const buf = [];
    const waitQueue = [];
    ws.on('message', (data) => {
      let msg;
      try { msg = JSON.parse(data.toString()); } catch { return; }
      if (waitQueue.length > 0) {
        const { res, timer } = waitQueue.shift();
        clearTimeout(timer);
        res(msg);
      } else {
        buf.push(msg);
      }
    });

    ws.nextMsg = (ms = 2000) =>
      new Promise((res, rej) => {
        if (buf.length > 0) { res(buf.shift()); return; }
        const timer = setTimeout(
          () => rej(new Error('ws message timeout')),
          ms,
        );
        waitQueue.push({ res, timer });
      });

    const timeout = setTimeout(() => reject(new Error('connect timeout')), 3000);
    ws.once('open', () => { clearTimeout(timeout); resolve(ws); });
    ws.once('error', (err) => { clearTimeout(timeout); reject(err); });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
async function registerUser(name, email) {
  const res = await request(app)
    .post('/auth/register')
    .send({ name, email, password: 'password123' });
  return { token: res.body.access_token, userId: res.body.user.id };
}

async function createProject(token, name = 'WsTestProject') {
  const res = await request(app)
    .post('/projects')
    .set({ Authorization: `Bearer ${token}` })
    .send({ name });
  return res.body.id;
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------
beforeAll(async () => {
  initDb();
  httpServer = http.createServer(app);
  wss = new WebSocketServer({ noServer: true });
  app.set('wss', wss);

  httpServer.on('upgrade', (req, socket, head) => {
    const url = new URL(req.url, 'http://localhost');
    const queryToken = url.searchParams.get('token');
    if (!queryToken) {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }
    const userId = verifyAccessToken(queryToken);
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

  setupWsHandler(wss);

  await new Promise((resolve) => {
    httpServer.listen(0, '127.0.0.1', () => {
      serverPort = httpServer.address().port;
      resolve();
    });
  });
});

afterAll(async () => {
  wss.clients.forEach((c) => c.terminate());
  await new Promise((resolve) => wss.close(resolve));
  await new Promise((resolve) => httpServer.close(resolve));
  getDb().close();
}, 10_000);

// ---------------------------------------------------------------------------
// Auth Handshake
// ---------------------------------------------------------------------------
describe('WS Auth Handshake', () => {
  it('kein Token → Connection wird abgelehnt', () => {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(`ws://127.0.0.1:${serverPort}`);
      ws.once('open', () => reject(new Error('should not connect')));
      ws.once('unexpected-response', () => { ws.terminate(); resolve(); });
      ws.once('error', () => resolve()); // may fire after unexpected-response; multiple resolve() calls are no-ops
    });
  });

  it('ungültiger Token → Connection wird abgelehnt', () => {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(`ws://127.0.0.1:${serverPort}?token=invalid.jwt.token`);
      ws.once('open', () => reject(new Error('should not connect')));
      ws.once('unexpected-response', () => { ws.terminate(); resolve(); });
      ws.once('error', () => resolve());
    });
  });

  it('gültiger Token → verbindet + empfängt welcome', async () => {
    const { token, userId } = await registerUser('WsUser1', 'ws-user1@test.com');
    const ws = await wsConnect(token);
    const msg = await ws.nextMsg();
    ws.close();

    expect(msg.type).toBe(WS_EVENTS.WELCOME);
    expect(msg.userId).toBe(userId);
  });
});

// ---------------------------------------------------------------------------
// Event-Bus: JOIN / LEAVE / PING
// ---------------------------------------------------------------------------
describe('WS Event-Bus', () => {
  let lead;
  let projectId;
  let ws;

  beforeAll(async () => {
    lead = await registerUser('WsLead', 'ws-lead@test.com');
    projectId = await createProject(lead.token, 'WsProject');
    ws = await wsConnect(lead.token);
    await ws.nextMsg(); // consume welcome
  }, 10_000);

  afterAll(() => { try { ws?.terminate(); } catch {} });

  it('PING → PONG', async () => {
    ws.send(JSON.stringify({ type: WS_EVENTS.PING }));
    const msg = await ws.nextMsg();
    expect(msg.type).toBe(WS_EVENTS.PONG);
  });

  it('JOIN setzt projectId (broadcast-Smoke-Test)', async () => {
    ws.send(JSON.stringify({ type: WS_EVENTS.JOIN, projectId }));
    // Give the server a tick to process the JOIN before broadcasting.
    await new Promise((r) => setTimeout(r, 80));

    const broadcastPromise = ws.nextMsg(3000);
    await request(app)
      .post('/tasks')
      .set({ Authorization: `Bearer ${lead.token}` })
      .send({ project_id: projectId, title: 'Broadcast Test' });

    const event = await broadcastPromise;
    expect(event.type).toBe(WS_EVENTS.TASK_CREATED);
    expect(event.task.project_id).toBe(projectId);
  });

  it('LEAVE stoppt Broadcast', async () => {
    ws.send(JSON.stringify({ type: WS_EVENTS.LEAVE }));
    await new Promise((r) => setTimeout(r, 80));

    let received = false;
    const orig = ws.onmessage;
    ws.on('message', () => { received = true; });

    await request(app)
      .post('/tasks')
      .set({ Authorization: `Bearer ${lead.token}` })
      .send({ project_id: projectId, title: 'After Leave' });

    await new Promise((r) => setTimeout(r, 150));
    expect(received).toBe(false);
    ws.onmessage = orig;
  });
});
