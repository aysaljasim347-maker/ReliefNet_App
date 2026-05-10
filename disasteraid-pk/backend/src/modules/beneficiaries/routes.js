const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const Joi = require('joi');

const aidRequestSchema = Joi.object({
  campaign_id: Joi.number().integer().allow(null),
  category: Joi.string().valid('FOOD', 'MEDICAL', 'SHELTER', 'CLOTHING', 'OTHER').required(),
  items_needed: Joi.array().items(Joi.string()).min(1).required(),
  description: Joi.string().min(10).max(1000).required(),
  urgency: Joi.string().valid('LOW', 'MEDIUM', 'HIGH', 'CRITICAL').default('MEDIUM'),
  family_size: Joi.number().integer().min(1).max(50).default(1),
  location: Joi.string().min(5).required(),
  latitude: Joi.number().min(-90).max(90).allow(null),
  longitude: Joi.number().min(-180).max(180).allow(null),
});

// POST /api/aid-requests - Beneficiary creates request
router.post('/aid-requests', auth('beneficiary'), async (req, res, next) => {
  try {
    const { error, value } = aidRequestSchema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400);

    const { campaign_id, category, items_needed, description, urgency, family_size, location, latitude, longitude } = value;
    let ngo_id = null;

    if (campaign_id) {
      const campaign = await db.query(`
        SELECT c.ngo_id, c.status, c.end_date, n.status as ngo_status
        FROM campaigns c
        JOIN ngo_profiles n ON c.ngo_id = n.id
        WHERE c.id = $1
      `, [campaign_id]);

      if (!campaign.rows[0]) return res.fail('Campaign not found', 404);
      if (campaign.rows[0].status!== 'ACTIVE') return res.fail('Campaign not active', 400);
      if (campaign.rows[0].ngo_status!== 'APPROVED') return res.fail('NGO not verified', 400);
      if (campaign.rows[0].end_date && new Date(campaign.rows[0].end_date) < new Date()) {
        return res.fail('Campaign has ended', 400);
      }
      ngo_id = campaign.rows[0].ngo_id;

      const existing = await db.query(
        `SELECT id FROM aid_requests
         WHERE beneficiary_id = $1 AND campaign_id = $2 AND status IN ('PENDING', 'APPROVED', 'ASSIGNED')`,
        [req.user.id, campaign_id]
      );
      if (existing.rows[0]) return res.fail('You already have an active request for this campaign', 400);
    } else {
      const defaultNgo = await db.query(
        `SELECT id FROM ngo_profiles WHERE status='APPROVED' ORDER BY created_at ASC LIMIT 1`
      );
      if (defaultNgo.rows[0]) ngo_id = defaultNgo.rows[0].id;
    }

    const result = await db.query(
      `INSERT INTO aid_requests (beneficiary_id, campaign_id, ngo_id, category, items_needed, description, urgency, family_size, location, latitude, longitude, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'PENDING') RETURNING *`,
      [req.user.id, campaign_id, ngo_id, category, JSON.stringify(items_needed), description, urgency, family_size, location, latitude, longitude]
    );
    res.success(result.rows[0], 201);
  } catch (e) { next(e); }
});

// GET /api/aid-requests/my
router.get('/aid-requests/my', auth('beneficiary'), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT a.*,
             COALESCE(c.title, 'General Request') as campaign_title,
             c.image_url,
             n.org_name,
             v.id as volunteer_id, u.name as volunteer_name, u.phone as volunteer_phone
      FROM aid_requests a
      LEFT JOIN campaigns c ON a.campaign_id = c.id
      LEFT JOIN ngo_profiles n ON a.ngo_id = n.id
      LEFT JOIN volunteer_profiles v ON a.volunteer_id = v.id
      LEFT JOIN users u ON v.user_id = u.id
      WHERE a.beneficiary_id = $1
      ORDER BY a.created_at DESC
      LIMIT 50
    `, [req.user.id]);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/aid-requests/:id
router.get('/aid-requests/:id', auth('beneficiary'), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT a.*,
             COALESCE(c.title, 'General Request') as campaign_title,
             n.org_name, n.phone as ngo_phone,
             v.id as volunteer_id, u.name as volunteer_name, u.phone as volunteer_phone
      FROM aid_requests a
      LEFT JOIN campaigns c ON a.campaign_id = c.id
      LEFT JOIN ngo_profiles n ON a.ngo_id = n.id
      LEFT JOIN volunteer_profiles v ON a.volunteer_id = v.id
      LEFT JOIN users u ON v.user_id = u.id
      WHERE a.id = $1 AND a.beneficiary_id = $2
    `, [req.params.id, req.user.id]);

    if (!result.rows[0]) return res.fail('Request not found', 404);
    res.success(result.rows[0]);
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
    if (!result.rows[0]) return res.fail('Cannot cancel this request', 400);
    res.success({ message: 'Request cancelled' });
  } catch (e) { next(e); }
});

// GET /api/aid-requests/map - For volunteer map
router.get('/map', auth('volunteer'), async (req, res, next) => {
  try {
    const { status = 'PENDING' } = req.query;
    const result = await db.query(`
      SELECT a.id, a.beneficiary_name, a.category, a.urgency,
             a.latitude, a.longitude, a.location as address, a.family_size,
             COALESCE(c.title, 'General Request') as campaign_title
      FROM aid_requests a
      LEFT JOIN campaigns c ON a.campaign_id = c.id
      WHERE a.status = $1
        AND a.latitude IS NOT NULL
        AND a.longitude IS NOT NULL
      ORDER BY a.created_at DESC
      LIMIT 100
    `, [status]);
    res.success(result.rows);
  } catch (e) { next(e); }
});

module.exports = router;