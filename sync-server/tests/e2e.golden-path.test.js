process.env.DB_PATH = ':memory:';

const request = require('supertest');
const app = require('../src/app');
const { initDb, getDb } = require('../src/db/schema');

beforeAll(() => {
  initDb();
});

afterAll(() => {
  getDb().close();
});

describe('golden path: register → projekt → task → übernehmen → erledigt', () => {
  let userId;
  let projectId;
  let taskId;

  it('POST /auth/register — neuen Nutzer anlegen', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ name: 'Alice', email: 'alice@example.com', password: 'secret123' });

    expect(res.status).toBe(201);
    expect(res.body.id).toBeDefined();
    expect(res.body.name).toBe('Alice');
    expect(res.body.email).toBe('alice@example.com');
    expect(res.body.password_hash).toBeUndefined();
    userId = res.body.id;
  });

  it('POST /projects — Projekt erstellen', async () => {
    const res = await request(app)
      .post('/projects')
      .set('X-User-Id', userId)
      .send({ name: 'TeamLink Alpha' });

    expect(res.status).toBe(201);
    expect(res.body.id).toBeDefined();
    expect(res.body.name).toBe('TeamLink Alpha');
    projectId = res.body.id;
  });

  it('POST /projects/:id/tasks — Task anlegen (status open)', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/tasks`)
      .set('X-User-Id', userId)
      .send({ title: 'Backend-API implementieren' });

    expect(res.status).toBe(201);
    expect(res.body.id).toBeDefined();
    expect(res.body.title).toBe('Backend-API implementieren');
    expect(res.body.status).toBe('open');
    expect(res.body.assignee_id).toBeNull();
    taskId = res.body.id;
  });

  it('PATCH /tasks/:id — Task übernehmen (status taken)', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set('X-User-Id', userId)
      .send({ status: 'taken', assignee_id: userId });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('taken');
    expect(res.body.assignee_id).toBe(userId);
  });

  it('PATCH /tasks/:id — Task erledigen (status done)', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set('X-User-Id', userId)
      .send({ status: 'done' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('done');
    expect(res.body.assignee_id).toBe(userId);
  });
});

describe('error paths', () => {
  let existingUserId;

  beforeAll(async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ name: 'Bob', email: 'bob@example.com', password: 'secret123' });
    existingUserId = res.body.id;
  });

  it('POST /auth/register — doppelte E-Mail → 409', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ name: 'Bob2', email: 'bob@example.com', password: 'secret456' });

    expect(res.status).toBe(409);
    expect(res.body.error).toBeDefined();
  });

  it('POST /auth/register — fehlende Felder → 400', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ name: 'NoEmail' });

    expect(res.status).toBe(400);
  });

  it('POST /projects — kein X-User-Id Header → 401', async () => {
    const res = await request(app)
      .post('/projects')
      .send({ name: 'Unauthorized' });

    expect(res.status).toBe(401);
  });

  it('PATCH /tasks/:id — ungültiger Status → 400', async () => {
    const projRes = await request(app)
      .post('/projects')
      .set('X-User-Id', existingUserId)
      .send({ name: 'Temp' });
    const taskRes = await request(app)
      .post(`/projects/${projRes.body.id}/tasks`)
      .set('X-User-Id', existingUserId)
      .send({ title: 'Temp task' });

    const res = await request(app)
      .patch(`/tasks/${taskRes.body.id}`)
      .set('X-User-Id', existingUserId)
      .send({ status: 'invalid-status' });

    expect(res.status).toBe(400);
  });

  it('PATCH /tasks/:id — nicht existierender Task → 404', async () => {
    const res = await request(app)
      .patch('/tasks/00000000-0000-0000-0000-000000000000')
      .set('X-User-Id', existingUserId)
      .send({ status: 'done' });

    expect(res.status).toBe(404);
  });
});
