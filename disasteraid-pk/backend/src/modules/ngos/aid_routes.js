const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const Joi = require('joi');

const updateRequestSchema = Joi.object({
  status: Joi.string().valid('APPROVED', 'REJECTED', 'ASSIGNED').required(),
  volunteer_id: Joi.number().integer().allow(null),
  rejection_reason: Joi.string().max(500).allow(null, ''),
});

// GET /api/ngos/aid-requests - All requests for NGO's campaigns
router.get('/aid-requests', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.status(400).json({ error: 'NGO profile not found' });

    const { status } = req.query;
    let query = `
      SELECT a.*, c.title as campaign_title, c.image_url,
             u.name as beneficiary_name, u.phone as beneficiary_phone,
             v.id as volunteer_id, vu.name as volunteer_name, vu.phone as volunteer_phone
      FROM aid_requests a
      JOIN campaigns c ON a.campaign_id = c.id
      JOIN users u ON a.beneficiary_id = u.id
      LEFT JOIN volunteer_profiles v ON a.volunteer_id = v.id
      LEFT JOIN users vu ON v.user_id = vu.id
      WHERE a.ngo_id = $1
    `;
    const params = [ngo.rows[0].id];
    if (status) { params.push(status); query += ` AND a.status = $${params.length}`; }
    query += ' ORDER BY CASE a.urgency WHEN \'CRITICAL\' THEN 1 WHEN \'HIGH\' THEN 2 WHEN \'MEDIUM\' THEN 3 ELSE 4 END, a.created_at DESC';

    const result = await db.query(query, params);
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// PATCH /api/ngos/aid-requests/:id - Approve + assign volunteer
router.patch('/aid-requests/:id', auth('ngo'), async (req, res, next) => {
  try {
    const { error, value } = updateRequestSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const { status, volunteer_id, rejection_reason } = value;
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.status(400).json({ error: 'NGO profile not found' });

    // If assigning volunteer, verify they belong to this NGO
    if (volunteer_id) {
      const vol = await db.query('SELECT id FROM volunteer_profiles WHERE id=$1 AND ngo_id=$2', [volunteer_id, ngo.rows[0].id]);
      if (!vol.rows[0]) return res.status(400).json({ error: 'Volunteer not found or not in your NGO' });
    }

    // Update status - only allow transitions from PENDING
    const result = await db.query(
      `UPDATE aid_requests SET
        status=$1,
        volunteer_id=$2,
        rejection_reason=$3,
        updated_at=NOW()
       WHERE id=$4 AND ngo_id=$5 AND status='PENDING'
       RETURNING *`,
      [status, volunteer_id || null, rejection_reason || null, req.params.id, ngo.rows[0].id]
    );

    if (!result.rows[0]) return res.status(400).json({ error: 'Request not found or already processed' });
    res.json({ success: true, data: result.rows[0] });
  } catch (e) { next(e); }
});

// GET /api/ngos/volunteers - List volunteers for NGO
router.get('/volunteers', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.json({ data: [] });

    const result = await db.query(`
      SELECT v.*, u.name, u.email, u.phone,
             COUNT(a.id) FILTER (WHERE a.status='DELIVERED') as completed_tasks,
             COUNT(a.id) FILTER (WHERE a.status IN ('ASSIGNED','PICKED_UP','IN_TRANSIT')) as active_tasks
      FROM volunteer_profiles v
      JOIN users u ON v.user_id = u.id
      LEFT JOIN aid_requests a ON a.volunteer_id = v.id
      WHERE v.ngo_id = $1
      GROUP BY v.id, u.id
      ORDER BY completed_tasks DESC
    `, [ngo.rows[0].id]);
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// GET /api/ngos/aid-requests/:id - Single request details
router.get('/aid-requests/:id', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    const result = await db.query(`
      SELECT a.*, c.title as campaign_title, u.name as beneficiary_name, u.phone as beneficiary_phone,
             v.id as volunteer_id, vu.name as volunteer_name, vu.phone as volunteer_phone
      FROM aid_requests a
      JOIN campaigns c ON a.campaign_id = c.id
      JOIN users u ON a.beneficiary_id = u.id
      LEFT JOIN volunteer_profiles v ON a.volunteer_id = v.id
      LEFT JOIN users vu ON v.user_id = vu.id
      WHERE a.id = $1 AND a.ngo_id = $2
    `, [req.params.id, ngo.rows[0].id]);

    if (!result.rows[0]) return res.status(404).json({ error: 'Request not found' });
    res.json({ data: result.rows[0] });
  } catch (e) { next(e); }
});

module.exports = router;