'use strict';

/** Magic OTP for LAN/dev onboarding smoke tests (iOS DEBUG prefill). */
const DEV_ONBOARDING_OTP = '000000';

function envTrue(name) {
  return String(process.env[name] || '').toLowerCase() === 'true';
}

/**
 * Accepts `000000` when NODE_ENV is not production, or when explicitly enabled on iobox
 * via ALLOW_DEV_ONBOARDING_OTP_BYPASS=true (see backend/env.example).
 */
function isDevOnboardingOtpBypass(code) {
  if (code !== DEV_ONBOARDING_OTP) return false;
  if (process.env.NODE_ENV !== 'production') return true;
  return envTrue('ALLOW_DEV_ONBOARDING_OTP_BYPASS');
}

module.exports = {
  DEV_ONBOARDING_OTP,
  isDevOnboardingOtpBypass,
};
