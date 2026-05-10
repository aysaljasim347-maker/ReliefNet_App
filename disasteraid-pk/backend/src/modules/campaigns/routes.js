const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const upload = require('../../utils/upload');
const Joi = require('joi');
const cloudinary = require('cloudinary').v2;
const fs = require('fs');

const campaignSchema = Joi.object({
  title: Joi.string().min(5).max(200).required(),
  description: Joi.string().min(20).max(5000).required(),
  category: Joi.string().valid('FOOD', 'MEDICAL', 'SHELTER', 'EDUCATION', 'CLOTHING', 'OTHER').required(),
  target_amount: Joi.number().integer().min(1000).max(10000000).required(),
  location: Joi.string().min(3).max(200).required(),
  end_date: Joi.date().min('now').required(),
  latitude: Joi.number().min(-90).max(90).allow(null),
  longitude: Joi.number().min(-180).max(180).allow(null),
  address: Joi.string().max(500).allow(null, '')
});

// POST /api/campaigns - Create campaign
router.post('/', auth('ngo'), upload.single('image'), async (req, res, next) => {
  try {
    const { error, value } = campaignSchema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400);

    const { title, description, category, target_amount, location, end_date, latitude, longitude, address } = value;

    const ngoCheck = await db.query(
      'SELECT id FROM ngo_profiles WHERE user_id=$1 AND status=$2',
      [req.user.id, 'APPROVED']
    );
    if (!ngoCheck.rows[0]) {
      return res.fail('NGO not approved yet', 403);
    }

    let image_url = null;
    if (req.file) {
      // CloudinaryStorage automatically uploads — req.file.path is the Cloudinary URL
      image_url = req.file.path;
    }

    const result = await db.query(
      `INSERT INTO campaigns (ngo_id, title, description, category, target_amount, location, latitude, longitude, address, image_url, end_date, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'ACTIVE') RETURNING *`,
      [ngoCheck.rows[0].id, title, description, category, target_amount, location, latitude, longitude, address, image_url, end_date]
    );

    res.success(result.rows[0], 201);
  } catch (e) { next(e); }
});

