const router = require('express').Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const db = require('../../config/db');
const auth = require('../../middleware/auth');

const registerSchema = Joi.object({
  email: Joi.string().email().allow(null, ''),
  phone: Joi.string().pattern(/^[0-9]{11}$/).allow(null, ''),
  password: Joi.string().min(6).required(),
  role: Joi.string().valid('donor', 'ngo', 'volunteer', 'beneficiary', 'admin').required(),
  name: Joi.string().min(2).required()
}).or('email', 'phone');

router.post('/register', async (req, res, next) => {
  try {
    const { error, value } = registerSchema.validate(req.body);
    if (error) return res.fail(error.details[0].message, 400);

    const { email, phone, password, role, name } = value;
    const hash = await bcrypt.hash(password, 10);

    const roleRes = await db.query('SELECT id FROM roles WHERE name=$1', [role]);
    if (!roleRes.rows[0]) return res.fail('Invalid role', 400);

    const user = await db.query(
      'INSERT INTO users (email, phone, password_hash, role_id, name) VALUES ($1,$2,$3,$4,$5) RETURNING id,name,email,phone,role_id',
      [email || null, phone || null, hash, roleRes.rows[0].id, name]
    );

    const token = jwt.sign({ id: user.rows[0].id, role }, process.env.JWT_SECRET, { expiresIn: '24h' });
    res.success({ token, user: {...user.rows[0], role } }, 201);
  } catch (e) {
    if (e.code === '23505') return res.fail('Email or phone already exists', 409);
    next(e);
  }
});

router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const user = await db.query(
      'SELECT u.*, r.name as role FROM users u JOIN roles r ON u.role_id=r.id WHERE u.email=$1 OR u.phone=$1',
      [email]
    );

    if (!user.rows[0] ||!await bcrypt.compare(password, user.rows[0].password_hash)) {
      return res.fail('Invalid credentials', 401);
    }

    const token = jwt.sign({ id: user.rows[0].id, role: user.rows[0].role }, process.env.JWT_SECRET, { expiresIn: '24h' });
    const { password_hash,...userData } = user.rows[0];
    res.success({ token, user: userData });
  } catch (e) { next(e); }
});

// GET /api/auth/me - Get current user, used by Flutter on app start
router.get('/me', auth(), async (req, res, next) => {
  try {
    const user = await db.query(
      'SELECT u.id, u.name, u.email, u.phone, u.locale, r.name as role FROM users u JOIN roles r ON u.role_id=r.id WHERE u.id=$1',
      [req.user.id]
    );
    if (!user.rows[0]) return res.fail('User not found', 404);
    res.success(user.rows[0]);
  } catch (e) { next(e); }
});

// PATCH /api/auth/fcm-token - Update FCM for push notifications
router.patch('/fcm-token', auth(), async (req, res, next) => {
  try {
    const { fcm_token } = req.body;
    await db.query('UPDATE users SET fcm_token=$1 WHERE id=$2', [fcm_token, req.user.id]);
    res.success({ message: 'FCM token updated' });
  } catch (e) { next(e); }
});

module.exports = router;