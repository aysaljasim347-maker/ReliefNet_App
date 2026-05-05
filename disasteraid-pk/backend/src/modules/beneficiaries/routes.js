const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const Joi = require('joi');

const aidRequestSchema = Joi.object({
  campaign_id: Joi.number().integer().required(),
  category: Joi.string().valid('FOOD', 'MEDICAL', 'SHELTER', 'CLOTHING', 'OTHER').required(),
  description: Joi.string().min(10).max(1000).required(),
  urgency: Joi.string().valid('LOW', 'MEDIUM', 'HIGH', 'CRITICAL').default('MEDIUM'),
  family_size: Joi.number().integer().min(1).max(50).default(1),
  location: Joi.string().min(5).required(),
  lat: Joi.number().min(-90).max(90).allow(null),
  lng: Joi.number().min(-180).max(180).allow(null),
});

// POST /api/aid-requests - Beneficiary creates request
router.post('/aid-requests', auth('beneficiary'), async (req, res, next) => {
  try {
    const { error, value } = aidRequestSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const { campaign_id, category, description, urgency, family_size, location, lat, lng } = value;

    // Check campaign exists, active, and NGO approved
    const campaign = await db.query(`
      SELECT c.ngo_id, c.status, c.end_date, n.status as ngo_status
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      WHERE c.id = $1
    `, [campaign_id]);

    if (!campaign.rows[0]) return res.status(404).json({ error: 'Campaign not found' });
    if (campaign.rows[0].status!== 'ACTIVE') return res.status(400).json({ error: 'Campaign not active' });
    if (campaign.rows[0].ngo_status!== 'APPROVED') return res.status(400).json({ error: 'NGO not verified' });
    if (campaign.rows[0].end_date && new Date(campaign.rows[0].end_date) < new Date()) {
      return res.status(400).json({ error: 'Campaign has ended' });
    }

    // Prevent duplicate pending requests for same campaign
    const existing = await db.query(
      `SELECT id FROM aid_requests
       WHERE beneficiary_id = $1 AND campaign_id = $2 AND status IN ('PENDING', 'APPROVED', 'ASSIGNED')`,
      [req.user.id, campaign_id]
    );
    if (existing.rows[0]) return res.status(400).json({ error: 'You already have an active request for this campaign' });

    const result = await db.query(
      `INSERT INTO aid_requests (beneficiary_id, campaign_id, ngo_id, category, description, urgency, family_size, location, lat, lng, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'PENDING') RETURNING *`,
      [req.user.id, campaign_id, campaign.rows[0].ngo_id, category, description, urgency, family_size, location, lat, lng]
    );
    res.json({ data: result.rows[0] });
  } catch (e) { next(e); }
});

// GET /api/aid-requests/my - Beneficiary's requests with volunteer info
router.get('/aid-requests/my', auth('beneficiary'), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT a.*, c.title as campaign_title, c.image_url, n.org_name,
             v.id as volunteer_id, u.name as volunteer_name, u.phone as volunteer_phone
      FROM aid_requests a
      JOIN campaigns c ON a.campaign_id = c.id
      JOIN ngo_profiles n ON a.ngo_id = n.id
      LEFT JOIN volunteer_profiles v ON a.volunteer_id = v.id
      LEFT JOIN users u ON v.user_id = u.id
      WHERE a.beneficiary_id = $1
      ORDER BY a.created_at DESC
      LIMIT 50
    `, [req.user.id]);
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// GET /api/aid-requests/:id - Single request details
router.get('/aid-requests/:id', auth('beneficiary'), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT a.*, c.title as campaign_title, n.org_name, n.phone as ngo_phone,
             v.id as volunteer_id, u.name as volunteer_name, u.phone as volunteer_phone
      FROM aid_requests a
      JOIN campaigns c ON a.campaign_id = c.id
      JOIN ngo_profiles n ON a.ngo_id = n.id
      LEFT JOIN volunteer_profiles v ON a.volunteer_id = v.id
      LEFT JOIN users u ON v.user_id = u.id
      WHERE a.id = $1 AND a.beneficiary_id = $2
    `, [req.params.id, req.user.id]);

    if (!result.rows[0]) return res.status(404).json({ error: 'Request not found' });
    res.json({ data: result.rows[0] });
  } catch (e) { next(e); }
});

// DELETE /api/aid-requests/:id - Cancel pending request
router.delete('/aid-requests/:id', auth('beneficiary'), async (req, res, next) => {
  try {
    const result = await db.query(
      `UPDATE aid_requests SET status='CANCELLED'
       WHERE id=$1 AND beneficiary_id=$2 AND status='PENDING' RETURNING *`,
      [req.params.id, req.user.id]
    );
    if (!result.rows[0]) return res.status(400).json({ error: 'Cannot cancel this request' });
    res.json({ success: true });
  } catch (e) { next(e); }
});

module.exports = router;