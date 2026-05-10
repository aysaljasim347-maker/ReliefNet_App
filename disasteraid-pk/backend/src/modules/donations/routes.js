const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const Joi = require('joi');
const { v4: uuidv4 } = require('uuid');
const { generateDonationReceipt } = require('../../utils/pdf-receipts');
const { sendReceiptEmail } = require('../../utils/mailer');
const path = require('path');
const { createNotification } = require('../../utils/notify');
const upload = require('../../utils/upload');

const donationSchema = Joi.object({
  campaign_id: Joi.number().required(),
  amount: Joi.number().min(100).required(),
  payment_method: Joi.string().uppercase().valid('MOCK', 'STRIPE', 'JAZZCASH', 'EASYPAISA', 'BANK_TRANSFER').default('MOCK'),
  transaction_id: Joi.string().allow('', null),
  donor_name: Joi.string().allow('', null),
  donor_email: Joi.string().email().allow('', null),
  is_anonymous: Joi.boolean().default(false)
});

// POST /api/donations - Direct donation (card/jazzcash)
router.post('/', auth(), async (req, res, next) => {
  const { error, value } = donationSchema.validate(req.body);
  if (error) return res.fail(error.details[0].message, 400);

  let { campaign_id, amount, payment_method, donor_name, donor_email, transaction_id, is_anonymous } = value;

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
      FOR UPDATE OF c
    `, [campaign_id]);

    if (!campaign.rows[0]) throw new Error('Campaign not found');
    if (campaign.rows[0].status!== 'ACTIVE') throw new Error('Campaign not active');
    if (campaign.rows[0].ngo_status!== 'APPROVED') throw new Error('NGO not verified');
    if (campaign.rows[0].end_date && new Date(campaign.rows[0].end_date) < new Date()) {
      throw new Error('Campaign has ended');
    }

    const existing = await client.query('SELECT id FROM donations WHERE transaction_ref = $1', [transaction_id]);
    if (existing.rows[0]) throw new Error('Duplicate transaction');

    const donation = await client.query(
      `INSERT INTO donations (user_id, campaign_id, amount, payment_method, status, transaction_ref, donor_name, donor_email, is_anonymous)
       VALUES ($1, $2, $3, $4, 'VERIFIED', $5, $6, $7, $8) RETURNING *`,
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

    res.success({
      id: donation.rows[0].id,
      campaign_id: donation.rows[0].campaign_id,
      amount: donation.rows[0].amount,
      payment_method: donation.rows[0].payment_method,
      transaction_ref: donation.rows[0].transaction_ref,
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
    }, 201);
  } catch (e) {
    await client.query('ROLLBACK');
    next(e);
  } finally {
    client.release();
  }
});

// GET /api/donations/my
router.get('/my', auth(), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT d.id, d.amount, d.status, d.created_at, d.verified_at, d.receipt_url,
             d.transaction_ref, d.payment_method, d.rejection_reason,
             c.title as campaign_title, c.image_url, c.status as campaign_status,
             n.org_name, n.id as ngo_id
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      JOIN ngo_profiles n ON c.ngo_id = n.id
      WHERE d.user_id = $1
      ORDER BY d.created_at DESC
      LIMIT 100
    `, [req.user.id]);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/donations/receipt/:id
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

    if (!result.rows[0]) return res.fail('Receipt not found', 404);
    res.success(result.rows[0]);
  } catch (e) { next(e); }
});

// POST /api/donations/manual - UPDATED: Returns PLATFORM bank details
router.post('/manual', auth('donor'), upload.single('proof'), async (req, res, next) => {
  const client = await db.connect();
  try {
    const schema = Joi.object({
      campaign_id: Joi.number().integer().required(),
      amount: Joi.number().positive().max(10000000).required(),
      donor_note: Joi.string().max(200).allow('', null),
    });
    const { error, value } = schema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400);
    if (!req.file) return res.fail('Payment proof image required', 400);

    await client.query('BEGIN');

    const campaign = await client.query(`
      SELECT c.id, c.title, c.ngo_id, n.org_name
      FROM campaigns c
      JOIN ngo_profiles n ON c.ngo_id = n.id
      WHERE c.id = $1 AND c.status = 'ACTIVE'
    `, [value.campaign_id]);

    if (!campaign.rows[0]) throw new Error('Campaign not found or inactive');

    // Check platform bank details exist in.env
    if (!process.env.PLATFORM_IBAN) throw new Error('Platform bank details not configured');

    const bankRef = `DON-${Date.now().toString().slice(-8)}`;

    const result = await client.query(`
      INSERT INTO donations (
        user_id, campaign_id, amount, payment_method, status,
        bank_reference, proof_of_payment_url, donor_note
      ) VALUES ($1, $2, $3, 'BANK_TRANSFER', 'PENDING', $4, $5, $6)
      RETURNING *
    `, [req.user.id, value.campaign_id, value.amount, bankRef, req.file.path, value.donor_note]);

    await client.query('COMMIT');

    // Return PLATFORM bank details, not NGO bank
    res.success({
      platform_bank_name: process.env.PLATFORM_BANK_NAME,
      platform_account_title: process.env.PLATFORM_ACCOUNT_TITLE,
      platform_account_number: process.env.PLATFORM_ACCOUNT_NUMBER,
      platform_iban: process.env.PLATFORM_IBAN,
      reference: bankRef,
      amount: value.amount,
      donation_id: result.rows[0].id,
      campaign_title: campaign.rows[0].title
    }, 201);
  } catch (e) {
    await client.query('ROLLBACK');
    next(e);
  } finally {
    client.release();
  }
});

