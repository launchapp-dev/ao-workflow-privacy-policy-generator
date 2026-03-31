// Payments module — processes payments via Stripe
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const { pool } = require('./config');

async function createPaymentIntent({ userId, amount, currency = 'usd', paymentMethod }) {
  const intent = await stripe.paymentIntents.create({
    amount,
    currency,
    payment_method: paymentMethod,
    confirm: true,
    metadata: { userId }
  });

  await pool.query(
    `INSERT INTO payment_logs (user_id, stripe_payment_intent_id, amount, currency, status, created_at)
     VALUES ($1, $2, $3, $4, $5, NOW())`,
    [userId, intent.id, amount, currency, intent.status]
  );

  return intent;
}

async function savePaymentMethod({ userId, cardNumber, expiryMonth, expiryYear, cvv }) {
  // In production: tokenize via Stripe Elements — never store raw card data
  // This is demo code — actual cardNumber/cvv never stored server-side
  const paymentMethod = await stripe.paymentMethods.create({
    type: 'card',
    card: { number: cardNumber, exp_month: expiryMonth, exp_year: expiryYear, cvc: cvv }
  });

  await pool.query(
    `INSERT INTO payment_methods (user_id, stripe_payment_method_id, last4, brand)
     VALUES ($1, $2, $3, $4)`,
    [userId, paymentMethod.id, paymentMethod.card.last4, paymentMethod.card.brand]
  );

  return paymentMethod.id;
}

async function getBillingInfo(userId) {
  const result = await pool.query(
    `SELECT u.email, u.first_name, u.last_name, u.address,
            pm.last4, pm.brand, pm.stripe_payment_method_id
     FROM users u
     LEFT JOIN payment_methods pm ON pm.user_id = u.id
     WHERE u.id = $1`,
    [userId]
  );
  return result.rows[0];
}

module.exports = { createPaymentIntent, savePaymentMethod, getBillingInfo };
