const request = require('supertest');
const express = require('express');
const bodyParser = require('body-parser');

// Mock db and auth
const db = require('../src/config/db');
jest.mock('../src/config/db');

// Setup minimal app for testing the router
const app = express();
app.use(bodyParser.json());

// Mock res.success/fail middlewares if they exist in the actual app
app.use((req, res, next) => {
  res.success = (data, code = 200) => res.status(code).json({ success: true, data });
  res.fail = (error, code = 400) => res.status(code).json({ success: false, error });
  next();
});

const campaignRoutes = require('../src/modules/campaigns/routes');
app.use('/api/campaigns', campaignRoutes);

describe('Campaign Pagination Test', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('GET /api/campaigns uses default pagination (page 1, limit 10)', async () => {
    db.query.mockResolvedValue({ rows: [] });

    await request(app).get('/api/campaigns');

    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining('LIMIT $1 OFFSET $2'),
      [10, 0]
    );
  });

  test('GET /api/campaigns uses custom pagination (page 2, limit 5)', async () => {
    db.query.mockResolvedValue({ rows: [] });

    await request(app).get('/api/campaigns?page=2&limit=5');

    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining('LIMIT $1 OFFSET $2'),
      [5, 5]
    );
  });

  test('GET /api/campaigns preserves other query filters with pagination', async () => {
    db.query.mockResolvedValue({ rows: [] });

    await request(app).get('/api/campaigns?category=FOOD&page=3&limit=20');

    // The query should have 3 params: category, limit, offset
    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining('AND c.category = $1'),
      expect.arrayContaining(['FOOD', 20, 40])
    );
    
    // Check that limit and offset are the last two params
    const callArgs = db.query.mock.calls[0][1];
    expect(callArgs[callArgs.length - 2]).toBe(20); // limit
    expect(callArgs[callArgs.length - 1]).toBe(40); // offset
  });
});
