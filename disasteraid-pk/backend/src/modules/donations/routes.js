const express = require('express');
const router = express.Router();
const db = require('../../config/db'); // db is now the pool
const auth = require('../../middleware/auth');
const Joi = require('joi');


const donationSchema = Joi.object({
  campaign_id: Joi.number().required(),
  amount: Joi.number().min(100).required(),
  payment_method: Joi.string().uppercase().valid('MOCK', 'STRIPE', 'JAZZCASH', 'EASYPAISA').required(),
  transaction_id: Joi.string().required(),
  // Optional - only used if user wants to donate anonymously or as guest
  donor_name: Joi.string().allow('', null),
  donor_email: Joi.string().email().allow('', null),
  is_anonymous: Joi.boolean().default(false)
});

// POST /api/donations - Create donation + update wallet
router.post('/', auth(), async (req, res, next) => { // Changed from auth('donor') to auth() - any logged user can donate
  const { error, value } = donationSchema.validate(req.body);
  if (error) return res.status(400).json({ error: error.details[0].message });

  const { campaign_id, amount, payment_method, donor_name, donor_email, transaction_id ,is_anonymous} = value;
  const client = await db.connect(); // Now works

  try {
    await client.query('BEGIN');

        // Get logged-in user info
    const userRes = await client.query('SELECT name, email FROM users WHERE id = $1', [req.user.id]);
    const user = userRes.rows[0];

    // Use provided name/email if anonymous, else use logged-in user's data
    const finalDonorName = is_anonymous && donor_name? donor_name : user.name;
    const finalDonorEmail = is_anonymous && donor_email? donor_email : user.email;


    // 1. Get campaign + NGO + check status
    const campaign = await client.query(`
      SELECT c.*, n.id as ngo_profile_id, n.status as ngo_status, n.org_name, u.email as ngo_email
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      JOIN users u ON n.user_id = u.id
      WHERE c.id = $1
    `, [campaign_id]);

    if (!campaign.rows[0]) throw new Error('Campaign not found');
    if (campaign.rows[0].status!== 'ACTIVE') throw new Error('Campaign not active');
    if (campaign.rows[0].ngo_status!== 'APPROVED') throw new Error('NGO not verified');
    if (campaign.rows[0].end_date && new Date(campaign.rows[0].end_date) < new Date()) {
      throw new Error('Campaign has ended');
    }


        const donation = await client.query(
      `INSERT INTO donations (user_id, campaign_id, amount, payment_method, status, transaction_ref, donor_name, donor_email, is_anonymous)
       VALUES ($1, $2, $3, $4, 'completed', $5, $6, $7, $8) RETURNING *`,
      [req.user.id, campaign_id, amount, payment_method, transaction_id, finalDonorName, finalDonorEmail, is_anonymous]
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
// Don't spread the whole row - pick fields
console.log('Donation row:', JSON.stringify(donation.rows[0]));
res.json({
  success: true,
  data: {
    id: donation.rows[0].id,
    campaign_id: donation.rows[0].campaign_id,
    amount: donation.rows[0].amount,
    payment_method: donation.rows[0].payment_method,
    status: donation.rows[0].status,
    created_at: donation.rows[0].created_at,
    donor_name: donation.rows[0].donor_name,
    donor_email: donation.rows[0].donor_email,
    campaign: {
      title: updatedCampaign.rows[0].title,
      raised_amount: updatedCampaign.rows[0].raised_amount,
      target_amount: updatedCampaign.rows[0].target_amount,
      status: updatedCampaign.rows[0].status
    }
  }
});

    // res.json({
    //   success: true,
    //   data: {
    //   ...donation.rows[0],
    //     campaign: {
    //       title: updatedCampaign.rows[0].title,
    //       raised_amount: updatedCampaign.rows[0].raised_amount,
    //       target_amount: updatedCampaign.rows[0].target_amount,
    //       status: updatedCampaign.rows[0].status
    //     }
    //   }
    // });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(400).json({ error: e.message });
  } finally {
    client.release();
  }
});

// GET /api/donations/my - Donor's donation history
router.get('/my', auth(), async (req, res, next) => {
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
      SELECT d.*, c.title, c.description, n.org_name, u.email as ngo_email,
             du.name as donor_name, du.email as donor_email
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      JOIN ngo_profiles n ON c.ngo_id = n.id
      JOIN users du ON d.user_id = du.id
      JOIN users u ON n.user_id = u.id
      WHERE d.id = $1 AND (d.user_id = $2 OR $3 = 'admin')
    `, [req.params.id, req.user.id, req.user.role]);

    if (!result.rows[0]) return res.status(404).json({ error: 'Receipt not found' });
    res.json({ data: result.rows[0] });
  } catch (e) { next(e); }
});

module.exports = router;