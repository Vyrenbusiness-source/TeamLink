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

async function createProject(token, name = 'InviteProject') {
  const res = await request(app).post('/projects').set(auth(token)).send({ name });
  return res.body.id;
}

async function createInvite(token, projectId, role = 'member') {
  const body = { role };
  if (projectId) body.project_id = projectId;
  const res = await request(app).post('/invites').set(auth(token)).send(body);
  return res;
}

// ---------------------------------------------------------------------------
// POST /invites
// ---------------------------------------------------------------------------
describe('POST /invites', () => {
  let lead, member;

  beforeAll(async () => {
    lead = await registerUser('InvLead', 'inv-lead@test.com');
    member = await registerUser('InvMember', 'inv-member@test.com');
  });

  it('Lead erstellt Projekt-Invite → 201 mit token', async () => {
    const projectId = await createProject(lead.token, 'InvProject1');
    const res = await createInvite(lead.token, projectId, 'member');
    expect(res.status).toBe(201);
    expect(typeof res.body.token).toBe('string');
    expect(res.body.token).toMatch(/^tlk_/);
    expect(res.body.project_id).toBe(projectId);
    expect(res.body.role).toBe('member');
    expect(typeof res.body.expires_at).toBe('number');
  });

  it('Invite ohne project_id (globaler Invite) → 201', async () => {
    const res = await request(app)
      .post('/invites')
      .set(auth(lead.token))
      .send({ role: 'member' });
    expect(res.status).toBe(201);
    expect(res.body.project_id).toBeNull();
  });

  it('ungültige Rolle → 400', async () => {
    const projectId = await createProject(lead.token, 'InvProject2');
    const res = await createInvite(lead.token, projectId, 'superadmin');
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/role must be/i);
  });

  it('Nicht-Mitglied erstellt Invite für fremdes Projekt → 403', async () => {
    const projectId = await createProject(lead.token, 'InvProject3');
    const res = await createInvite(member.token, projectId, 'member');
    expect(res.status).toBe(403);
  });

  it('Mitglied (nicht lead) erstellt Invite → 403', async () => {
    const projectId = await createProject(lead.token, 'InvProject4');
    await request(app)
      .post(`/projects/${projectId}/members`)
      .set(auth(lead.token))
      .send({ email: 'inv-member@test.com', role: 'member' });
    const res = await createInvite(member.token, projectId, 'member');
    expect(res.status).toBe(403);
  });

  it('kein Token → 401', async () => {
    const res = await request(app).post('/invites').send({ role: 'member' });
    expect(res.status).toBe(401);
  });

  it('ttl_hours wird berücksichtigt (kurzlebiger Token)', async () => {
    const projectId = await createProject(lead.token, 'InvProjectTTL');
    const res = await request(app)
      .post('/invites')
      .set(auth(lead.token))
      .send({ project_id: projectId, role: 'member', ttl_hours: 1 });
    expect(res.status).toBe(201);
    const nowSec = Math.floor(Date.now() / 1000);
    expect(res.body.expires_at).toBeGreaterThan(nowSec);
    expect(res.body.expires_at).toBeLessThanOrEqual(nowSec + 3700);
  });
});

// ---------------------------------------------------------------------------
// GET /invites/:token
// ---------------------------------------------------------------------------
describe('GET /invites/:token', () => {
  let lead, inviteToken, projectId;

  beforeAll(async () => {
    lead = await registerUser('InvGetLead', 'inv-get-lead@test.com');
    projectId = await createProject(lead.token, 'InvGetProject');
    const res = await createInvite(lead.token, projectId);
    inviteToken = res.body.token;
  });

  it('gibt Invite-Details zurück', async () => {
    const res = await request(app).get(`/invites/${inviteToken}`);
    expect(res.status).toBe(200);
    expect(res.body.token).toBe(inviteToken);
    expect(res.body.project_id).toBe(projectId);
    expect(res.body.role).toBe('member');
    expect(res.body.password_hash).toBeUndefined();
  });

  it('unbekannter Token → 404', async () => {
    const res = await request(app).get('/invites/tlk_doesnotexist000000000000');
    expect(res.status).toBe(404);
  });
});

// ---------------------------------------------------------------------------
// POST /invites/:token/accept
// ---------------------------------------------------------------------------
describe('POST /invites/:token/accept', () => {
  let lead, projectId;

  beforeEach(async () => {
    const ts = Date.now();
    lead = await registerUser(`AccLead${ts}`, `acc-lead-${ts}@test.com`);
    projectId = await createProject(lead.token, `AccProject${ts}`);
  });

  it('akzeptiert Invite, erstellt User und fügt ihn zum Projekt hinzu', async () => {
    const inv = await createInvite(lead.token, projectId, 'member');
    const token = inv.body.token;

    const ts = Date.now();
    const res = await request(app)
      .post(`/invites/${token}/accept`)
      .send({ name: `NewUser${ts}`, email: `new-${ts}@test.com`, password: 'secret123' });

    expect(res.status).toBe(201);
    expect(typeof res.body.user.id).toBe('string');
    expect(res.body.user.email).toBe(`new-${ts}@test.com`);
    expect(res.body.project_id).toBe(projectId);
    expect(res.body.role).toBe('member');
    expect(res.body.user.password_hash).toBeUndefined();
  });

  it('bereits verwendeter Token → 410', async () => {
    const inv = await createInvite(lead.token, projectId, 'member');
    const token = inv.body.token;
    const ts = Date.now();

    await request(app)
      .post(`/invites/${token}/accept`)
      .send({ name: `First${ts}`, email: `first-${ts}@test.com`, password: 'secret123' });

    const res = await request(app)
      .post(`/invites/${token}/accept`)
      .send({ name: `Second${ts}`, email: `second-${ts}@test.com`, password: 'secret123' });

    expect(res.status).toBe(410);
    expect(res.body.error).toMatch(/already used/i);
  });

  it('doppelte E-Mail beim Accept → 409', async () => {
    const inv = await createInvite(lead.token, projectId, 'observer');
    const token = inv.body.token;
    const ts = Date.now();
    const email = `dupe-acc-${ts}@test.com`;

    await request(app)
      .post('/auth/register')
      .send({ name: `DupeAcc${ts}`, email, password: 'secret123' });

    const res = await request(app)
      .post(`/invites/${token}/accept`)
      .send({ name: `DupeAcc2${ts}`, email, password: 'secret123' });

    expect(res.status).toBe(409);
    expect(res.body.error).toMatch(/email already in use/i);
  });

  it('fehlende Pflichtfelder → 400', async () => {
    const inv = await createInvite(lead.token, projectId);
    const token = inv.body.token;

    const res = await request(app)
      .post(`/invites/${token}/accept`)
      .send({ name: 'Partial' });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/name, email and password/i);
  });

  it('zu kurzes Passwort → 400', async () => {
    const inv = await createInvite(lead.token, projectId);
    const token = inv.body.token;
    const ts = Date.now();

    const res = await request(app)
      .post(`/invites/${token}/accept`)
      .send({ name: `Short${ts}`, email: `short-acc-${ts}@test.com`, password: 'abc' });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/at least 8/i);
  });

  it('unbekannter Token → 404', async () => {
    const res = await request(app)
      .post('/invites/tlk_nonexistent000000000000/accept')
      .send({ name: 'Ghost', email: 'ghost@test.com', password: 'password123' });
    expect(res.status).toBe(404);
  });
});
