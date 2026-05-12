# PROJECT SNAPSHOT - ReliefNet App (DisasterAid PK)
**TRULY EXHAUSTIVE VERSION**

## 1. PROJECT STRUCTURE & MODULES
```
C:\project\ReliefNet_App\disasteraid-pk
├───backend
│   ├───src
│   │   ├───config/ (db.js)
│   │   ├───middleware/ (auth.js, error.js)
│   │   ├───modules/
│   │   │   ├───admin/ (routes.js, export_routes.js)
│   │   │   ├───auth/ (routes.js)
│   │   │   ├───beneficiaries/ (routes.js)
│   │   │   ├───campaigns/ (routes.js)
│   │   │   ├───chat/ (routes.js)
│   │   │   ├───donations/ (routes.js)
│   │   │   ├───in_kind/ (routes.js)
│   │   │   ├───ngos/ (routes.js, aid_routes.js, withdrawal_routes.js)
│   │   │   ├───notifications/ (routes.js)
│   │   │   └───volunteers/ (routes.js)
│   │   ├───utils/ (audit.js, mailer.js, notify.js, pdf-receipts.js, socket.js, upload.js)
│   │   └───server.js
│   ├───tests/ (auth.test.js, donations.test.js, withdrawals.test.js)
│   └───package.json
├───database
│   ├───schema.sql (Full DDL)
│   └───full_dump.sql
└───flutter_app
    ├───lib
    │   ├───core/ (api/api_client.dart, auth/auth_provider.dart, services/)
    │   ├───features/ (admin, auth, beneficiaries, campaigns, chat, donations, donor, in_kind, maps, ngo, settings, volunteers)
    │   ├───shared/ (widgets)
    │   └───main.dart
```

## 2. BACKEND API ROUTES (EXHAUSTIVE)

### Auth Module (`auth/routes.js`)
| METHOD | PATH | AUTH | ROLES | VALIDATION KEYS | HANDLER |
|--------|------|------|-------|-----------------|---------|
| POST | /api/auth/register | None | ALL | email, phone, password, role, name | routes.js:16 |
| POST | /api/auth/login | None | ALL | email, password | routes.js:40 |
| GET | /api/auth/me | auth() | ALL | None | routes.js:59 |
| PATCH | /api/auth/fcm-token | auth() | ALL | fcm_token | routes.js:71 |

### Admin Module (`admin/routes.js`)
| METHOD | PATH | AUTH | ROLES | VALIDATION KEYS | HANDLER |
|--------|------|------|-------|-----------------|---------|
| GET | /api/admin/stats | auth('admin') | admin | None | routes.js:9 |
| PATCH | /api/admin/ngos/:id/approve | auth('admin') | admin | None | routes.js:55 |
| PATCH | /api/admin/ngos/:id/reject | auth('admin') | admin | reason | routes.js:67 |
| GET | /api/admin/ngos | auth('admin') | admin | status (query) | routes.js:83 |
| GET | /api/admin/ngos/pending | auth('admin') | admin | None | routes.js:115 |
| GET | /api/admin/ngos/all | auth('admin') | admin | None | routes.js:129 |
| GET | /api/admin/campaigns | auth('admin') | admin | status, ngo_id (query) | routes.js:142 |
| PATCH | /api/admin/campaigns/:id/status | auth('admin') | admin | status | routes.js:163 |
| GET | /api/admin/analytics | auth('admin') | admin | start_date, end_date (query) | routes.js:179 |
| GET | /api/admin/aid-requests | auth('admin') | admin | status (query) | routes.js:240 |
| PATCH | /api/admin/aid-requests/:id/assign| auth('admin') | admin | ngo_id, status, rejection_reason | routes.js:266 |
| GET | /api/admin/withdrawals | auth('admin') | admin | status (query) | routes.js:308 |
| PATCH | /api/admin/withdrawals/:id | auth('admin') | admin | status, admin_notes, transaction_ref | routes.js:328 |
| POST | /api/reports | auth() | ALL | target_type, target_id, reason, description | routes.js:388 |
| GET | /api/admin/reports | auth('admin') | admin | status (query) | routes.js:415 |
| PATCH | /api/admin/reports/:id | auth('admin') | admin | status, admin_notes | routes.js:437 |
| GET | /api/admin/audit-logs | auth('admin') | admin | action, target_type, limit (query) | routes.js:457 |
| PATCH | /api/admin/ngos/:id/status | auth('admin') | admin | status, rejection_reason | routes.js:484 |
| GET | /api/admin/delivered | auth('admin') | admin | None | routes.js:522 |

