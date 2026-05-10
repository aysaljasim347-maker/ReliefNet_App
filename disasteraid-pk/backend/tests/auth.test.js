/**
 * Auth Routes Tests
 * Tests: registration, login, token validation, edge cases
 */
const request = require('supertest');

// We need to set up the app without starting the server
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret-key-minimum-32-chars!!';
process.env.DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/disasteraid_test';

const app = require('../src/server');

describe('Auth Routes', () => {
  const testUser = {
    name: 'Test Donor',
    email: `testdonor_${Date.now()}@test.com`,
    password: 'testpass123',
    role: 'donor',
  };

  let token;

  describe('POST /api/auth/register', () => {
    it('should register a new user', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send(testUser)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data.token).toBeDefined();
      expect(res.body.data.user.email).toBe(testUser.email);
      token = res.body.data.token;
    });

    it('should reject duplicate email', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send(testUser)
        .expect(409);

      expect(res.body.success).toBe(false);
    });

    it('should reject missing password', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ email: 'x@x.com', role: 'donor', name: 'x' })
        .expect(400);

      expect(res.body.success).toBe(false);
    });

    it('should reject invalid role', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ email: 'y@y.com', password: '123456', role: 'hacker', name: 'y' })
        .expect(400);

      expect(res.body.success).toBe(false);
    });

    it('should reject short password', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ email: 'z@z.com', password: '12', role: 'donor', name: 'z' })
        .expect(400);

      expect(res.body.success).toBe(false);
    });

    it('should reject missing name', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ email: 'a@a.com', password: '123456', role: 'donor' })
        .expect(400);

      expect(res.body.success).toBe(false);
    });
  });

  describe('POST /api/auth/login', () => {
    it('should login with valid credentials', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: testUser.email, password: testUser.password })
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.token).toBeDefined();
      token = res.body.data.token;
    });

    it('should reject invalid password', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: testUser.email, password: 'wrongpass' })
        .expect(401);

      expect(res.body.success).toBe(false);
    });

    it('should reject non-existent email', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: 'nonexistent@test.com', password: 'testpass123' })
        .expect(401);

      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/auth/me', () => {
    it('should return user data with valid token', async () => {
      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.email).toBe(testUser.email);
      expect(res.body.data.role).toBe('donor');
    });

    it('should reject without token', async () => {
      const res = await request(app)
        .get('/api/auth/me')
        .expect(401);
    });

    it('should reject with invalid token', async () => {
      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', 'Bearer invalidtoken123')
        .expect(401);
    });
  });

  describe('Security: SQL Injection', () => {
    it('should not be vulnerable to SQL injection in login', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: "' OR 1=1 --", password: 'anything' })
        .expect(401);

      expect(res.body.success).toBe(false);
    });
  });
});
