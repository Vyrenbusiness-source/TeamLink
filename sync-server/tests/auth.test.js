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
// /auth/register
// ---------------------------------------------------------------------------
describe('POST /auth/register', () => {
  it('legt User an und gibt Token-Paar zurück', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ name: 'Alice', email: 'alice@test.com', password: 'secret123' });

    expect(res.status).toBe(201);
    expect(res.body.user.email).toBe('alice@test.com');
    expect(res.body.user.password_hash).toBeUndefined();
    expect(typeof res.body.access_token).toBe('string');
    expect(typeof res.body.refresh_token).toBe('string');
    expect(res.body.token_type).toBe('Bearer');
    expect(res.body.expires_in).toBe(900);
  });

  it('gleiche E-Mail → 409', async () => {
    await request(app)
      .post('/auth/register')
      .send({ name: 'Dupe', email: 'dupe@test.com', password: 'secret123' });

    const res = await request(app)
      .post('/auth/register')
      .send({ name: 'Dupe2', email: 'dupe@test.com', password: 'secret456' });

    expect(res.status).toBe(409);
    expect(res.body.error).toMatch(/already in use/i);
  });

  it('fehlende Pflichtfelder → 400', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ email: 'nopass@test.com' });
    expect(res.status).toBe(400);
  });

  it('zu kurzes Passwort → 400', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ name: 'Short', email: 'short@test.com', password: 'abc' });
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// /auth/login
// ---------------------------------------------------------------------------
describe('POST /auth/login', () => {
  beforeAll(async () => {
    await request(app)
      .post('/auth/register')
      .send({ name: 'Bob', email: 'bob@test.com', password: 'password123' });
  });

  it('gültige Credentials → Token-Paar + User', async () => {
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'bob@test.com', password: 'password123' });

    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe('bob@test.com');
    expect(res.body.user.password_hash).toBeUndefined();
    expect(typeof res.body.access_token).toBe('string');
    expect(typeof res.body.refresh_token).toBe('string');
    expect(res.body.token_type).toBe('Bearer');
  });

  it('falsches Passwort → 401', async () => {
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'bob@test.com', password: 'wrong' });
    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/invalid credentials/i);
  });

  it('unbekannte E-Mail → 401', async () => {
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'nobody@test.com', password: 'password123' });
    expect(res.status).toBe(401);
  });

  it('fehlende Felder → 400', async () => {
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'bob@test.com' });
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// /auth/refresh
// ---------------------------------------------------------------------------
describe('POST /auth/refresh', () => {
  let firstRefreshToken;
  let rotatedRefreshToken;

  beforeAll(async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ name: 'Carol', email: 'carol@test.com', password: 'refresh999' });
    firstRefreshToken = res.body.refresh_token;
  });

  it('gültiger Refresh-Token → neues Token-Paar', async () => {
    const res = await request(app)
      .post('/auth/refresh')
      .send({ refresh_token: firstRefreshToken });

    expect(res.status).toBe(200);
    expect(typeof res.body.access_token).toBe('string');
    expect(typeof res.body.refresh_token).toBe('string');
    expect(res.body.token_type).toBe('Bearer');
    rotatedRefreshToken = res.body.refresh_token;
  });

  it('Token nach Rotation → 401 (revoked)', async () => {
    const res = await request(app)
      .post('/auth/refresh')
      .send({ refresh_token: firstRefreshToken });
    expect(res.status).toBe(401);
  });

  it('rotierter Token funktioniert', async () => {
    const res = await request(app)
      .post('/auth/refresh')
      .send({ refresh_token: rotatedRefreshToken });
    expect(res.status).toBe(200);
    expect(typeof res.body.access_token).toBe('string');
  });

  it('kein Token → 400', async () => {
    const res = await request(app).post('/auth/refresh').send({});
    expect(res.status).toBe(400);
  });

  it('ungültiger Token-String → 401', async () => {
    const res = await request(app)
      .post('/auth/refresh')
      .send({ refresh_token: 'not.a.valid.jwt' });
    expect(res.status).toBe(401);
  });

  it('Access-Token wird mit korrektem Subject ausgestellt', async () => {
    const jwt = require('jsonwebtoken');
    const reg = await request(app)
      .post('/auth/register')
      .send({ name: 'Dave', email: 'dave@test.com', password: 'secret123' });

    const loginRes = await request(app)
      .post('/auth/login')
      .send({ email: 'dave@test.com', password: 'secret123' });

    const payload = jwt.decode(loginRes.body.access_token);
    expect(payload.sub).toBe(reg.body.user.id);
  });
});