### Campaigns Module (`campaigns/routes.js`)
| METHOD | PATH | AUTH | ROLES | VALIDATION KEYS | HANDLER |
|--------|------|------|-------|-----------------|---------|
| POST | /api/campaigns | auth('ngo') | ngo | title, desc, category, target, location, end_date, lat, lng | routes.js:23 |
| GET | /api/campaigns | None | ALL | ngo_id, status, category (query) | routes.js:55 |
| GET | /api/campaigns/my | auth('ngo') | ngo | None | routes.js:84 |
| GET | /api/campaigns/map | None | ALL | None | routes.js:102 |
| GET | /api/campaigns/nearby | None | ALL | lat, lng, radius (query) | routes.js:120 |
| GET | /api/campaigns/:id | None | ALL | None | routes.js:160 |
| PUT | /api/campaigns/:id | auth('ngo') | ngo | (same as POST) | routes.js:193 |
| PATCH | /api/campaigns/:id/status | auth('ngo') | ngo | status | routes.js:221 |

### Donations Module (`donations/routes.js`)
| METHOD | PATH | AUTH | ROLES | VALIDATION KEYS | HANDLER |
|--------|------|------|-------|-----------------|---------|
| POST | /api/donations | auth() | ALL | campaign_id, amount, payment_method, transaction_id | routes.js:24 |
| GET | /api/donations/my | auth() | ALL | None | routes.js:121 |
| GET | /api/donations/receipt/:id | auth() | ALL | None | routes.js:140 |
| POST | /api/donations/manual | auth('donor') | donor | campaign_id, amount, donor_note, proof (file) | routes.js:159 |
| GET | /api/donations/ngo | auth('ngo') | ngo | None | routes.js:217 |
| GET | /api/donations/pending | auth('admin') | admin | None | routes.js:235 |
| PATCH | /api/donations/:id/verify | auth('admin') | admin | status, rejection_reason | routes.js:254 |

### Beneficiaries Module (`beneficiaries/routes.js`)
| METHOD | PATH | AUTH | ROLES | VALIDATION KEYS | HANDLER |
|--------|------|------|-------|-----------------|---------|
| POST | /api/aid-requests | auth('beneficiary')| beneficiary | campaign_id, category, items_needed, description, family_size | routes.js:20 |
| GET | /api/aid-requests/my | auth('beneficiary')| beneficiary | None | routes.js:67 |
| GET | /api/aid-requests/:id | auth('beneficiary')| beneficiary | None | routes.js:89 |
| DELETE | /api/aid-requests/:id | auth('beneficiary')| beneficiary | None | routes.js:110 |
| GET | /api/aid-requests/map | auth('volunteer') | volunteer | status (query) | routes.js:123 |

### In-Kind Module (`in_kind/routes.js`)
| METHOD | PATH | AUTH | ROLES | VALIDATION KEYS | HANDLER |
|--------|------|------|-------|-----------------|---------|
| POST | /api/in-kind | auth('donor') | donor | title, desc, image_url, location, lat, lng, expires_at | routes.js:28 |
| GET | /api/in-kind/my | auth('donor') | donor | None | routes.js:58 |
| GET | /api/in-kind/my/:id/requests| auth('donor') | donor | None | routes.js:82 |
| POST | /api/in-kind/my/:dId/requests/:rId/approve | auth('donor') | donor | None | routes.js:111 |
| GET | /api/in-kind | auth('beneficiary')| beneficiary | None | routes.js:217 |
| GET | /api/in-kind/my-requests | auth('beneficiary')| beneficiary | None | routes.js:248 |
| GET | /api/in-kind/:id | auth('beneficiary')| beneficiary | None | routes.js:286 |
| POST | /api/in-kind/:id/request | auth('beneficiary')| beneficiary | message | routes.js:312 |
| GET | /api/in-kind/admin/all | auth('admin') | admin | None | routes.js:368 |

