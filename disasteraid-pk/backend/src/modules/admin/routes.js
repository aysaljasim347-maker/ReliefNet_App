const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const { logAction } = require('../../utils/audit');
const upload = require('../../utils/upload');

// GET /api/admin/stats - Dashboard stats
router.get('/stats', auth('admin'), async (req, res, next) => {
  try {
    const [users, ngos, campaigns, donations] = await Promise.all([
      db.query(`
        SELECT
          COUNT(*) as total,
          COUNT(*) FILTER (WHERE r.name = 'donor') as donors,
          COUNT(*) FILTER (WHERE r.name = 'ngo') as ngos,
          COUNT(*) FILTER (WHERE r.name = 'volunteer') as volunteers,
          COUNT(*) FILTER (WHERE r.name = 'beneficiary') as beneficiaries
        FROM users u
        JOIN roles r ON u.role_id = r.id
      `),
      db.query(`
        SELECT
          COUNT(*) FILTER (WHERE status='PENDING') as pending,
          COUNT(*) FILTER (WHERE status='APPROVED') as approved,
          COUNT(*) FILTER (WHERE status='REJECTED') as rejected
        FROM ngo_profiles
      `),
      db.query(`
        SELECT
          COUNT(*) as total,
          COUNT(*) FILTER (WHERE status='ACTIVE') as active,
          COALESCE(SUM(target_amount), 0) as total_target,
          COALESCE(SUM(raised_amount), 0) as total_raised
        FROM campaigns
      `),
      db.query(`
        SELECT
          COUNT(*) as total_donations,
          COALESCE(SUM(amount), 0) as total_amount
        FROM donations WHERE status IN ('completed', 'VERIFIED')
      `)
    ]);

    res.success({
      users: users.rows[0],
      ngos: ngos.rows[0],
      campaigns: campaigns.rows[0],
      donations: donations.rows[0]
    });
  } catch (e) { next(e); }
});

// PATCH /api/admin/ngos/:id/approve
router.patch('/ngos/:id/approve', auth('admin'), async (req, res, next) => {
  try {
    const result = await db.query(
      `UPDATE ngo_profiles SET status='APPROVED', approved_by=$1, approved_at=NOW() WHERE id=$2 AND status='PENDING' RETURNING *`,
      [req.user.id, req.params.id]
    );
    if (!result.rows[0]) return res.fail('NGO not found or not pending', 404);
    res.success(result.rows[0]);
  } catch (e) { next(e); }
});

// PATCH /api/admin/ngos/:id/reject
router.patch('/ngos/:id/reject', auth('admin'), async (req, res, next) => {
  try {
    const { reason } = req.body;
    if (!reason || reason.trim() === '') {
      return res.fail('Rejection reason required', 400);
    }
    const result = await db.query(
      `UPDATE ngo_profiles SET status='REJECTED', rejection_reason=$1 WHERE id=$2 AND status='PENDING' RETURNING *`,
      [reason.trim(), req.params.id]
    );
    if (!result.rows[0]) return res.fail('NGO not found or not pending', 404);
    res.success(result.rows[0]);
  } catch (e) { next(e); }
});

