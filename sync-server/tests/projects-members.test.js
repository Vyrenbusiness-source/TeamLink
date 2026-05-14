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

describe('projekt anlegen + mitglieder einladen', () => {
  let aliceId;
  let bobId;
  let projectId;

  beforeAll(async () => {
    const alice = await request(app)
      .post('/auth/register')
      .send({ name: 'Alice', email: 'alice@proj.com', password: 'secret123' });
    aliceId = alice.body.id;

    const bob = await request(app)
      .post('/auth/register')
      .send({ name: 'Bob', email: 'bob@proj.com', password: 'secret123' });
    bobId = bob.body.id;
  });

  it('POST /projects — projekt anlegen', async () => {
    const res = await request(app)
      .post('/projects')
      .set('X-User-Id', aliceId)
      .send({ name: 'Alpha' });
    expect(res.status).toBe(201);
    expect(res.body.name).toBe('Alpha');
    projectId = res.body.id;
  });

  it('GET /projects — eigene Projekte auflisten', async () => {
    const res = await request(app)
      .get('/projects')
      .set('X-User-Id', aliceId);
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].name).toBe('Alpha');
  });

  it('GET /projects/:id/members — creator ist lead', async () => {
    const res = await request(app)
      .get(`/projects/${projectId}/members`)
      .set('X-User-Id', aliceId);
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].id).toBe(aliceId);
    expect(res.body[0].role).toBe('lead');
  });

  it('POST /projects/:id/members — per E-Mail einladen', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/members`)
      .set('X-User-Id', aliceId)
      .send({ email: 'bob@proj.com', role: 'member' });
    expect(res.status).toBe(201);
    expect(res.body.user_id).toBe(bobId);
    expect(res.body.role).toBe('member');
  });

  it('POST /projects/:id/members — doppelt einladen → 409', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/members`)
      .set('X-User-Id', aliceId)
      .send({ email: 'bob@proj.com' });
    expect(res.status).toBe(409);
  });

  it('POST /projects/:id/members — per Username einladen', async () => {
    await request(app)
      .post('/auth/register')
      .send({ name: 'Carol', email: 'carol@proj.com', password: 'secret123' });
    const res = await request(app)
      .post(`/projects/${projectId}/members`)
      .set('X-User-Id', aliceId)
      .send({ username: 'Carol', role: 'observer' });
    expect(res.status).toBe(201);
    expect(res.body.role).toBe('observer');
  });

  it('POST /projects/:id/members — ungültige Rolle → 400', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/members`)
      .set('X-User-Id', aliceId)
      .send({ email: 'nobody@example.com', role: 'superadmin' });
    expect(res.status).toBe(400);
  });

  it('POST /projects/:id/members — unbekannte E-Mail → 404', async () => {
    const res = await request(app)
      .post(`/projects/${projectId}/members`)
      .set('X-User-Id', aliceId)
      .send({ email: 'nobody@example.com' });
    expect(res.status).toBe(404);
  });

  it('GET /projects — eingeladener Nutzer sieht Projekt', async () => {
    const res = await request(app)
      .get('/projects')
      .set('X-User-Id', bobId);
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
  });

  it('GET /projects — kein Header → 401', async () => {
    const res = await request(app).get('/projects');
    expect(res.status).toBe(401);
  });
});
