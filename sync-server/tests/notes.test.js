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

async function createProject(token, name = 'NoteProject') {
  const res = await request(app)
    .post('/projects')
    .set(auth(token))
    .send({ name });
  return res.body.id;
}

// ---------------------------------------------------------------------------
// GET /projects/:projectId/notes
// ---------------------------------------------------------------------------
describe('GET /projects/:projectId/notes', () => {
  let lead, stranger, projectId;

  beforeAll(async () => {
    lead = await registerUser('NoteLeadGet', 'note-lead-get@test.com');
    stranger = await registerUser('NoteStrangerGet', 'note-stranger-get@test.com');
    projectId = await createProject(lead.token, 'NoteGetProject');
  });

  it('gibt Note zurück (wird auto-erstellt wenn nicht vorhanden)', async () => {
    const res = await request(app)
      .get(`/projects/${projectId}/notes`)
      .set(auth(lead.token));
    expect(res.status).toBe(200);
    expect(res.body.project_id).toBe(projectId);
    expect(typeof res.body.id).toBe('string');
  });

  it('zweiter Aufruf gibt dieselbe Note zurück (kein Duplikat)', async () => {
    const first = await request(app)
      .get(`/projects/${projectId}/notes`)
      .set(auth(lead.token));
    const second = await request(app)
      .get(`/projects/${projectId}/notes`)
      .set(auth(lead.token));
    expect(second.status).toBe(200);
    expect(second.body.id).toBe(first.body.id);
  });

  it('Nicht-Mitglied → 403', async () => {
    const res = await request(app)
      .get(`/projects/${projectId}/notes`)
      .set(auth(stranger.token));
    expect(res.status).toBe(403);
  });

  it('kein Token → 401', async () => {
    const res = await request(app).get(`/projects/${projectId}/notes`);
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// PATCH /projects/:projectId/notes
// ---------------------------------------------------------------------------
describe('PATCH /projects/:projectId/notes', () => {
  let lead, member, stranger, projectId;

  beforeAll(async () => {
    lead = await registerUser('NoteLeadPatch', 'note-lead-patch@test.com');
    member = await registerUser('NoteMemberPatch', 'note-member-patch@test.com');
    stranger = await registerUser('NoteStrangerPatch', 'note-stranger-patch@test.com');
    projectId = await createProject(lead.token, 'NotePatchProject');

    await request(app)
      .post(`/projects/${projectId}/members`)
      .set(auth(lead.token))
      .send({ email: 'note-member-patch@test.com', role: 'member' });
  });

  it('Lead kann content setzen', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/notes`)
      .set(auth(lead.token))
      .send({ content: 'Erste Notiz' });
    expect(res.status).toBe(200);
    expect(res.body.content).toBe('Erste Notiz');
    expect(res.body.updated_by).toBe(lead.userId);
  });

  it('Mitglied kann content ändern', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/notes`)
      .set(auth(member.token))
      .send({ content: 'Von Member geändert' });
    expect(res.status).toBe(200);
    expect(res.body.content).toBe('Von Member geändert');
    expect(res.body.updated_by).toBe(member.userId);
  });

  it('content leer-string ist gültig', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/notes`)
      .set(auth(lead.token))
      .send({ content: '' });
    expect(res.status).toBe(200);
    expect(res.body.content).toBe('');
  });

  it('fehlendes content-Feld → 400', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/notes`)
      .set(auth(lead.token))
      .send({});
    expect(res.status).toBe(400);
  });

  it('Nicht-Mitglied → 403', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/notes`)
      .set(auth(stranger.token))
      .send({ content: 'Hack' });
    expect(res.status).toBe(403);
  });

  it('kein Token → 401', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/notes`)
      .send({ content: 'X' });
    expect(res.status).toBe(401);
  });

  it('GET nach PATCH gibt aktualisierten content zurück', async () => {
    await request(app)
      .patch(`/projects/${projectId}/notes`)
      .set(auth(lead.token))
      .send({ content: 'Persistiert?' });

    const get = await request(app)
      .get(`/projects/${projectId}/notes`)
      .set(auth(lead.token));
    expect(get.status).toBe(200);
    expect(get.body.content).toBe('Persistiert?');
  });
});
