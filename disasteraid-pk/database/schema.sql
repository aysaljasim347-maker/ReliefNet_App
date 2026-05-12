--
-- PostgreSQL database dump
-- ReliefNet - Disaster Aid Platform
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

-- ============================================================
-- FUNCTIONS
-- ============================================================

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

-- ============================================================
-- TABLES
-- ============================================================

--
-- roles
--

CREATE TABLE public.roles (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE
);

ALTER TABLE public.roles OWNER TO postgres;

--
-- users
--

CREATE TABLE public.users (
    id            SERIAL PRIMARY KEY,
    email         VARCHAR(255) UNIQUE,
    phone         VARCHAR(20)  UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role_id       INTEGER REFERENCES public.roles(id),
    name          VARCHAR(255) NOT NULL,
    locale        VARCHAR(5)   DEFAULT 'en',
    fcm_token     TEXT,
    created_at    TIMESTAMP    DEFAULT NOW()
);

ALTER TABLE public.users OWNER TO postgres;

--
-- ngo_profiles
--

CREATE TABLE public.ngo_profiles (
    id                  SERIAL PRIMARY KEY,
    user_id             INTEGER UNIQUE REFERENCES public.users(id),
    org_name            VARCHAR(255),
    registration_number VARCHAR(100) UNIQUE,
    address             TEXT,
    contact_person      VARCHAR(255),
    mission             TEXT,
    docs_url            TEXT[],
    status              VARCHAR(20)  DEFAULT 'PENDING',
    rejection_reason    TEXT,
    created_at          TIMESTAMP    DEFAULT NOW(),
    approved_by         INTEGER      REFERENCES public.users(id),
    approved_at         TIMESTAMP,
    updated_at          TIMESTAMP    DEFAULT NOW(),
    bank_name           VARCHAR(100),
    bank_account_title  VARCHAR(100),
    bank_account_number VARCHAR(50),
    bank_iban           VARCHAR(30),
    latitude            DECIMAL(10,8),
    longitude           DECIMAL(11,8),
    email               VARCHAR(255),
    phone               VARCHAR(20)
);

ALTER TABLE public.ngo_profiles OWNER TO postgres;

--
-- ngo_wallets
--

CREATE TABLE public.ngo_wallets (
    id              SERIAL PRIMARY KEY,
    ngo_id          INTEGER UNIQUE REFERENCES public.ngo_profiles(id),
    balance         DECIMAL(12,2) DEFAULT 0,
    total_received  DECIMAL(12,2) DEFAULT 0,
    total_withdrawn DECIMAL(12,2) DEFAULT 0,
    updated_at      TIMESTAMP     DEFAULT NOW()
);

ALTER TABLE public.ngo_wallets OWNER TO postgres;

--
-- volunteer_profiles
--

CREATE TABLE public.volunteer_profiles (
    id           SERIAL PRIMARY KEY,
    user_id      INTEGER UNIQUE REFERENCES public.users(id),
    ngo_id       INTEGER REFERENCES public.ngo_profiles(id),
    location     TEXT,
    skills       TEXT[],
    status       VARCHAR(20) DEFAULT 'ACTIVE',
    availability VARCHAR(20) DEFAULT 'FLEXIBLE',
    created_at   TIMESTAMP   DEFAULT NOW(),
    updated_at   TIMESTAMP   DEFAULT NOW()
);

ALTER TABLE public.volunteer_profiles OWNER TO postgres;

--
-- campaigns
--

