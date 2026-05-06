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
**Commit:** [add hash after commit]   0c9e800

## #6 - is_anonymous column mismatch + payment_method case
**Status:** Fixed
**Error:** 400 Bad Request - "is_anonymous is not defined"
**Root Cause:** Backend schema missing is_anonymous field, Flutter sending lowercase payment_method
**Fix:** Added is_anonymous to Joi schema and INSERT. Changed Flutter to send uppercase payment methods
**Files:** backend/src/modules/donations/routes.js, campaign_detail_screen.dart
**Commit:** [add hash after commit]  98dd76d



## #7 - Maximum call stack size exceeded on campaign detail
**Status:** Fixed
**Error:** 500 Internal Server Error - Maximum call stack size exceeded
**Root Cause:** SELECT c.* pulled non-serializable column causing JSON.stringify to recurse infinitely
**Fix:** Replaced c.* with explicit column list. Removed spread operator on db row in donation response
**Files:** backend/src/modules/campaigns/routes.js, backend/src/modules/donations/routes.js
**Commit:** [add hash after commit]  d2d3751


## #8 - Infinite recursion in db.js causing Maximum call stack size exceeded
**Status:** Fixed
**Error:** RangeError: Maximum call stack size exceeded at db.js:11
**Root Cause:** module.exports = pool; then module.exports.query = ... overwrote pool and created recursive function
**Fix:** Export pool directly. Removed custom .query wrapper since pg Pool already provides it
**File:** backend/src/config/db.js
**Commit:** [add hash after commit] d2d3751


## #9 - Flutter Dropdown assertion failed on payment method
**Status:** Fixed
**Error:** Failed assertion: There should be exactly one item with value: jazzcash
**Root Cause:** Backend Joi expects uppercase JAZZCASH but Flutter dropdown used lowercase values
**Fix:** Changed Flutter dropdown values to uppercase MOCK, JAZZCASH, EASYPAISA, STRIPE. Set default to MOCK
**File:** campaign_detail_screen.dart
**Commit:** [add hash after commit] d2d3751
