'use strict';

const { MongoClient } = require('mongodb');

async function createIndexIfMissing(collection, keys, options) {
  const name = options.name;
  const existing = (await collection.indexes()).find((index) => index.name === name);
  if (existing) {
    return { name, status: 'already_present' };
  }
  await collection.createIndex(keys, options);
  return { name, status: 'created' };
}

/**
 * Compound indexes for signup / onboarding hot paths.
 */
async function createOnboardingIndexes() {
  const uri = process.env.PARSE_SERVER_DATABASE_URI;
  if (!uri || typeof uri !== 'string' || !uri.trim()) {
    return { ok: true, skipped: true, reason: 'PARSE_SERVER_DATABASE_URI missing' };
  }

  const client = new MongoClient(uri.trim(), { maxPoolSize: 2 });
  await client.connect();

  try {
    const db = client.db();
    const results = [];

    results.push(await createIndexIfMissing(
      db.collection('OnboardingProgress'),
      { userId: 1, updatedAt: -1 },
      { name: 'onboarding_progress_user_updated' },
    ));

    results.push(await createIndexIfMissing(
      db.collection('OnboardingAudit'),
      { userId: 1, completedAt: 1 },
      { name: 'onboarding_audit_user_completed' },
    ));

    results.push(await createIndexIfMissing(
      db.collection('VerificationCode'),
      { userId: 1, createdAt: -1 },
      { name: 'verification_code_user_created' },
    ));

    results.push(await createIndexIfMissing(
      db.collection('PhoneVerificationCode'),
      { userId: 1, createdAt: -1 },
      { name: 'phone_verification_code_user_created' },
    ));

    results.push(await createIndexIfMissing(
      db.collection('_User'),
      { customerNumber: 1 },
      { name: 'user_customer_number_1', sparse: true },
    ));

    return { ok: true, indexes: results };
  } finally {
    await client.close();
  }
}

module.exports = {
  createOnboardingIndexes,
};
