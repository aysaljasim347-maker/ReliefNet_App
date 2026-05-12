// require('dotenv').config();
// const express = require('express');
// const cors = require('cors');
// const rateLimit = require('express-rate-limit');
// const helmet = require('helmet');
// const http = require('http');
// const morgan = require('morgan');
// const { v4: uuidv4 } = require('uuid');
// const socket = require('./utils/socket');
// const inKindRoutes = require('./modules/in_kind/routes');


// const app = express();
// const server = http.createServer(app);
// app.use('/api/in-kind', inKindRoutes);
// const PORT = process.env.PORT || 3000;

// // Init Socket.io
// socket.init(server);
// app.set('io', socket.getIO());

// // Trust proxy for rate limiting behind nginx/heroku
// app.set('trust proxy', 1);

// // Security middleware
// app.use(helmet({
//   crossOriginResourcePolicy: { policy: "cross-origin" } // Allow image loading
// }));

// app.use(cors({
//   origin: process.env.FRONTEND_URL?.split(',') || ['http://localhost:3000', 'http://localhost:8080'],
//   credentials: true,
//   methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']
// }));

// // Request ID for tracing
// app.use((req, res, next) => {
//   req.id = uuidv4();
//   res.setHeader('X-Request-Id', req.id);
//   next();
// });

// // Logging
// if (process.env.NODE_ENV !== 'test') {
//   morgan.token('id', (req) => req.id);
//   app.use(morgan(':id :method :url :status :response-time ms'));
// }

// // Body parsing
// app.use(express.json({ limit: '10mb' }));
// app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// // Standard response helpers - ADD THIS
// app.use((req, res, next) => {
//   res.success = (data, code = 200) => {
//     return res.status(code).json({
//       success: true,
//       data,
//       error: null,
//       requestId: req.id
//     });
//   };

//   res.fail = (error, code = 400) => {
//     return res.status(code).json({
//       success: false,
//       data: null,
//       error: typeof error === 'string' ? error : error.message,
//       requestId: req.id
//     });
//   };

//   next();
// });

// // Rate limiting - Stricter for auth
// const authLimiter = rateLimit({
//   windowMs: 15 * 60 * 1000,
//   max: 10,
//   standardHeaders: true,
//   legacyHeaders: false,
//   message: { success: false, data: null, error: 'Too many attempts, try again in 15 minutes' }
// });

// const apiLimiter = rateLimit({
//   windowMs: 15 * 60 * 1000,
//   max: 100,
//   standardHeaders: true,
//   legacyHeaders: false,
//   message: { success: false, data: null, error: 'Too many requests, try again later' }
// });

// const donationLimiter = rateLimit({
//   windowMs: 60 * 1000,
//   max: 5,
//   standardHeaders: true,
//   legacyHeaders: false,
//   keyGenerator: (req) => req.user?.id || req.ip,
//   message: { success: false, data: null, error: 'Too many donations. Max 5 per minute.' }
// });

// app.use('/api/auth', authLimiter);
// app.use('/api/', apiLimiter);

// // Health check
// app.get('/api/health', (req, res) => res.success({
//   status: 'ok',
//   timestamp: new Date().toISOString(),
//   uptime: process.uptime()
// }));

// // Static file serving for receipts and uploads
// const path = require('path');
// app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// // Routes
// app.use('/api/chat', require('./modules/chat/routes'));
// app.use('/api/auth', require('./modules/auth/routes'));
// app.use('/api/ngos', require('./modules/ngos/routes'));
// app.use('/api/ngos', require('./modules/ngos/withdrawal_routes'));
// app.use('/api/ngos', require('./modules/ngos/aid_routes'));
// app.use('/api/campaigns', require('./modules/campaigns/routes'));
// app.use('/api/donations', donationLimiter, require('./modules/donations/routes'));
// app.use('/api/volunteers', require('./modules/volunteers/routes'));
// app.use('/api/admin', require('./modules/admin/routes'));
// app.use('/api/admin/export', require('./modules/admin/export_routes'));
// app.use('/api/notifications', require('./modules/notifications/routes'));
// app.use('/api', require('./modules/beneficiaries/routes'));