### NGOs Module (`ngos/routes.js` + `aid_routes.js` + `withdrawal_routes.js`)
| METHOD | PATH | AUTH | ROLES | VALIDATION KEYS | HANDLER |
|--------|------|------|-------|-----------------|---------|
| GET | /api/ngos | None | ALL | None | routes.js:18 |
| POST | /api/ngos/onboard | auth('ngo') | ngo | org_name, reg_num, address, contact, mission, docs (files) | routes.js:28 |
| GET | /api/ngos/me | auth('ngo') | ngo | None | routes.js:54 |
| GET | /api/ngos/profile | auth('ngo') | ngo | None | routes.js:69 |
| GET | /api/ngos/dashboard/stats | auth('ngo') | ngo | None | routes.js:77 |
| GET | /api/ngos/dashboard/chart | auth('ngo') | ngo | days (query) | routes.js:110 |
| GET | /api/ngos/dashboard/recent | auth('ngo') | ngo | None | routes.js:135 |
| PUT | /api/ngos/bank-details | auth('ngo') | ngo | bank_name, account_title, account_number, iban | routes.js:154 |
| GET | /api/ngos/aid-requests | auth('ngo') | ngo | status (query) | aid_routes.js:15 |
| PATCH | /api/ngos/aid-requests/:id | auth('ngo') | ngo | status, rejection_reason | aid_routes.js:42 |
| GET | /api/ngos/volunteers | auth('ngo') | ngo | None | aid_routes.js:73 |
| GET | /api/ngos/aid-requests/:id | auth('ngo') | ngo | None | aid_routes.js:94 |
| PATCH | /api/ngos/:id/deliver | auth('volunteer') | volunteer | proof (file), delivery_notes | aid_routes.js:114 |
| GET | /api/ngos/:id/proof | auth() | ALL | None | aid_routes.js:153 |
| POST | /api/ngos/withdrawals | auth('ngo') | ngo | amount, bank_name, account_title, account_number, iban | withdrawal_routes.js:18 |
| GET | /api/ngos/withdrawals | auth('ngo') | ngo | None | withdrawal_routes.js:58 |
| GET | /api/ngos/wallet | auth('ngo') | ngo | None | withdrawal_routes.js:76 |

### Volunteers Module (`volunteers/routes.js`)
| METHOD | PATH | AUTH | ROLES | VALIDATION KEYS | HANDLER |
|--------|------|------|-------|-----------------|---------|
| POST | /api/volunteers/register | auth('volunteer') | volunteer | ngo_id, location, skills, availability | routes.js:16 |
| GET | /api/volunteers/tasks/available | auth('volunteer') | volunteer | None | routes.js:38 |
| POST | /api/volunteers/tasks/:id/accept | auth('volunteer') | volunteer | None | routes.js:60 |

### Notifications & Chat (`notifications/routes.js`, `chat/routes.js`)
| METHOD | PATH | AUTH | ROLES | VALIDATION KEYS | HANDLER |
|--------|------|------|-------|-----------------|---------|
| GET | /api/notifications | auth() | ALL | None | notifications/routes.js:6 |
| PATCH | /api/notifications/:id/read | auth() | ALL | None | notifications/routes.js:20 |
| PATCH | /api/notifications/read-all | auth() | ALL | None | notifications/routes.js:32 |
| GET | /api/chat/:requestId | auth() | ALL | None | chat/routes.js:12 |
| POST | /api/chat/:requestId | auth() | ALL | message | chat/routes.js:45 |
| GET | /api/chat | auth() | ALL | None | chat/routes.js:85 |

## 3. FRONTEND API CALLS (EXHAUSTIVE)

