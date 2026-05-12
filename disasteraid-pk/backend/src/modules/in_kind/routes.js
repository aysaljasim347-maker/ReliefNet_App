const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const Joi = require('joi');
const { createNotification } = require('../../utils/notify');

// ─── Validation Schemas ───────────────────────────────────────────────────────

const createSchema = Joi.object({
    title: Joi.string().min(3).max(100).required(),
    description: Joi.string().max(500).allow('', null),
    image_url: Joi.string().uri().required(),
    location: Joi.string().max(200).required(),
    latitude: Joi.number().min(-90).max(90).allow(null),
    longitude: Joi.number().min(-180).max(180).allow(null),
    expires_at: Joi.date().iso().min('now').allow(null),
});

const requestSchema = Joi.object({
    message: Joi.string().max(300).allow('', null),
});

// ─── DONOR ROUTES ─────────────────────────────────────────────────────────────

// POST /api/in-kind
// Donor posts a new in-kind donation (image already uploaded to Cloudinary)
router.post('/', auth('donor'), async (req, res, next) => {
    const { error, value } = createSchema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400);

    try {
        const result = await db.query(
            `INSERT INTO in_kind_donations
         (donor_id, title, description, image_url, location, latitude, longitude, expires_at, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'available')
       RETURNING *`,
            [
                req.user.id,
                value.title,
                value.description || null,
                value.image_url,
                value.location,
                value.latitude || null,
                value.longitude || null,
                value.expires_at || null,
            ]
        );

        res.success(result.rows[0], 201);
    } catch (e) {
        next(e);
    }
});

// GET /api/in-kind/my
// Donor sees their own donations
router.get('/my', auth('donor'), async (req, res, next) => {
    try {
        const result = await db.query(
            `SELECT d.*,
              u.name  AS claimed_by_name,
              u.email AS claimed_by_email,
              u.phone AS claimed_by_phone,
              (SELECT COUNT(*) FROM in_kind_requests r
               WHERE r.donation_id = d.id AND r.status = 'pending') AS pending_requests
       FROM in_kind_donations d
       LEFT JOIN users u ON u.id = d.claimed_by
       WHERE d.donor_id = $1
       ORDER BY d.created_at DESC`,
            [req.user.id]
        );

        res.success(result.rows);
    } catch (e) {
        next(e);
    }
});

// GET /api/in-kind/my/:id/requests
// Donor sees all requests for one of their donations
router.get('/my/:id/requests', auth('donor'), async (req, res, next) => {
    try {
        // Verify ownership
        const donation = await db.query(
            `SELECT id FROM in_kind_donations WHERE id = $1 AND donor_id = $2`,
            [req.params.id, req.user.id]
        );
        if (!donation.rows[0]) return res.fail('Donation not found', 404);

        const result = await db.query(
            `SELECT r.*,
              u.name     AS beneficiary_name,
              u.email    AS beneficiary_email,
              u.phone    AS beneficiary_phone
       FROM in_kind_requests r
       JOIN users u ON u.id = r.beneficiary_id
       WHERE r.donation_id = $1
       ORDER BY r.created_at ASC`,
            [req.params.id]
        );

        res.success(result.rows);
    } catch (e) {
        next(e);
    }
});