CREATE TABLE public.campaigns (
    id            SERIAL PRIMARY KEY,
    ngo_id        INTEGER REFERENCES public.ngo_profiles(id) ON DELETE CASCADE,
    title         VARCHAR(255) NOT NULL,
    description   TEXT,
    category      VARCHAR(50),
    target_amount DECIMAL(12,2) NOT NULL,
    raised_amount DECIMAL(12,2) DEFAULT 0,
    image_url     TEXT,
    location      VARCHAR(255),
    status        VARCHAR(20)  DEFAULT 'ACTIVE',
    created_at    TIMESTAMP    DEFAULT NOW(),
    end_date      TIMESTAMP,
    latitude      DECIMAL(10,8),
    longitude     DECIMAL(11,8),
    address       TEXT,
    updated_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.campaigns OWNER TO postgres;

--
-- donations
--

CREATE TABLE public.donations (
    id                  SERIAL PRIMARY KEY,
    user_id             INTEGER REFERENCES public.users(id),
    campaign_id         INTEGER REFERENCES public.campaigns(id),
    amount              DECIMAL(10,2) NOT NULL,
    payment_method      VARCHAR(50)   DEFAULT 'MOCK',
    status              VARCHAR(20)   DEFAULT 'completed',
    transaction_ref     VARCHAR(255)  UNIQUE,
    created_at          TIMESTAMP     DEFAULT NOW(),
    donor_name          VARCHAR(255),
    donor_email         VARCHAR(255),
    is_anonymous        BOOLEAN       DEFAULT FALSE,
    proof_of_payment_url TEXT,
    verified_by         INTEGER       REFERENCES public.users(id),
    verified_at         TIMESTAMP,
    bank_reference      VARCHAR(100)  UNIQUE,
    donor_note          TEXT,
    rejection_reason    TEXT,
    receipt_url         TEXT,
    receipt_sent_at     TIMESTAMP
);

ALTER TABLE public.donations OWNER TO postgres;

--
-- aid_requests
--

CREATE TABLE public.aid_requests (
    id                 SERIAL PRIMARY KEY,
    beneficiary_id     INTEGER REFERENCES public.users(id),
    campaign_id        INTEGER REFERENCES public.campaigns(id),
    category           VARCHAR(50)  NOT NULL,
    description        TEXT         NOT NULL,
    urgency            VARCHAR(20)  DEFAULT 'MEDIUM',
    family_size        INTEGER      DEFAULT 1,
    location           TEXT         NOT NULL,
    lat                DECIMAL(10,8),
    lng                DECIMAL(11,8),
    status             VARCHAR(20)  DEFAULT 'PENDING',
    volunteer_id       INTEGER      REFERENCES public.volunteer_profiles(id),
    ngo_id             INTEGER      REFERENCES public.ngo_profiles(id),
    proof_url          TEXT,
    delivered_at       TIMESTAMP,
    created_at         TIMESTAMP    DEFAULT NOW(),
    items_needed       JSONB        DEFAULT '[]',
    updated_at         TIMESTAMP    DEFAULT NOW(),
    delivery_proof_url TEXT,
    delivered_by       INTEGER      REFERENCES public.users(id),
    delivery_notes     TEXT,
    rejection_reason   TEXT,
    latitude           DECIMAL(10,8),
    longitude          DECIMAL(11,8)
);

ALTER TABLE public.aid_requests OWNER TO postgres;

--
-- messages
--

CREATE TABLE public.messages (
    id         SERIAL PRIMARY KEY,
    request_id INTEGER   NOT NULL REFERENCES public.aid_requests(id) ON DELETE CASCADE,
    sender_id  INTEGER   NOT NULL REFERENCES public.users(id),
    message    TEXT      NOT NULL,
    read_at    TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.messages OWNER TO postgres;

--
-- notifications
--

CREATE TABLE public.notifications (
    id         SERIAL PRIMARY KEY,
    user_id    INTEGER      NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title      VARCHAR(100) NOT NULL,
    body       TEXT         NOT NULL,
    type       VARCHAR(50)  NOT NULL,
    data       JSONB,
    is_read    BOOLEAN      DEFAULT FALSE,
    created_at TIMESTAMP    DEFAULT NOW()
);

ALTER TABLE public.notifications OWNER TO postgres;

--
-- wallet_transactions
--

CREATE TABLE public.wallet_transactions (
    id          SERIAL PRIMARY KEY,
    ngo_id      INTEGER       REFERENCES public.ngo_profiles(id),
    amount      DECIMAL(10,2) NOT NULL,
    type        VARCHAR(20)   NOT NULL,
    donation_id INTEGER       REFERENCES public.donations(id),
    description TEXT,
    created_at  TIMESTAMP     DEFAULT NOW()
);

ALTER TABLE public.wallet_transactions OWNER TO postgres;

--
-- withdrawal_requests
--

CREATE TABLE public.withdrawal_requests (
    id                SERIAL PRIMARY KEY,
    ngo_id            INTEGER       REFERENCES public.ngo_profiles(id),
    amount            DECIMAL(12,2) NOT NULL,
    bank_name         VARCHAR(100)  NOT NULL,
    account_title     VARCHAR(255)  NOT NULL,
    account_number    VARCHAR(50)   NOT NULL,
    iban              VARCHAR(50),
    status            VARCHAR(20)   DEFAULT 'PENDING',
    rejection_reason  TEXT,
    approved_by       INTEGER       REFERENCES public.users(id),
    transaction_ref   VARCHAR(255),
    created_at        TIMESTAMP     DEFAULT NOW(),
    processed_at      TIMESTAMP,
    transfer_proof_url TEXT,
    admin_notes       TEXT,
    requested_by      INTEGER       REFERENCES public.users(id)
);

ALTER TABLE public.withdrawal_requests OWNER TO postgres;

--
-- reports
--

CREATE TABLE public.reports (
    id           SERIAL PRIMARY KEY,
    reporter_id  INTEGER     REFERENCES public.users(id) ON DELETE SET NULL,
    target_type  VARCHAR(20) NOT NULL,
    target_id    INTEGER     NOT NULL,
    reason       VARCHAR(50) NOT NULL,
    description  TEXT,
    status       VARCHAR(20) DEFAULT 'PENDING',
    admin_notes  TEXT,
    created_at   TIMESTAMP   DEFAULT NOW(),
    reviewed_at  TIMESTAMP,
    reviewed_by  INTEGER     REFERENCES public.users(id),
    CONSTRAINT reports_reason_check CHECK (
        reason IN ('SPAM','SCAM','INAPPROPRIATE','FAKE','HARASSMENT','OTHER')
    ),
    CONSTRAINT reports_status_check CHECK (
        status IN ('PENDING','REVIEWED','RESOLVED','DISMISSED')
    ),
    CONSTRAINT reports_target_type_check CHECK (
        target_type IN ('user','campaign','request')
    )
);

ALTER TABLE public.reports OWNER TO postgres;

--
-- audit_logs
--

CREATE TABLE public.audit_logs (
    id          SERIAL PRIMARY KEY,
    admin_id    INTEGER     REFERENCES public.users(id) ON DELETE SET NULL,
    action      VARCHAR(50) NOT NULL,
    target_type VARCHAR(20) NOT NULL,
    target_id   INTEGER     NOT NULL,
    old_value   JSONB,
    new_value   JSONB,
    reason      TEXT,
    ip_address  INET,
    created_at  TIMESTAMP   DEFAULT NOW()
);

ALTER TABLE public.audit_logs OWNER TO postgres;

-- ============================================================
-- IN-KIND DONATION TABLES (new feature)
-- ============================================================

--
-- in_kind_donations
--

CREATE TABLE public.in_kind_donations (
    id          SERIAL PRIMARY KEY,
    donor_id    INTEGER      NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title       VARCHAR(255) NOT NULL,
    description TEXT,
    image_url   VARCHAR(500),
    location    VARCHAR(255) NOT NULL,
    latitude    DECIMAL(10,8),
    longitude   DECIMAL(11,8),
    expires_at  TIMESTAMP,
    status      VARCHAR(20)  DEFAULT 'available'
                CHECK (status IN ('available', 'claimed', 'expired')),
    claimed_by  INTEGER      REFERENCES public.users(id),
    created_at  TIMESTAMP    DEFAULT NOW(),
    updated_at  TIMESTAMP    DEFAULT NOW()
);

ALTER TABLE public.in_kind_donations OWNER TO postgres;

--
-- in_kind_requests
--

CREATE TABLE public.in_kind_requests (
    id              SERIAL PRIMARY KEY,
    donation_id     INTEGER NOT NULL REFERENCES public.in_kind_donations(id) ON DELETE CASCADE,
    beneficiary_id  INTEGER NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message         TEXT,
    status          VARCHAR(20) DEFAULT 'pending'
                    CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(donation_id, beneficiary_id)
);

ALTER TABLE public.in_kind_requests OWNER TO postgres;

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_aid_requests_beneficiary  ON public.aid_requests (beneficiary_id);
CREATE INDEX idx_aid_requests_ngo          ON public.aid_requests (ngo_id);
CREATE INDEX idx_aid_requests_ngo_id       ON public.aid_requests (ngo_id);
CREATE INDEX idx_aid_requests_status       ON public.aid_requests (status);
CREATE INDEX idx_aid_requests_location     ON public.aid_requests (latitude, longitude)
    WHERE status = 'PENDING';

CREATE INDEX idx_campaigns_location        ON public.campaigns (latitude, longitude)
    WHERE status = 'ACTIVE';

CREATE INDEX idx_donations_bank_ref        ON public.donations (bank_reference);
CREATE INDEX idx_donations_status          ON public.donations (status);

CREATE INDEX idx_messages_request          ON public.messages (request_id, created_at DESC);
CREATE INDEX idx_messages_unread           ON public.messages (request_id, sender_id)
    WHERE read_at IS NULL;

CREATE INDEX idx_notifications_user        ON public.notifications (user_id, is_read, created_at DESC);

CREATE INDEX idx_reports_status            ON public.reports (status);
CREATE INDEX idx_reports_target            ON public.reports (target_type, target_id);

CREATE INDEX idx_audit_logs_action         ON public.audit_logs (action);
CREATE INDEX idx_audit_logs_admin          ON public.audit_logs (admin_id);
CREATE INDEX idx_audit_logs_target         ON public.audit_logs (target_type, target_id);

CREATE INDEX idx_volunteer_profiles_ngo    ON public.volunteer_profiles (ngo_id);

CREATE INDEX idx_withdrawal_ngo            ON public.withdrawal_requests (ngo_id);
CREATE INDEX idx_withdrawal_status         ON public.withdrawal_requests (status);
CREATE INDEX idx_withdrawals_ngo           ON public.withdrawal_requests (ngo_id);
CREATE INDEX idx_withdrawals_status        ON public.withdrawal_requests (status);

CREATE INDEX idx_in_kind_donations_donor   ON public.in_kind_donations (donor_id);
CREATE INDEX idx_in_kind_donations_status  ON public.in_kind_donations (status);
CREATE INDEX idx_in_kind_requests_donation ON public.in_kind_requests (donation_id);
CREATE INDEX idx_in_kind_requests_beneficiary ON public.in_kind_requests (beneficiary_id);

-- New Performance Indexes (Added based on handoff audit)
CREATE INDEX idx_messages_sender           ON public.messages (sender_id);
CREATE INDEX idx_ngo_profiles_approved     ON public.ngo_profiles (approved_by);
CREATE INDEX idx_donations_verified        ON public.donations (verified_by);

-- ============================================================
-- TRIGGERS
-- ============================================================

CREATE TRIGGER update_campaigns_updated_at
    BEFORE UPDATE ON public.campaigns
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_in_kind_donations_updated_at
    BEFORE UPDATE ON public.in_kind_donations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- SEED DATA (roles only — minimum required)
-- ============================================================

INSERT INTO public.roles (name) VALUES
    ('donor'),
    ('ngo'),
    ('volunteer'),
    ('beneficiary'),
    ('admin');
