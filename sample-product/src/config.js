// App configuration and database connection
const { Pool } = require('pg');
const Sentry = require('@sentry/node');

// Initialize Sentry error tracking
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV || 'production',
  tracesSampleRate: 1.0,
  // Captures user context for error reports
  beforeSend(event) {
    if (event.user) {
      // Strip PII from Sentry events in production
      delete event.user.email;
      delete event.user.ip_address;
    }
    return event;
  }
});

// Database connection pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: true } : false
});

// Intercom integration for customer support
const intercomConfig = {
  appId: process.env.INTERCOM_APP_ID,
  apiKey: process.env.INTERCOM_API_KEY
};

// Google Analytics config
const GA_TRACKING_ID = process.env.GA_TRACKING_ID;

module.exports = {
  pool,
  sentry: Sentry,
  intercomConfig,
  GA_TRACKING_ID,
  jwtSecret: process.env.JWT_SECRET,
  stripePublishableKey: process.env.STRIPE_PUBLISHABLE_KEY
};