// GET /api/admin/ngos - list NGOs with optional status filter
router.get('/ngos', auth('admin'), async (req, res, next) => {
  try {
    const { status } = req.query;
    let query = `
      SELECT
        n.*,
        u.email,
        u.phone,
        u.name,
        w.balance,
        w.total_received,
        w.total_withdrawn
      FROM ngo_profiles n
      JOIN users u ON n.user_id = u.id
      LEFT JOIN ngo_wallets w ON w.ngo_id = n.id
      WHERE 1=1
    `;
    const params = [];

    if (status && ['PENDING', 'APPROVED', 'REJECTED'].includes(status.toUpperCase())) {
      params.push(status.toUpperCase());
      query += ` AND n.status = $${params.length}`;
    }

    query += ` ORDER BY n.created_at DESC`;

    const result = await db.query(query, params);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/admin/ngos/pending
router.get('/ngos/pending', auth('admin'), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT n.*, u.email, u.phone, u.name
      FROM ngo_profiles n
      JOIN users u ON n.user_id = u.id
      WHERE n.status = 'PENDING'
      ORDER BY n.created_at DESC
    `);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/admin/ngos/all
router.get('/ngos/all', auth('admin'), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT n.*, u.email, u.phone, u.name
      FROM ngo_profiles n
      JOIN users u ON n.user_id = u.id
      ORDER BY n.created_at DESC
    `);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/admin/campaigns
router.get('/campaigns', auth('admin'), async (req, res, next) => {
  try {
    const { status, ngo_id } = req.query;
    let query = `
      SELECT c.*, n.org_name, u.email as ngo_email
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      JOIN users u ON n.user_id = u.id
      WHERE 1=1
    `;
    const params = [];
    if (status) { params.push(status); query += ` AND c.status = $${params.length}`; }
    if (ngo_id) { params.push(ngo_id); query += ` AND c.ngo_id = $${params.length}`; }
    query += ' ORDER BY c.created_at DESC';

    const result = await db.query(query, params);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// PATCH /api/admin/campaigns/:id/status
router.patch('/campaigns/:id/status', auth('admin'), async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!['ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED'].includes(status)) {
      return res.fail('Invalid status', 400);
    }
    const result = await db.query(
      `UPDATE campaigns SET status=$1, updated_at=NOW() WHERE id=$2 RETURNING *`,
      [status, req.params.id]
    );
    if (!result.rows[0]) return res.fail('Campaign not found', 404);
    res.success(result.rows[0]);
  } catch (e) { next(e); }
});

// GET /api/admin/analytics
router.get('/analytics', auth('admin'), async (req, res, next) => {
  try {
    const { start_date, end_date } = req.query;
    const params = [];
    let dateFilter = '';
    let donationDateFilter = '';

    if (start_date && end_date) {
      params.push(start_date, end_date);
      dateFilter = `WHERE d.created_at BETWEEN $1 AND $2`;
      donationDateFilter = `AND d.created_at BETWEEN $1 AND $2`;
    }

    const [dailyDonations, topCampaigns, topNgos, categoryStats] = await Promise.all([
      db.query(`
        SELECT DATE(created_at) as date, COUNT(*) as count, SUM(amount) as total
        FROM donations ${dateFilter}
        GROUP BY DATE(created_at)
        ORDER BY date DESC LIMIT 30
      `, params),
      db.query(`
        SELECT c.title, n.org_name, c.raised_amount, c.target_amount,
               COUNT(d.id) as donation_count
        FROM campaigns c
        JOIN ngo_profiles n ON c.ngo_id = n.id
        LEFT JOIN donations d ON d.campaign_id = c.id
        GROUP BY c.id, n.id
        ORDER BY c.raised_amount DESC LIMIT 10
      `),
      db.query(`
        SELECT n.org_name, COALESCE(w.total_received, 0) as total_received,
               COALESCE(w.balance, 0) as balance,
               COUNT(DISTINCT c.id) as campaign_count,
               COUNT(a.id) FILTER (WHERE a.status='DELIVERED') as aid_delivered
        FROM ngo_profiles n
        LEFT JOIN ngo_wallets w ON w.ngo_id = n.id
        LEFT JOIN campaigns c ON c.ngo_id = n.id
        LEFT JOIN aid_requests a ON a.ngo_id = n.id
        WHERE n.status = 'APPROVED'
        GROUP BY n.id, w.id
        ORDER BY w.total_received DESC NULLS LAST LIMIT 10
      `),
      db.query(`
        SELECT c.category, COUNT(d.id) as count, COALESCE(SUM(d.amount), 0) as total
        FROM donations d
        JOIN campaigns c ON d.campaign_id = c.id
        ${start_date && end_date ? 'WHERE d.created_at BETWEEN $1 AND $2' : ''}
        GROUP BY c.category
      `, start_date && end_date ? [start_date, end_date] : [])
    ]);

    res.success({
      dailyDonations: dailyDonations.rows,
      topCampaigns: topCampaigns.rows,
      topNgos: topNgos.rows,
      categoryStats: categoryStats.rows
    });
  } catch (e) { next(e); }
});

// GET /api/admin/aid-requests
router.get('/aid-requests', auth('admin'), async (req, res, next) => {
  try {
    const { status } = req.query;
    let query = `
      SELECT a.*,
             COALESCE(c.title, 'General Request') as campaign_title,
             n.org_name,
             u.name as beneficiary_name, u.phone as beneficiary_phone,
             v.id as volunteer_id, vu.name as volunteer_name
      FROM aid_requests a
      LEFT JOIN campaigns c ON a.campaign_id = c.id
      LEFT JOIN ngo_profiles n ON a.ngo_id = n.id
      JOIN users u ON a.beneficiary_id = u.id
      LEFT JOIN volunteer_profiles v ON a.volunteer_id = v.id
      LEFT JOIN users vu ON v.user_id = vu.id
    `;
    const params = [];
    if (status) { params.push(status); query += ` WHERE a.status = $${params.length}`; }
    query += ' ORDER BY CASE a.urgency WHEN \'CRITICAL\' THEN 1 WHEN \'HIGH\' THEN 2 WHEN \'MEDIUM\' THEN 3 ELSE 4 END, a.created_at DESC';

    const result = await db.query(query, params);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// PATCH /api/admin/aid-requests/:id/assign
router.patch('/aid-requests/:id/assign', auth('admin'), async (req, res, next) => {
  const { ngo_id, status, rejection_reason } = req.body;
  const client = await db.connect();

  try {
    await client.query('BEGIN');

    if (status === 'REJECTED') {
      const result = await client.query(
        `UPDATE aid_requests SET status='REJECTED', rejection_reason=$1, updated_at=NOW()
         WHERE id=$2 AND status='PENDING' RETURNING *`,
        [rejection_reason, req.params.id]
      );
      if (!result.rows[0]) throw new Error('Request not found or already processed');
      await client.query('COMMIT');
      return res.success(result.rows[0]);
    }

    if (!ngo_id) throw new Error('ngo_id required for approval');

    const ngo = await client.query('SELECT status FROM ngo_profiles WHERE id=$1', [ngo_id]);
    if (!ngo.rows[0] || ngo.rows[0].status!== 'APPROVED') throw new Error('NGO not approved');

    const result = await client.query(
      `UPDATE aid_requests
       SET ngo_id=$1, status='APPROVED', updated_at=NOW()
       WHERE id=$2 AND status='PENDING' RETURNING *`,
      [ngo_id, req.params.id]
    );
    if (!result.rows[0]) throw new Error('Request not found or already processed');

    await client.query('COMMIT');
    res.success(result.rows[0]);
  } catch (e) {
    await client.query('ROLLBACK');
    next(e);
  } finally {
    client.release();
  }
});

// GET /api/admin/withdrawals
router.get('/withdrawals', auth('admin'), async (req, res, next) => {
  try {
    const { status } = req.query;
    let query = `
      SELECT w.*, n.org_name, u.email
      FROM withdrawal_requests w
      JOIN ngo_profiles n ON w.ngo_id = n.id
      JOIN users u ON n.user_id = u.id
      WHERE 1=1
    `;
    const params = [];
    if (status) { params.push(status); query += ` AND w.status = $${params.length}`; }
    query += ' ORDER BY w.created_at DESC';

    const result = await db.query(query, params);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// PATCH /api/admin/withdrawals/:id
router.patch('/withdrawals/:id', auth('admin'), upload.single('proof'), async (req, res, next) => {
  const { status, admin_notes, rejection_reason, transaction_ref } = req.body;
  const client = await db.connect();

  try {
    if (!['APPROVED', 'COMPLETED', 'REJECTED'].includes(status)) throw new Error('Invalid status');
    await client.query('BEGIN');

    const w = await client.query(`SELECT * FROM withdrawal_requests WHERE id = $1 FOR UPDATE`, [req.params.id]);
    if (!w.rows[0]) throw new Error('Withdrawal not found');
    const withdrawal = w.rows[0];

    if (status === 'APPROVED' && withdrawal.status!== 'PENDING') throw new Error('Can only approve PENDING');
    if (status === 'COMPLETED' && withdrawal.status!== 'APPROVED') throw new Error('Must approve before completing');
    if (status === 'COMPLETED' &&!req.file) throw new Error('Upload transfer proof to complete');
    if (status === 'REJECTED' && withdrawal.status!== 'PENDING') throw new Error('Can only reject PENDING');

    if (status === 'COMPLETED') {
      const wallet = await client.query(`SELECT balance FROM ngo_wallets WHERE ngo_id = $1 FOR UPDATE`, [withdrawal.ngo_id]);
      if (!wallet.rows[0]) throw new Error('Wallet not found');
      if (parseFloat(wallet.rows[0].balance) < parseFloat(withdrawal.amount)) {
        throw new Error('Insufficient wallet balance');
      }

      await client.query(
        `UPDATE ngo_wallets SET balance = balance - $1, total_withdrawn = total_withdrawn + $1 WHERE ngo_id = $2`,
        [withdrawal.amount, withdrawal.ngo_id]
      );
    }

    const result = await client.query(`
      UPDATE withdrawal_requests SET
        status = $1, admin_notes = $2, rejection_reason = $3,
        transfer_proof_url = $4, approved_by = $5, processed_at = NOW(),
        transaction_ref = $6
      WHERE id = $7 RETURNING *
    `, [status, admin_notes, rejection_reason, req.file?.path || null, req.user.id, transaction_ref || null, req.params.id]);

    await logAction({
      adminId: req.user.id,
      action: `WITHDRAWAL_${status}`,
      targetType: 'withdrawal',
      targetId: withdrawal.id,
      oldValue: { status: withdrawal.status },
      newValue: { status: status },
      reason: admin_notes || rejection_reason,
      req: req,
    });

    await client.query('COMMIT');
    res.success(result.rows[0]);
  } catch (e) {
    await client.query('ROLLBACK');
    next(e);
  } finally {
    client.release();
  }
});

// POST /api/reports
router.post('/reports', auth(), async (req, res, next) => {
  try {
    const schema = Joi.object({
      target_type: Joi.string().valid('user', 'campaign', 'request').required(),
      target_id: Joi.number().integer().required(),
      reason: Joi.string().valid('SPAM', 'SCAM', 'INAPPROPRIATE', 'FAKE', 'HARASSMENT', 'OTHER').required(),
      description: Joi.string().max(500).allow('', null),
    });
    const { error, value } = schema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400);

    const existing = await db.query(
      'SELECT id FROM reports WHERE reporter_id=$1 AND target_type=$2 AND target_id=$3 AND status=\'PENDING\'',
      [req.user.id, value.target_type, value.target_id]
    );
    if (existing.rows[0]) return res.fail('You already reported this', 400);

    const result = await db.query(
      `INSERT INTO reports (reporter_id, target_type, target_id, reason, description)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [req.user.id, value.target_type, value.target_id, value.reason, value.description]
    );
    res.success(result.rows[0], 201);
  } catch (e) { next(e); }
});

// GET /api/admin/reports
router.get('/reports', auth('admin'), async (req, res, next) => {
  try {
    const { status = 'PENDING' } = req.query;
    const result = await db.query(`
      SELECT r.*,
             u.name as reporter_name, u.email as reporter_email,
             CASE
               WHEN r.target_type = 'user' THEN (SELECT name FROM users WHERE id = r.target_id)
               WHEN r.target_type = 'campaign' THEN (SELECT title FROM campaigns WHERE id = r.target_id)
               WHEN r.target_type = 'request' THEN (SELECT 'Request #' || id FROM aid_requests WHERE id = r.target_id)
             END as target_name
      FROM reports r
      LEFT JOIN users u ON r.reporter_id = u.id
      WHERE r.status = $1
      ORDER BY r.created_at DESC
      LIMIT 100
    `, [status]);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// PATCH /api/admin/reports/:id
router.patch('/reports/:id', auth('admin'), async (req, res, next) => {
  try {
    const schema = Joi.object({
      status: Joi.string().valid('REVIEWED', 'RESOLVED', 'DISMISSED').required(),
      admin_notes: Joi.string().max(500).allow('', null),
    });
    const { error, value } = schema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400);

    const result = await db.query(
      `UPDATE reports SET status=$1, admin_notes=$2, reviewed_at=NOW(), reviewed_by=$3
       WHERE id=$4 RETURNING *`,
      [value.status, value.admin_notes, req.user.id, req.params.id]
    );
    if (!result.rows[0]) return res.fail('Report not found', 404);
    res.success(result.rows[0]);
  } catch (e) { next(e); }
});

// GET /api/admin/audit-logs
router.get('/audit-logs', auth('admin'), async (req, res, next) => {
  try {
    const { action, target_type, limit = 100 } = req.query;
    let query = `
      SELECT a.*,
             u.name as admin_name, u.email as admin_email,
             CASE
               WHEN a.target_type = 'ngo' THEN (SELECT org_name FROM ngo_profiles WHERE id = a.target_id)
               WHEN a.target_type = 'campaign' THEN (SELECT title FROM campaigns WHERE id = a.target_id)
               WHEN a.target_type = 'user' THEN (SELECT name FROM users WHERE id = a.target_id)
             END as target_name
      FROM audit_logs a
      LEFT JOIN users u ON a.admin_id = u.id
      WHERE 1=1
    `;
    const params = [];
    if (action) { params.push(action); query += ` AND a.action = $${params.length}`; }
    if (target_type) { params.push(target_type); query += ` AND a.target_type = $${params.length}`; }
    query += ` ORDER BY a.created_at DESC LIMIT $${params.length + 1}`;
    params.push(limit);

    const result = await db.query(query, params);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// PATCH /api/admin/ngos/:id/status
router.patch('/ngos/:id/status', auth('admin'), async (req, res, next) => {
  const { status, rejection_reason } = req.body;
  const client = await db.connect();

  try {
    await client.query('BEGIN');

    const oldNgo = await client.query('SELECT * FROM ngo_profiles WHERE id = $1', [req.params.id]);
    if (!oldNgo.rows[0]) throw new Error('NGO not found');

    const result = await client.query(
      `UPDATE ngo_profiles SET status = $1, rejection_reason = $2, updated_at = NOW()
       WHERE id = $3 RETURNING *`,
      [status, rejection_reason, req.params.id]
    );

    await logAction({
      adminId: req.user.id,
      action: status === 'APPROVED'? 'APPROVE_NGO' : 'REJECT_NGO',
      targetType: 'ngo',
      targetId: req.params.id,
      oldValue: { status: oldNgo.rows[0].status },
      newValue: { status: status, rejection_reason: rejection_reason },
      reason: rejection_reason,
      req: req,
    });

    await client.query('COMMIT');
    res.success(result.rows[0]);
  } catch (e) {
    await client.query('ROLLBACK');
    next(e);
  } finally {
    client.release();
  }
});

// GET /api/aids/delivered
router.get('/delivered', auth('admin'), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT ar.id, ar.delivery_proof_url, ar.delivered_at, ar.delivery_notes,
             du.name as delivered_by_name, bu.name as victim_name, n.org_name
      FROM aid_requests ar
      JOIN users du ON ar.delivered_by = du.id
      JOIN users bu ON ar.beneficiary_id = bu.id
      JOIN ngo_profiles n ON ar.ngo_id = n.id
      WHERE ar.status = 'DELIVERED'
      ORDER BY ar.delivered_at DESC
    `);
    res.success(result.rows);
  } catch (e) { next(e); }
});

module.exports = router;