// // 404 handler
// app.use((req, res) => {
//   res.fail('Route not found', 404);
// });

// // Global error handler - UPDATED
// app.use((err, req, res, next) => {
//   console.error(`[${req.id}] Error:`, err);

//   // Multer file errors
//   if (err.code === 'LIMIT_FILE_SIZE') {
//     return res.fail('File too large. Max 5MB', 413);
//   }

//   // JWT errors
//   if (err.name === 'JsonWebTokenError') {
//     return res.fail('Invalid token', 401);
//   }

//   if (err.name === 'TokenExpiredError') {
//     return res.fail('Token expired', 401);
//   }

//   // Postgres errors
//   if (err.code === '23505') {
//     return res.fail('Resource already exists', 409);
//   }

//   if (err.code === '23503') {
//     return res.fail('Referenced resource not found', 400);
//   }

//   // Default
//   const status = err.status || err.statusCode || 500;
//   const message = process.env.NODE_ENV === 'production' && status === 500 
//     ? 'Internal server error' 
//     : err.message;

//   res.fail(message, status);
// });

// // Start server
// const serverInstance = server.listen(PORT, '0.0.0.0', () => {
//   console.log(`[${process.env.NODE_ENV}] API running on http://localhost:${PORT}`);
//   console.log(`Socket.io ready`);
// });

// // Graceful shutdown - ADD THIS
// const shutdown = async () => {
//   console.log('Shutting down gracefully...');
//   serverInstance.close(() => {
//     console.log('HTTP server closed');
//     socket.getIO().close();
//     console.log('Socket.io closed');
//     process.exit(0);
//   });

//   // Force close after 10s
//   setTimeout(() => {
//     console.error('Forced shutdown');
//     process.exit(1);
//   }, 10000);
// };

// process.on('SIGTERM', shutdown);
// process.on('SIGINT', shutdown);

// module.exports = app;

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const http = require('http');
const morgan = require('morgan');
const { v4: uuidv4 } = require('uuid');
const socket = require('./utils/socket');
const inKindRoutes = require('./modules/in_kind/routes');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;

// Init Socket.io
socket.init(server);
app.set('io', socket.getIO());

// Trust proxy for rate limiting behind nginx/heroku
app.set('trust proxy', 1);

// Security middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));

// ── CORS — must be before ALL routes ─────────────────────────────────────────
app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps, curl, Postman)
    if (!origin) return callback(null, true);
    // Allow all localhost ports and Android emulator loopback
    if (origin.startsWith('http://localhost') || 
        origin.startsWith('http://127.0.0.1') ||
        origin.startsWith('http://10.0.2.2')) {
      return callback(null, true);
    }
    // Allow production origins from .env
    const allowed = process.env.FRONTEND_URL?.split(',') || [];
    if (allowed.includes(origin)) return callback(null, true);
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  exposedHeaders: ['X-Request-Id'], // Crucial for client-side tracing
}));

// Handle preflight for all routes
app.options('*', cors());

// Force JSON Content-Type for all responses to prevent Flutter decode crashes
app.use((req, res, next) => {
  res.setHeader('Content-Type', 'application/json');
  next();
});

// Request ID for tracing
app.use((req, res, next) => {
  req.id = uuidv4();
  res.setHeader('X-Request-Id', req.id);
  next();
});

// Logging
if (process.env.NODE_ENV !== 'test') {
  morgan.token('id', (req) => req.id);
  app.use(morgan(':id :method :url :status :response-time ms'));
}

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Standard response helpers
app.use((req, res, next) => {
  res.success = (data, code = 200) => {
    return res.status(code).json({
      success: true,
      data,
      error: null,
      requestId: req.id
    });
  };

  res.fail = (error, code = 400) => {
    return res.status(code).json({
      success: false,
      data: null,
      error: typeof error === 'string' ? error : error.message,
      requestId: req.id
    });
  };

  next();
});