// POST /api/in-kind/my/:donationId/requests/:requestId/approve
// Donor approves one request → all others auto-rejected
router.post(
    '/my/:donationId/requests/:requestId/approve',
    auth('donor'),
    async (req, res, next) => {
        const client = await db.connect();
        try {
            await client.query('BEGIN');

            // Verify ownership + status
            const donationRes = await client.query(
                `SELECT d.*, u.name AS donor_name, u.email AS donor_email, u.phone AS donor_phone
         FROM in_kind_donations d
         JOIN users u ON u.id = d.donor_id
         WHERE d.id = $1 AND d.donor_id = $2 AND d.status = 'available'
         FOR UPDATE`,
                [req.params.donationId, req.user.id]
            );
            if (!donationRes.rows[0])
                throw Object.assign(new Error('Donation not found or already claimed'), { status: 404 });

            const donation = donationRes.rows[0];

            // Verify the request belongs to this donation
            const requestRes = await client.query(
                `SELECT r.*, u.id AS beneficiary_user_id
         FROM in_kind_requests r
         JOIN users u ON u.id = r.beneficiary_id
         WHERE r.id = $1 AND r.donation_id = $2 AND r.status = 'pending'`,
                [req.params.requestId, req.params.donationId]
            );
            if (!requestRes.rows[0])
                throw Object.assign(new Error('Request not found or already processed'), { status: 404 });

            const approvedRequest = requestRes.rows[0];

            // Approve the chosen request
            await client.query(
                `UPDATE in_kind_requests SET status = 'approved' WHERE id = $1`,
                [req.params.requestId]
            );

            // Auto-reject all other pending requests for this donation
            await client.query(
                `UPDATE in_kind_requests
         SET status = 'rejected'
         WHERE donation_id = $1 AND id != $2 AND status = 'pending'`,
                [req.params.donationId, req.params.requestId]
            );

            // Mark donation as claimed
            await client.query(
                `UPDATE in_kind_donations
         SET status = 'claimed', claimed_by = $1, updated_at = NOW()
         WHERE id = $2`,
                [approvedRequest.beneficiary_user_id, req.params.donationId]
            );

            await client.query('COMMIT');

            // Notify the approved beneficiary — reveal donor contact
            await createNotification(
                approvedRequest.beneficiary_user_id,
                'Your request was approved!',
                `Great news! Your request for "${donation.title}" was approved. ` +
                `Contact the donor: ${donation.donor_name} — ` +
                `📧 ${donation.donor_email}` +
                (donation.donor_phone ? ` | 📞 ${donation.donor_phone}` : ''),
                'in_kind_approved',
                {
                    donation_id: donation.id,
                    donor_name: donation.donor_name,
                    donor_email: donation.donor_email,
                    donor_phone: donation.donor_phone || null,
                }
            );

            // Notify all rejected beneficiaries
            const rejectedRes = await db.query(
                `SELECT r.beneficiary_id FROM in_kind_requests r
         WHERE r.donation_id = $1 AND r.status = 'rejected'`,
                [req.params.donationId]
            );
            for (const row of rejectedRes.rows) {
                await createNotification(
                    row.beneficiary_id,
                    'Request not selected',
                    `Unfortunately your request for "${donation.title}" was not selected this time.`,
                    'in_kind_rejected',
                    { donation_id: donation.id }
                );
            }

            res.success({ message: 'Request approved, beneficiary notified' });
        } catch (e) {
            await client.query('ROLLBACK');
            next(e);
        } finally {
            client.release();
        }
    }
);

// ─── BENEFICIARY ROUTES ───────────────────────────────────────────────────────

// GET /api/in-kind
// Beneficiaries browse all available donations
router.get('/', auth('beneficiary'), async (req, res, next) => {
    try {
        const result = await db.query(
            `SELECT d.*,
              u.name AS donor_name
       FROM in_kind_donations d
       JOIN users u ON u.id = d.donor_id
       WHERE d.status = 'available'
         AND (d.expires_at IS NULL OR d.expires_at > NOW())
       ORDER BY d.created_at DESC
       LIMIT 100`
        );

        res.success(result.rows);
    } catch (e) {
        next(e);
    }
});


// ─────────────────────────────────────────────────────────────────────────────
// ADD THIS ROUTE to backend/modules/in_kind/routes.js
//
// Place it inside the BENEFICIARY ROUTES section, just before the
// existing  GET /api/in-kind/:id  route  (it must come before /:id
// so Express doesn't treat "my-requests" as a donation ID).
// ─────────────────────────────────────────────────────────────────────────────

