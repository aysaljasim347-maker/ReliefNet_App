const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const upload = require('../../utils/upload');
const Joi = require('joi');

const campaignSchema = Joi.object({
  title: Joi.string().min(5).max(255).required(),
  description: Joi.string().min(20).required(),
  category: Joi.string().valid('FOOD', 'MEDICAL', 'SHELTER', 'EDUCATION', 'CLOTHING', 'OTHER').required(),
  target_amount: Joi.number().positive().required(),
  location: Joi.string().min(3).required(),
  end_date: Joi.date().greater('now').required(),
});

// POST /api/campaigns - NGO creates campaign with Cloudinary image
router.post('/', auth('ngo'), upload.single('image'), async (req, res, next) => {
  try {
    const { error, value } = campaignSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const ngo = await db.query('SELECT id, status FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.status(400).json({ error: 'Create NGO profile first' });
    if (ngo.rows[0].status!== 'APPROVED') return res.status(403).json({ error: 'NGO not approved yet' });

    const image_url = req.file? req.file.path : null;
    const { title, description, category, target_amount, location, end_date } = value;

    const result = await db.query(
      `INSERT INTO campaigns (ngo_id, title, description, category, target_amount, image_url, location, end_date, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'ACTIVE') RETURNING *`,
      [ngo.rows[0].id, title, description, category, target_amount, image_url, location, end_date]
    );
    res.json({ data: result.rows[0] });
  } catch (e) { next(e); }
});

// GET /api/campaigns - Public list with donor count
router.get('/', async (req, res, next) => {
  try {
    const { status = 'ACTIVE', category, limit = 20, offset = 0 } = req.query;
    let query = `
      SELECT c.*, n.org_name, n.id as ngo_id,
             COUNT(DISTINCT d.user_id) as donor_count
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      LEFT JOIN donations d ON d.campaign_id = c.id
      WHERE 1=1
    `;
    const params = [];
    if (status) { params.push(status); query += ` AND c.status = $${params.length}`; }
    if (category) { params.push(category); query += ` AND c.category = $${params.length}`; }
    query += ` GROUP BY c.id, n.id ORDER BY c.created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);

    const result = await db.query(query, params);
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// GET /api/campaigns/my - NGO's own campaigns with stats
router.get('/my', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.json({ data: [] });

    const result = await db.query(`
      SELECT c.*, COUNT(DISTINCT d.user_id) as donor_count
      FROM campaigns c
      LEFT JOIN donations d ON d.campaign_id = c.id
      WHERE c.ngo_id = $1
      GROUP BY c.id
      ORDER BY c.created_at DESC
    `, [ngo.rows[0].id]);
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// GET /api/campaigns/:id - Single campaign with full stats
router.get('/:id', async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT c.*, n.org_name, n.contact_person, n.email, n.phone,
             COUNT(DISTINCT d.user_id) as donor_count
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      LEFT JOIN donations d ON d.campaign_id = c.id
      WHERE c.id = $1
      GROUP BY c.id, n.id
    `, [req.params.id]);

    if (!result.rows[0]) return res.status(404).json({ error: 'Campaign not found' });
    res.json({ data: result.rows[0] });
  } catch (e) { next(e); }
});

// PUT /api/campaigns/:id - NGO edits own campaign
router.put('/:id', auth('ngo'), upload.single('image'), async (req, res, next) => {
  try {
    const { error, value } = campaignSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.status(403).json({ error: 'NGO profile not found' });

    const image_url = req.file? req.file.path : req.body.image_url;
    const { title, description, category, target_amount, location, end_date } = value;

    const result = await db.query(
      `UPDATE campaigns SET title=$1, description=$2, category=$3, target_amount=$4, image_url=$5, location=$6, end_date=$7
       WHERE id=$8 AND ngo_id=$9 RETURNING *`,
      [title, description, category, target_amount, image_url, location, end_date, req.params.id, ngo.rows[0].id]
    );

    if (!result.rows[0]) return res.status(403).json({ error: 'Campaign not found or not yours' });
    res.json({ data: result.rows[0] });
  } catch (e) { next(e); }
});

// PATCH /api/campaigns/:id/status - NGO ends/pauses campaign
router.patch('/:id/status', auth('ngo'), async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!['ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    const result = await db.query(
      `UPDATE campaigns SET status=$1 WHERE id=$2 AND ngo_id=$3 RETURNING *`,
      [status, req.params.id, ngo.rows[0].id]
    );

    if (!result.rows[0]) return res.status(403).json({ error: 'Campaign not found or not yours' });
    res.json({ data: result.rows[0] });
  } catch (e) { next(e); }
});

module.exports = router;