// GET /api/donations/ngo - NGO sees donations to their campaigns
router.get('/ngo', auth('ngo'), async (req, res, next) => {
  try {
    const ngo = await db.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [req.user.id]);
    if (!ngo.rows[0]) return res.fail('NGO profile not found', 403);

    const result = await db.query(`
      SELECT d.*, c.title as campaign_title, u.name as donor_name, u.email as donor_email
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      JOIN users u ON d.user_id = u.id
      WHERE c.ngo_id = $1
      ORDER BY d.created_at DESC LIMIT 100
    `, [ngo.rows[0].id]);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// GET /api/donations/pending - ADDED: Admin sees all pending donations
router.get('/pending', auth('admin'), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT d.id, d.amount, d.status, d.created_at, d.proof_of_payment_url,
             d.bank_reference, d.donor_note,
             c.title as campaign_title, n.org_name,
             u.name as donor_name, u.email as donor_email, u.phone as donor_phone
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      JOIN ngo_profiles n ON c.ngo_id = n.id
      JOIN users u ON d.user_id = u.id
      WHERE d.status = 'PENDING' AND d.payment_method = 'BANK_TRANSFER'
      ORDER BY d.created_at ASC
    `);
    res.success(result.rows);
  } catch (e) { next(e); }
});

// PATCH /api/admin/donations/:id/verify - Admin verifies donation
router.patch('/:id/verify', auth('admin'), async (req, res, next) => {
  const { status, rejection_reason } = req.body;
  const client = await db.connect();

  try {
    if (!['VERIFIED', 'REJECTED'].includes(status)) throw new Error('Invalid status');

    await client.query('BEGIN');

    const donationQuery = await client.query(`
      SELECT d.*, c.title as campaign_title, c.ngo_id, n.org_name, n.id as ngo_profile_id,
             u.name as donor_name, u.email as donor_email, u.id as donor_id
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      JOIN ngo_profiles n ON c.ngo_id = n.id
      JOIN users u ON d.user_id = u.id
      WHERE d.id = $1 AND d.status = 'PENDING'
      FOR UPDATE
    `, [req.params.id]);

    if (!donationQuery.rows[0]) throw new Error('Donation not found or already processed');
    const donation = donationQuery.rows[0];

    const result = await client.query(`
      UPDATE donations
      SET status = $1, verified_by = $2, verified_at = NOW(), rejection_reason = $3
      WHERE id = $4
      RETURNING *
    `, [status, req.user.id, rejection_reason || null, req.params.id]);

    let receiptUrl = null;

    if (status === 'VERIFIED') {
      // Update NGO wallet
      await client.query(`
        INSERT INTO ngo_wallets (ngo_id, balance, total_received)
        VALUES ($1, $2, $2)
        ON CONFLICT (ngo_id) DO UPDATE SET
          balance = ngo_wallets.balance + $2,
          total_received = ngo_wallets.total_received + $2,
          updated_at = NOW()
      `, [donation.ngo_profile_id, donation.amount]);

      // Update campaign raised_amount
      await client.query(`
        UPDATE campaigns
        SET raised_amount = raised_amount + $1,
            status = CASE WHEN raised_amount + $1 >= target_amount THEN 'COMPLETED' ELSE status END,
            updated_at = NOW()
        WHERE id = $2
      `, [donation.amount, donation.campaign_id]);

      // Generate receipt
      const fullPath = await generateDonationReceipt({
      ...donation,
        verified_at: new Date(),
        payment_method: donation.payment_method || 'BANK_TRANSFER',
        transaction_id: donation.bank_reference || donation.transaction_ref
      });

      receiptUrl = fullPath;

      await client.query(
        'UPDATE donations SET receipt_url = $1, receipt_sent_at = NOW() WHERE id = $2',
        [receiptUrl, req.params.id]
      );

      if (donation.donor_email) {
        try {
          const absolutePath = path.join(__dirname, '../../', receiptUrl);
          await sendReceiptEmail(donation.donor_email, absolutePath, donation);
        } catch (mailErr) {
          console.error('Failed to email receipt:', mailErr.message);
        }
      }
    }

    await client.query('COMMIT');

    await createNotification(
      donation.donor_id,
      status === 'VERIFIED'? 'Donation Verified' : 'Donation Rejected',
      status === 'VERIFIED'
       ? `Your PKR ${donation.amount} donation to ${donation.campaign_title} is verified.`
        : `Your donation to ${donation.campaign_title} was rejected. Reason: ${rejection_reason}`,
      status === 'VERIFIED'? 'donation_verified' : 'donation_rejected',
      { donation_id: donation.id, campaign_id: donation.campaign_id }
    );

    res.success({
      donation: result.rows[0],
      receipt_url: receiptUrl,
      message: status === 'VERIFIED'? 'Donation verified & receipt sent' : 'Donation rejected'
    });
  } catch (e) {
    await client.query('ROLLBACK');
    next(e);
  } finally {
    client.release();
  }
});

module.exports = router;