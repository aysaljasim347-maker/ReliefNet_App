const router = require('express').Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');

// GET /api/notifications - Get my notifications
router.get('/', auth(), async (req, res, next) => {
  try {
    const result = await db.query(
      `SELECT * FROM notifications
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 50`,
      [req.user.id]
    );
    res.json({ data: result.rows });
  } catch (e) { next(e); }
});

// PATCH /api/notifications/:id/read - Mark as read
router.patch('/:id/read', auth(), async (req, res, next) => {
  try {
    await db.query(
      `UPDATE notifications SET is_read = true
       WHERE id = $1 AND user_id = $2`,
      [req.params.id, req.user.id]
    );
    res.json({ success: true });
  } catch (e) { next(e); }
});

// PATCH /api/notifications/read-all - Mark all as read
router.patch('/read-all', auth(), async (req, res, next) => {
  try {
    await db.query(
      `UPDATE notifications SET is_read = true
       WHERE user_id = $1 AND is_read = false`,
      [req.user.id]
    );
    res.json({ success: true });
  } catch (e) { next(e); }
});

module.exports = router;