// ============================================================================
// One-time migration: encrypt existing plaintext PII in MongoDB
// functions/encryptExistingData.js
//
// Run via: Parse.Cloud.run('encryptExistingData', {}, { useMasterKey: true })
//   or:   curl -X POST .../parse/functions/encryptExistingData \
//            -H "X-Parse-Application-Id: ..." \
//            -H "X-Parse-Master-Key: ..."
// ============================================================================

'use strict';

const {
  encrypt,
  encryptObject,
  isEncrypted,
  isKeyConfigured,
} = require('../utils/fieldEncryption');

Parse.Cloud.define('encryptExistingData', async (request) => {
  if (!request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Master key required');
  }

  if (!isKeyConfigured()) {
    throw new Parse.Error(Parse.Error.INTERNAL_SERVER_ERROR,
      'FIELD_ENCRYPTION_KEY is not configured');
  }

  const stats = {
    userProfile: { scanned: 0, encrypted: 0 },
    onboardingProgress: { scanned: 0, encrypted: 0 },
    onboardingAudit: { scanned: 0, encrypted: 0 },
    user: { scanned: 0, encrypted: 0 },
  };

  // --- UserProfile ---
  const profileFields = ['firstName', 'lastName', 'dateOfBirth', 'mobilePhone'];
  let profileSkip = 0;
  while (true) {
    const q = new Parse.Query('UserProfile');
    q.limit(100);
    q.skip(profileSkip);
    const batch = await q.find({ useMasterKey: true });
    if (batch.length === 0) break;

    for (const obj of batch) {
      stats.userProfile.scanned++;
      let changed = false;
      for (const field of profileFields) {
        const val = obj.get(field);
        if (val != null && val !== '' && !isEncrypted(String(val))) {
          obj.set(field, encrypt(String(val)));
          changed = true;
        }
      }
      if (changed) {
        await obj.save(null, { useMasterKey: true, context: { skipEncryptionTrigger: true } });
        stats.userProfile.encrypted++;
      }
    }
    profileSkip += batch.length;
  }

  // --- OnboardingProgress (data blob) ---
  let progressSkip = 0;
  while (true) {
    const q = new Parse.Query('OnboardingProgress');
    q.limit(100);
    q.skip(progressSkip);
    const batch = await q.find({ useMasterKey: true });
    if (batch.length === 0) break;

    for (const obj of batch) {
      stats.onboardingProgress.scanned++;
      const val = obj.get('data');
      if (val != null && typeof val === 'object') {
        obj.set('data', encryptObject(val));
        await obj.save(null, { useMasterKey: true, context: { skipEncryptionTrigger: true } });
        stats.onboardingProgress.encrypted++;
      }
    }
    progressSkip += batch.length;
  }

  // --- OnboardingAudit (answers blob) ---
  let auditSkip = 0;
  while (true) {
    const q = new Parse.Query('OnboardingAudit');
    q.limit(100);
    q.skip(auditSkip);
    const batch = await q.find({ useMasterKey: true });
    if (batch.length === 0) break;

    for (const obj of batch) {
      stats.onboardingAudit.scanned++;
      const val = obj.get('answers');
      if (val != null && typeof val === 'object') {
        obj.set('answers', encryptObject(val));
        await obj.save(null, { useMasterKey: true, context: { skipEncryptionTrigger: true } });
        stats.onboardingAudit.encrypted++;
      }
    }
    auditSkip += batch.length;
  }

  // --- _User (phone_number) ---
  let userSkip = 0;
  while (true) {
    const q = new Parse.Query(Parse.User);
    q.limit(100);
    q.skip(userSkip);
    const batch = await q.find({ useMasterKey: true });
    if (batch.length === 0) break;

    for (const obj of batch) {
      stats.user.scanned++;
      const phone = obj.get('phone_number');
      if (phone && !isEncrypted(phone)) {
        obj.set('phone_number', encrypt(phone));
        await obj.save(null, { useMasterKey: true, context: { skipEncryptionTrigger: true } });
        stats.user.encrypted++;
      }
    }
    userSkip += batch.length;
  }

  console.log('[encryptExistingData] Migration complete:', JSON.stringify(stats, null, 2));
  return { success: true, stats };
});