// Rate limiting
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, data: null, error: 'Too many attempts, try again in 15 minutes' }
});

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, data: null, error: 'Too many requests, try again later' }
});

const donationLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id || req.ip,
  message: { success: false, data: null, error: 'Too many donations. Max 5 per minute.' }
});

app.use('/api/auth', authLimiter);
app.use('/api/', apiLimiter);

// Health check
app.get('/api/health', (req, res) => res.success({
  status: 'ok',
  timestamp: new Date().toISOString(),
  uptime: process.uptime()
}));

// Static files
const path = require('path');
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/chat', require('./modules/chat/routes'));
app.use('/api/auth', require('./modules/auth/routes'));
app.use('/api/ngos', require('./modules/ngos/routes'));
app.use('/api/ngos', require('./modules/ngos/withdrawal_routes'));
app.use('/api/ngos', require('./modules/ngos/aid_routes'));
app.use('/api/campaigns', require('./modules/campaigns/routes'));
app.use('/api/donations', donationLimiter, require('./modules/donations/routes'));
app.use('/api/volunteers', require('./modules/volunteers/routes'));
app.use('/api/admin', require('./modules/admin/routes'));
app.use('/api/admin/export', require('./modules/admin/export_routes'));
app.use('/api/notifications', require('./modules/notifications/routes'));
app.use('/api/in-kind', inKindRoutes);           // ← moved here with all routes
app.use('/api', require('./modules/beneficiaries/routes'));

// 404 handler
app.use((req, res) => {
  res.fail('Route not found', 404);
});

// Global error handler - STANDARDIZED
app.use((err, req, res, next) => {
  console.error(`[${req.id}] Error:`, err);

  let statusCode = err.status || err.statusCode || 500;
  let errorCode = 'SERVER_ERROR';
  let message = err.message || 'An unexpected error occurred';
  let details = err.details || [];

  // Multer file errors
  if (err.code === 'LIMIT_FILE_SIZE') {
    statusCode = 413;
    errorCode = 'FILE_TOO_LARGE';
    message = 'File size exceeds 5MB limit';
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    errorCode = 'INVALID_TOKEN';
    message = 'Authentication failed: Invalid token';
  }

  if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    errorCode = 'TOKEN_EXPIRED';
    message = 'Session expired. Please log in again.';
  }

  // Postgres errors
  if (err.code === '23505') {
    statusCode = 409;
    errorCode = 'DUPLICATE_RESOURCE';
    message = 'A resource with this information already exists';
  }

  if (err.code === '23503') {
    statusCode = 400;
    errorCode = 'FOREIGN_KEY_VIOLATION';
    message = 'Referenced resource not found';
  }

  // Joi Validation errors (extracted from Joi schema.validate)
  if (err.isJoi) {
    statusCode = 400;
    errorCode = 'VALIDATION_FAILED';
    message = 'Invalid request data';
    details = err.details.map(d => ({
      field: d.path[0],
      message: d.message
    }));
  }

  // Hide detailed errors in production
  if (process.env.NODE_ENV === 'production' && statusCode === 500) {
    message = 'Internal server error';
  }

  res.status(statusCode).json({
    success: false,
    error: errorCode,
    message: message,
    details: details,
    requestId: req.id
  });
});

// Start server
const serverInstance = server.listen(PORT, '0.0.0.0', () => {
  console.log(`[${process.env.NODE_ENV}] API running on http://localhost:${PORT}`);
  console.log(`Socket.io ready`);
});

// Graceful shutdown
const shutdown = async () => {
  console.log('Shutting down gracefully...');
  serverInstance.close(() => {
    console.log('HTTP server closed');
    socket.getIO().close();
    console.log('Socket.io closed');
    process.exit(0);
  });
  setTimeout(() => {
    console.error('Forced shutdown');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

module.exports = app;
