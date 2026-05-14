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

async function createProject(token, name = 'ProjTaskProject') {
  const res = await request(app).post('/projects').set(auth(token)).send({ name });
  return res.body.id;
}

async function addMember(leadToken, projectId, email, role = 'member') {
  return request(app)
    .post(`/projects/${projectId}/members`)
    .set(auth(leadToken))
    .send({ email, role });
}

// ---------------------------------------------------------------------------
// POST /projects/:projectId/tasks
// ---------------------------------------------------------------------------
describe('POST /projects/:projectId/tasks', () => {
  let lead, member, stranger, projectId;

  beforeAll(async () => {
    lead = await registerUser('ProjTaskLead', 'proj-task-lead@test.com');
    member = await registerUser('ProjTaskMember', 'proj-task-member@test.com');
    stranger = await registerUser('ProjTaskStranger', 'proj-task-stranger@test.com');
    projectId = await createProject(lead.token, 'ProjCreateTask');
    await addMember(lead.token, projectId, 'proj-task-member@test.com');
  });

  it('Lead legt Task an → 201', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(lead.token))
      .send({ title: 'Proj Task 1', deadline: null });
    expect(res.status).toBe(201);
    expect(res.body.title).toBe('Proj Task 1');
    expect(res.body.project_id).toBe(projectId);
    expect(res.body.status).toBe('open');
  });

  it('Mitglied legt Task an → 201', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(member.token))
      .send({ title: 'Member Task' });
    expect(res.status).toBe(201);
    expect(res.body.title).toBe('Member Task');
  });

  it('Task mit assignee → status "taken"', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(lead.token))
      .send({ title: 'Assigned', assignee_id: member.userId });
    expect(res.status).toBe(201);
    expect(res.body.status).toBe('taken');
    expect(res.body.assignee_id).toBe(member.userId);
  });

  it('assignee nicht im Projekt → 400', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(lead.token))
      .send({ title: 'Bad assignee', assignee_id: stranger.userId });
    expect(res.status).toBe(400);
  });

  it('fehlender title → 400', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(lead.token))
      .send({});
    expect(res.status).toBe(400);
  });

  it('Nicht-Mitglied → 403', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(stranger.token))
      .send({ title: 'Hack' });
    expect(res.status).toBe(403);
  });

  it('kein Token → 401', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .send({ title: 'X' });
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// GET /projects/:projectId/tasks
// ---------------------------------------------------------------------------
describe('GET /projects/:projectId/tasks', () => {
  let lead, stranger, projectId;

  beforeAll(async () => {
    lead = await registerUser('ProjGetTaskLead', 'proj-get-task-lead@test.com');
    stranger = await registerUser('ProjGetTaskStranger', 'proj-get-task-stranger@test.com');
    projectId = await createProject(lead.token, 'ProjGetTaskProject');

    await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(lead.token))
      .send({ title: 'Task A' });
    await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(lead.token))
      .send({ title: 'Task B' });
  });

  it('gibt alle Tasks des Projekts zurück', async () => {
    const res = await request(app)
      .get(`/projects/${projectId}/tasks`)
      .set(auth(lead.token));
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(2);
    const titles = res.body.map((t) => t.title);
    expect(titles).toContain('Task A');
    expect(titles).toContain('Task B');
  });

  it('Nicht-Mitglied → 403', async () => {
    const res = await request(app)
      .get(`/projects/${projectId}/tasks`)
      .set(auth(stranger.token));
    expect(res.status).toBe(403);
  });

  it('kein Token → 401', async () => {
    const res = await request(app).get(`/projects/${projectId}/tasks`);
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// PATCH /projects/:projectId/tasks/:taskId
// ---------------------------------------------------------------------------
describe('PATCH /projects/:projectId/tasks/:taskId', () => {
  let lead, member, stranger, projectId, taskId;

  beforeAll(async () => {
    lead = await registerUser('ProjPatchTaskLead', 'proj-patch-task-lead@test.com');
    member = await registerUser('ProjPatchTaskMember', 'proj-patch-task-member@test.com');
    stranger = await registerUser('ProjPatchTaskStranger', 'proj-patch-task-stranger@test.com');
    projectId = await createProject(lead.token, 'ProjPatchTaskProject');
    await addMember(lead.token, projectId, 'proj-patch-task-member@test.com');

    const res = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(lead.token))
      .send({ title: 'PatchableTask' });
    taskId = res.body.id;
  });

  it('Mitglied kann status aktualisieren', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/tasks/${taskId}`)
      .set(auth(member.token))
      .send({ status: 'done' });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('done');
  });

  it('Lead kann title und assignee setzen', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/tasks/${taskId}`)
      .set(auth(lead.token))
      .send({ title: 'Updated via project route', assignee_id: member.userId });
    expect(res.status).toBe(200);
    expect(res.body.title).toBe('Updated via project route');
    expect(res.body.assignee_id).toBe(member.userId);
    expect(res.body.status).toBe('taken');
  });

  it('ungültiger status → 400', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/tasks/${taskId}`)
      .set(auth(lead.token))
      .send({ status: 'invalid' });
    expect(res.status).toBe(400);
  });

  it('LWW: veraltetes updated_at → 409', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/tasks/${taskId}`)
      .set(auth(lead.token))
      .send({ title: 'Stale write', updated_at: 0 });
    expect(res.status).toBe(409);
    expect(res.body.error).toMatch(/conflict/i);
  });

  it('unbekannte taskId → 404', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/tasks/00000000-0000-0000-0000-000000000000`)
      .set(auth(lead.token))
      .send({ status: 'done' });
    expect(res.status).toBe(404);
  });

  it('Nicht-Mitglied → 403', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/tasks/${taskId}`)
      .set(auth(stranger.token))
      .send({ status: 'done' });
    expect(res.status).toBe(403);
  });

  it('kein Token → 401', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/tasks/${taskId}`)
      .send({ status: 'done' });
    expect(res.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// DELETE /projects/:projectId/tasks/:taskId
// ---------------------------------------------------------------------------
describe('DELETE /projects/:projectId/tasks/:taskId', () => {
  let lead, member, projectId;

  beforeEach(async () => {
    const ts = Date.now();
    lead = await registerUser(`ProjDelTaskLead${ts}`, `proj-del-task-lead-${ts}@test.com`);
    member = await registerUser(`ProjDelTaskMember${ts}`, `proj-del-task-member-${ts}@test.com`);
    projectId = await createProject(lead.token, `ProjDelProject${ts}`);
    await addMember(lead.token, projectId, `proj-del-task-member-${ts}@test.com`);
  });

  it('Mitglied löscht Task → 204', async () => {
    const create = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(lead.token))
      .send({ title: 'ToDelete' });
    const taskId = create.body.id;

    const del = await request(app)
      .delete(`/projects/${projectId}/tasks/${taskId}`)
      .set(auth(lead.token));
    expect(del.status).toBe(204);

    const get = await request(app)
      .get(`/projects/${projectId}/tasks`)
      .set(auth(lead.token));
    expect(get.body.map((t) => t.id)).not.toContain(taskId);
  });

  it('normales Mitglied kann ebenfalls löschen → 204', async () => {
    const create = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(lead.token))
      .send({ title: 'MemberDelete' });
    const taskId = create.body.id;

    const del = await request(app)
      .delete(`/projects/${projectId}/tasks/${taskId}`)
      .set(auth(member.token));
    expect(del.status).toBe(204);
  });

  it('Nicht-Mitglied → 403', async () => {
    const ts = Date.now();
    const stranger2 = await registerUser(`DelStranger${ts}`, `del-stranger-${ts}@test.com`);
    const create = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(lead.token))
      .send({ title: 'StrangerNoDelete' });
    const taskId = create.body.id;

    const del = await request(app)
      .delete(`/projects/${projectId}/tasks/${taskId}`)
      .set(auth(stranger2.token));
    expect(del.status).toBe(403);
  });

  it('unbekannte taskId → 404', async () => {
    const del = await request(app)
      .delete(`/projects/${projectId}/tasks/00000000-0000-0000-0000-000000000000`)
      .set(auth(lead.token));
    expect(del.status).toBe(404);
  });

  it('kein Token → 401', async () => {
    const create = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set(auth(lead.token))
      .send({ title: 'AuthTest' });
    const del = await request(app)
      .delete(`/projects/${projectId}/tasks/${create.body.id}`);
    expect(del.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// PATCH /projects/:projectId/members/:userId  (Rolle ändern)
// ---------------------------------------------------------------------------
describe('PATCH /projects/:projectId/members/:userId', () => {
  let lead, member, stranger, projectId;

  beforeAll(async () => {
    lead = await registerUser('PatchRoleLead', 'patch-role-lead@test.com');
    member = await registerUser('PatchRoleMember', 'patch-role-member@test.com');
    stranger = await registerUser('PatchRoleStranger', 'patch-role-stranger@test.com');
    projectId = await createProject(lead.token, 'PatchRoleProject');
    await addMember(lead.token, projectId, 'patch-role-member@test.com', 'member');
  });

  it('Lead ändert Rolle von member → observer', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/members/${member.userId}`)
      .set(auth(lead.token))
      .send({ role: 'observer' });
    expect(res.status).toBe(200);
    expect(res.body.role).toBe('observer');
    expect(res.body.user_id).toBe(member.userId);
  });

  it('Lead befördert observer → lead', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/members/${member.userId}`)
      .set(auth(lead.token))
      .send({ role: 'lead' });
    expect(res.status).toBe(200);
    expect(res.body.role).toBe('lead');
  });

  it('ungültige Rolle → 400', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/members/${member.userId}`)
      .set(auth(lead.token))
      .send({ role: 'superadmin' });
    expect(res.status).toBe(400);
  });

  it('Nicht-Mitglied als Ziel → 404', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/members/${stranger.userId}`)
      .set(auth(lead.token))
      .send({ role: 'member' });
    expect(res.status).toBe(404);
  });

  it('Nicht-Lead darf Rolle nicht ändern → 403', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/members/${lead.userId}`)
      .set(auth(stranger.token))
      .send({ role: 'observer' });
    expect(res.status).toBe(403);
  });

  it('kein Token → 401', async () => {
    const res = await request(app)
      .patch(`/projects/${projectId}/members/${member.userId}`)
      .send({ role: 'member' });
    expect(res.status).toBe(401);
  });
});
