require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.FRONTEND_URL || '*',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting - 100 requests per 15 min per IP
app.use('/api/', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Too many requests, try again later' }
}));

// Health check - before auth routes
app.get('/api/health', (req, res) => res.json({
  status: 'ok',
  timestamp: new Date().toISOString()
}));

// Routes - order matters
app.use('/api/auth', require('./modules/auth/routes'));
app.use('/api/ngos', require('./modules/ngos/routes'));
app.use('/api/ngos', require('./modules/ngos/withdrawal_routes'));
app.use('/api/ngos', require('./modules/ngos/aid_routes'));
app.use('/api/campaigns', require('./modules/campaigns/routes'));
app.use('/api/donations', require('./modules/donations/routes'));
app.use('/api/volunteers', require('./modules/volunteers/routes'));
app.use('/api/admin', require('./modules/admin/routes'));
app.use('/api', require('./modules/beneficiaries/routes')); // Mounts /aid-requests

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handler - must be last
app.use(require('./middleware/error'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`API running on http://localhost:${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/api/health`);
});

module.exports = app;