-- Migration 001: Add missing UNIQUE constraints and columns
-- Date: 2026-05-10
-- Fixes: ON CONFLICT clauses in wallet upsert and volunteer registration

-- 1. ngo_wallets: Add UNIQUE constraint on ngo_id
-- Required for: ON CONFLICT (ngo_id) DO UPDATE in donations/routes.js
ALTER TABLE ngo_wallets ADD CONSTRAINT ngo_wallets_ngo_id_unique UNIQUE (ngo_id);

-- 2. volunteer_profiles: Add UNIQUE constraint on user_id
-- Required for: ON CONFLICT (user_id) DO UPDATE in volunteers/routes.js
ALTER TABLE volunteer_profiles ADD CONSTRAINT volunteer_profiles_user_id_unique UNIQUE (user_id);

-- 3. Add index on donations.transaction_ref for duplicate check
CREATE INDEX IF NOT EXISTS idx_donations_transaction_ref ON donations(transaction_ref) WHERE transaction_ref IS NOT NULL;

-- 4. Add index on donations.status for filtered queries
CREATE INDEX IF NOT EXISTS idx_donations_status ON donations(status);

-- 5. Add index on campaigns.status for filtered queries
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);

-- 6. Add index on ngo_profiles.status for admin queries
CREATE INDEX IF NOT EXISTS idx_ngo_profiles_status ON ngo_profiles(status);

-- 7. Add index on withdrawal_requests.status for admin queries
CREATE INDEX IF NOT EXISTS idx_withdrawal_status ON withdrawal_requests(status);

-- 8. Ensure donations.status uses consistent uppercase values
-- First check current data, then update if needed
UPDATE donations SET status = 'VERIFIED' WHERE status = 'completed';
