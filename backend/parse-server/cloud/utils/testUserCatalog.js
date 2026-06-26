'use strict';

/** Canonical iOS debug-list users (investor1@test.com … trader10@test.com). */
const SEED_TEST_USER_EMAIL_REGEX = '^(investor|trader)\\d+@test\\.com$';

/** DEBUG Get Started runs with timestamped mailbox (signup+{ts}@test.com). */
const SIGNUP_RUN_EMAIL_REGEX = '^signup\\+.*@test\\.com$';

function isSeedTestUserEmail(email) {
  return new RegExp(SEED_TEST_USER_EMAIL_REGEX, 'i').test(String(email || '').trim());
}

function isSignupRunEmail(email) {
  return new RegExp(SIGNUP_RUN_EMAIL_REGEX, 'i').test(String(email || '').trim());
}

function searchQueryTargetsSignupRuns(searchQuery) {
  return /signup/i.test(String(searchQuery || '').trim());
}

/**
 * Hide Get-Started noise from default admin lists unless explicitly requested.
 */
function shouldExcludeSignupRuns({ searchQuery, testUserFilter } = {}) {
  if (testUserFilter === 'signupRuns') return false;
  if (searchQueryTargetsSignupRuns(searchQuery)) return false;
  return true;
}

module.exports = {
  SEED_TEST_USER_EMAIL_REGEX,
  SIGNUP_RUN_EMAIL_REGEX,
  isSeedTestUserEmail,
  isSignupRunEmail,
  searchQueryTargetsSignupRuns,
  shouldExcludeSignupRuns,
};
