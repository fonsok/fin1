'use strict';

const crypto = require('crypto');
let smsService;
try {
  smsService = require('../../utils/smsService');
} catch (e) {
  console.warn('smsService not available - verification SMS will be logged only');
}

// ============================================================================
// PHONE VERIFICATION (Onboarding SMS OTP)
// ============================================================================

/**
 * Send a 6-digit verification code to the user's phone number.
 * Rate-limited: max 1 code per 60 seconds, max 5 per hour.
 */
Parse.Cloud.define('sendPhoneVerificationCode', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const phone = (request.params.phoneNumber || '').trim();
  if (!phone || !/^\+[1-9]\d{6,14}$/.test(phone)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Valid E.164 phone number required (e.g. +491771234567)');
  }

  const PhoneCode = Parse.Object.extend('PhoneVerificationCode');

  // Rate limiting: 1 per 60s
  const recentQuery = new Parse.Query(PhoneCode);
  recentQuery.equalTo('userId', user.id);
  recentQuery.greaterThan('createdAt', new Date(Date.now() - 60 * 1000));
  if (await recentQuery.first({ useMasterKey: true })) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Please wait 60 seconds before requesting a new code');
  }

  // Hourly cap: 5 per hour
  const hourQuery = new Parse.Query(PhoneCode);
  hourQuery.equalTo('userId', user.id);
  hourQuery.greaterThan('createdAt', new Date(Date.now() - 60 * 60 * 1000));
  if ((await hourQuery.count({ useMasterKey: true })) >= 5) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Too many attempts. Please try again in one hour.');
  }

  const code = String(crypto.randomInt(100000, 999999));
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

  const entry = new PhoneCode();
  entry.set('userId', user.id);
  entry.set('phone', phone);
  entry.set('code', crypto.createHash('sha256').update(code).digest('hex'));
  entry.set('expiresAt', expiresAt);
  entry.set('verified', false);
  await entry.save(null, { useMasterKey: true });

  if (smsService) {
    await smsService.sendSMS({
      to: phone,
      text: `Ihr FIN1-Verifizierungscode: ${code} (10 Min. gültig)`,
    });
  }

  console.log(`[PHONE_VERIFY] Code for ${phone}: ${code} (expires ${expiresAt.toISOString()})`);

  return { success: true, expiresInSeconds: 600 };
});

/**
 * Verify the 6-digit phone code entered by the user.
 */
Parse.Cloud.define('verifyPhoneCode', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { code } = request.params;
  if (!code || code.length !== 6) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid code format');
  }

  const hashedCode = crypto.createHash('sha256').update(code).digest('hex');

  const PhoneCode = Parse.Object.extend('PhoneVerificationCode');
  const query = new Parse.Query(PhoneCode);
  query.equalTo('userId', user.id);
  query.equalTo('code', hashedCode);
  query.equalTo('verified', false);
  query.greaterThan('expiresAt', new Date());
  query.descending('createdAt');
  const entry = await query.first({ useMasterKey: true });

  if (!entry) {
    // Brute-force mitigation
    const failQuery = new Parse.Query(PhoneCode);
    failQuery.equalTo('userId', user.id);
    failQuery.equalTo('verified', false);
    failQuery.greaterThan('createdAt', new Date(Date.now() - 10 * 60 * 1000));
    if ((await failQuery.count({ useMasterKey: true })) >= 10) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Too many failed attempts. Please request a new code.');
    }
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid or expired code');
  }

  entry.set('verified', true);
  entry.set('verifiedAt', new Date());
  await entry.save(null, { useMasterKey: true });

  user.set('isPhoneVerified', true);
  user.set('phoneVerifiedAt', new Date());
  user.set('phoneNumber', entry.get('phone'));
  await user.save(null, { useMasterKey: true });

  // Audit trail
  const OnboardingAudit = Parse.Object.extend('OnboardingAudit');
  const audit = new OnboardingAudit();
  audit.set('userId', user.id);
  audit.set('step', 'phoneVerification');
  audit.set('completedAt', new Date());
  audit.set('answers', { phone: entry.get('phone'), method: 'sms_otp_6digit' });
  audit.save(null, { useMasterKey: true }).catch(err => {
    console.error(`[OnboardingAudit] phone verification audit failed: ${err.message}`);
  });

  return { success: true, verified: true };
});
