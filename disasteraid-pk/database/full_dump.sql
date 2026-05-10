--
-- PostgreSQL database dump
--

\restrict HVVUWjoEZAG58U4MQyLu2CnGfCNfIyHENhAiKH3DumajDoLfBhPf57119FrC7ZQ

-- Dumped from database version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

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

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: aid_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aid_requests (
    id integer NOT NULL,
    beneficiary_id integer,
    campaign_id integer,
    category character varying(50) NOT NULL,
    description text NOT NULL,
    urgency character varying(20) DEFAULT 'MEDIUM'::character varying,
    family_size integer DEFAULT 1,
    location text NOT NULL,
    lat numeric(10,8),
    lng numeric(11,8),
    status character varying(20) DEFAULT 'PENDING'::character varying,
    volunteer_id integer,
    ngo_id integer,
    proof_url text,
    delivered_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now(),
    items_needed jsonb DEFAULT '[]'::jsonb,
    updated_at timestamp without time zone DEFAULT now(),
    delivery_proof_url text,
    delivered_by integer,
    delivery_notes text,
    rejection_reason text,
    latitude numeric(10,8),
    longitude numeric(11,8)
);


ALTER TABLE public.aid_requests OWNER TO postgres;

--
-- Name: aid_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aid_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.aid_requests_id_seq OWNER TO postgres;

--
-- Name: aid_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aid_requests_id_seq OWNED BY public.aid_requests.id;


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_logs (
    id integer NOT NULL,
    admin_id integer,
    action character varying(50) NOT NULL,
    target_type character varying(20) NOT NULL,
    target_id integer NOT NULL,
    old_value jsonb,
    new_value jsonb,
    reason text,
    ip_address inet,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.audit_logs OWNER TO postgres;

--
-- Name: audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_logs_id_seq OWNER TO postgres;

--
-- Name: audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.audit_logs_id_seq OWNED BY public.audit_logs.id;


--
-- Name: campaigns; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.campaigns (
    id integer NOT NULL,
    ngo_id integer,
    title character varying(255) NOT NULL,
    description text,
    category character varying(50),
    target_amount numeric(12,2) NOT NULL,
    raised_amount numeric(12,2) DEFAULT 0,
    image_url text,
    location character varying(255),
    status character varying(20) DEFAULT 'ACTIVE'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    end_date timestamp without time zone,
    latitude numeric(10,8),
    longitude numeric(11,8),
    address text,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.campaigns OWNER TO postgres;

--
-- Name: campaigns_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.campaigns_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.campaigns_id_seq OWNER TO postgres;

--
-- Name: campaigns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.campaigns_id_seq OWNED BY public.campaigns.id;


--
-- Name: donations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.donations (
    id integer NOT NULL,
    user_id integer,
    campaign_id integer,
    amount numeric(10,2) NOT NULL,
    payment_method character varying(50) DEFAULT 'MOCK'::character varying,
    status character varying(20) DEFAULT 'completed'::character varying,
    transaction_ref character varying(255),
    created_at timestamp without time zone DEFAULT now(),
    donor_name character varying(255),
    donor_email character varying(255),
    is_anonymous boolean DEFAULT false,
    proof_of_payment_url text,
    verified_by integer,
    verified_at timestamp without time zone,
    bank_reference character varying(100),
    donor_note text,
    rejection_reason text,
    receipt_url text,
    receipt_sent_at timestamp without time zone
);


ALTER TABLE public.donations OWNER TO postgres;

--
-- Name: donations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.donations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.donations_id_seq OWNER TO postgres;

--
-- Name: donations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.donations_id_seq OWNED BY public.donations.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    request_id integer NOT NULL,
    sender_id integer NOT NULL,
    message text NOT NULL,
    read_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.messages OWNER TO postgres;

--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.messages_id_seq OWNER TO postgres;

--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: ngo_profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ngo_profiles (
    id integer NOT NULL,
    user_id integer,
    org_name character varying(255),
    registration_number character varying(100),
    address text,
    contact_person character varying(255),
    mission text,
    docs_url text[],
    status character varying(20) DEFAULT 'PENDING'::character varying,
    rejection_reason text,
    created_at timestamp without time zone DEFAULT now(),
    approved_by integer,
    approved_at timestamp without time zone,
    updated_at timestamp without time zone DEFAULT now(),
    bank_name character varying(100),
    bank_account_title character varying(100),
    bank_account_number character varying(50),
    bank_iban character varying(30),
    latitude numeric(10,8),
    longitude numeric(11,8),
    email character varying(255),
    phone character varying(20)
);


ALTER TABLE public.ngo_profiles OWNER TO postgres;

--
-- Name: ngo_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ngo_profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ngo_profiles_id_seq OWNER TO postgres;

--
-- Name: ngo_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ngo_profiles_id_seq OWNED BY public.ngo_profiles.id;


--
-- Name: ngo_wallets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ngo_wallets (
    id integer NOT NULL,
    ngo_id integer,
    balance numeric(12,2) DEFAULT 0,
    total_received numeric(12,2) DEFAULT 0,
    total_withdrawn numeric(12,2) DEFAULT 0,
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.ngo_wallets OWNER TO postgres;

--
-- Name: ngo_wallets_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ngo_wallets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ngo_wallets_id_seq OWNER TO postgres;

--
-- Name: ngo_wallets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ngo_wallets_id_seq OWNED BY public.ngo_wallets.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id integer NOT NULL,
    user_id integer NOT NULL,
    title character varying(100) NOT NULL,
    body text NOT NULL,
    type character varying(50) NOT NULL,
    data jsonb,
    is_read boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notifications_id_seq OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reports (
    id integer NOT NULL,
    reporter_id integer,
    target_type character varying(20) NOT NULL,
    target_id integer NOT NULL,
    reason character varying(50) NOT NULL,
    description text,
    status character varying(20) DEFAULT 'PENDING'::character varying,
    admin_notes text,
    created_at timestamp without time zone DEFAULT now(),
    reviewed_at timestamp without time zone,
    reviewed_by integer,
    CONSTRAINT reports_reason_check CHECK (((reason)::text = ANY ((ARRAY['SPAM'::character varying, 'SCAM'::character varying, 'INAPPROPRIATE'::character varying, 'FAKE'::character varying, 'HARASSMENT'::character varying, 'OTHER'::character varying])::text[]))),
    CONSTRAINT reports_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'REVIEWED'::character varying, 'RESOLVED'::character varying, 'DISMISSED'::character varying])::text[]))),
    CONSTRAINT reports_target_type_check CHECK (((target_type)::text = ANY ((ARRAY['user'::character varying, 'campaign'::character varying, 'request'::character varying])::text[])))
);


