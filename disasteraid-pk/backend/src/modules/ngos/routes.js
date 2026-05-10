const router = require('express').Router();
const auth = require('../../middleware/auth');
const db = require('../../config/db');
const upload = require('../../utils/upload');
const Joi = require('joi');

const onboardSchema = Joi.object({
  org_name: Joi.string().min(3).required(),
  registration_number: Joi.string().min(5).required(),
  address: Joi.string().min(10).required(),
  contact_person: Joi.string().min(2).required(),
  mission: Joi.string().min(20).required(),
  email: Joi.string().email().required(),
  phone: Joi.string().pattern(/^[0-9]{11}$/).required(),
});

// GET /api/ngos - List approved NGOs for volunteers to choose
router.get('/', async (req, res, next) => {
  try {
    const result = await db.query(
      `SELECT id, org_name, address as city FROM ngo_profiles WHERE status='APPROVED' ORDER BY org_name`
    );
    res.success(result.rows);
  } catch (e) { next(e); }
});

// POST /api/ngos/onboard - NGO submits verification docs
router.post('/onboard', auth('ngo'), upload.array('docs', 5), async (req, res, next) => {
  try {
    const { error, value } = onboardSchema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400); // was res.fail

    const existing = await db.query('SELECT status FROM ngo_profiles WHERE user_id=$1', [req.user.id]);
    if (existing.rows[0]?.status === 'PENDING') return res.fail('Already submitted for review', 400); // was res.fail
    if (existing.rows[0]?.status === 'APPROVED') return res.fail('Already verified', 400); // was res.fail

    if (!req.files || req.files.length === 0) return res.fail('At least 1 document required', 400); // was res.fail

    const urls = req.files.map(f => f.path);
    const { org_name, registration_number, address, contact_person, mission, email, phone } = value;

    await db.query(
      `INSERT INTO ngo_profiles(user_id, org_name, registration_number, address, contact_person, mission, email, phone, docs_url, status)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,'PENDING')
       ON CONFLICT (user_id) DO UPDATE SET
       org_name=$2, registration_number=$3, address=$4, contact_person=$5, mission=$6, email=$7, phone=$8, docs_url=$9, status='PENDING', updated_at=NOW()`,
      [req.user.id, org_name, registration_number, address, contact_person, mission, email, phone, urls]
    );
    res.success({ message: 'Submitted for admin approval' }, 201);
  } catch (e) { next(e); }
});

// GET /api/ngos/me - Get own NGO profile with wallet info
router.get('/me', auth('ngo'), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT n.*, COALESCE(w.balance, 0) as balance,
             COALESCE(w.total_received, 0) as total_received,
             COALESCE(w.total_withdrawn, 0) as total_withdrawn
      FROM ngo_profiles n
      LEFT JOIN ngo_wallets w ON w.ngo_id = n.id
      WHERE n.user_id=$1
    `, [req.user.id]);
    res.success(result.rows[0] || null);
  } catch (e) { next(e); }
});

// GET /api/ngos/profile - Alias for /me
router.get('/profile', auth('ngo'), async (req, res, next) => {
  try {
    const result = await db.query('SELECT * FROM ngo_profiles WHERE user_id=$1', [req.user.id]);
    res.success(result.rows[0] || null);
  } catch (e) { next(e); }
});

// GET /api/ngo/dashboard/stats - KPI cards
router.get('/dashboard/stats', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.fail('NGO profile not found', 403);
    const ngoId = ngo.rows[0].id;

    const result = await db.query(`
      SELECT
        (SELECT COALESCE(balance, 0) FROM ngo_wallets WHERE ngo_id = $1) as wallet_balance,
        (SELECT COALESCE(total_received, 0) FROM ngo_wallets WHERE ngo_id = $1) as total_raised,
        (SELECT COUNT(*) FROM campaigns WHERE ngo_id = $1) as total_campaigns,
        (SELECT COUNT(*) FROM campaigns WHERE ngo_id = $1 AND status = 'ACTIVE') as active_campaigns,
        (SELECT COUNT(DISTINCT d.user_id) FROM donations d
         JOIN campaigns c ON d.campaign_id = c.id
         WHERE c.ngo_id = $1 AND d.status = 'VERIFIED') as total_donors,
        (SELECT COUNT(*) FROM aid_requests ar WHERE ar.ngo_id = $1) as total_aid_requests,
        (SELECT COUNT(*) FROM aid_requests ar WHERE ar.ngo_id = $1 AND ar.status = 'DELIVERED') as delivered_count,
        (SELECT COUNT(*) FROM withdrawal_requests WHERE ngo_id = $1 AND status = 'PENDING') as pending_withdrawals
    `, [ngoId]);

    const stats = result.rows[0];
    const deliveryRate = stats.total_aid_requests > 0
     ? ((stats.delivered_count / stats.total_aid_requests) * 100).toFixed(1)
      : 0;

    res.success({
     ...stats,
      delivery_rate: parseFloat(deliveryRate)
    });
  } catch (e) { next(e); }
});

// GET /api/ngo/dashboard/chart?days=30 - Donations over time
router.get('/dashboard/chart', auth('ngo'), async (req, res, next) => {
  try {
    const days = parseInt(req.query.days) || 30;
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.fail('NGO profile not found', 403);

    const result = await db.query(`
      SELECT
        DATE(d.verified_at) as date,
        SUM(d.amount)::int as amount,
        COUNT(d.id)::int as count
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      WHERE c.ngo_id = $1
        AND d.status = 'VERIFIED'
        AND d.verified_at >= NOW() - INTERVAL '1 day' * $2
      GROUP BY DATE(d.verified_at)
      ORDER BY date ASC
    `, [ngo.rows[0].id, days]);

    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/ngo/dashboard/recent - Last 5 donations
router.get('/dashboard/recent', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.fail('NGO profile not found', 403);

    const result = await db.query(`
      SELECT d.id, d.amount, d.verified_at, d.donor_name, c.title as campaign_title
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      WHERE c.ngo_id = $1 AND d.status = 'VERIFIED'
      ORDER BY d.verified_at DESC
      LIMIT 5
    `, [ngo.rows[0].id]);

    res.success(result.rows);
  } catch (e) { next(e); }
});

// PUT /api/ngos/bank-details - NGO adds bank info after approval
router.put('/bank-details', auth('ngo'), async (req, res, next) => {
  try {
    const { error, value } = Joi.object({
      bank_name: Joi.string().min(2).required(),
      bank_account_title: Joi.string().min(2).required(),
      bank_account_number: Joi.string().min(5).required(),
      bank_iban: Joi.string().length(24).pattern(/^PK/).required(),
    }).validate(req.body);

    if (error) return res.fail(error.details[0].message, 400);

    const { bank_name, bank_account_title, bank_account_number, bank_iban } = value;

    const result = await db.query(
      `UPDATE ngo_profiles
       SET bank_name=$1, bank_account_title=$2, bank_account_number=$3, bank_iban=$4, updated_at=NOW()
       WHERE user_id=$5 AND status='APPROVED'
       RETURNING *`,
      [bank_name, bank_account_title, bank_account_number, bank_iban, req.user.id]
    );

    if (result.rows.length === 0) {
      return res.fail('NGO not approved or profile not found', 403);
    }

    res.success({ message: 'Bank details saved', data: result.rows[0] });
  } catch (e) { next(e); }
});

module.exports = router;