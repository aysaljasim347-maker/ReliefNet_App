const express = require('express');
const router = express.Router();
const db = require('../../config/db'); // db is now the pool
const auth = require('../../middleware/auth');
const Joi = require('joi');
const { v4: uuidv4 } = require('uuid'); // add

const { generateDonationReceipt } = require('../../utils/pdf-receipts');
const { sendReceiptEmail } = require('../../utils/mailer');
const path = require('path')
const { createNotification } = require('../../utils/notify');

const upload = require('../../utils/upload'); // Cloudinary from Phase 0.3




const donationSchema = Joi.object({
  campaign_id: Joi.number().required(),
  amount: Joi.number().min(100).required(),
  payment_method: Joi.string().uppercase().valid('MOCK', 'STRIPE', 'JAZZCASH', 'EASYPAISA').default('MOCK'),
  transaction_id: Joi.string().allow('', null), // FIXED: optional now
  donor_name: Joi.string().allow('', null),
  donor_email: Joi.string().email().allow('', null),
  is_anonymous: Joi.boolean().default(false)
});


router.post('/', auth(), async (req, res, next) => {
  const { error, value } = donationSchema.validate(req.body);
  if (error) return res.status(400).json({ error: error.details[0].message });

  let { campaign_id, amount, payment_method, donor_name, donor_email, transaction_id, is_anonymous } = value;

  // FIXED: Auto-generate transaction_id if missing or MOCK
  if (!transaction_id || transaction_id.startsWith('MOCK')) {
    transaction_id = `${payment_method}_${uuidv4()}`;
  }

  const client = await db.connect();

  try {
    await client.query('BEGIN');

    const userRes = await client.query('SELECT name, email FROM users WHERE id = $1', [req.user.id]);
    const user = userRes.rows[0];

    const finalDonorName = is_anonymous && donor_name? donor_name : user.name;
    const finalDonorEmail = is_anonymous && donor_email? donor_email : user.email;

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

    // FIXED: Check for duplicate transaction_id to prevent double-spend
    const existing = await client.query('SELECT id FROM donations WHERE transaction_ref = $1', [transaction_id]);
    if (existing.rows[0]) throw new Error('Duplicate transaction');

    const donation = await client.query(
      `INSERT INTO donations (user_id, campaign_id, amount, payment_method, status, transaction_ref, donor_name, donor_email, is_anonymous)
       VALUES ($1, $2, $3, $4, 'completed', $5, $6, $7, $8) RETURNING *`,
      [req.user.id, campaign_id, amount, payment_method, transaction_id, finalDonorName, finalDonorEmail, is_anonymous]
    );

    const updatedCampaign = await client.query(
      `UPDATE campaigns
       SET raised_amount = raised_amount + $1,
           status = CASE WHEN raised_amount + $1 >= target_amount THEN 'COMPLETED' ELSE status END
       WHERE id = $2
       RETURNING *`,
      [amount, campaign_id]
    );

    await client.query(`
      INSERT INTO ngo_wallets (ngo_id, balance, total_received)
      VALUES ($1, $2, $2)
      ON CONFLICT (ngo_id) DO UPDATE SET
        balance = ngo_wallets.balance + $2,
        total_received = ngo_wallets.total_received + $2,
        updated_at = NOW()
    `, [campaign.rows[0].ngo_profile_id, amount]);

    await client.query(
      `INSERT INTO wallet_transactions (ngo_id, amount, type, donation_id, description)
       VALUES ($1, $2, 'credit', $3, $4)`,
      [campaign.rows[0].ngo_profile_id, amount, donation.rows[0].id, `Donation for: ${campaign.rows[0].title}`]
    );

    await client.query('COMMIT');

    res.json({
      success: true,
      data: {
        id: donation.rows[0].id,
        campaign_id: donation.rows[0].campaign_id,
        amount: donation.rows[0].amount,
        payment_method: donation.rows[0].payment_method,
        transaction_ref: donation.rows[0].transaction_ref, // FIXED: return it
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
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(400).json({ error: e.message });
  } finally {
    client.release();
  }
});
// GET /api/donations/my - Donor's donation history
// GET /api/donations/my - Donor's donation history
router.get('/my', auth(), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT d.id, d.amount, d.status, d.created_at, d.verified_at, d.receipt_url,
             d.transaction_ref, d.payment_method,
             c.title as campaign_title, c.image_url, c.status as campaign_status,
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





// POST /api/donations/manual - Donor creates manual donation
router.post('/manual', auth('donor'), upload.single('proof'), async (req, res, next) => {
  const client = await db.connect();
  try {
    const schema = Joi.object({
      campaign_id: Joi.number().integer().required(),
      amount: Joi.number().positive().max(10000000).required(),
      donor_note: Joi.string().max(200).allow('', null),
    });
    const { error, value } = schema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });
    if (!req.file) return res.status(400).json({ error: 'Payment proof image required' });

    await client.query('BEGIN');

    // Get NGO bank details for this campaign
    const campaign = await client.query(`
      SELECT c.id, c.ngo_id, n.org_name, n.bank_name, n.bank_account_title, n.bank_account_number, n.bank_iban
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      WHERE c.id = $1 AND c.status = 'ACTIVE'
    `, [value.campaign_id]);

    if (!campaign.rows[0]) throw new Error('Campaign not found or inactive');
    if (!campaign.rows[0].bank_iban) throw new Error('NGO has not added bank details yet');

    // Generate unique bank reference
    const bankRef = `DON-${Date.now().toString().slice(-8)}`;

const result = await client.query(`
  INSERT INTO donations (
    user_id, campaign_id, amount, payment_method, status,
    bank_reference, proof_of_payment_url, donor_note
  ) VALUES ($1, $2, $3, 'BANK_TRANSFER', 'PENDING', $4, $5, $6)
  RETURNING *
`, [req.user.id, value.campaign_id, value.amount, bankRef, req.file.path, value.donor_note]);
    await client.query('COMMIT');
    res.json({
      data: result.rows[0],
      bank_details: {
        bank_name: campaign.rows[0].bank_name,
        account_title: campaign.rows[0].bank_account_title,
        account_number: campaign.rows[0].bank_account_number,
        iban: campaign.rows[0].bank_iban,
        reference: bankRef,
        amount: value.amount,
      }
    });
  } catch (e) {
    await client.query('ROLLBACK');
    next(e);
  } finally {
    client.release();
  }
});

// GET /api/donations/ngo - NGO sees their pending donations
router.get('/ngo', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.status(403).json({ error: 'NGO profile not found' });

    const result = await db.query(`
      SELECT d.*, c.title as campaign_title, u.name as donor_name, u.email as donor_email
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      JOIN users u ON d.donor_id = u.id
      WHERE c.ngo_id = $1 AND d.payment_method = 'BANK_TRANSFER'
      ORDER BY d.created_at DESC LIMIT 100
    `, [ngo.rows[0].id]);
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// PATCH /api/admin/donations/:id/verify - Admin approves/rejects
// PATCH /api/admin/donations/:id/verify - Admin approves/rejects + generates receipt
router.patch('/admin/donations/:id/verify', auth('admin'), async (req, res, next) => {
  const { status, rejection_reason } = req.body;
  const client = await db.connect();

  try {
    if (!['VERIFIED', 'REJECTED'].includes(status)) throw new Error('Invalid status');

    await client.query('BEGIN');

    // 1. Get donation with full details
    const donationQuery = await client.query(`
      SELECT d.*, c.title as campaign_title, c.ngo_id, n.org_name, n.id as ngo_profile_id,
             u.name as donor_name, u.email as donor_email
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      JOIN ngo_profiles n ON c.ngo_id = n.id
      JOIN users u ON d.donor_id = u.id
      WHERE d.id = $1 AND d.status = 'PENDING'
      FOR UPDATE
    `, [req.params.id]);

    if (!donationQuery.rows[0]) throw new Error('Donation not found or already processed');
    const donation = donationQuery.rows[0];

    // 2. Update donation status
    const result = await client.query(`
      UPDATE donations
      SET status = $1, verified_by = $2, verified_at = NOW(), rejection_reason = $3
      WHERE id = $4
      RETURNING *
    `, [status, req.user.id, rejection_reason || null, req.params.id]);

    let receiptUrl = null;

    // 3. If VERIFIED: add to NGO wallet + generate receipt
    if (status === 'VERIFIED') {
      // Add to wallet
      await client.query(`
        INSERT INTO ngo_wallets (ngo_id, balance, total_received)
        VALUES ($1, $2, $2)
        ON CONFLICT (ngo_id) DO UPDATE SET
          balance = ngo_wallets.balance + $2,
          total_received = ngo_wallets.total_received + $2,
          updated_at = NOW()
      `, [donation.ngo_profile_id, donation.amount]);

      // Update campaign raised amount
      await client.query(`
        UPDATE campaigns
        SET raised_amount = raised_amount + $1,
            status = CASE WHEN raised_amount + $1 >= target_amount THEN 'COMPLETED' ELSE status END,
            updated_at = NOW()
        WHERE id = $2
      `, [donation.amount, donation.campaign_id]);

      // Generate PDF receipt
      const fullPath = await generateDonationReceipt({
       ...donation,
        verified_at: new Date(),
        payment_method: donation.payment_method || 'BANK_TRANSFER',
        transaction_id: donation.bank_reference || donation.transaction_ref
      });

      receiptUrl = fullPath;

      // Save receipt URL
      await client.query(
        'UPDATE donations SET receipt_url = $1, receipt_sent_at = NOW() WHERE id = $2',
        [receiptUrl, req.params.id]
      );

      // Email receipt if donor has email
      if (donation.donor_email) {
        try {
          const absolutePath = path.join(__dirname, '../../', receiptUrl);
          await sendReceiptEmail(donation.donor_email, absolutePath, donation);
        } catch (mailErr) {
          console.error('Failed to email receipt:', mailErr.message);
          // Don't fail the whole request if email fails
        }
      }
    }

    await client.query('COMMIT');

    // After admin verifies donation, inside PATCH /:id/verify
await createNotification(
  donation.donor_id,
  'Donation Verified',
  `Your PKR ${donation.amount} donation to ${campaign.title} is verified.`,
  'donation_verified',
  { donation_id: donation.id, campaign_id: donation.campaign_id }
);
    res.json({
      data: result.rows[0],
      receipt_url: receiptUrl,
      message: status === 'VERIFIED'? 'Donation verified & receipt sent' : 'Donation rejected'
    });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(400).json({ error: e.message });
  } finally {
    client.release();
  }
});



module.exports = router;