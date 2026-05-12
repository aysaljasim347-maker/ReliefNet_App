# DEVELOPMENT HANDOFF

## 1. API PAYLOAD EXAMPLES

### POST /api/auth/register
**Request:**
curl -X POST http://localhost:3000/api/auth/register -H "Content-Type: application/json" -d '{"email":"donor@example.com","password":"password123","role":"donor","name":"John Doe"}'
**Success 201:** `{"success":true,"data":{"token":"JWT_TOKEN","user":{"id":1,"name":"John Doe","email":"donor@example.com","role":"donor"}},"error":null,"requestId":"UUID"}`
**Error 400:** `{"success":false,"data":null,"error":"\"password\" length must be at least 6 characters","requestId":"UUID"}`

### POST /api/auth/login
**Request:**
curl -X POST http://localhost:3000/api/auth/login -H "Content-Type: application/json" -d '{"email":"donor@example.com","password":"password123"}'
**Success 200:** `{"success":true,"data":{"token":"JWT_TOKEN","user":{"id":1,"name":"John Doe","email":"donor@example.com","role":"donor"}},"error":null,"requestId":"UUID"}`
**Error 401:** `{"success":false,"data":null,"error":"Invalid credentials","requestId":"UUID"}`

### POST /api/campaigns
**Request:**
curl -X POST http://localhost:3000/api/campaigns -H "Authorization: Bearer TOKEN" -F "title=Food Drive 2024" -F "description=Urgent food aid for flood victims in Sindh" -F "category=FOOD" -F "target_amount=500000" -F "location=Sindh" -F "end_date=2024-12-31" -F "image=@photo.jpg"
**Success 201:** `{"success":true,"data":{"id":1,"title":"Food Drive 2024","status":"ACTIVE",...},"error":null,"requestId":"UUID"}`
**Error 403:** `{"success":false,"data":null,"error":"NGO not approved yet","requestId":"UUID"}`

### POST /api/donations
**Request:**
curl -X POST http://localhost:3000/api/donations -H "Authorization: Bearer TOKEN" -d '{"campaign_id":1,"amount":5000,"payment_method":"MOCK"}'
**Success 201:** `{"success":true,"data":{"id":1,"amount":5000,"status":"VERIFIED",...},"error":null,"requestId":"UUID"}`
**Error 400:** `{"success":false,"data":null,"error":"Campaign not active","requestId":"UUID"}`

### POST /api/aid-requests
**Request:**
curl -X POST http://localhost:3000/api/aid-requests/aid-requests -H "Authorization: Bearer TOKEN" -d '{"category":"FOOD","items_needed":["Flour","Oil"],"description":"Family of 5 needs ration","location":"Karachi"}'
**Success 201:** `{"success":true,"data":{"id":1,"status":"PENDING",...},"error":null,"requestId":"UUID"}`

### POST /api/in-kind
**Request:**
curl -X POST http://localhost:3000/api/in-kind -H "Authorization: Bearer TOKEN" -d '{"title":"Wheelchair","description":"Slightly used","image_url":"http://cloudinary.com/img.jpg","location":"Lahore"}'
**Success 201:** `{"success":true,"data":{"id":1,"status":"available",...},"error":null,"requestId":"UUID"}`

**Standard Error Formats (middleware/error.js & server.js):**
- **400 Bad Request:** `{"success":false,"data":null,"error":"Validation error message","requestId":"UUID"}`
- **401 Unauthorized:** `{"success":false,"data":null,"error":"Invalid token","requestId":"UUID"}`
- **403 Forbidden:** `{"success":false,"data":null,"error":"Forbidden","requestId":"UUID"}`
- **404 Not Found:** `{"success":false,"data":null,"error":"Route not found","requestId":"UUID"}`
- **500 Internal Server Error:** `{"success":false,"data":null,"error":"Internal server error","requestId":"UUID"}`

## 2. DATABASE CONSTRAINTS & TRIGGERS
**Source:** `disasteraid-pk/database/schema.sql`

**UNIQUE Constraints:**
- `roles(name)`
- `users(email)`, `users(phone)`
- `ngo_profiles(user_id)`, `ngo_profiles(registration_number)`
- `ngo_wallets(ngo_id)`
- `volunteer_profiles(user_id)`
- `donations(transaction_ref)`, `donations(bank_reference)`
- `in_kind_requests(donation_id, beneficiary_id)`

