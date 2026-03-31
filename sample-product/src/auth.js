// Authentication module — collects and processes user credentials
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { pool } = require('./config');

async function registerUser({ email, password, firstName, lastName, dateOfBirth }) {
  const hashedPassword = await bcrypt.hash(password, 12);

  const result = await pool.query(
    `INSERT INTO users (email, password_hash, first_name, last_name, date_of_birth, created_at)
     VALUES ($1, $2, $3, $4, $5, NOW())
     RETURNING id, email, first_name, last_name`,
    [email, hashedPassword, firstName, lastName, dateOfBirth]
  );

  return result.rows[0];
}

async function loginUser({ email, password, ipAddress, userAgent }) {
  const user = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  if (!user.rows[0]) throw new Error('User not found');

  const valid = await bcrypt.compare(password, user.rows[0].password_hash);
  if (!valid) throw new Error('Invalid credentials');

  // Log authentication event with network info
  await pool.query(
    `INSERT INTO auth_logs (user_id, ip_address, user_agent, logged_at)
     VALUES ($1, $2, $3, NOW())`,
    [user.rows[0].id, ipAddress, userAgent]
  );

  const token = jwt.sign({ userId: user.rows[0].id }, process.env.JWT_SECRET, { expiresIn: '7d' });
  return { token, user: user.rows[0] };
}

async function updateProfile({ userId, firstName, lastName, phone, address }) {
  const result = await pool.query(
    `UPDATE users SET first_name = $1, last_name = $2, phone = $3, address = $4
     WHERE id = $5 RETURNING *`,
    [firstName, lastName, phone, address, userId]
  );
  return result.rows[0];
}

module.exports = { registerUser, loginUser, updateProfile };
