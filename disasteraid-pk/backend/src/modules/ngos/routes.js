const router = require('express').Router();
const auth = require('../../middleware/auth');
const db = require('../../config/db');
const upload = require('../../utils/upload'); // This should be multer-storage-cloudinary
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

// POST /api/ngos/onboard - NGO submits verification docs
router.post('/onboard', auth('ngo'), upload.array('docs', 5), async (req, res, next) => {
  try {
    const { error, value } = onboardSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const existing = await db.query('SELECT status FROM ngo_profiles WHERE user_id=$1', [req.user.id]);
    if (existing.rows[0]?.status === 'PENDING') return res.status(400).json({ error: 'Already submitted for review' });
    if (existing.rows[0]?.status === 'APPROVED') return res.status(400).json({ error: 'Already verified' });

    if (!req.files || req.files.length === 0) return res.status(400).json({ error: 'At least 1 document required' });

    // Cloudinary returns full URLs in req.files[].path
    const urls = req.files.map(f => f.path);
    const { org_name, registration_number, address, contact_person, mission, email, phone } = value;

    await db.query(
      `INSERT INTO ngo_profiles(user_id, org_name, registration_number, address, contact_person, mission, email, phone, docs_url, status)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,'PENDING')
       ON CONFLICT (user_id) DO UPDATE SET
       org_name=$2, registration_number=$3, address=$4, contact_person=$5, mission=$6, email=$7, phone=$8, docs_url=$9, status='PENDING', updated_at=NOW()`,
      [req.user.id, org_name, registration_number, address, contact_person, mission, email, phone, urls]
    );
    res.json({ success: true, message: 'Submitted for admin approval' });
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
    res.json({ data: result.rows[0] || null });
  } catch (e) { next(e); }
});

// GET /api/ngos/profile - Alias for /me
router.get('/profile', auth('ngo'), async (req, res, next) => {
  try {
    const result = await db.query('SELECT * FROM ngo_profiles WHERE user_id=$1', [req.user.id]);
    res.json({ data: result.rows[0] || null });
  } catch (e) { next(e); }
});

module.exports = router;