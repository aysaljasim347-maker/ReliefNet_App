require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const http = require('http');
const socket = require('./utils/socket');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;

// Init Socket.io
socket.init(server);

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

// Rate limiting
app.use('/api/', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Too many requests, try again later' }
}));

// Health check
app.get('/api/health', (req, res) => res.json({
  status: 'ok',
  timestamp: new Date().toISOString()
}));

// Routes
app.use('/api/auth', require('./modules/auth/routes'));
app.use('/api/ngos', require('./modules/ngos/routes'));
app.use('/api/ngos', require('./modules/ngos/withdrawal_routes'));
app.use('/api/ngos', require('./modules/ngos/aid_routes'));
app.use('/api/campaigns', require('./modules/campaigns/routes'));
app.use('/api/donations', require('./modules/donations/routes'));
app.use('/api/volunteers', require('./modules/volunteers/routes'));
app.use('/api/admin', require('./modules/admin/routes'));
app.use('/api/notifications', require('./modules/notifications/routes')); // NEW
app.use('/api', require('./modules/beneficiaries/routes'));

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handler
app.use(require('./middleware/error'));

// Start server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`API running on http://localhost:${PORT}`);
  console.log(`Socket.io ready`);
});

module.exports = app;