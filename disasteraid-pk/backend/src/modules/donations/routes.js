const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const Joi = require('joi');

const donationSchema = Joi.object({
  campaign_id: Joi.number().integer().required(),
  amount: Joi.number().positive().min(10).max(1000000).required(),
  payment_method: Joi.string().valid('MOCK', 'STRIPE', 'JAZZCASH', 'EASYPAISA').default('MOCK'),
});

// POST /api/donations - Create donation + update wallet
router.post('/', auth('donor'), async (req, res, next) => {
  const { error, value } = donationSchema.validate(req.body);
  if (error) return res.status(400).json({ error: error.details[0].message });

  const { campaign_id, amount, payment_method } = value;
  const client = await db.pool.connect();

  try {
    await client.query('BEGIN');

    // 1. Get campaign + NGO + check status
    const campaign = await client.query(`
      SELECT c.*, n.id as ngo_profile_id, n.status as ngo_status
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      WHERE c.id = $1
    `, [campaign_id]);

    if (!campaign.rows[0]) throw new Error('Campaign not found');
    if (campaign.rows[0].status!== 'ACTIVE') throw new Error('Campaign not active');
    if (campaign.rows[0].ngo_status!== 'APPROVED') throw new Error('NGO not verified');
    if (campaign.rows[0].end_date && new Date(campaign.rows[0].end_date) < new Date()) {
      throw new Error('Campaign has ended');
    }

    // 2. Create donation record
    const donation = await client.query(
      `INSERT INTO donations (user_id, campaign_id, amount, payment_method, status, transaction_ref)
       VALUES ($1, $2, $3, $4, 'completed', $5) RETURNING *`,
      [req.user.id, campaign_id, amount, payment_method, `TXN_${Date.now()}`]
    );

    // 3. Update campaign raised_amount + check if target hit
    const updatedCampaign = await client.query(
      `UPDATE campaigns
       SET raised_amount = raised_amount + $1,
           status = CASE WHEN raised_amount + $1 >= target_amount THEN 'COMPLETED' ELSE status END
       WHERE id = $2
       RETURNING *`,
      [amount, campaign_id]
    );

    // 4. Update NGO wallet - create if doesn't exist
    await client.query(`
      INSERT INTO ngo_wallets (ngo_id, balance, total_received)
      VALUES ($1, $2, $2)
      ON CONFLICT (ngo_id) DO UPDATE SET
        balance = ngo_wallets.balance + $2,
        total_received = ngo_wallets.total_received + $2,
        updated_at = NOW()
    `, [campaign.rows[0].ngo_profile_id, amount]);

    // 5. Log wallet transaction
    await client.query(
      `INSERT INTO wallet_transactions (ngo_id, amount, type, donation_id, description)
       VALUES ($1, $2, 'credit', $3, $4)`,
      [campaign.rows[0].ngo_profile_id, amount, donation.rows[0].id, `Donation for: ${campaign.rows[0].title}`]
    );

    await client.query('COMMIT');
    res.json({
      success: true,
      data: {
       ...donation.rows[0],
        campaign: {
          title: updatedCampaign.rows[0].title,
          raised_amount: updatedCampaign.rows[0].raised_amount,
          target_amount: updatedCampaign.rows[0].target_amount,
          status: updatedCampaign.rows[0].status
        }
      }
    });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(400).json({ error: e.message });
  } finally {
    client.release();
  }
});

// GET /api/donations/my - Donor's donation history with campaign details
router.get('/my', auth('donor'), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT d.*, c.title as campaign_title, c.image_url, c.status as campaign_status,
             n.org_name, n.id as ngo_id
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      JOIN ngo_profiles n ON c.ngo_id = n.id
      WHERE d.user_id = $1
      ORDER BY d.created_at DESC
      LIMIT 100
    `, [req.user.id]);
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// GET /api/donations/receipt/:id - Single donation receipt
router.get('/receipt/:id', auth(), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT d.*, c.title, c.description, n.org_name, n.email as ngo_email,
             u.name as donor_name, u.email as donor_email
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      JOIN ngo_profiles n ON c.ngo_id = n.id
      JOIN users u ON d.user_id = u.id
      WHERE d.id = $1 AND (d.user_id = $2 OR $3 = 'admin')
    `, [req.params.id, req.user.id, req.user.role]);

    if (!result.rows[0]) return res.status(404).json({ error: 'Receipt not found' });
    res.json({ data: result.rows[0] });
  } catch (e) { next(e); }
});

module.exports = router;