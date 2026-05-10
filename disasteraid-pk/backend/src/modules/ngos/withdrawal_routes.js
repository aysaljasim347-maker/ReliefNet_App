const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const Joi = require('joi');
const upload = require('../../utils/upload');
const { logAction } = require('../../utils/audit');

const withdrawalSchema = Joi.object({
  amount: Joi.number().positive().min(100).required(),
  bank_name: Joi.string().min(3).required(),
  account_title: Joi.string().min(3).required(),
  account_number: Joi.string().min(8).required(),
  iban: Joi.string().length(24).required(),
});

// POST /api/ngos/withdrawals - Request withdrawal
router.post('/withdrawals', auth('ngo'), async (req, res, next) => {
  const { error, value } = withdrawalSchema.validate(req.body);
  if (error) return res.fail(error.details[0].message, 400);

  const { amount, bank_name, account_title, account_number, iban } = value;
  const client = await db.connect();

  try {
    await client.query('BEGIN');
    const ngo = await client.query('SELECT id, status FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) throw new Error('NGO profile not found');
    if (ngo.rows[0].status!== 'APPROVED') throw new Error('NGO not approved yet');

    const wallet = await client.query('SELECT balance FROM ngo_wallets WHERE ngo_id = $1 FOR UPDATE', [ngo.rows[0].id]);
    if (!wallet.rows[0]) throw new Error('Wallet not found');
    if (parseFloat(wallet.rows[0].balance) < amount) throw new Error('Insufficient balance');

    const pending = await client.query(
      `SELECT id FROM withdrawal_requests WHERE ngo_id = $1 AND status = 'PENDING'`,
      [ngo.rows[0].id]
    );
    if (pending.rows[0]) throw new Error('You already have a pending withdrawal');

    const withdrawal = await client.query(
      `INSERT INTO withdrawal_requests (ngo_id, amount, bank_name, account_title, account_number, iban, requested_by, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'PENDING') RETURNING *`,
      [ngo.rows[0].id, amount, bank_name, account_title, account_number, iban, req.user.id]
    );

    await client.query('COMMIT');
    res.success(withdrawal.rows[0], 201);
  } catch (e) {
    await client.query('ROLLBACK');
    next(e);
  } finally {
    client.release();
  }
});

// GET /api/ngos/withdrawals - My withdrawal history
router.get('/withdrawals', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.success([]);

    const result = await db.query(
      `SELECT *, created_at AS requested_at
       FROM withdrawal_requests
       WHERE ngo_id = $1
       ORDER BY created_at DESC
       LIMIT 50`,
      [ngo.rows[0].id]
    );
    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/ngos/wallet - Current wallet balance
router.get('/wallet', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.success({ balance: 0, total_received: 0, total_withdrawn: 0 });

    const wallet = await db.query(
      'SELECT balance, total_received, total_withdrawn FROM ngo_wallets WHERE ngo_id = $1',
      [ngo.rows[0].id]
    );
    res.success(wallet.rows[0] || { balance: 0, total_received: 0, total_withdrawn: 0 });
  } catch (e) { next(e); }
});

// GET /api/admin/withdrawals - Admin sees all requests
router.get('/admin/withdrawals', auth('admin'), async (req, res, next) => {
  try {
    const { status = 'PENDING' } = req.query;
    const result = await db.query(`
      SELECT
        w.*,
        w.created_at AS requested_at,
        n.org_name,
        u.email AS requester_email
      FROM withdrawal_requests w
      JOIN ngo_profiles n ON w.ngo_id = n.id
      JOIN users u ON n.user_id = u.id
      WHERE w.status = $1
      ORDER BY requested_at ASC
    `, [status]);

    res.success(result.rows);
  } catch (e) { next(e); }
});

// PATCH /api/admin/withdrawals/:id - Admin approves/rejects/completes
router.patch('/admin/withdrawals/:id', auth('admin'), upload.single('proof'), async (req, res, next) => {
  const { status, admin_notes, rejection_reason } = req.body;
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

    if (status === 'COMPLETED') {
      const wallet = await client.query(`SELECT balance FROM ngo_wallets WHERE ngo_id = $1 FOR UPDATE`, [withdrawal.ngo_id]);
      if (parseFloat(wallet.rows[0].balance) < parseFloat(withdrawal.amount)) throw new Error('Insufficient wallet balance');

      await client.query(`UPDATE ngo_wallets SET balance = balance - $1, total_withdrawn = total_withdrawn + $1 WHERE ngo_id = $2`,
        [withdrawal.amount, withdrawal.ngo_id]);
    }

    const result = await client.query(`
      UPDATE withdrawal_requests SET
        status = $1, admin_notes = $2, rejection_reason = $3,
        transfer_proof_url = $4, approved_by = $5, processed_at = NOW()
      WHERE id = $6 RETURNING *
    `, [status, admin_notes, rejection_reason, req.file?.path || null, req.user.id, req.params.id]);

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

module.exports = router;