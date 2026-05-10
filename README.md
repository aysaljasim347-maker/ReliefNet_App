# DisasterAid PK 🇵🇰

A donation platform connecting donors to verified NGOs in Pakistan. Built with Node.js/Express + PostgreSQL backend and Flutter mobile-first frontend.

## Quick Start

### Prerequisites
- Node.js 18+
- PostgreSQL 15+
- Flutter SDK 3.3+ (for mobile app)

### Backend Setup

```bash
cd disasteraid-pk/backend

# 1. Install dependencies
npm install

# 2. Configure environment
cp .env.example .env
# Edit .env with your database URL, JWT secret, Cloudinary keys

# 3. Set up database
psql -U postgres -d disasteraid -f ../database/full_dump.sql

# 4. Run migrations
psql -U postgres -d disasteraid -f src/db/migrations/001_add_constraints.sql

# 5. Start development server
npm run dev
# Server runs on http://localhost:3000
```

### Flutter Setup

```bash
cd disasteraid-pk/flutter_app

# 1. Create .env file
echo "API_BASE_URL=http://10.0.2.2:3000/api" > .env
# Use 10.0.2.2 for Android emulator, localhost for web

# 2. Install dependencies
flutter pub get

# 3. Run the app
flutter run
```

### Running Tests

```bash
cd disasteraid-pk/backend
npm test                # Run all tests
npm run test:coverage   # Run with coverage report
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT` | Yes | Server port (default: 3000) |
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `JWT_SECRET` | Yes | JWT signing key (min 32 chars) |
| `NODE_ENV` | Yes | `development` or `production` |
| `CLOUDINARY_CLOUD_NAME` | Yes | Cloudinary cloud name |
| `CLOUDINARY_API_KEY` | Yes | Cloudinary API key |
| `CLOUDINARY_API_SECRET` | Yes | Cloudinary API secret |
| `PLATFORM_BANK_NAME` | Yes | Platform bank name (shown to donors) |
| `PLATFORM_ACCOUNT_TITLE` | Yes | Platform account title |
| `PLATFORM_ACCOUNT_NUMBER` | Yes | Platform account number |
| `PLATFORM_IBAN` | Yes | Platform IBAN |
| `MAIL_USER` | No | Gmail address for receipt emails |
| `MAIL_PASS` | No | Gmail app password |

## API Documentation

### Authentication

```
POST /api/auth/register   - Register new user
POST /api/auth/login      - Login (returns JWT)
GET  /api/auth/me         - Get current user profile
```

### Donation Flow (Core)

```
1. GET  /api/campaigns           - List active campaigns
2. GET  /api/campaigns/:id       - Campaign detail (includes platform bank info)
3. POST /api/donations           - Direct donation (auto-verified for MOCK/card)
4. POST /api/donations/manual    - Bank transfer donation (upload proof → admin verifies)
5. GET  /api/donations/my        - Donor's donation history
```

### Admin Verification Flow

```
1. GET   /api/donations/pending       - List pending bank transfer donations
2. PATCH /api/donations/:id/verify    - Verify/reject donation → credits NGO wallet
3. GET   /api/admin/stats             - Dashboard statistics
4. GET   /api/admin/export/donations  - CSV export of donations
5. GET   /api/admin/export/ngos       - CSV export of NGOs
```

### NGO Withdrawal Flow

```
1. GET  /api/ngos/wallet           - Check wallet balance
2. POST /api/ngos/withdrawals      - Request withdrawal (balance checked)
3. GET  /api/ngos/withdrawals      - Withdrawal history
4. PATCH /api/admin/withdrawals/:id - Admin approve → complete with proof
```

## Architecture

```
backend/
├── src/
│   ├── server.js           # Express app + middleware + routes
│   ├── config/db.js        # PostgreSQL pool
│   ├── middleware/
│   │   ├── auth.js          # JWT + role-based auth
│   │   └── error.js         # Error handler
│   ├── modules/
│   │   ├── auth/            # Registration, login, JWT
│   │   ├── campaigns/       # CRUD + map + nearby
│   │   ├── donations/       # Direct + manual + admin verify
│   │   ├── ngos/            # Profile, wallet, withdrawals, aid requests
│   │   ├── admin/           # Dashboard, analytics, exports, reports
│   │   ├── volunteers/      # Tasks, delivery tracking
│   │   ├── beneficiaries/   # Aid requests
│   │   ├── chat/            # Real-time messaging
│   │   └── notifications/   # In-app notifications
│   └── utils/
│       ├── upload.js        # Cloudinary + multer
│       ├── audit.js         # Admin action logging
│       ├── notify.js        # Notification creation
│       ├── pdf-receipts.js  # PDF receipt generation
│       ├── mailer.js        # Email sending
│       └── socket.js        # Socket.io setup
├── tests/                   # Jest + Supertest tests
└── .env.example
```

## Security Features

- **Helmet** security headers on all responses
- **Rate limiting**: 10 login attempts/15min, 5 donations/min per user, 100 API calls/15min
- **Parameterized queries** — no SQL injection possible (all fixed)
- **JWT authentication** with role-based access control
- **FOR UPDATE locks** on wallet/campaign during money operations
- **Input validation** via Joi on all POST/PATCH endpoints
- **File upload limits**: 5MB max, allowed formats: jpg, png, pdf
- **CORS** configured for specific origins
- **Request IDs** for tracing (X-Request-Id header)
- **Audit logging** for admin actions

## License

Private — DisasterAid PK
