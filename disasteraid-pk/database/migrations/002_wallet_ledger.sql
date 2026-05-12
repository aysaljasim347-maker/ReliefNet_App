-- Migration: Finalize wallet_transactions table for double-entry ledger

-- Drop the old table if it exists
DROP TABLE IF EXISTS public.wallet_transactions;

-- Recreate with robust ledger fields
CREATE TABLE public.wallet_transactions (
    id              SERIAL PRIMARY KEY,
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN ('DONATION', 'WITHDRAWAL', 'FEE_DEDUCTION', 'REFUND')),
    amount          DECIMAL(12,2) NOT NULL,
    currency        VARCHAR(3) DEFAULT 'PKR',
    status          VARCHAR(20) DEFAULT 'COMPLETED' CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED')),
    source_id       INTEGER, -- Can link to users (donors) or ngo_profiles
    destination_id  INTEGER, -- Can link to campaigns or ngo_profiles
    donation_id     INTEGER REFERENCES public.donations(id),
    withdrawal_id   INTEGER REFERENCES public.withdrawal_requests(id),
    idempotency_key VARCHAR(255) UNIQUE,
    description     TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- Ensure fast lookups for balances and audits
CREATE INDEX idx_wallet_tx_source ON public.wallet_transactions (source_id);
CREATE INDEX idx_wallet_tx_destination ON public.wallet_transactions (destination_id);
CREATE INDEX idx_wallet_tx_donation ON public.wallet_transactions (donation_id);
CREATE INDEX idx_wallet_tx_idempotency ON public.wallet_transactions (idempotency_key);
