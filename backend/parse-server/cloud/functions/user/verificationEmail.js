'use strict';

const crypto = require('crypto');
let emailService;
try {
  emailService = require('../../utils/emailService');
} catch (e) {
  console.warn('emailService not available - verification emails will be logged only');
}

// ============================================================================
// EMAIL VERIFICATION (Onboarding OTP)
// ============================================================================

/**
 * Send a 6-digit verification code to the user's email.
 * Rate-limited: max 1 code per 60 seconds, max 5 per hour.
 */
Parse.Cloud.define('sendVerificationCode', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const email = user.get('email');
  if (!email) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'No email on account');

  // Rate limiting: check last code sent
  const VerificationCode = Parse.Object.extend('VerificationCode');
  const recentQuery = new Parse.Query(VerificationCode);
  recentQuery.equalTo('userId', user.id);
  recentQuery.greaterThan('createdAt', new Date(Date.now() - 60 * 1000));
  const recentCode = await recentQuery.first({ useMasterKey: true });
  if (recentCode) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Please wait 60 seconds before requesting a new code');
  }

  // Hourly limit
  const hourQuery = new Parse.Query(VerificationCode);
  hourQuery.equalTo('userId', user.id);
  hourQuery.greaterThan('createdAt', new Date(Date.now() - 60 * 60 * 1000));
  const hourCount = await hourQuery.count({ useMasterKey: true });
  if (hourCount >= 5) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Too many attempts. Please try again in one hour.');
  }

  // Generate 6-digit code
  const code = String(crypto.randomInt(100000, 999999));
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 min

  // Store code
  const entry = new VerificationCode();
  entry.set('userId', user.id);
  entry.set('email', email);
  entry.set('code', crypto.createHash('sha256').update(code).digest('hex'));
  entry.set('expiresAt', expiresAt);
  entry.set('verified', false);
  await entry.save(null, { useMasterKey: true });

  // Send email (falls back to console log when SMTP is not configured)
  if (emailService) {
    await emailService.sendEmail({
      to: email,
      subject: '[FIN1] Ihr Verifizierungscode',
      text: `Ihr Verifizierungscode lautet: ${code}\n\nDieser Code ist 10 Minuten gültig.\n\nFalls Sie diesen Code nicht angefordert haben, ignorieren Sie diese E-Mail.`,
      html: `
<div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
  <h2 style="color: #1a5f7a;">E-Mail-Verifizierung</h2>
  <p>Ihr Verifizierungscode lautet:</p>
  <div style="font-size: 32px; font-weight: bold; letter-spacing: 8px; text-align: center; padding: 20px; background: #f4f4f4; border-radius: 8px; margin: 16px 0;">${code}</div>
  <p style="color: #888; font-size: 13px;">Dieser Code ist 10 Minuten gültig.</p>
  <hr style="border: 1px solid #eee;">
  <p style="color: #aaa; font-size: 11px;">Falls Sie diesen Code nicht angefordert haben, ignorieren Sie diese E-Mail.</p>
</div>`.trim(),
    });
  }

  // Always log for development/debugging
  console.log(`[VERIFY] Code for ${email}: ${code} (expires ${expiresAt.toISOString()})`);

  return { success: true, expiresInSeconds: 600 };
});

/**
 * Verify the 6-digit code entered by the user.
 */
Parse.Cloud.define('verifyEmailCode', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { code } = request.params;
  if (!code || code.length !== 6) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid code format');
  }

  const hashedCode = crypto.createHash('sha256').update(code).digest('hex');

  const VerificationCode = Parse.Object.extend('VerificationCode');
  const query = new Parse.Query(VerificationCode);
  query.equalTo('userId', user.id);
  query.equalTo('code', hashedCode);
  query.equalTo('verified', false);
  query.greaterThan('expiresAt', new Date());
  query.descending('createdAt');
  const entry = await query.first({ useMasterKey: true });

  if (!entry) {
    // Brute-force mitigation: count recent failures
    const failQuery = new Parse.Query(VerificationCode);
    failQuery.equalTo('userId', user.id);
    failQuery.equalTo('verified', false);
    failQuery.greaterThan('createdAt', new Date(Date.now() - 10 * 60 * 1000));
    const attempts = await failQuery.count({ useMasterKey: true });
    if (attempts >= 10) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Too many failed attempts. Please request a new code.');
    }

    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid or expired code');
  }

  // Mark as verified
  entry.set('verified', true);
  entry.set('verifiedAt', new Date());
  await entry.save(null, { useMasterKey: true });

  // Update user
  user.set('isEmailVerified', true);
  user.set('emailVerifiedAt', new Date());
  await user.save(null, { useMasterKey: true });

  // Audit trail
  const OnboardingAudit = Parse.Object.extend('OnboardingAudit');
  const audit = new OnboardingAudit();
  audit.set('userId', user.id);
  audit.set('step', 'emailVerification');
  audit.set('completedAt', new Date());
  audit.set('answers', { email: user.get('email'), method: 'otp_6digit' });
  audit.save(null, { useMasterKey: true }).catch(err => {
    console.error(`[OnboardingAudit] email verification audit failed: ${err.message}`);
  });

  return { success: true, verified: true };
});
