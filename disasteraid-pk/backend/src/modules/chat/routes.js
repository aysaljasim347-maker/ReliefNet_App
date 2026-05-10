const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const auth = require('../../middleware/auth');
const Joi = require('joi');

const messageSchema = Joi.object({
  message: Joi.string().min(1).max(2000).required()
});

// GET /api/chat/:requestId - Get messages for a request
router.get('/:requestId', auth(), async (req, res, next) => {
  try {
    const { requestId } = req.params;

    const check = await db.query(`
      SELECT id FROM aid_requests
      WHERE id = $1 AND (beneficiary_id = $2 OR volunteer_id = $2)
    `, [requestId, req.user.id]);

    if (!check.rows[0]) {
      return res.fail('Access denied', 403);
    }

    const result = await db.query(`
      SELECT m.id, m.message, m.created_at, m.read_at,
             m.sender_id, u.name as sender_name, u.role as sender_role
      FROM messages m
      JOIN users u ON m.sender_id = u.id
      WHERE m.request_id = $1
      ORDER BY m.created_at ASC
      LIMIT 100
    `, [requestId]);

    await db.query(`
      UPDATE messages SET read_at = CURRENT_TIMESTAMP
      WHERE request_id = $1 AND sender_id!= $2 AND read_at IS NULL
    `, [requestId, req.user.id]);

    res.success(result.rows);
  } catch (e) { next(e); }
});

// POST /api/chat/:requestId - Send message
router.post('/:requestId', auth(), async (req, res, next) => {
  try {
    const { requestId } = req.params;
    const { error, value } = messageSchema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400);

    const check = await db.query(`
      SELECT a.id, a.beneficiary_id, a.volunteer_id
      FROM aid_requests a
      WHERE a.id = $1 AND (a.beneficiary_id = $2 OR a.volunteer_id = $2)
    `, [requestId, req.user.id]);

    if (!check.rows[0]) {
      return res.fail('Access denied', 403);
    }

    const result = await db.query(
      `INSERT INTO messages (request_id, sender_id, message)
       VALUES ($1, $2, $3) RETURNING *`,
      [requestId, req.user.id, value.message]
    );

    const msg = result.rows[0];

    const io = req.app.get('io');
    io.to(`request_${requestId}`).emit('new_message', {
      id: msg.id,
      request_id: requestId,
      message: msg.message,
      sender_id: req.user.id,
      sender_name: req.user.name,
      sender_role: req.user.role,
      created_at: msg.created_at
    });

    res.success(msg, 201);
  } catch (e) { next(e); }
});

// GET /api/chat - List user's active chats
router.get('/', auth(), async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT DISTINCT ON (a.id)
        a.id as request_id,
        a.category, a.urgency,
        CASE
          WHEN a.beneficiary_id = $1 THEN uv.name
          ELSE ub.name
        END as other_user_name,
        CASE
          WHEN a.beneficiary_id = $1 THEN 'volunteer'
          ELSE 'beneficiary'
        END as other_user_role,
        m.message as last_message,
        m.created_at as last_message_time,
        (SELECT COUNT(*) FROM messages
         WHERE request_id = a.id AND sender_id!= $1 AND read_at IS NULL) as unread_count
      FROM aid_requests a
      LEFT JOIN messages m ON m.request_id = a.id
      LEFT JOIN volunteer_profiles v ON a.volunteer_id = v.id
      LEFT JOIN users uv ON v.user_id = uv.id
      LEFT JOIN users ub ON a.beneficiary_id = ub.id
      WHERE (a.beneficiary_id = $1 OR a.volunteer_id = $1)
        AND a.status IN ('ASSIGNED', 'IN_PROGRESS')
      ORDER BY a.id, m.created_at DESC
    `, [req.user.id]);

    res.success(result.rows);
  } catch (e) { next(e); }
});

module.exports = router;