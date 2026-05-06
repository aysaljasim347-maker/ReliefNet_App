## #1 - NgoDashboard 404 + Backend role column error
**Status:** Fixed
**Error:** DioException 404 on /ngos/campaigns + Backend: column "role" does not exist
**Root Cause:** Missing route + outdated SQL query using denormalized role column
**Fix:** Changed frontend to /campaigns?ngo_id=X + Fixed backend SQL to JOIN roles table
**Commit:** [commit hash after you push]  47f230e



## #2 - Campaign detail 500 error: column n.email does not exist
**Status:** Fixed
**Error:** 500 on GET /api/campaigns/:id - column n.email does not exist
**Root Cause:** SQL query selecting n.email but email field is in users table, not ngo_profiles
**Fix:** Changed query to JOIN users u and select u.email as ngo_email
**File:** backend/src/modules/campaigns/routes.js:83
**Commit:** [add hash after commit] 56db7a4 



## #3 - Donation 400 error: payment_method case mismatch
**Status:** Fixed
**Error:** 400 Bad Request - "payment_method" must be one of [MOCK, STRIPE, JAZZCASH, EASYPAISA]
**Root Cause:** Frontend sending lowercase 'jazzcash', backend Joi validation expects uppercase
**Fix:** Changed frontend to send 'MOCK' for testing. Optional: Add .uppercase() to backend validation
**File:** features/donations/screens/donate_screen.dart
**Commit:** [add hash after commit]  56db7a4

## #4 - Donations crash: db.pool is undefined
**Status:** Fixed
**Error:** TypeError: Cannot read properties of undefined (reading 'connect')
**Root Cause:** config/db.js exports pool directly as 'db', not as db.pool
**Fix:** Changed db.pool.connect() to db.connect() in donations/routes.js
**File:** backend/src/modules/donations/routes.js:22
**Commit:** [add hash after commit]  529d5eb


## #5 - Donations table missing donor_name column
**Status:** Fixed
**Error:** 400 Bad Request - column "donor_name" of relation "donations" does not exist
**Root Cause:** donations table schema missing donor_name, donor_email, transaction_ref columns
**Fix:** ALTER TABLE donations ADD COLUMN donor_name VARCHAR(255), donor_email VARCHAR(255), transaction_ref VARCHAR(255)
**File:** Database migration