// GET /api/campaigns
router.get('/', async (req, res, next) => {
  try {
    const { ngo_id, status, category } = req.query;
    let query = `
      SELECT
        c.*,
        n.org_name,
        u.email as ngo_email,
        COUNT(d.id) as donor_count
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      JOIN users u ON n.user_id = u.id
      LEFT JOIN donations d ON d.campaign_id = c.id AND d.status = 'VERIFIED'
      WHERE 1=1
    `;
    const params = [];

    if (ngo_id) { params.push(ngo_id); query += ` AND c.ngo_id = $${params.length}`; }
    if (status) { params.push(status); query += ` AND c.status = $${params.length}`; }
    if (category) { params.push(category); query += ` AND c.category = $${params.length}`; }

    query += ' GROUP BY c.id, n.id, u.id ORDER BY c.created_at DESC';

    const result = await db.query(query, params);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/campaigns/my - NGO's own campaigns with stats
router.get('/my', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.success([]);

    const result = await db.query(`
      SELECT c.*, COUNT(DISTINCT d.user_id) as donor_count
      FROM campaigns c
      LEFT JOIN donations d ON d.campaign_id = c.id AND d.status = 'VERIFIED'
      WHERE c.ngo_id = $1
      GROUP BY c.id
      ORDER BY c.created_at DESC
    `, [ngo.rows[0].id]);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/campaigns/map - For map view
router.get('/map', async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT c.id, c.title, c.raised_amount, c.target_amount, c.category,
             c.latitude, c.longitude, c.address, c.image_url,
             n.org_name
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      WHERE c.status = 'ACTIVE'
        AND c.latitude IS NOT NULL
        AND c.longitude IS NOT NULL
      ORDER BY c.created_at DESC
    `);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/campaigns/nearby?lat=31.5204&lng=74.3587&radius=10
router.get('/nearby', async (req, res, next) => {
  try {
    const { lat, lng, radius = 10 } = req.query;

    if (!lat ||!lng) {
      return res.fail('lat and lng required', 400);
    }

    const result = await db.query(`
      SELECT c.id, c.title, c.raised_amount, c.target_amount, c.category,
             c.latitude, c.longitude, c.address, c.image_url,
             n.org_name,
             (
               6371 * acos(
                 cos(radians($1)) * cos(radians(c.latitude)) *
                 cos(radians(c.longitude) - radians($2)) +
                 sin(radians($1)) * sin(radians(c.latitude))
               )
             ) AS distance_km
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      WHERE c.status = 'ACTIVE'
        AND c.latitude IS NOT NULL
        AND c.longitude IS NOT NULL
        AND (
          6371 * acos(
            cos(radians($1)) * cos(radians(c.latitude)) *
            cos(radians(c.longitude) - radians($2)) +
            sin(radians($1)) * sin(radians(c.latitude))
          )
        ) <= $3
      ORDER BY distance_km ASC
      LIMIT 50
    `, [lat, lng, radius]);

    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/campaigns/:id - Campaign detail
router.get('/:id', async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT
        c.id, c.ngo_id, c.title, c.description, c.category,
        c.target_amount, c.raised_amount, c.image_url, c.location,
        c.latitude, c.longitude, c.address, c.status, c.created_at, c.end_date,
        n.org_name, n.contact_person, n.address as ngo_address, n.mission,
        u.email as ngo_email, u.phone as ngo_phone, u.name as ngo_contact_name,
        COUNT(d.id) as donor_count
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      JOIN users u ON n.user_id = u.id
      LEFT JOIN donations d ON d.campaign_id = c.id AND d.status = 'VERIFIED'
      WHERE c.id = $1
      GROUP BY c.id, n.id, u.id
    `, [req.params.id]);

    if (!result.rows[0]) return res.fail('Campaign not found', 404);
    
    // Add platform bank details from .env
    const campaign = {
      ...result.rows[0],
      platform_bank_name: process.env.PLATFORM_BANK_NAME,
      platform_account_title: process.env.PLATFORM_ACCOUNT_TITLE,
      platform_account_number: process.env.PLATFORM_ACCOUNT_NUMBER,
      platform_iban: process.env.PLATFORM_IBAN,
    };
    
    res.success(campaign);
  } catch (e) { next(e); }
});
// PUT /api/campaigns/:id - NGO edits own campaign
router.put('/:id', auth('ngo'), upload.single('image'), async (req, res, next) => {
  try {
    const { error, value } = campaignSchema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400);

    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.fail('NGO profile not found', 403);

    let image_url = req.body.image_url;
    if (req.file) {
      // CloudinaryStorage automatically uploads — req.file.path is the Cloudinary URL
      image_url = req.file.path;
    }

    const { title, description, category, target_amount, location, end_date, latitude, longitude, address } = value;

    const result = await db.query(
      `UPDATE campaigns SET title=$1, description=$2, category=$3, target_amount=$4, image_url=$5, location=$6, end_date=$7, latitude=$8, longitude=$9, address=$10
       WHERE id=$11 AND ngo_id=$12 RETURNING *`,
      [title, description, category, target_amount, image_url, location, end_date, latitude, longitude, address, req.params.id, ngo.rows[0].id]
    );

    if (!result.rows[0]) return res.fail('Campaign not found or not yours', 403);
    res.success(result.rows[0]);
  } catch (e) { next(e); }
});

// PATCH /api/campaigns/:id/status - NGO ends/pauses campaign
router.patch('/:id/status', auth('ngo'), async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!['ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED'].includes(status)) {
      return res.fail('Invalid status', 400);
    }

    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.fail('NGO profile not found', 403);

    const result = await db.query(
      `UPDATE campaigns SET status=$1 WHERE id=$2 AND ngo_id=$3 RETURNING *`,
      [status, req.params.id, ngo.rows[0].id]
    );

    if (!result.rows[0]) return res.fail('Campaign not found or not yours', 403);
    res.success(result.rows[0]);
  } catch (e) { next(e); }
});

module.exports = router;