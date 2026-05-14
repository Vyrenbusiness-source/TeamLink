process.env.DB_PATH = ':memory:';
process.env.NODE_ENV = 'test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-mindestens-32-zeichen-lang';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-mindestens-32-zeichen-lang';
process.env.ALLOW_DEV_AUTH = '1';

const request = require('supertest');
const app = require('../src/app');
const { initDb, getDb } = require('../src/db/schema');

beforeAll(() => {
  initDb();
});

afterAll(() => {
  getDb().close();
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
async function registerUser(name, email) {
  const res = await request(app)
    .post('/auth/register')
    .send({ name, email, password: 'password123' });
  return { token: res.body.access_token, userId: res.body.user.id };
}

function auth(token) {
  return { Authorization: `Bearer ${token}` };
}

async function createProject(token, name) {
  const res = await request(app).post('/projects').set(auth(token)).send({ name });
  return res.body.id;
}

// ---------------------------------------------------------------------------
// POST /messages/:partnerId
// ---------------------------------------------------------------------------
describe('POST /messages/:partnerId', () => {
  let alice, bob, charlie;

  beforeAll(async () => {
    alice = await registerUser('MsgAlice', 'msg-alice@test.com');
    bob = await registerUser('MsgBob', 'msg-bob@test.com');
    charlie = await registerUser('MsgCharlie', 'msg-charlie@test.com');
  });

  it('sendet Nachricht und gibt sie zurück', async () => {
    const res = await request(app)
      .post(`/messages/${bob.userId}`)
      .set(auth(alice.token))
      .send({ content: 'Hallo Bob!' });
    expect(res.status).toBe(201);
    expect(res.body.content).toBe('Hallo Bob!');
    expect(res.body.sender_id).toBe(alice.userId);
    expect(res.body.recipient_id).toBe(bob.userId);
    expect(typeof res.body.id).toBe('string');
  });

  it('leerer content → 400', async () => {
    const res = await request(app)
      .post(`/messages/${bob.userId}`)
      .set(auth(alice.token))
      .send({ content: '   ' });
    expect(res.status).toBe(400);
  });

  it('fehlendes content → 400', async () => {
    const res = await request(app)
      .post(`/messages/${bob.userId}`)
      .set(auth(alice.token))
      .send({});
    expect(res.status).toBe(400);
  });

  it('unbekannter Empfänger → 404', async () => {
    const res = await request(app)
      .post('/messages/00000000-0000-0000-0000-000000000000')
      .set(auth(alice.token))
      .send({ content: 'Hello?' });
    expect(res.status).toBe(404);
  });

  it('kein Token → 401', async () => {
    const res = await request(app)
      .post(`/messages/${bob.userId}`)
      .send({ content: 'X' });
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// GET /messages/:partnerId
// ---------------------------------------------------------------------------
describe('GET /messages/:partnerId', () => {
  let alice, bob;

  beforeAll(async () => {
    alice = await registerUser('MsgAliceGet', 'msg-alice-get@test.com');
    bob = await registerUser('MsgBobGet', 'msg-bob-get@test.com');

    await request(app)
      .post(`/messages/${bob.userId}`)
      .set(auth(alice.token))
      .send({ content: 'Erster' });
    await request(app)
      .post(`/messages/${alice.userId}`)
      .set(auth(bob.token))
      .send({ content: 'Antwort' });
  });

  it('gibt Konversation in chronologischer Reihenfolge zurück', async () => {
    const res = await request(app)
      .get(`/messages/${bob.userId}`)
      .set(auth(alice.token));
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(2);
    expect(res.body[0].content).toBe('Erster');
    expect(res.body[1].content).toBe('Antwort');
  });

  it('perspektivisch: Bob sieht dieselbe Konversation', async () => {
    const res = await request(app)
      .get(`/messages/${alice.userId}`)
      .set(auth(bob.token));
    expect(res.status).toBe(200);
    expect(res.body.length).toBe(2);
  });

  it('leere Konversation → leeres Array', async () => {
    const dave = await registerUser('MsgDaveGet', 'msg-dave-get@test.com');
    const res = await request(app)
      .get(`/messages/${dave.userId}`)
      .set(auth(alice.token));
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('kein Token → 401', async () => {
    const res = await request(app).get(`/messages/${bob.userId}`);
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// GET /messages/conversations
// ---------------------------------------------------------------------------
describe('GET /messages/conversations', () => {
  let alice, bob, carol;

  beforeAll(async () => {
    alice = await registerUser('ConvAlice', 'conv-alice@test.com');
    bob = await registerUser('ConvBob', 'conv-bob@test.com');
    carol = await registerUser('ConvCarol', 'conv-carol@test.com');

    await request(app)
      .post(`/messages/${bob.userId}`)
      .set(auth(alice.token))
      .send({ content: 'Hi Bob' });
    await request(app)
      .post(`/messages/${carol.userId}`)
      .set(auth(alice.token))
      .send({ content: 'Hi Carol' });
  });

  it('gibt Konversationsliste mit letzter Nachricht zurück', async () => {
    const res = await request(app)
      .get('/messages/conversations')
      .set(auth(alice.token));
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(2);
    const partnerIds = res.body.map((c) => c.id);
    expect(partnerIds).toContain(bob.userId);
    expect(partnerIds).toContain(carol.userId);
  });

  it('User ohne Nachrichten → leeres Array', async () => {
    const nobody = await registerUser('ConvNobody', 'conv-nobody@test.com');
    const res = await request(app)
      .get('/messages/conversations')
      .set(auth(nobody.token));
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('kein Token → 401', async () => {
    const res = await request(app).get('/messages/conversations');
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// GET /messages/users
// ---------------------------------------------------------------------------
describe('GET /messages/users', () => {
  let alice, bob, carol;

  beforeAll(async () => {
    alice = await registerUser('UsersAlice', 'users-alice@test.com');
    bob = await registerUser('UsersBob', 'users-bob@test.com');
    carol = await registerUser('UsersCarol', 'users-carol@test.com');

    const projectId = await createProject(alice.token, 'UsersProject');
    await request(app)
      .post(`/projects/${projectId}/members`)
      .set(auth(alice.token))
      .send({ email: 'users-bob@test.com', role: 'member' });
    await request(app)
      .post(`/projects/${projectId}/members`)
      .set(auth(alice.token))
      .send({ email: 'users-carol@test.com', role: 'member' });
  });

  it('gibt Projekt-Mitglieder ohne sich selbst zurück', async () => {
    const res = await request(app)
      .get('/messages/users')
      .set(auth(alice.token));
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    const ids = res.body.map((u) => u.id);
    expect(ids).toContain(bob.userId);
    expect(ids).toContain(carol.userId);
    expect(ids).not.toContain(alice.userId);
  });

  it('User ohne Projekte → leeres Array', async () => {
    const loner = await registerUser('UsersLoner', 'users-loner@test.com');
    const res = await request(app)
      .get('/messages/users')
      .set(auth(loner.token));
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('kein Token → 401', async () => {
    const res = await request(app).get('/messages/users');
    expect(res.status).toBe(401);
  });
});