ALTER TABLE public.reports OWNER TO postgres;

--
-- Name: reports_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.reports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.reports_id_seq OWNER TO postgres;

--
-- Name: reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.reports_id_seq OWNED BY public.reports.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying(50)
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.roles_id_seq OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying(255),
    phone character varying(20),
    password_hash character varying(255) NOT NULL,
    role_id integer,
    name character varying(255) NOT NULL,
    locale character varying(5) DEFAULT 'en'::character varying,
    fcm_token text,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: volunteer_profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.volunteer_profiles (
    id integer NOT NULL,
    user_id integer,
    ngo_id integer,
    location text,
    skills text[],
    status character varying(20) DEFAULT 'ACTIVE'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    availability character varying(20) DEFAULT 'FLEXIBLE'::character varying,
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.volunteer_profiles OWNER TO postgres;

--
-- Name: volunteer_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.volunteer_profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.volunteer_profiles_id_seq OWNER TO postgres;

--
-- Name: volunteer_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.volunteer_profiles_id_seq OWNED BY public.volunteer_profiles.id;


--
-- Name: wallet_transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wallet_transactions (
    id integer NOT NULL,
    ngo_id integer,
    amount numeric(10,2) NOT NULL,
    type character varying(20) NOT NULL,
    donation_id integer,
    description text,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.wallet_transactions OWNER TO postgres;

--
-- Name: wallet_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.wallet_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.wallet_transactions_id_seq OWNER TO postgres;

--
-- Name: wallet_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.wallet_transactions_id_seq OWNED BY public.wallet_transactions.id;


--
-- Name: withdrawal_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.withdrawal_requests (
    id integer NOT NULL,
    ngo_id integer,
    amount numeric(12,2) NOT NULL,
    bank_name character varying(100) NOT NULL,
    account_title character varying(255) NOT NULL,
    account_number character varying(50) NOT NULL,
    iban character varying(50),
    status character varying(20) DEFAULT 'PENDING'::character varying,
    rejection_reason text,
    approved_by integer,
    transaction_ref character varying(255),
    created_at timestamp without time zone DEFAULT now(),
    processed_at timestamp without time zone,
    transfer_proof_url text,
    admin_notes text,
    requested_by integer
);


ALTER TABLE public.withdrawal_requests OWNER TO postgres;

--
-- Name: withdrawal_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.withdrawal_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.withdrawal_requests_id_seq OWNER TO postgres;

--
-- Name: withdrawal_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.withdrawal_requests_id_seq OWNED BY public.withdrawal_requests.id;


--
-- Name: aid_requests id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aid_requests ALTER COLUMN id SET DEFAULT nextval('public.aid_requests_id_seq'::regclass);


--
-- Name: audit_logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN id SET DEFAULT nextval('public.audit_logs_id_seq'::regclass);


--
-- Name: campaigns id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campaigns ALTER COLUMN id SET DEFAULT nextval('public.campaigns_id_seq'::regclass);


--
-- Name: donations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.donations ALTER COLUMN id SET DEFAULT nextval('public.donations_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: ngo_profiles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ngo_profiles ALTER COLUMN id SET DEFAULT nextval('public.ngo_profiles_id_seq'::regclass);


--
-- Name: ngo_wallets id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ngo_wallets ALTER COLUMN id SET DEFAULT nextval('public.ngo_wallets_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: reports id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports ALTER COLUMN id SET DEFAULT nextval('public.reports_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: volunteer_profiles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.volunteer_profiles ALTER COLUMN id SET DEFAULT nextval('public.volunteer_profiles_id_seq'::regclass);


--
-- Name: wallet_transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wallet_transactions ALTER COLUMN id SET DEFAULT nextval('public.wallet_transactions_id_seq'::regclass);


--
-- Name: withdrawal_requests id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.withdrawal_requests ALTER COLUMN id SET DEFAULT nextval('public.withdrawal_requests_id_seq'::regclass);


--
-- Data for Name: aid_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.aid_requests (id, beneficiary_id, campaign_id, category, description, urgency, family_size, location, lat, lng, status, volunteer_id, ngo_id, proof_url, delivered_at, created_at, items_needed, updated_at, delivery_proof_url, delivered_by, delivery_notes, rejection_reason, latitude, longitude) FROM stdin;
1	25	\N	FOOD	i need just need	MEDIUM	1	lahroe	\N	\N	APPROVED	\N	1	\N	\N	2026-05-07 22:01:50.605086	["food"]	2026-05-08 09:27:03.990649	\N	\N	\N	\N	\N	\N
3	25	\N	FOOD	lovelfjklafjkljkljkl	MEDIUM	1	ljkljklj	\N	\N	PENDING	\N	1	\N	\N	2026-05-08 09:27:49.213909	["food", "water"]	2026-05-08 09:27:49.213909	\N	\N	\N	\N	\N	\N
4	25	\N	FOOD	kljlkjkljkljljljkljlkjkljkl	MEDIUM	1	kjljkljklj	\N	\N	APPROVED	\N	1	\N	\N	2026-05-09 09:06:55.154895	["food", "water"]	2026-05-09 09:08:03.801091	\N	\N	\N	\N	\N	\N
2	25	\N	FOOD	need water	MEDIUM	1	kljikjkl	\N	\N	APPROVED	\N	1	\N	\N	2026-05-07 22:41:59.8654	["water"]	2026-05-09 09:08:07.887961	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_logs (id, admin_id, action, target_type, target_id, old_value, new_value, reason, ip_address, created_at) FROM stdin;
\.


--
-- Data for Name: campaigns; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campaigns (id, ngo_id, title, description, category, target_amount, raised_amount, image_url, location, status, created_at, end_date, latitude, longitude, address, updated_at) FROM stdin;
1	1	give me 	this is a chanda system	education	121323.00	6500.00	\N	uoh	ACTIVE	2026-05-06 02:00:22.582857	\N	\N	\N	\N	2026-05-10 10:01:53.867396
2	1	MY CAMPAING	THIS IS THE CAMP OF THE LOAKFAJFL KAKLAKLAJJKLFJKLAJFKLWRJKLWQJ	FOOD	147844545.00	1500.00	\N	gurjat	ACTIVE	2026-05-07 00:53:34.314565	2026-06-30 00:00:00	\N	\N	\N	2026-05-10 10:01:53.867396
3	1	i am here	this is the end of hte life that is starting	FOOD	21546.00	0.00	\N	Lat: 29.5095, Lng: 47.7618	ACTIVE	2026-05-09 16:32:11.71302	2026-06-14 00:00:00	29.50945502	47.76178935	Lat: 29.5095, Lng: 47.7618	2026-05-10 10:01:53.867396
4	4	my love is life	what are you doing here i ma not here	FOOD	123456.00	456.00	\N	Lat: 28.5324, Lng: 69.1749	ACTIVE	2026-05-10 09:01:20.670063	2026-06-30 00:00:00	28.53239168	69.17488477	Lat: 28.5324, Lng: 69.1749	2026-05-10 10:02:05.86397
\.


--
-- Data for Name: donations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.donations (id, user_id, campaign_id, amount, payment_method, status, transaction_ref, created_at, donor_name, donor_email, is_anonymous, proof_of_payment_url, verified_by, verified_at, bank_reference, donor_note, rejection_reason, receipt_url, receipt_sent_at) FROM stdin;
1	5	1	5000.00	JAZZCASH	completed	MOCK_1778089623503	2026-05-06 22:47:03.614124	donor	donor@gmail.com	f	\N	\N	\N	\N	\N	\N	\N	\N
2	5	1	1000.00	MOCK	completed	MOCK_1778091301960	2026-05-06 23:15:02.094323	donor	donor@gmail.com	f	\N	\N	\N	\N	\N	\N	\N	\N
3	5	1	500.00	MOCK	completed	MOCK_1778091576095	2026-05-06 23:19:36.197605	donor	donor@gmail.com	f	\N	\N	\N	\N	\N	\N	\N	\N
4	25	2	500.00	MOCK	completed	MOCK_1778173329473	2026-05-07 22:02:09.606103	beneficiary	benef@gmail.com	f	\N	\N	\N	\N	\N	\N	\N	\N
5	5	2	1000.00	MOCK	completed	MOCK_621c1f40-71b6-4633-a81f-faddcd063fb5	2026-05-08 09:13:35.853282	donor	donor@gmail.com	f	\N	\N	\N	\N	\N	\N	\N	\N
6	5	4	456.00	BANK_TRANSFER	VERIFIED	\N	2026-05-10 09:25:45.925935	\N	\N	f	https://res.cloudinary.com/dlrw50wd7/image/upload/v1778387143/disasteraid/ngo_docs/jaje9ghlydgfuxiyk8nq.png	3	2026-05-10 10:02:05.86397	DON-87145932	\N	\N	/uploads/receipts/receipt_6_1778389325902.pdf	2026-05-10 10:02:05.86397
\.


--
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messages (id, request_id, sender_id, message, read_at, created_at) FROM stdin;
\.


--
-- Data for Name: ngo_profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ngo_profiles (id, user_id, org_name, registration_number, address, contact_person, mission, docs_url, status, rejection_reason, created_at, approved_by, approved_at, updated_at, bank_name, bank_account_title, bank_account_number, bank_iban, latitude, longitude, email, phone) FROM stdin;
1	2	kjkljkljjhfgcgjuj	hghggcvxvukyjhvfgc	ajfhjkaflakjfkla jl lj  kj j jkaf	03187821704	qqqqqqqqqqqqqqqqqqqqwertyuilkjhgfdfbtdsn v  ngg jk kjuiwajfioxjjkfjksdjjfsdjkahjkhjkhjkh	{https://res.cloudinary.com/dlrw50wd7/image/upload/v1778007232/disasteraid/ngo_docs/lv4rdnlidtnmigq6tqcu.png}	APPROVED	\N	2026-05-05 23:53:53.485268	\N	\N	2026-05-06 00:14:17.825521	\N	\N	\N	\N	\N	\N	\N	\N
3	16	this is an orga	1123465465465465	bnbvcfdghbhjukjvghvjknj	031878214047	gghfffgdfdssdasaS FFGSFDSDS YTFFGDDRYUYU FYTGYUGY	{https://res.cloudinary.com/dlrw50wd7/image/upload/v1778015579/disasteraid/ngo_docs/a2bdriv1zmxo2wgueugz.png}	REJECTED	yaar waisay mera hi platfrom aur meri marzi nahi	2026-05-06 02:13:00.160089	\N	\N	2026-05-06 02:13:00.160089	\N	\N	\N	\N	\N	\N	\N	\N
2	4	my name is google 	main nahi bataunga ga ky number kiya hy	office jb hy hi nahi tou address kaisiay bataun??	03187821407	waisya yare the mission hota kiya hamara to maqsad ha wo has yoi know 	{https://res.cloudinary.com/dlrw50wd7/image/upload/v1778008219/disasteraid/ngo_docs/mc5ndizsshfckayttl09.png}	APPROVED	\N	2026-05-06 00:10:19.763586	3	2026-05-09 09:08:33.779152	2026-05-06 00:14:17.825521	\N	\N	\N	\N	\N	\N	\N	\N
4	29	my name is life	13243545151651651	main nahi bataunga and you know why i would not tell	03124587985	my mission statement is nothing but to be a gkfjklafjklajfklfaklj	{https://res.cloudinary.com/dlrw50wd7/image/upload/v1778384887/disasteraid/ngo_docs/wlkgsezaylxzkbsb87rd.png}	APPROVED	\N	2026-05-10 08:48:08.809962	3	2026-05-10 08:59:41.814722	2026-05-10 09:20:25.150144	my name is life	my name is life	6566163656565156	PK36SCBL0000001123456702	\N	\N	m.arshad.baloch2004@gmail.com	03124545454
\.


--
-- Data for Name: ngo_wallets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ngo_wallets (id, ngo_id, balance, total_received, total_withdrawn, updated_at) FROM stdin;
1	1	7000.00	8000.00	1000.00	2026-05-08 09:13:35.853282
7	4	456.00	456.00	0.00	2026-05-10 10:02:05.86397
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (id, user_id, title, body, type, data, is_read, created_at) FROM stdin;
1	5	Donation Verified	Your PKR 456.00 donation to my love is life is verified.	donation_verified	{"campaign_id": 4, "donation_id": 6}	f	2026-05-10 10:02:06.976368
\.


--
-- Data for Name: reports; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reports (id, reporter_id, target_type, target_id, reason, description, status, admin_notes, created_at, reviewed_at, reviewed_by) FROM stdin;
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (id, name) FROM stdin;
1	donor
2	ngo
3	volunteer
4	beneficiary
5	admin
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, phone, password_hash, role_id, name, locale, fcm_token, created_at) FROM stdin;
1	arshad@gmail.com	\N	$2b$10$4Kz7BuXz7qG7hIuYoF5hieg2swDio6b440DtMBy9qBetJGgjkNtxy	1	arshad	en	\N	2026-05-05 22:24:14.186928
2	ngo@gmail.com	\N	$2b$10$XZJZrJjjRcsFuZnotLIuuuPb4XmqTo4J2NXBxOJQWGdsBk.ZM8W02	2	ngo	en	\N	2026-05-05 23:13:02.512459
3	admin@gmail.com	\N	$2b$10$3s99sIoSQP5xaGhGR0FOn.7J0Pg4RS32FctnlE7eCs.FmKQlU7EDe	5	admin	en	\N	2026-05-06 00:05:22.348171
4	ngo1@gmail.com	\N	$2b$10$M4a9u8SPB8eDKGFJ7CDm5O4RA73MQKkptF8yqMnWGnBvoDWM3bc62	2	ngo1	en	\N	2026-05-06 00:09:00.181657
5	donor@gmail.com	\N	$2b$10$NVg7sT5BS6PiBRg73aW3z.8Q5gYa9FdiSm4PQ4sJELE2yrGFrRhUK	1	donor	en	\N	2026-05-06 02:04:58.428229
7	donors@gmail.com	\N	$2b$10$bcug0xqusSjybGJXFnhfb.9PpyJC2/VewqfRoE/x1ZgAt2/AO4RCK	1	donor	en	\N	2026-05-06 02:05:47.025282
10	dono@gmail.com	\N	$2b$10$aVY6B6jLqr3UQR.xj8sfLO3O2K.js7uoCWAtUHbY4PXWGeaMciYZC	1	donors	en	\N	2026-05-06 02:06:11.005868
11	ngo2@gmail.com	\N	$2b$10$SUY/uSReYQh1d1Om07chgeJaO9TKZ6BYAuE8lsViAYOYTH7E8BC66	2	ngo	en	\N	2026-05-06 02:07:21.761927
15	donr@gmail.com	\N	$2b$10$MwsZrLRc7UkUlznw5ZO8WeIA8iE8urEqHqWyOH4OSYwfU31TcnJ5q	1	donor	en	\N	2026-05-06 02:11:18.971422
16	ngo3@gmail.com	\N	$2b$10$xy.vk1xKgI.tyBLL5rVHzew5y5w0RxC7CooaJplN.6LXkleZjzxAm	2	ngo3	en	\N	2026-05-06 02:12:20.39149
17	test@test.com	\N	$2b$10$Ekey/U65Dipws0jHhQkYDOWyIw9s7YFo8OjV56Yiy4bBw41wUJTGG	1	Test	en	\N	2026-05-06 02:52:53.669523
19	volun@gmail.com	03187821407	$2b$10$XKKrqo0wXH.M2xgssAwnYO9KgjQw3auY5FN7VlcPkmx2.g1/Ntvpu	3	volunteer	en	\N	2026-05-07 00:07:46.241709
22	benf@gmail.com	03124587545	$2b$10$EVj8qzKI9jkNprGSDEHF.uUFBAWILHp.oZGwq4L.p7b6tx9Hg2leG	4	beneficiary	en	\N	2026-05-07 00:08:47.634837
24	vreg@gmail.com	\N	$2b$10$.GZNNxeSQ/6K1BE1yH.n0.MI8zQ21LNKQd7nDh3Z6chQd1wSTvuzG	3	arshad	en	\N	2026-05-07 19:38:09.696061
25	benef@gmail.com	\N	$2b$10$s2KyKBhTSjs.g/yQ/z8ydeePykpNMtzQXPtIHuyyV.Z6B0TD8QqwG	4	beneficiary	en	\N	2026-05-07 20:26:49.182562
26	benefi@gmail.com	\N	$2b$10$0gCFq38WIEM4RpKsgyxQVO4jHHxU0sAK8FQYoJjPif5mXuPJI28A2	4	love	en	\N	2026-05-07 20:27:47.869277
28	benefic@gmail.com	\N	$2b$10$U9qwxtqy8TL4./SFa/GGf.VmROmnLe2uILuQX.fH9P2w2PJcrjZwa	4	love	en	\N	2026-05-07 20:29:51.049767
29	newngo@gmail.com	03124545454	$2b$10$ixz6XEEoAsP0fFbHvB6dbe6o5jYM212yIk2kjQApkDSojts/SGlGC	2	newNgo	en	\N	2026-05-10 08:29:59.268879
30	newdonor@gmail.com	03124578451	$2b$10$go5LJtpXng74z4tf1pM53.a9tsvbP0ATAC1kqcQVNT1D13Rup8ySy	1	newdonor	en	\N	2026-05-10 09:02:41.211837
\.


--
-- Data for Name: volunteer_profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.volunteer_profiles (id, user_id, ngo_id, location, skills, status, created_at, availability, updated_at) FROM stdin;
1	19	1	lahore	{MEDICAL}	ACTIVE	2026-05-08 09:12:30.498352	FLEXIBLE	2026-05-08 09:12:30.498352
\.


--
-- Data for Name: wallet_transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wallet_transactions (id, ngo_id, amount, type, donation_id, description, created_at) FROM stdin;
1	1	5000.00	credit	1	Donation for: give me 	2026-05-06 22:47:03.614124
2	1	1000.00	credit	2	Donation for: give me 	2026-05-06 23:15:02.094323
3	1	500.00	credit	3	Donation for: give me 	2026-05-06 23:19:36.197605
4	1	500.00	credit	4	Donation for: MY CAMPAING	2026-05-07 22:02:09.606103
5	1	1000.00	credit	5	Donation for: MY CAMPAING	2026-05-08 09:13:35.853282
\.


--
-- Data for Name: withdrawal_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.withdrawal_requests (id, ngo_id, amount, bank_name, account_title, account_number, iban, status, rejection_reason, approved_by, transaction_ref, created_at, processed_at, transfer_proof_url, admin_notes, requested_by) FROM stdin;
1	1	1000.00	alfalah	12wkhfjkahfk	124578987	QWDEFRGTYHJUHGFJF;FJKLJK	APPROVED	\N	3	1223455645	2026-05-07 00:38:18.189704	2026-05-07 01:05:54.263786	\N	\N	\N
\.


--
-- Name: aid_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.aid_requests_id_seq', 4, true);


--
-- Name: audit_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_logs_id_seq', 1, false);


--
-- Name: campaigns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.campaigns_id_seq', 4, true);


--
-- Name: donations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.donations_id_seq', 6, true);


--
-- Name: messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.messages_id_seq', 1, false);


--
-- Name: ngo_profiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ngo_profiles_id_seq', 4, true);


--
-- Name: ngo_wallets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ngo_wallets_id_seq', 7, true);


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_id_seq', 1, true);


--
-- Name: reports_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.reports_id_seq', 1, false);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 85, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 30, true);


--
-- Name: volunteer_profiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.volunteer_profiles_id_seq', 1, true);


--
-- Name: wallet_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.wallet_transactions_id_seq', 5, true);


--
-- Name: withdrawal_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.withdrawal_requests_id_seq', 1, true);


--
-- Name: aid_requests aid_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aid_requests
    ADD CONSTRAINT aid_requests_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (id);


--
-- Name: donations donations_bank_reference_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_bank_reference_key UNIQUE (bank_reference);


--
-- Name: donations donations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: ngo_profiles ngo_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ngo_profiles
    ADD CONSTRAINT ngo_profiles_pkey PRIMARY KEY (id);


--
-- Name: ngo_profiles ngo_profiles_registration_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ngo_profiles
    ADD CONSTRAINT ngo_profiles_registration_number_key UNIQUE (registration_number);


--
-- Name: ngo_profiles ngo_profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ngo_profiles
    ADD CONSTRAINT ngo_profiles_user_id_key UNIQUE (user_id);


--
-- Name: ngo_wallets ngo_wallets_ngo_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ngo_wallets
    ADD CONSTRAINT ngo_wallets_ngo_id_key UNIQUE (ngo_id);


--
-- Name: ngo_wallets ngo_wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ngo_wallets
    ADD CONSTRAINT ngo_wallets_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: donations unique_transaction_ref; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT unique_transaction_ref UNIQUE (transaction_ref);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: volunteer_profiles volunteer_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.volunteer_profiles
    ADD CONSTRAINT volunteer_profiles_pkey PRIMARY KEY (id);


--
-- Name: volunteer_profiles volunteer_profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.volunteer_profiles
    ADD CONSTRAINT volunteer_profiles_user_id_key UNIQUE (user_id);


--
-- Name: wallet_transactions wallet_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_pkey PRIMARY KEY (id);


--
-- Name: withdrawal_requests withdrawal_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.withdrawal_requests
    ADD CONSTRAINT withdrawal_requests_pkey PRIMARY KEY (id);


--
-- Name: idx_aid_requests_beneficiary; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aid_requests_beneficiary ON public.aid_requests USING btree (beneficiary_id);


--
-- Name: idx_aid_requests_location; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aid_requests_location ON public.aid_requests USING btree (latitude, longitude) WHERE ((status)::text = 'PENDING'::text);


--
-- Name: idx_aid_requests_ngo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aid_requests_ngo ON public.aid_requests USING btree (ngo_id);


--
-- Name: idx_aid_requests_ngo_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aid_requests_ngo_id ON public.aid_requests USING btree (ngo_id);


--
-- Name: idx_aid_requests_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aid_requests_status ON public.aid_requests USING btree (status);


--
-- Name: idx_audit_logs_action; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_logs_action ON public.audit_logs USING btree (action);


--
-- Name: idx_audit_logs_admin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_logs_admin ON public.audit_logs USING btree (admin_id);


--
-- Name: idx_audit_logs_target; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_logs_target ON public.audit_logs USING btree (target_type, target_id);


--
-- Name: idx_campaigns_location; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_campaigns_location ON public.campaigns USING btree (latitude, longitude) WHERE ((status)::text = 'ACTIVE'::text);


--
-- Name: idx_donations_bank_ref; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_donations_bank_ref ON public.donations USING btree (bank_reference);


--
-- Name: idx_donations_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_donations_status ON public.donations USING btree (status);


--
-- Name: idx_messages_request; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_messages_request ON public.messages USING btree (request_id, created_at DESC);


--
-- Name: idx_messages_unread; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_messages_unread ON public.messages USING btree (request_id, sender_id) WHERE (read_at IS NULL);


--
-- Name: idx_notifications_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user ON public.notifications USING btree (user_id, is_read, created_at DESC);


--
-- Name: idx_reports_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reports_status ON public.reports USING btree (status);


--
-- Name: idx_reports_target; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reports_target ON public.reports USING btree (target_type, target_id);


--
-- Name: idx_volunteer_profiles_ngo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_volunteer_profiles_ngo ON public.volunteer_profiles USING btree (ngo_id);


--
-- Name: idx_withdrawal_ngo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_withdrawal_ngo ON public.withdrawal_requests USING btree (ngo_id);


--
-- Name: idx_withdrawal_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_withdrawal_status ON public.withdrawal_requests USING btree (status);


--
-- Name: idx_withdrawals_ngo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_withdrawals_ngo ON public.withdrawal_requests USING btree (ngo_id);


--
-- Name: idx_withdrawals_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_withdrawals_status ON public.withdrawal_requests USING btree (status);


--
-- Name: campaigns update_campaigns_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_campaigns_updated_at BEFORE UPDATE ON public.campaigns FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: aid_requests aid_requests_beneficiary_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aid_requests
    ADD CONSTRAINT aid_requests_beneficiary_id_fkey FOREIGN KEY (beneficiary_id) REFERENCES public.users(id);


--
-- Name: aid_requests aid_requests_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aid_requests
    ADD CONSTRAINT aid_requests_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id);


--
-- Name: aid_requests aid_requests_delivered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aid_requests
    ADD CONSTRAINT aid_requests_delivered_by_fkey FOREIGN KEY (delivered_by) REFERENCES public.users(id);


--
-- Name: aid_requests aid_requests_ngo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aid_requests
    ADD CONSTRAINT aid_requests_ngo_id_fkey FOREIGN KEY (ngo_id) REFERENCES public.ngo_profiles(id);


--
-- Name: aid_requests aid_requests_volunteer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aid_requests
    ADD CONSTRAINT aid_requests_volunteer_id_fkey FOREIGN KEY (volunteer_id) REFERENCES public.volunteer_profiles(id);


--
-- Name: audit_logs audit_logs_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: campaigns campaigns_ngo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_ngo_id_fkey FOREIGN KEY (ngo_id) REFERENCES public.ngo_profiles(id) ON DELETE CASCADE;


--
-- Name: donations donations_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id);


--
-- Name: donations donations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: donations donations_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.users(id);


--
-- Name: messages messages_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.aid_requests(id) ON DELETE CASCADE;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id);


--
-- Name: ngo_profiles ngo_profiles_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ngo_profiles
    ADD CONSTRAINT ngo_profiles_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: ngo_profiles ngo_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ngo_profiles
    ADD CONSTRAINT ngo_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: ngo_wallets ngo_wallets_ngo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ngo_wallets
    ADD CONSTRAINT ngo_wallets_ngo_id_fkey FOREIGN KEY (ngo_id) REFERENCES public.ngo_profiles(id);


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reports reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: reports reports_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id);


--
-- Name: users users_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: volunteer_profiles volunteer_profiles_ngo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.volunteer_profiles
    ADD CONSTRAINT volunteer_profiles_ngo_id_fkey FOREIGN KEY (ngo_id) REFERENCES public.ngo_profiles(id);


--
-- Name: volunteer_profiles volunteer_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.volunteer_profiles
    ADD CONSTRAINT volunteer_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: wallet_transactions wallet_transactions_donation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_donation_id_fkey FOREIGN KEY (donation_id) REFERENCES public.donations(id);


--
-- Name: wallet_transactions wallet_transactions_ngo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_ngo_id_fkey FOREIGN KEY (ngo_id) REFERENCES public.ngo_profiles(id);


--
-- Name: withdrawal_requests withdrawal_requests_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.withdrawal_requests
    ADD CONSTRAINT withdrawal_requests_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: withdrawal_requests withdrawal_requests_ngo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.withdrawal_requests
    ADD CONSTRAINT withdrawal_requests_ngo_id_fkey FOREIGN KEY (ngo_id) REFERENCES public.ngo_profiles(id);


--
-- Name: withdrawal_requests withdrawal_requests_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.withdrawal_requests
    ADD CONSTRAINT withdrawal_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

\unrestrict HVVUWjoEZAG58U4MQyLu2CnGfCNfIyHENhAiKH3DumajDoLfBhPf57119FrC7ZQ

