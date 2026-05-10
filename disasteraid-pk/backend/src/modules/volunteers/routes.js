const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const Joi = require('joi');
const upload = require('../../utils/upload');

const volunteerSchema = Joi.object({
  ngo_id: Joi.number().integer().required(),
  location: Joi.string().min(3),
  skills: Joi.array().items(Joi.string()).default([]),
  availability: Joi.string().valid('WEEKENDS', 'WEEKDAYS', 'FLEXIBLE').default('FLEXIBLE'),
});

// POST /api/volunteers/register - Join as volunteer
router.post('/register', auth('volunteer'), async (req, res, next) => {
  try {
    const { error, value } = volunteerSchema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400);

    const { ngo_id, location, skills, availability } = value;

    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE id=$1 AND status=$2', [ngo_id, 'APPROVED']);
    if (!ngo.rows[0]) return res.fail('NGO not found or not approved', 400);

    const result = await db.query(
      `INSERT INTO volunteer_profiles (user_id, ngo_id, location, skills, availability)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (user_id) DO UPDATE SET ngo_id=$2, location=$3, skills=$4, availability=$5, updated_at=NOW()
       RETURNING *`,
      [req.user.id, ngo_id, location, skills, availability]
    );
    res.success(result.rows[0], 201);
  } catch (e) { next(e); }
});

// GET /api/volunteers/tasks/available
router.get('/tasks/available', auth('volunteer'), async (req, res, next) => {
  try {
    const vol = await db.query('SELECT * FROM volunteer_profiles WHERE user_id = $1', [req.user.id]);
    if (!vol.rows[0]) return res.fail('Complete volunteer profile first', 400);

    const result = await db.query(`
      SELECT a.*, c.title as campaign_title, c.image_url,
             u.name as beneficiary_name, u.phone as beneficiary_phone
      FROM aid_requests a
      JOIN campaigns c ON a.campaign_id = c.id
      JOIN users u ON a.beneficiary_id = u.id
      WHERE a.ngo_id = $1 AND a.status = 'APPROVED' AND a.volunteer_id IS NULL
      ORDER BY
        CASE a.urgency WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END,
        a.created_at ASC
      LIMIT 50
    `, [vol.rows[0].ngo_id]);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// POST /api/volunteers/tasks/:id/accept
router.post('/tasks/:id/accept', auth('volunteer'), async (req, res, next) => {
  const client = await db.connect();
  try {
    await client.query('BEGIN');

    const vol = await client.query('SELECT id, ngo_id FROM volunteer_profiles WHERE user_id = $1', [req.user.id]);
    if (!vol.rows[0]) throw new Error('Volunteer profile not found');

    const task = await client.query(
      `SELECT id, ngo_id, status FROM aid_requests WHERE id = $1 FOR UPDATE`,
      [req.params.id]
    );

    if (!task.rows[0]) throw new Error('Task not found');
    if (task.rows[0].status!== 'APPROVED') throw new Error('Task not available');
    if (task.rows[0].ngo_id!== vol.rows[0].ngo_id) throw new Error('Task not for your NGO');

    await client.query(
      `UPDATE aid_requests SET volunteer_id=$1, status='ASSIGNED' WHERE id=$2`,
      [vol.rows[0].id, req.params.id]
    );

    await client.query('COMMIT');
    res.success({ message: 'Task accepted' });
  } catch (e) {
    await client.query('ROLLBACK');
    next(e);
  } finally {
    client.release();
  }
});

// GET /api/volunteers/tasks/my
router.get('/tasks/my', auth('volunteer'), async (req, res, next) => {
  try {
    const vol = await db.query('SELECT id FROM volunteer_profiles WHERE user_id = $1', [req.user.id]);
    if (!vol.rows[0]) return res.success([]);

    const result = await db.query(`
      SELECT a.*, c.title as campaign_title, c.image_url,
             u.name as beneficiary_name, u.phone as beneficiary_phone
      FROM aid_requests a
      JOIN campaigns c ON a.campaign_id = c.id
      JOIN users u ON a.beneficiary_id = u.id
      WHERE a.volunteer_id = $1 AND a.status IN ('ASSIGNED', 'PICKED_UP', 'IN_TRANSIT')
      ORDER BY a.created_at DESC
    `, [vol.rows[0].id]);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// PATCH /api/volunteers/tasks/:id/status
router.patch('/tasks/:id/status', auth('volunteer'), upload.single('proof'), async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!['PICKED_UP', 'IN_TRANSIT', 'DELIVERED'].includes(status)) {
      return res.fail('Invalid status', 400);
    }

    const vol = await db.query('SELECT id FROM volunteer_profiles WHERE user_id = $1', [req.user.id]);
    if (!vol.rows[0]) return res.fail('Volunteer profile not found', 403);

    const proof_url = req.file? req.file.path : req.body.proof_url;

    const result = await db.query(
      `UPDATE aid_requests SET
        status=$1,
        proof_url=COALESCE($2, proof_url),
        delivered_at=CASE WHEN $1='DELIVERED' THEN NOW() ELSE delivered_at END
       WHERE id=$3 AND volunteer_id=$4
       RETURNING *`,
      [status, proof_url, req.params.id, vol.rows[0].id]
    );

    if (!result.rows[0]) return res.fail('Task not found or not assigned to you', 403);

    // Note: completed_tasks is tracked via COUNT query in /stats, not a column

    res.success(result.rows[0]);
  } catch (e) { next(e); }
});

// GET /api/volunteers/stats
router.get('/stats', auth('volunteer'), async (req, res, next) => {
  try {
    const vol = await db.query(`
      SELECT v.*, u.name,
             COUNT(a.id) FILTER (WHERE a.status='DELIVERED') as completed,
             COUNT(a.id) FILTER (WHERE a.status IN ('ASSIGNED','PICKED_UP','IN_TRANSIT')) as active
      FROM volunteer_profiles v
      JOIN users u ON v.user_id = u.id
      LEFT JOIN aid_requests a ON a.volunteer_id = v.id
      WHERE v.user_id = $1
      GROUP BY v.id, u.name
    `, [req.user.id]);

    res.success(vol.rows[0] || null);
  } catch (e) { next(e); }
});

module.exports = router;