// GET /api/in-kind/my-requests
// Beneficiary sees all their own requests + donation info + donor contact
// (donor contact is only meaningful once status = 'approved')
router.get('/my-requests', auth('beneficiary'), async (req, res, next) => {
    try {
        const result = await db.query(
            `SELECT
                r.id                  AS request_id,
                r.status              AS request_status,
                r.message             AS request_message,
                r.created_at          AS requested_at,

                -- Donation details
                d.id                  AS donation_id,
                d.title               AS donation_title,
                d.description         AS donation_description,
                d.image_url           AS donation_image_url,
                d.location            AS donation_location,
                d.status              AS donation_status,

                -- Donor contact — always returned but frontend
                -- must only display when request_status = 'approved'
                u.name                AS donor_name,
                u.email               AS donor_email,
                u.phone               AS donor_phone

             FROM in_kind_requests r
             JOIN in_kind_donations d ON d.id = r.donation_id
             JOIN users u             ON u.id = d.donor_id
             WHERE r.beneficiary_id = $1
             ORDER BY r.created_at DESC`,
            [req.user.id]
        );

        res.success(result.rows);
    } catch (e) {
        next(e);
    }
});
// GET /api/in-kind/:id
// Beneficiary views a single donation detail
router.get('/:id', auth('beneficiary'), async (req, res, next) => {
    try {
        const result = await db.query(
            `SELECT d.*,
              u.name AS donor_name,
              (SELECT COUNT(*) FROM in_kind_requests r
               WHERE r.donation_id = d.id) AS total_requests,
              (SELECT json_build_object('id', r.id, 'status', r.status, 'message', r.message)
               FROM in_kind_requests r
               WHERE r.donation_id = d.id AND r.beneficiary_id = $2
               LIMIT 1) AS my_request
       FROM in_kind_donations d
       JOIN users u ON u.id = d.donor_id
       WHERE d.id = $1`,
            [req.params.id, req.user.id]
        );

        if (!result.rows[0]) return res.fail('Donation not found', 404);
        res.success(result.rows[0]);
    } catch (e) {
        next(e);
    }
});

// POST /api/in-kind/:id/request
// Beneficiary sends a request for a donation
router.post('/:id/request', auth('beneficiary'), async (req, res, next) => {
    const { error, value } = requestSchema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400);

    try {
        // Check donation is still available
        const donation = await db.query(
            `SELECT d.*, u.id AS donor_user_id
       FROM in_kind_donations d
       JOIN users u ON u.id = d.donor_id
       WHERE d.id = $1 AND d.status = 'available'
         AND (d.expires_at IS NULL OR d.expires_at > NOW())`,
            [req.params.id]
        );
        if (!donation.rows[0]) return res.fail('Donation not available', 404);

        // Prevent duplicate request
        const existing = await db.query(
            `SELECT id FROM in_kind_requests
       WHERE donation_id = $1 AND beneficiary_id = $2`,
            [req.params.id, req.user.id]
        );
        if (existing.rows[0]) return res.fail('You have already requested this item', 409);

        const result = await db.query(
            `INSERT INTO in_kind_requests (donation_id, beneficiary_id, message, status)
       VALUES ($1, $2, $3, 'pending')
       RETURNING *`,
            [req.params.id, req.user.id, value.message || null]
        );

        // Notify the donor
        const beneficiaryRes = await db.query(
            `SELECT name FROM users WHERE id = $1`,
            [req.user.id]
        );
        const beneficiaryName = beneficiaryRes.rows[0]?.name ?? 'Someone';

        await createNotification(
            donation.rows[0].donor_user_id,
            'New request for your donation',
            `${beneficiaryName} has requested your donation: "${donation.rows[0].title}". Open the app to review.`,
            'in_kind_request_received',
            { donation_id: donation.rows[0].id, request_id: result.rows[0].id }
        );

        res.success(result.rows[0], 201);
    } catch (e) {
        next(e);
    }
});

// ─── ADMIN ROUTES ─────────────────────────────────────────────────────────────

// GET /api/in-kind/admin/all
// Admin sees full record of all in-kind donations
router.get('/admin/all', auth('admin'), async (req, res, next) => {
    try {
        const result = await db.query(
            `SELECT d.*,
              donor.name   AS donor_name,
              donor.email  AS donor_email,
              donor.phone  AS donor_phone,
              claimer.name  AS claimed_by_name,
              claimer.email AS claimed_by_email,
              (SELECT COUNT(*) FROM in_kind_requests r
               WHERE r.donation_id = d.id) AS total_requests
       FROM in_kind_donations d
       JOIN users donor ON donor.id = d.donor_id
       LEFT JOIN users claimer ON claimer.id = d.claimed_by
       ORDER BY d.created_at DESC
       LIMIT 200`
        );

        res.success(result.rows);
    } catch (e) {
        next(e);
    }
});

module.exports = router;