| METHOD | FULL_PATH | FILE | BODY KEYS / PARAMS | RESPONSE TYPE |
|--------|-----------|------|--------------------|---------------|
| GET | /auth/me | auth_provider.dart | None | User Object |
| POST | /auth/register | auth_provider.dart | email, phone, password, role, name | Token + User |
| POST | /auth/login | auth_provider.dart | email, password | Token + User |
| GET | /admin/audit-logs | admin_audit_screen.dart | query params | List<AuditLog> |
| GET | /admin/campaigns | admin_campaigns_screen.dart| query params | List<Campaign> |
| PATCH | /admin/campaigns/:id/status| admin_campaigns_screen.dart| status | Campaign |
| GET | /admin/stats | admin_dashboard.dart | None | Stats Object |
| GET | /in-kind/admin/all | admin_dashboard.dart | None | List<InKind> |
| GET | /admin/aids/delivered | admin_delivery_proofs_screen.dart| None | List<AidRequest> |
| GET | /donations/pending | admin_donations_screen.dart | None | List<Donation> |
| PATCH | /donations/:id/verify | admin_donations_screen.dart | status, rejection_reason | Donation |
| GET | /admin/ngos | admin_ngos_screen.dart | status (query) | List<NGO> |
| PATCH | /admin/ngos/:id/approve | admin_ngos_screen.dart | None | NGO |
| PATCH | /admin/ngos/:id/reject | admin_ngos_screen.dart | reason | NGO |
| GET | /admin/reports | admin_reports_screen.dart | status (query) | List<Report> |
| PATCH | /admin/reports/:id | admin_reports_screen.dart | status, admin_notes | Report |
| GET | /admin/aid-requests | admin_request_screen.dart | status (query) | List<AidRequest> |
| PATCH | /admin/aid-requests/:id/assign| admin_request_screen.dart | ngo_id, status, reason | AidRequest |
| GET | /admin/withdrawals | admin_withdrawals_screen.dart| query params | List<Withdrawal>|
| PATCH | /admin/withdrawals/:id | admin_withdrawals_screen.dart| FormData (proof, etc) | Withdrawal |
| GET | /in-kind/my-requests | beneficiary_my_request_screen.dart| None | List<InKindReq> |
| GET | /aid-requests/my | beneficiary_dashboard.dart | None | List<AidRequest> |
| GET | /beneficiary/stats | beneficiary_dashboard.dart | None | Stats Object |
| GET | /campaigns/map | beneficiary_map_screen.dart | None | List<MapCampaign>|
| POST | /aid-requests | request_aid_screen.dart | category, items, desc, etc | AidRequest |
| POST | /donations/manual | campaign_detail_screen.dart | FormData (proof, etc) | ManualDonationRes|
| POST | /donations | campaign_detail_screen.dart | campaign_id, amount, etc | Donation |
| GET | /campaigns | campaign_service.dart | ngo_id, status, etc | List<Campaign> |
| GET | /campaigns/my | campaign_service.dart | None | List<Campaign> |
| POST | /campaigns | campaign_service.dart | FormData (image, etc) | Campaign |
| GET | /campaigns/:id | campaign_service.dart | None | Campaign Detail |
| PUT | /campaigns/:id | campaign_service.dart | FormData (image, etc) | Campaign |
| PATCH | /campaigns/:id/status| campaign_service.dart | status | Campaign |
| GET | /chat | chat_list_screen.dart | None | List<ChatSession> |
| GET | /chat/:requestId | chat_screen.dart | None | List<Message> |
| POST | /chat/:requestId | chat_screen.dart | message | Message |
| GET | /donations/my | donor_donation_screen.dart | None | List<Donation> |
| GET | /in-kind | in_kind_service.dart | None | List<InKind> |
| GET | /in-kind/:id | in_kind_service.dart | None | InKind Detail |
| POST | /in-kind | in_kind_service.dart | title, desc, img, loc, etc | InKind |
| GET | /in-kind/my | in_kind_service.dart | None | List<InKind> |
| GET | /in-kind/my/:id/requests | in_kind_service.dart | None | List<InKindReq> |
| POST | /in-kind/my/:dId/requests/:rId/approve | in_kind_service.dart | None | Success |
| GET | /campaigns/nearby | campaign_map_screen.dart | lat, lng, radius | List<Campaign> |
| GET | /ngos/aid-requests | ngo_aid_requests_screen.dart | status (query) | List<AidRequest> |
| GET | /ngos/volunteers | ngo_aid_requests_screen.dart | None | List<Volunteer> |
| PATCH | /ngos/aid-requests/:id| ngo_aid_requests_screen.dart | ngo_id, status, etc | AidRequest |
| GET | /ngos/me | ngo_bank_details_screen.dart| None | NGO Profile |
| PUT | /ngos/bank-details | ngo_bank_details_screen.dart| bank_name, etc | NGO Profile |
| GET | /ngos/dashboard/stats | ngo_dashboard_screen.dart | None | NGO Stats |
| GET | /ngos/dashboard/chart | ngo_dashboard_screen.dart | days (query) | Chart Data |
| GET | /ngos/dashboard/recent | ngo_dashboard_screen.dart | None | Recent Activity |
| POST | /ngos/onboard | ngo_onboard_screen.dart | FormData (docs, etc) | NGO Profile |
| GET | /ngos/wallet | ngo_withdrawals_screen.dart | None | Wallet Object |
| GET | /ngos/withdrawals | ngo_withdrawals_screen.dart | None | List<Withdrawal>|
| GET | /ngos/profile | ngo_withdrawals_screen.dart | None | NGO Profile |
| POST | /ngos/withdrawals | ngo_withdrawals_screen.dart | amount, bank details | Withdrawal |
| POST | /volunteers/register | complete_profile_screen.dart | ngo_id, skills, etc | Volunteer Prof |
| PATCH | /volunteers/tasks/:id/deliver| deliver_aid_screen.dart | FormData (proof, etc) | Success |
| GET | /volunteer/stats | volunteer_dashboard.dart | None | Stats Object |
| GET | /volunteers/tasks/available| volunteer_map_screen.dart | None | List<AidRequest> |
| POST | /volunteers/tasks/:id/accept| volunteer_tasks_screen.dart | None | Success |
| PATCH | /volunteers/tasks/:id/status| volunteer_tasks_screen.dart | FormData (status, etc) | Success |
| POST | /reports | report_dialog.dart | target_type, id, reason | Report |

