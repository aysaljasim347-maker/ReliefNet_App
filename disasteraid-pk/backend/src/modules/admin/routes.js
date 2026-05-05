const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');

// GET /api/admin/stats - Dashboard stats
router.get('/stats', auth('admin'), async (req, res, next) => {
  try {
    const [users, ngos, campaigns, donations] = await Promise.all([
      db.query(`SELECT COUNT(*) as total,
        COUNT(*) FILTER (WHERE role='donor') as donors,
        COUNT(*) FILTER (WHERE role='ngo') as ngos,
        COUNT(*) FILTER (WHERE role='volunteer') as volunteers,
        COUNT(*) FILTER (WHERE role='beneficiary') as beneficiaries
        FROM users`),
      db.query(`SELECT
        COUNT(*) FILTER (WHERE status='PENDING') as pending,
        COUNT(*) FILTER (WHERE status='APPROVED') as approved,
        COUNT(*) FILTER (WHERE status='REJECTED') as rejected
        FROM ngo_profiles`),
      db.query(`SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status='ACTIVE') as active,
        COALESCE(SUM(target_amount), 0) as total_target,
        COALESCE(SUM(raised_amount), 0) as total_raised
        FROM campaigns`),
      db.query(`SELECT
        COUNT(*) as total_donations,
        COALESCE(SUM(amount), 0) as total_amount
        FROM donations WHERE status='completed'`)
    ]);

    res.json({
      data: {
        users: users.rows[0],
        ngos: ngos.rows[0],
        campaigns: campaigns.rows[0],
        donations: donations.rows[0]
      }
    });
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
    res.json({ data: result.rows });
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
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// POST /api/admin/ngos/:id/approve
router.post('/ngos/:id/approve', auth('admin'), async (req, res, next) => {
  try {
    const result = await db.query(
      `UPDATE ngo_profiles SET status='APPROVED', approved_by=$1, approved_at=NOW() WHERE id=$2 RETURNING *`,
      [req.user.id, req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'NGO not found' });
    res.json({ success: true, data: result.rows[0] });
  } catch (e) { next(e); }
});

// POST /api/admin/ngos/:id/reject
router.post('/ngos/:id/reject', auth('admin'), async (req, res, next) => {
  try {
    const { reason } = req.body;
    const result = await db.query(
      `UPDATE ngo_profiles SET status='REJECTED', rejection_reason=$1 WHERE id=$2 RETURNING *`,
      [reason || 'Not specified', req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'NGO not found' });
    res.json({ success: true, data: result.rows[0] });
  } catch (e) { next(e); }
});

// GET /api/admin/campaigns - All campaigns with filters
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
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// PATCH /api/admin/campaigns/:id/status - Pause/Resume/Complete
router.patch('/campaigns/:id/status', auth('admin'), async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!['ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }
    const result = await db.query(
      `UPDATE campaigns SET status=$1, updated_at=NOW() WHERE id=$2 RETURNING *`,
      [status, req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Campaign not found' });
    res.json({ success: true, data: result.rows[0] });
  } catch (e) { next(e); }
});

// GET /api/admin/analytics - Advanced stats
router.get('/analytics', auth('admin'), async (req, res, next) => {
  try {
    const { start_date, end_date } = req.query;
    const dateFilter = start_date && end_date? `WHERE d.created_at BETWEEN '${start_date}' AND '${end_date}'` : '';

    const [dailyDonations, topCampaigns, topNgos, categoryStats] = await Promise.all([
      db.query(`
        SELECT DATE(created_at) as date, COUNT(*) as count, SUM(amount) as total
        FROM donations ${dateFilter}
        GROUP BY DATE(created_at)
        ORDER BY date DESC LIMIT 30
      `),
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
        ${dateFilter}
        GROUP BY c.category
      `)
    ]);

    res.json({
      data: {
        dailyDonations: dailyDonations.rows,
        topCampaigns: topCampaigns.rows,
        topNgos: topNgos.rows,
        categoryStats: categoryStats.rows
      }
    });
  } catch (e) { next(e); }
});

// GET /api/admin/withdrawals - All withdrawal requests
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
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// PATCH /api/admin/withdrawals/:id - Approve/Reject withdrawal
router.patch('/withdrawals/:id', auth('admin'), async (req, res, next) => {
  const { status, rejection_reason, transaction_ref } = req.body;
  const client = await db.pool.connect();

  try {
    await client.query('BEGIN');
    const withdrawal = await client.query('SELECT * FROM withdrawal_requests WHERE id = $1 FOR UPDATE', [req.params.id]);
    if (!withdrawal.rows[0]) throw new Error('Withdrawal not found');
    if (withdrawal.rows[0].status!== 'PENDING') throw new Error('Already processed');

    if (status === 'APPROVED') {
      await client.query(
        `UPDATE withdrawal_requests SET status='APPROVED', approved_by=$1, transaction_ref=$2, processed_at=NOW() WHERE id=$3`,
        [req.user.id, transaction_ref || `TXN_${Date.now()}`, req.params.id]
      );
      await client.query(
        'UPDATE ngo_wallets SET total_withdrawn = total_withdrawn + $1 WHERE ngo_id = $2',
        [withdrawal.rows[0].amount, withdrawal.rows[0].ngo_id]
      );
    } else if (status === 'REJECTED') {
      await client.query(
        `UPDATE withdrawal_requests SET status='REJECTED', rejection_reason=$1, processed_at=NOW() WHERE id=$2`,
        [rejection_reason || 'Not specified', req.params.id]
      );
      await client.query(
        'UPDATE ngo_wallets SET balance = balance + $1 WHERE ngo_id = $2',
        [withdrawal.rows[0].amount, withdrawal.rows[0].ngo_id]
      );
    } else {
      throw new Error('Invalid status');
    }

    await client.query('COMMIT');
    res.json({ success: true });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(400).json({ error: e.message });
  } finally {
    client.release();
  }
});

module.exports = router;