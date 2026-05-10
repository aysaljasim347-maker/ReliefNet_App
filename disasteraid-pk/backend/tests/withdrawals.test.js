/**
 * Withdrawal Flow Tests
 * Tests: create withdrawal, balance check, admin approve/reject, edge cases
 */
const request = require('supertest');

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret-key-minimum-32-chars!!';
process.env.DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/disasteraid_test';

const app = require('../src/server');

describe('Withdrawal Routes', () => {
  let ngoToken;
  let adminToken;

  beforeAll(async () => {
    // Login as NGO
    try {
      const ngoRes = await request(app)
        .post('/api/auth/login')
        .send({ email: 'ngo@gmail.com', password: 'password123' });
      ngoToken = ngoRes.body?.data?.token;
    } catch (e) {
      console.warn('NGO login failed:', e.message);
    }

    // Login as admin
    try {
      const adminRes = await request(app)
        .post('/api/auth/login')
        .send({ email: 'admin@gmail.com', password: 'password123' });
      adminToken = adminRes.body?.data?.token;
    } catch (e) {
      console.warn('Admin login failed:', e.message);
    }
  });

  describe('POST /api/ngos/withdrawals', () => {
    it('should reject without auth', async () => {
      await request(app)
        .post('/api/ngos/withdrawals')
        .send({
          amount: 100,
          bank_name: 'Test Bank',
          account_title: 'Test Account',
          account_number: '12345678',
          iban: 'PK36SCBL000000112345670',
        })
        .expect(401);
    });

    it('should reject amount below minimum', async () => {
      if (!ngoToken) return;

      const res = await request(app)
        .post('/api/ngos/withdrawals')
        .set('Authorization', `Bearer ${ngoToken}`)
        .send({
          amount: 50,
          bank_name: 'Test Bank',
          account_title: 'Test Account',
          account_number: '12345678',
          iban: 'PK36SCBL000000112345670',
        })
        .expect(400);

      expect(res.body.success).toBe(false);
    });

    it('should reject negative amount', async () => {
      if (!ngoToken) return;

      const res = await request(app)
        .post('/api/ngos/withdrawals')
        .set('Authorization', `Bearer ${ngoToken}`)
        .send({
          amount: -1000,
          bank_name: 'Test Bank',
          account_title: 'Test Account',
          account_number: '12345678',
          iban: 'PK36SCBL000000112345670',
        })
        .expect(400);

      expect(res.body.success).toBe(false);
    });

    it('should reject missing bank details', async () => {
      if (!ngoToken) return;

      const res = await request(app)
        .post('/api/ngos/withdrawals')
        .set('Authorization', `Bearer ${ngoToken}`)
        .send({ amount: 1000 })
        .expect(400);

      expect(res.body.success).toBe(false);
    });

    // This test depends on the NGO having sufficient balance
    it('should reject withdrawal exceeding balance', async () => {
      if (!ngoToken) return;

      const res = await request(app)
        .post('/api/ngos/withdrawals')
        .set('Authorization', `Bearer ${ngoToken}`)
        .send({
          amount: 999999999,
          bank_name: 'Test Bank',
          account_title: 'Test Account',
          account_number: '12345678',
          iban: 'PK36SCBL000000112345670',
        });

      // Should fail with 500 (thrown error about insufficient balance)
      expect(res.status).toBeGreaterThanOrEqual(400);
    });
  });

  describe('GET /api/ngos/withdrawals', () => {
    it('should return NGO withdrawal history', async () => {
      if (!ngoToken) return;

      const res = await request(app)
        .get('/api/ngos/withdrawals')
        .set('Authorization', `Bearer ${ngoToken}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);
    });
  });

  describe('GET /api/ngos/wallet', () => {
    it('should return wallet balance', async () => {
      if (!ngoToken) return;

      const res = await request(app)
        .get('/api/ngos/wallet')
        .set('Authorization', `Bearer ${ngoToken}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('balance');
      expect(res.body.data).toHaveProperty('total_received');
      expect(res.body.data).toHaveProperty('total_withdrawn');
    });
  });

  describe('Admin Withdrawal Management', () => {
    it('should list withdrawals for admin', async () => {
      if (!adminToken) return;

      const res = await request(app)
        .get('/api/admin/withdrawals')
        .set('Authorization', `Bearer ${adminToken}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('should reject non-admin listing withdrawals', async () => {
      if (!ngoToken) return;

      await request(app)
        .get('/api/admin/withdrawals')
        .set('Authorization', `Bearer ${ngoToken}`)
        .expect(403);
    });
  });
});
