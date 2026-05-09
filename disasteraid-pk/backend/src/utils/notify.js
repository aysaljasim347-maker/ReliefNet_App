const db = require('../config/db');
const { sendToUser } = require('./socket');

async function createNotification(userId, title, body, type, data = {}) {
  try {
    // 1. Save to DB
    await db.query(
      `INSERT INTO notifications (user_id, title, body, type, data)
       VALUES ($1, $2, $3, $4, $5)`,
      [userId, title, body, type, JSON.stringify(data)]
    );

    // 2. Push via socket
    sendToUser(userId, 'notification', { title, body, type, data });

    console.log(`Notification created for user ${userId}: ${title}`);
  } catch (e) {
    console.error('Notification error:', e.message);
  }
}

module.exports = { createNotification };