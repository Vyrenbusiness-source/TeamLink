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

async function createProject(token, name = 'TestProject') {
  const res = await request(app)
    .post('/projects')
    .set(auth(token))
    .send({ name });
  return res.body.id;
}

async function addMember(leadToken, projectId, email, role = 'member') {
  return request(app)
    .post(`/projects/${projectId}/members`)
    .set(auth(leadToken))
    .send({ email, role });
}

// ---------------------------------------------------------------------------
// POST /tasks
// ---------------------------------------------------------------------------
describe('POST /tasks', () => {
  let lead, projectId;

  beforeAll(async () => {
    lead = await registerUser('LeadCreate', 'lead-create@test.com');
    projectId = await createProject(lead.token, 'CreateProject');
  });

  it('legt Task an und gibt sie zurück', async () => {
    const res = await request(app)
      .post('/tasks')
      .set(auth(lead.token))
      .send({ project_id: projectId, title: 'Erste Task', priority: 'high' });

    expect(res.status).toBe(201);
    expect(res.body.title).toBe('Erste Task');
    expect(res.body.priority).toBe('high');
    expect(res.body.status).toBe('open');
    expect(res.body.project_id).toBe(projectId);
    expect(typeof res.body.id).toBe('string');
  });

  it('Task mit assignee_id → status "taken"', async () => {
    const member = await registerUser('MemberAssign', 'member-assign@test.com');
    await addMember(lead.token, projectId, 'member-assign@test.com');

    const res = await request(app)
      .post('/tasks')
      .set(auth(lead.token))
      .send({ project_id: projectId, title: 'Assigned Task', assignee_id: member.userId });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('taken');
    expect(res.body.assignee_id).toBe(member.userId);
  });

  it('fehlender title → 400', async () => {
    const res = await request(app)
      .post('/tasks')
      .set(auth(lead.token))
      .send({ project_id: projectId });
    expect(res.status).toBe(400);
  });

  it('fehlende project_id → 400', async () => {
    const res = await request(app)
      .post('/tasks')
      .set(auth(lead.token))
      .send({ title: 'X' });
    expect(res.status).toBe(400);
  });

  it('ungültige priority → 400', async () => {
    const res = await request(app)
      .post('/tasks')
      .set(auth(lead.token))
      .send({ project_id: projectId, title: 'X', priority: 'critical' });
    expect(res.status).toBe(400);
  });

  it('Nicht-Mitglied → 403', async () => {
    const stranger = await registerUser('StrangerCreate', 'stranger-create@test.com');
    const res = await request(app)
      .post('/tasks')
      .set(auth(stranger.token))
      .send({ project_id: projectId, title: 'Hack' });
    expect(res.status).toBe(403);
  });

  it('kein Token → 401', async () => {
    const res = await request(app)
      .post('/tasks')
      .send({ project_id: projectId, title: 'X' });
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// GET /tasks/:taskId
// ---------------------------------------------------------------------------
describe('GET /tasks/:taskId', () => {
  let lead, member, stranger, taskId, projectId;

  beforeAll(async () => {
    lead = await registerUser('LeadGet', 'lead-get@test.com');
    member = await registerUser('MemberGet', 'member-get@test.com');
    stranger = await registerUser('StrangerGet', 'stranger-get@test.com');

    projectId = await createProject(lead.token, 'GetTaskProject');
    await addMember(lead.token, projectId, 'member-get@test.com');

    const res = await request(app)
      .post('/tasks')
      .set(auth(lead.token))
      .send({ project_id: projectId, title: 'GetMe', priority: 'low' });
    taskId = res.body.id;
  });

  it('Lead bekommt Task', async () => {
    const res = await request(app).get(`/tasks/${taskId}`).set(auth(lead.token));
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(taskId);
    expect(res.body.title).toBe('GetMe');
  });

  it('Mitglied bekommt Task', async () => {
    const res = await request(app).get(`/tasks/${taskId}`).set(auth(member.token));
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(taskId);
  });

  it('Nicht-Mitglied → 403', async () => {
    const res = await request(app).get(`/tasks/${taskId}`).set(auth(stranger.token));
    expect(res.status).toBe(403);
  });

  it('unbekannte ID → 404', async () => {
    const res = await request(app)
      .get('/tasks/00000000-0000-0000-0000-000000000000')
      .set(auth(lead.token));
    expect(res.status).toBe(404);
  });

  it('kein Token → 401', async () => {
    const res = await request(app).get(`/tasks/${taskId}`);
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// PATCH /tasks/:taskId
// ---------------------------------------------------------------------------
describe('PATCH /tasks/:taskId', () => {
  let lead, member, stranger, taskId, projectId;

  beforeAll(async () => {
    lead = await registerUser('LeadPatchTask', 'lead-patch-task@test.com');
    member = await registerUser('MemberPatchTask', 'member-patch-task@test.com');
    stranger = await registerUser('StrangerPatchTask', 'stranger-patch-task@test.com');

    projectId = await createProject(lead.token, 'PatchTaskProject');
    await addMember(lead.token, projectId, 'member-patch-task@test.com');

    const res = await request(app)
      .post('/tasks')
      .set(auth(lead.token))
      .send({ project_id: projectId, title: 'PatchMe' });
    taskId = res.body.id;
  });

  it('Mitglied kann Status ändern', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set(auth(member.token))
      .send({ status: 'done' });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('done');
  });

  it('Mitglied kann Titel und description ändern', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set(auth(lead.token))
      .send({ title: 'Updated', description: 'Neue Beschreibung', priority: 'medium' });
    expect(res.status).toBe(200);
    expect(res.body.title).toBe('Updated');
    expect(res.body.description).toBe('Neue Beschreibung');
    expect(res.body.priority).toBe('medium');
  });

  it('updated_by wird gesetzt', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set(auth(lead.token))
      .send({ status: 'open' });
    expect(res.status).toBe(200);
    expect(res.body.updated_by).toBe(lead.userId);
  });

  it('ungültiger Status → 400', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set(auth(lead.token))
      .send({ status: 'invalid' });
    expect(res.status).toBe(400);
  });

  it('Nicht-Mitglied → 403', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set(auth(stranger.token))
      .send({ status: 'done' });
    expect(res.status).toBe(403);
  });

  it('kein Token → 401', async () => {
    const res = await request(app).patch(`/tasks/${taskId}`).send({ status: 'done' });
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// DELETE /tasks/:taskId
// ---------------------------------------------------------------------------
describe('DELETE /tasks/:taskId', () => {
  let lead, member, projectId;

  beforeEach(async () => {
    const ts = Date.now();
    lead = await registerUser(`DelLeadTask${ts}`, `del-lead-task-${ts}@test.com`);
    member = await registerUser(`DelMemberTask${ts}`, `del-member-task-${ts}@test.com`);
    projectId = await createProject(lead.token, 'DelTaskProject');
    await addMember(lead.token, projectId, `del-member-task-${ts}@test.com`);
  });

  it('Lead löscht Task → 204', async () => {
    const create = await request(app)
      .post('/tasks')
      .set(auth(lead.token))
      .send({ project_id: projectId, title: 'ToDelete' });
    const taskId = create.body.id;

    const del = await request(app).delete(`/tasks/${taskId}`).set(auth(lead.token));
    expect(del.status).toBe(204);

    const get = await request(app).get(`/tasks/${taskId}`).set(auth(lead.token));
    expect(get.status).toBe(404);
  });

  it('normales Mitglied → 403', async () => {
    const create = await request(app)
      .post('/tasks')
      .set(auth(lead.token))
      .send({ project_id: projectId, title: 'NoDelete' });
    const taskId = create.body.id;

    const del = await request(app).delete(`/tasks/${taskId}`).set(auth(member.token));
    expect(del.status).toBe(403);
  });

  it('Nicht-Mitglied → 403', async () => {
    const create = await request(app)
      .post('/tasks')
      .set(auth(lead.token))
      .send({ project_id: projectId, title: 'NotYours' });
    const taskId = create.body.id;

    const stranger = await registerUser(`StrangerDel${Date.now()}`, `stranger-del-${Date.now()}@test.com`);
    const del = await request(app).delete(`/tasks/${taskId}`).set(auth(stranger.token));
    expect(del.status).toBe(403);
  });

  it('unbekannte ID → 404', async () => {
    const del = await request(app)
      .delete('/tasks/00000000-0000-0000-0000-000000000000')
      .set(auth(lead.token));
    expect(del.status).toBe(404);
  });

  it('kein Token → 401', async () => {
    const create = await request(app)
      .post('/tasks')
      .set(auth(lead.token))
      .send({ project_id: projectId, title: 'Auth test' });
    const del = await request(app).delete(`/tasks/${create.body.id}`);
    expect(del.status).toBe(401);
  });
});
