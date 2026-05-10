const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');

/**
 * GET /api/admin/export/donations?days=30
 * Export donations as CSV for the last N days
 */
router.get('/donations', auth('admin'), async (req, res, next) => {
  try {
    const days = parseInt(req.query.days) || 30;

    const result = await db.query(`
      SELECT d.id, d.amount, d.status, d.payment_method, d.bank_reference,
             d.created_at, d.verified_at,
             u.name as donor_name, u.email as donor_email,
             c.title as campaign_title, n.org_name
      FROM donations d
      JOIN users u ON d.user_id = u.id
      JOIN campaigns c ON d.campaign_id = c.id
      JOIN ngo_profiles n ON c.ngo_id = n.id
      WHERE d.created_at >= NOW() - INTERVAL '1 day' * $1
      ORDER BY d.created_at DESC
    `, [days]);

    const rows = result.rows;
    if (rows.length === 0) {
      return res.success({ csv: 'No donations in this period', count: 0 });
    }

    // Build CSV
    const headers = Object.keys(rows[0]).join(',');
    const csvRows = rows.map(row =>
      Object.values(row).map(v => {
        if (v === null) return '';
        const str = String(v).replace(/"/g, '""');
        return `"${str}"`;
      }).join(',')
    );

    const csv = [headers, ...csvRows].join('\n');

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename=donations_last_${days}_days.csv`);
    res.send(csv);
  } catch (e) { next(e); }
});

/**
 * GET /api/admin/export/ngos
 * Export NGOs as CSV
 */
router.get('/ngos', auth('admin'), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT n.id, n.org_name, n.registration_number, n.address, n.status,
             n.contact_person, n.email, n.phone,
             n.created_at, n.approved_at,
             COALESCE(w.balance, 0) as wallet_balance,
             COALESCE(w.total_received, 0) as total_received,
             COALESCE(w.total_withdrawn, 0) as total_withdrawn,
             COUNT(DISTINCT c.id) as campaign_count
      FROM ngo_profiles n
      LEFT JOIN ngo_wallets w ON w.ngo_id = n.id
      LEFT JOIN campaigns c ON c.ngo_id = n.id
      GROUP BY n.id, w.id
      ORDER BY n.created_at DESC
    `);

    const rows = result.rows;
    if (rows.length === 0) {
      return res.success({ csv: 'No NGOs found', count: 0 });
    }

    const headers = Object.keys(rows[0]).join(',');
    const csvRows = rows.map(row =>
      Object.values(row).map(v => {
        if (v === null) return '';
        const str = String(v).replace(/"/g, '""');
        return `"${str}"`;
      }).join(',')
    );

    const csv = [headers, ...csvRows].join('\n');

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=ngos_export.csv');
    res.send(csv);
  } catch (e) { next(e); }
});

module.exports = router;
