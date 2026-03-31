// Analytics module — tracks user behavior and page views
// Uses Google Analytics and Segment for analytics

// Google Analytics (gtag)
function initGoogleAnalytics(trackingId) {
  window.dataLayer = window.dataLayer || [];
  function gtag() { dataLayer.push(arguments); }
  gtag('js', new Date());
  gtag('config', trackingId, {
    anonymize_ip: false,
    send_page_view: true
  });
}

// Segment analytics
const analytics = require('@segment/analytics-next');

function trackPageview(userId, page, properties) {
  // Track with Segment
  analytics.page(page, {
    userId,
    url: window.location.href,
    referrer: document.referrer,
    ...properties
  });

  // Track with Google Analytics
  gtag('event', 'page_view', {
    page_title: document.title,
    page_location: window.location.href
  });
}

function trackEvent(userId, eventName, properties) {
  analytics.track(eventName, {
    userId,
    timestamp: new Date().toISOString(),
    ...properties
  });
}

function identifyUser(userId, traits) {
  analytics.identify(userId, {
    email: traits.email,
    name: traits.firstName + ' ' + traits.lastName,
    createdAt: traits.createdAt,
    plan: traits.subscriptionPlan
  });
}

// Store user preferences in localStorage
function saveUserPreferences(preferences) {
  localStorage.setItem('user_preferences', JSON.stringify(preferences));
}

function getUserPreferences() {
  return JSON.parse(localStorage.getItem('user_preferences') || '{}');
}

// Cookie consent management
function setCookie(name, value, days) {
  document.cookie = `${name}=${value}; max-age=${days * 86400}; SameSite=Lax; Secure`;
}

module.exports = {
  initGoogleAnalytics,
  trackPageview,
  trackEvent,
  identifyUser,
  saveUserPreferences,
  getUserPreferences,
  setCookie
};