## 4. DATABASE SCHEMA (EXHAUSTIVE)

### Tables
- **roles:** `id (SERIAL PK)`, `name (VARCHAR UNIQUE)`
- **users:** `id (SERIAL PK)`, `email (UNIQUE)`, `phone (UNIQUE)`, `password_hash`, `role_id (FK)`, `name`, `locale`, `fcm_token`, `created_at`
- **ngo_profiles:** `id (SERIAL PK)`, `user_id (UNIQUE FK)`, `org_name`, `registration_number (UNIQUE)`, `address`, `contact_person`, `mission`, `docs_url (TEXT[])`, `status (PENDING/APPROVED/REJECTED)`, `rejection_reason`, `created_at`, `approved_by (FK)`, `approved_at`, `updated_at`, `bank_name`, `bank_account_title`, `bank_account_number`, `bank_iban`, `latitude`, `longitude`, `email`, `phone`
- **ngo_wallets:** `id (SERIAL PK)`, `ngo_id (UNIQUE FK)`, `balance (DECIMAL)`, `total_received`, `total_withdrawn`, `updated_at`
- **volunteer_profiles:** `id (SERIAL PK)`, `user_id (UNIQUE FK)`, `ngo_id (FK)`, `location`, `skills (TEXT[])`, `status`, `availability`, `created_at`, `updated_at`
- **campaigns:** `id (SERIAL PK)`, `ngo_id (FK)`, `title`, `description`, `category`, `target_amount`, `raised_amount`, `image_url`, `location`, `status`, `created_at`, `end_date`, `latitude`, `longitude`, `address`, `updated_at`
- **donations:** `id (SERIAL PK)`, `user_id (FK)`, `campaign_id (FK)`, `amount`, `payment_method`, `status (PENDING/VERIFIED/REJECTED/completed)`, `transaction_ref (UNIQUE)`, `created_at`, `donor_name`, `donor_email`, `is_anonymous`, `proof_of_payment_url`, `verified_by (FK)`, `verified_at`, `bank_reference (UNIQUE)`, `donor_note`, `rejection_reason`, `receipt_url`, `receipt_sent_at`
- **aid_requests:** `id (SERIAL PK)`, `beneficiary_id (FK)`, `campaign_id (FK)`, `category`, `description`, `urgency`, `family_size`, `location`, `lat/lng`, `status (PENDING/APPROVED/ASSIGNED/DELIVERED/CANCELLED/REJECTED)`, `volunteer_id (FK)`, `ngo_id (FK)`, `proof_url`, `delivered_at`, `created_at`, `items_needed (JSONB)`, `updated_at`, `delivery_proof_url`, `delivered_by (FK)`, `delivery_notes`, `rejection_reason`, `latitude/longitude`
- **messages:** `id (SERIAL PK)`, `request_id (FK)`, `sender_id (FK)`, `message`, `read_at`, `created_at`
- **notifications:** `id (SERIAL PK)`, `user_id (FK)`, `title`, `body`, `type`, `data (JSONB)`, `is_read`, `created_at`
- **wallet_transactions:** `id (SERIAL PK)`, `ngo_id (FK)`, `amount`, `type (credit/debit)`, `donation_id (FK)`, `description`, `created_at`
- **withdrawal_requests:** `id (SERIAL PK)`, `ngo_id (FK)`, `amount`, `bank_name`, `account_title`, `account_number`, `iban`, `status (PENDING/APPROVED/COMPLETED/REJECTED)`, `rejection_reason`, `approved_by (FK)`, `transaction_ref`, `created_at`, `processed_at`, `transfer_proof_url`, `admin_notes`, `requested_by (FK)`
- **reports:** `id (SERIAL PK)`, `reporter_id (FK)`, `target_type (user/campaign/request)`, `target_id`, `reason`, `description`, `status`, `admin_notes`, `created_at`, `reviewed_at`, `reviewed_by (FK)`
- **audit_logs:** `id (SERIAL PK)`, `admin_id (FK)`, `action`, `target_type`, `target_id`, `old_value (JSONB)`, `new_value (JSONB)`, `reason`, `ip_address`, `created_at`
- **in_kind_donations:** `id (SERIAL PK)`, `donor_id (FK)`, `title`, `description`, `image_url`, `location`, `lat/lng`, `expires_at`, `status (available/claimed/expired)`, `claimed_by (FK)`, `created_at`, `updated_at`
- **in_kind_requests:** `id (SERIAL PK)`, `donation_id (FK)`, `beneficiary_id (FK)`, `message`, `status (pending/approved/rejected)`, `created_at`