**CHECK Constraints:**
- `reports_reason_check`: reason IN ('SPAM','SCAM','INAPPROPRIATE','FAKE','HARASSMENT','OTHER')
- `reports_status_check`: status IN ('PENDING','REVIEWED','RESOLVED','DISMISSED')
- `reports_target_type_check`: target_type IN ('user','campaign','request')
- `in_kind_donations_status_check`: status IN ('available', 'claimed', 'expired')
- `in_kind_requests_status_check`: status IN ('pending', 'approved', 'rejected')

**TRIGGERS:**
- `update_campaigns_updated_at`: BEFORE UPDATE ON campaigns → update_updated_at_column()
- `update_in_kind_donations_updated_at`: BEFORE UPDATE ON in_kind_donations → update_updated_at_column()

**DEFAULT Values:**
- `users.locale`: 'en'
- `users.created_at`: NOW()
- `ngo_profiles.status`: 'PENDING'
- `ngo_wallets.balance`: 0
- `donations.status`: 'completed' (Note: code often overrides to 'VERIFIED' or 'PENDING')
- `aid_requests.status`: 'PENDING'
- `aid_requests.urgency`: 'MEDIUM'
- `notifications.is_read`: FALSE

## 3. FILE UPLOAD SPEC
**Source:** `backend/src/utils/upload.js` and module routes.

PATH | FIELD_NAME | MAX_SIZE | ALLOWED_MIME | STORAGE_PATH | FILE:LINE
---|---|---|---|---|---
POST /api/campaigns | image | 5MB | jpg, png, pdf | cloudinary: disasteraid/ngo_docs | campaigns/routes.js:23
PUT /api/campaigns/:id | image | 5MB | jpg, png, pdf | cloudinary: disasteraid/ngo_docs | campaigns/routes.js:193
POST /api/donations/manual | proof | 5MB | jpg, png, pdf | cloudinary: disasteraid/ngo_docs | donations/routes.js:159
POST /api/ngos/onboard | docs (array, max 5) | 5MB | jpg, png, pdf | cloudinary: disasteraid/ngo_docs | ngos/routes.js:28
PATCH /api/admin/withdrawals/:id | proof | 5MB | jpg, png, pdf | cloudinary: disasteraid/ngo_docs | ngos/withdrawal_routes.js:111
PATCH /api/aids/:id/deliver | proof | 5MB | jpg, png, pdf | cloudinary: disasteraid/ngo_docs | ngos/aid_routes.js:114

## 4. SOCKET.IO EVENTS
**Source:** `backend/src/utils/socket.js`, `backend/src/modules/chat/routes.js`, `flutter_app/lib/features/chat/screens/chat_screen.dart`

EVENT_NAME | DIRECTION | PAYLOAD_SCHEMA | FILE:LINE
---|---|---|---
join | client→server | `userId` | utils/socket.js:12
join_request | client→server | `requestId` | utils/socket.js:18
leave_request | client→server | `requestId` | utils/socket.js:23
new_message | server→client | `{id, request_id, message, sender_id, sender_name, sender_role, created_at}` | chat/routes.js:70
notification | server→client | `{title, body, type, data}` (inferred from `sendToUser`) | utils/socket.js:36

## 5. SCHEDULED JOBS / CRON
**NONE_FOUND**

## 6. THIRD PARTY INTEGRATIONS
SERVICE | PURPOSE | ENV_VARS_NEEDED | SDK_VERSION | FILE:LINE
---|---|---|---|---
Cloudinary | Image & Doc Storage | CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET | cloudinary@1.41.3 | upload.js:4
Nodemailer | Sending Receipts/Emails | MAIL_USER, MAIL_PASS | nodemailer@8.0.7 | mailer.js:6
PostgreSQL | Primary Database | DATABASE_URL | pg@8.11.3 | config/db.js:5
Socket.io | Real-time Chat | - | socket.io@4.8.3 | utils/socket.js:1

## 7. STATE MACHINES
MODEL | FROM_STATUS | TO_STATUS | TRIGGER_ENDPOINT | FILE:LINE
---|---|---|---|---
aid_requests | PENDING | APPROVED | PATCH /api/admin/aid-requests/:id/assign | admin/routes.js:303
aid_requests | PENDING | REJECTED | PATCH /api/admin/aid-requests/:id/assign | admin/routes.js:280
aid_requests | APPROVED | ASSIGNED | POST /api/volunteers/tasks/:id/accept | volunteers/routes.js:75
aid_requests | ASSIGNED | DELIVERED | PATCH /api/volunteers/tasks/:id/status | volunteers/routes.js:125
campaigns | ACTIVE | PAUSED/COMPLETED/CANCELLED | PATCH /api/campaigns/:id/status | campaigns/routes.js:221
donations | PENDING | VERIFIED/REJECTED | PATCH /api/donations/:id/verify | donations/routes.js:254
withdrawals | PENDING | APPROVED | PATCH /api/admin/withdrawals/:id | admin/routes.js:347
withdrawals | APPROVED | COMPLETED | PATCH /api/admin/withdrawals/:id | admin/routes.js:347
withdrawals | PENDING | REJECTED | PATCH /api/admin/withdrawals/:id | admin/routes.js:347

