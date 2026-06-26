'use strict';

const WINDOW_MS = 60 * 1000;
const MAX_SAVES_PER_WINDOW = 40;

/** @type {Map<string, { start: number, count: number }>} */
const buckets = new Map();

/**
 * Per-user soft limit for saveOnboardingProgress (signup burst protection).
 * In-memory per Parse process — sufficient for single-node / moderate cluster load.
 */
function assertOnboardingProgressRateLimit(userId) {
  if (!userId) return;

  const now = Date.now();
  let bucket = buckets.get(userId);
  if (!bucket || now - bucket.start > WINDOW_MS) {
    bucket = { start: now, count: 0 };
    buckets.set(userId, bucket);
  }

  bucket.count += 1;
  if (bucket.count > MAX_SAVES_PER_WINDOW) {
    const Parse = global.Parse;
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Too many onboarding save requests. Please wait a moment and try again.',
    );
  }
}

/** Test helper */
function resetOnboardingProgressRateLimitForTests() {
  buckets.clear();
}

module.exports = {
  assertOnboardingProgressRateLimit,
  resetOnboardingProgressRateLimitForTests,
  WINDOW_MS,
  MAX_SAVES_PER_WINDOW,
};
