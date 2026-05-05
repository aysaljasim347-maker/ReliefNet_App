const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const Joi = require('joi');

const withdrawalSchema = Joi.object({
  amount: Joi.number().positive().min(100).required(), // Min 100 PKR
  bank_name: Joi.string().min(3).required(),
  account_title: Joi.string().min(3).required(),
  account_number: Joi.string().min(8).required(),
  iban: Joi.string().length(24).required(),
});

// POST /api/ngos/withdrawals - Request withdrawal
router.post('/withdrawals', auth('ngo'), async (req, res, next) => {
  const { error, value } = withdrawalSchema.validate(req.body);
  if (error) return res.status(400).json({ error: error.details[0].message });

  const { amount, bank_name, account_title, account_number, iban } = value;
  const client = await db.pool.connect();

  try {
    await client.query('BEGIN');
    const ngo = await client.query('SELECT id, status FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) throw new Error('NGO profile not found');
    if (ngo.rows[0].status!== 'APPROVED') throw new Error('NGO not approved yet');

    // Lock wallet row to prevent race condition
    const wallet = await client.query('SELECT balance FROM ngo_wallets WHERE ngo_id = $1 FOR UPDATE', [ngo.rows[0].id]);
    if (!wallet.rows[0]) throw new Error('Wallet not found');
    if (parseFloat(wallet.rows[0].balance) < amount) throw new Error('Insufficient balance');

    // Create withdrawal request
    const withdrawal = await client.query(
      `INSERT INTO withdrawal_requests (ngo_id, amount, bank_name, account_title, account_number, iban, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'PENDING') RETURNING *`,
      [ngo.rows[0].id, amount, bank_name, account_title, account_number, iban]
    );

    // Hold amount in wallet - subtract from balance
    await client.query('UPDATE ngo_wallets SET balance = balance - $1 WHERE ngo_id = $2', [amount, ngo.rows[0].id]);

    await client.query('COMMIT');
    res.json({ data: withdrawal.rows[0], message: 'Withdrawal request submitted' });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(400).json({ error: e.message });
  } finally {
    client.release();
  }
});

// GET /api/ngos/withdrawals - My withdrawal history
router.get('/withdrawals', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.json({ data: [] });

    const result = await db.query(
      'SELECT * FROM withdrawal_requests WHERE ngo_id = $1 ORDER BY created_at DESC LIMIT 50',
      [ngo.rows[0].id]
    );
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// GET /api/ngos/wallet - Current wallet balance
router.get('/wallet', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.json({ data: { balance: 0, total_received: 0, total_withdrawn: 0 } });

    const wallet = await db.query(
      'SELECT balance, total_received, total_withdrawn FROM ngo_wallets WHERE ngo_id = $1',
      [ngo.rows[0].id]
    );
    res.json({ data: wallet.rows[0] || { balance: 0, total_received: 0, total_withdrawn: 0 } });
  } catch (e) { next(e); }
});

module.exports = router;