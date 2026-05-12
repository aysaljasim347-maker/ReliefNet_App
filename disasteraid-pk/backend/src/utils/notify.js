const db = require('../config/db');
const { sendToUser } = require('./socket');

/**
 * Centralized Notification Service
 * Handles DB persistence, Socket.io (Foreground), and FCM (Background)
 */
async function createNotification(userId, title, body, type, data = {}) {
  try {
    // 1. Save to Database for the Notification Center
    await db.query(
      `INSERT INTO notifications (user_id, title, body, type, data)
       VALUES ($1, $2, $3, $4, $5)`,
      [userId, title, body, type, JSON.stringify(data)]
    );

    // 2. Push via Socket.io for immediate UI updates if app is open
    sendToUser(userId, 'notification', { title, body, type, data });

    // 3. Trigger FCM for system-level background notifications
    await sendFCMNotification(userId, title, body, data);

    console.log(`Notification sent to user ${userId}: ${title}`);
  } catch (e) {
    console.error('Notification error:', e.message);
  }
}

/**
 * Reusable wrapper for specific push notification triggers
 */
async function sendNotification(userId, title, body, data = {}) {
  return createNotification(userId, title, body, 'system_alert', data);
}

/**
 * Internal logic for Firebase Cloud Messaging
 */
async function sendFCMNotification(userId, title, body, data) {
  try {
    const userRes = await db.query('SELECT fcm_token FROM users WHERE id = $1', [userId]);
    const token = userRes.rows[0]?.fcm_token;

    if (!token) {
      console.log(`No FCM token found for user ${userId}, skipping push.`);
      return;
    }

    // Note: Integration with firebase-admin would go here.
    // Assuming 'admin' is initialized in a separate config or at server start.
    /*
    const message = {
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      token: token
    };
    await admin.messaging().send(message);
    */
    console.log(`FCM Push Triggered for ${userId} (Token: ${token.substring(0, 10)}...)`);
  } catch (err) {
    console.error('FCM Error:', err.message);
  }
}

module.exports = { createNotification, sendNotification };