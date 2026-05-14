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

// ---------------------------------------------------------------------------
// POST /projects
// ---------------------------------------------------------------------------
describe('POST /projects', () => {
  it('legt Projekt an und gibt es zurück', async () => {
    const { token } = await registerUser('Alice', 'alice-p@test.com');
    const res = await request(app)
      .post('/projects')
      .set(auth(token))
      .send({ name: 'Alpha' });

    expect(res.status).toBe(201);
    expect(res.body.name).toBe('Alpha');
    expect(typeof res.body.id).toBe('string');
  });

  it('fehlender name → 400', async () => {
    const { token } = await registerUser('Alice2', 'alice2-p@test.com');
    const res = await request(app)
      .post('/projects')
      .set(auth(token))
      .send({});
    expect(res.status).toBe(400);
  });

  it('kein Token → 401', async () => {
    const res = await request(app).post('/projects').send({ name: 'X' });
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// GET /projects
// ---------------------------------------------------------------------------
describe('GET /projects', () => {
  it('gibt nur eigene Projekte zurück', async () => {
    const alice = await registerUser('AliceList', 'alice-list@test.com');
    const bob = await registerUser('BobList', 'bob-list@test.com');

    await request(app).post('/projects').set(auth(alice.token)).send({ name: 'AliceProj' });
    await request(app).post('/projects').set(auth(bob.token)).send({ name: 'BobProj' });

    const res = await request(app).get('/projects').set(auth(alice.token));
    expect(res.status).toBe(200);
    const names = res.body.map((p) => p.name);
    expect(names).toContain('AliceProj');
    expect(names).not.toContain('BobProj');
  });

  it('kein Token → 401', async () => {
    const res = await request(app).get('/projects');
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// GET /projects/:projectId
// ---------------------------------------------------------------------------
describe('GET /projects/:projectId', () => {
  let alice, projectId;

  beforeAll(async () => {
    alice = await registerUser('AliceGet', 'alice-get@test.com');
    const res = await request(app)
      .post('/projects')
      .set(auth(alice.token))
      .send({ name: 'GetProject' });
    projectId = res.body.id;
  });

  it('Mitglied bekommt Projekt', async () => {
    const res = await request(app)
      .get(`/projects/${projectId}`)
      .set(auth(alice.token));
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(projectId);
    expect(res.body.name).toBe('GetProject');
    expect(res.body.my_role).toBe('lead');
  });

  it('Nicht-Mitglied → 403', async () => {
    const bob = await registerUser('BobGet', 'bob-get@test.com');
    const res = await request(app)
      .get(`/projects/${projectId}`)
      .set(auth(bob.token));
    expect(res.status).toBe(403);
  });

  it('unbekannte ID → 403 (kein Leak ob Projekt existiert)', async () => {
    const res = await request(app)
      .get('/projects/00000000-0000-0000-0000-000000000000')
      .set(auth(alice.token));
    // requireMembership fires before route handler — 403, not 404
    expect(res.status).toBe(403);
  });

  it('kein Token → 401', async () => {
    const res = await request(app).get(`/projects/${projectId}`);
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// PATCH /projects/:projectId
// ---------------------------------------------------------------------------
describe('PATCH /projects/:projectId', () => {
  let lead, member, projectId;

  beforeAll(async () => {
    lead = await registerUser('LeadPatch', 'lead-patch@test.com');
    member = await registerUser('MemberPatch', 'member-patch@test.com');

    const res = await request(app)
      .post('/projects')
      .set(auth(lead.token))
      .send({ name: 'PatchProject' });
    projectId = res.body.id;

    await request(app)
      .post(`/projects/${projectId}/members`)
      .set(auth(lead.token))
      .send({ email: 'member-patch@test.com', role: 'member' });
  });

  it('lead kann Name ändern', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}`)
      .set(auth(lead.token))
      .send({ name: 'PatchedName' });
    expect(res.status).toBe(200);
    expect(res.body.name).toBe('PatchedName');
  });

  it('lead kann description setzen', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}`)
      .set(auth(lead.token))
      .send({ description: 'Mein Projekt' });
    expect(res.status).toBe(200);
    expect(res.body.description).toBe('Mein Projekt');
  });

  it('normales Mitglied (nicht lead) → 403', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}`)
      .set(auth(member.token))
      .send({ name: 'HijackName' });
    expect(res.status).toBe(403);
  });

  it('Nicht-Mitglied → 403', async () => {
    const stranger = await registerUser('StrangerPatch', 'stranger-patch@test.com');
    const res = await request(app)
      .patch(`/projects/${projectId}`)
      .set(auth(stranger.token))
      .send({ name: 'HijackName' });
    expect(res.status).toBe(403);
  });

  it('leerer Body → 400', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}`)
      .set(auth(lead.token))
      .send({});
    expect(res.status).toBe(400);
  });

  it('kein Token → 401', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}`)
      .send({ name: 'X' });
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// DELETE /projects/:projectId
// ---------------------------------------------------------------------------
describe('DELETE /projects/:projectId', () => {
  let lead, member;

  beforeEach(async () => {
    const ts = Date.now();
    const leadEmail = `del-lead-${ts}@test.com`;
    const memberEmail = `del-member-${ts}@test.com`;
    lead = { ...(await registerUser(`DelLead${ts}`, leadEmail)), email: leadEmail };
    member = { ...(await registerUser(`DelMember${ts}`, memberEmail)), email: memberEmail };
  });

  it('lead löscht Projekt → 204', async () => {
    const res = await request(app)
      .post('/projects')
      .set(auth(lead.token))
      .send({ name: 'ToDelete' });
    const projectId = res.body.id;

    const del = await request(app)
      .delete(`/projects/${projectId}`)
      .set(auth(lead.token));
    expect(del.status).toBe(204);

    // Projekt danach nicht mehr erreichbar (Mitgliedschaft ebenfalls gelöscht → 403)
    const get = await request(app)
      .get(`/projects/${projectId}`)
      .set(auth(lead.token));
    expect(get.status).toBe(403);
  });

  it('normales Mitglied → 403', async () => {
    const res = await request(app)
      .post('/projects')
      .set(auth(lead.token))
      .send({ name: 'NoDeleteByMember' });
    const projectId = res.body.id;

    await request(app)
      .post(`/projects/${projectId}/members`)
      .set(auth(lead.token))
      .send({ email: member.email, role: 'member' });

    const del = await request(app)
      .delete(`/projects/${projectId}`)
      .set(auth(member.token));
    expect(del.status).toBe(403);
  });

  it('Nicht-Mitglied → 403', async () => {
    const proj = await request(app)
      .post('/projects')
      .set(auth(lead.token))
      .send({ name: 'NotYours' });
    const stranger = await registerUser(`Stranger${Date.now()}`, `stranger-${Date.now()}@test.com`);
    const del = await request(app)
      .delete(`/projects/${proj.body.id}`)
      .set(auth(stranger.token));
    expect(del.status).toBe(403);
  });

  it('unbekannte ID → 403 (kein Leak ob Projekt existiert)', async () => {
    const del = await request(app)
      .delete('/projects/00000000-0000-0000-0000-000000000000')
      .set(auth(lead.token));
    // requireLead fires before route handler — returns 403 for non-existent project
    expect(del.status).toBe(403);
  });

  it('kein Token → 401', async () => {
    const proj = await request(app)
      .post('/projects')
      .set(auth(lead.token))
      .send({ name: 'Auth test' });
    const del = await request(app).delete(`/projects/${proj.body.id}`);
    expect(del.status).toBe(401);
  });
});