## 8. ROLE-BASED ACCESS MATRIX
PATH | ADMIN | NGO | DONOR | VOLUNTEER | BENEFICIARY | FIELD_FILTERS
---|---|---|---|---|---|---
/api/admin/* | YES | NO | NO | NO | NO | ALL
/api/campaigns | GET | POST/PUT/PATCH | GET | GET | GET | NGO sees own stats
/api/donations | GET (Pending) | GET (NGO) | POST (Donor) | NO | NO | NGO sees limited donor info
/api/aid-requests | GET (All) | GET (NGO) | NO | GET (Available) | POST/GET (My) | -
/api/in-kind | GET | NO | POST/GET (My) | NO | GET/POST (Request) | -
/api/chat/:id | NO | NO | NO | YES (Assigned) | YES (Owner) | -

## 9. ENVIRONMENT DEPENDENCIES
**Backend:**
node -v: v24.15.0
npm list:
+-- bcrypt@6.0.0
+-- UNMET DEPENDENCY bcryptjs@^3.0.3
+-- cloudinary@1.41.3
+-- cors@2.8.6
+-- dotenv@16.6.1
+-- express-rate-limit@7.5.1
+-- express@4.22.1
+-- UNMET DEPENDENCY helmet@^8.1.0
+-- UNMET DEPENDENCY jest@^29.7.0
+-- joi@17.13.3
+-- jsonwebtoken@9.0.3
+-- UNMET DEPENDENCY morgan@^1.10.1
+-- multer-storage-cloudinary@4.0.0
+-- multer@2.1.1
+-- UNMET DEPENDENCY nodemailer@^8.0.7
+-- nodemon@3.1.14
+-- UNMET DEPENDENCY pdfkit@^0.18.0
+-- pg@8.20.0
+-- UNMET DEPENDENCY socket.io@^4.8.3
+-- UNMET DEPENDENCY supertest@^6.3.3
+-- UNMET DEPENDENCY uuid@^14.0.0

**Flutter:**
Flutter 3.41.9 • channel stable
Dart 3.11.5 • DevTools 2.54.2

**Flag:** Multiple `UNMET DEPENDENCY` in backend indicate `npm install` was incomplete or `package.json` has missing locks.

## 10. DEPLOYMENT REQUIREMENTS
**DEPLOYMENT_CONFIG_MISSING**

## 11. PERFORMANCE HOTSPOTS
FILE:LINE | ISSUE | WHY_RISKY
---|---|---
donations/routes.js:324 | Loop with Notification | Sequential notifications in `for` loop blocks the response if many rejections occur.
in_kind/routes.js:187 | Loop with Notification | Same as above; blocks donor approval flow.
admin/routes.js:181 | 4 Sequential DB Queries | `analytics` endpoint runs 4 heavy aggregations without parallelism (though `Promise.all` is used, Postgres handles them sequentially if not optimized).
campaigns/routes.js:52 | Missing Pagination | `GET /api/campaigns` returns full table; will crash client as data grows.
schema.sql | Missing Indexes | No indexes on `messages.sender_id`, `ngo_profiles.approved_by`, `donations.verified_by`.

## 12. CONFIG & FEATURE FLAGS
FLAG_NAME | DEFAULT | PURPOSE | FILE:LINE
---|---|---|---
DATABASE_URL | - | DB Connection String | config/db.js:5
JWT_SECRET | - | JWT Signing Key | auth/routes.js:32
PLATFORM_IBAN | - | Target for manual donations | donations/routes.js:183
FRONTEND_URL | localhost:3000 | CORS allowed origins | server.js:236
NODE_ENV | - | Logging/Error Verbosity | server.js:359

## 13. EXTERNAL API CONTRACTS
**NONE_FOUND** (Uses SDKs for Cloudinary and Nodemailer)

## 14. MIGRATION HISTORY
FILENAME | DATE | CHANGES_SUMMARY
---|---|---
001_add_constraints.sql | 2026-05-10 | Added DB constraints and initial schema adjustments.
add_in_kind_tables.sql | 2026-05-12 | Created tables for in-kind donations and requests.