## 5. ENVIRONMENT CONFIG (EXHAUSTIVE)

| VAR_NAME | PURPOSE | USED IN |
|----------|---------|---------|
| `DATABASE_URL` | PostgreSQL Connection String | `db.js`, `tests` |
| `JWT_SECRET` | Signing/Verifying JWTs | `auth.js`, `routes.js` |
| `PORT` | Backend Server Port | `server.js` |
| `NODE_ENV` | Environment mode (production/test/dev) | `db.js`, `server.js` |
| `FRONTEND_URL` | CORS Allowed Origins | `server.js` |
| `CLOUDINARY_CLOUD_NAME` | Image Hosting Cloud Name | `upload.js` |
| `CLOUDINARY_API_KEY` | Image Hosting API Key | `upload.js` |
| `CLOUDINARY_API_SECRET` | Image Hosting API Secret | `upload.js` |
| `MAIL_USER` | Email (Nodemailer) User | `mailer.js` |
| `MAIL_PASS` | Email (Nodemailer) Password | `mailer.js` |
| `PLATFORM_IBAN` | Platform Bank IBAN for Donations | `donations.js`, `campaigns.js` |
| `PLATFORM_BANK_NAME` | Platform Bank Name | `donations.js`, `campaigns.js` |
| `PLATFORM_ACCOUNT_TITLE` | Platform Bank Account Title | `donations.js`, `campaigns.js` |
| `PLATFORM_ACCOUNT_NUMBER`| Platform Bank Account Number | `donations.js`, `campaigns.js` |
| `API_BASE_URL` | (Frontend) Backend API Address | `api_client.dart` |

## 6. CRITICAL FLOWS

### NGO Onboarding
1. NGO registers as 'ngo' user.
2. NGO calls `POST /api/ngos/onboard` with registration docs.
3. Admin reviews at `GET /api/admin/ngos/pending`.
4. Admin approves via `PATCH /api/admin/ngos/:id/approve`.
5. NGO can now create campaigns.

### Manual Bank Donation & Verification
1. Donor calls `POST /api/donations/manual` with amount and proof of payment.
2. Donation is created with status 'PENDING'.
3. Admin sees it in `GET /api/donations/pending`.
4. Admin verifies the transfer and calls `PATCH /api/donations/:id/verify` with status 'VERIFIED'.
5. Backend updates campaign `raised_amount`, NGO wallet `balance`, and generates PDF receipt.
6. Receipt is emailed to donor and notification sent.

### Aid Request & Delivery
1. Beneficiary calls `POST /api/aid-requests`.
2. Admin reviews and assigns to an NGO via `PATCH /api/admin/aid-requests/:id/assign`.
3. NGO assigns to a volunteer or volunteer accepts via `POST /api/volunteers/tasks/:id/accept`.
4. Volunteer delivers aid and uploads proof via `PATCH /api/volunteers/tasks/:id/status` (or `PATCH /api/ngos/:id/deliver`).
5. Status becomes 'DELIVERED'.

## 7. RUNTIME HEALTH & COMMANDS
- **Health Check:** `GET /api/health`
- **Backend Start:** `npm start` (in `backend/`)
- **Backend Tests:** `npm test` (Uses Jest, Supertest)
- **Frontend Build:** `flutter build apk` / `flutter build web`
- **Frontend Tests:** `flutter test`
- **Database Migration:** Managed via SQL scripts in `backend/src/db/migrations/` and `schema.sql`.
