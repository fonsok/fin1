'use strict';

const { MongoClient } = require('mongodb');

const LOCKOUT_FIELDS = ['_failed_login_count', '_account_lockout_expires_at'];

let mongoPromise;

function getDatabaseUri() {
  const uri = process.env.PARSE_SERVER_DATABASE_URI;
  if (!uri || typeof uri !== 'string' || !uri.trim()) {
    return null;
  }
  return uri.trim();
}

async function getMongoDb() {
  const uri = getDatabaseUri();
  if (!uri) {
    return null;
  }
  if (!mongoPromise) {
    mongoPromise = (async () => {
      const client = new MongoClient(uri, { maxPoolSize: 5 });
      await client.connect();
      return { client, db: client.db() };
    })();
  }
  const { db } = await mongoPromise;
  return db;
}

/**
 * Clears Parse Server account-lockout fields on _User (see AccountLockout.js).
 * REST PUT with Delete ops does not reliably remove internal underscore fields;
 * use MongoDB $unset on the same database as Parse Server.
 */
async function clearAccountLockoutForUserObjectId(objectId) {
  if (!objectId) {
    return;
  }

  const db = await getMongoDb();
  if (!db) {
    throw new Parse.Error(
      Parse.Error.INTERNAL_SERVER_ERROR,
      'PARSE_SERVER_DATABASE_URI is missing — account lockout cannot be cleared.',
    );
  }

  const unset = LOCKOUT_FIELDS.reduce((acc, field) => {
    acc[field] = '';
    return acc;
  }, {});

  const result = await db.collection('_User').updateOne(
    { _id: objectId },
    {
      $unset: unset,
      $set: { failedLoginCount: 0 },
    },
  );

  if (result.matchedCount !== 1) {
    throw new Parse.Error(
      Parse.Error.OBJECT_NOT_FOUND,
      `User not found for lockout clear: ${objectId}`,
    );
  }
}

/**
 * Master key only: immediately clear Parse account lockout for a user (no password change).
 * Params: { email: string }
 */
async function handleUnlockParseAccountLockout(request) {
  if (!request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Master key required');
  }
  const email = (request.params && request.params.email && String(request.params.email).toLowerCase().trim()) || '';
  if (!email) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'email is required');
  }

  const q = new Parse.Query(Parse.User);
  q.equalTo('email', email);
  let user = await q.first({ useMasterKey: true });
  if (!user) {
    const qu = new Parse.Query(Parse.User);
    qu.equalTo('username', email);
    user = await qu.first({ useMasterKey: true });
  }
  if (!user) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, `User not found: ${email}`);
  }

  await clearAccountLockoutForUserObjectId(user.id);
  return {
    success: true,
    message: `Account lockout cleared for ${user.get('email') || email}`,
    objectId: user.id,
  };
}

module.exports = {
  clearAccountLockoutForUserObjectId,
  handleUnlockParseAccountLockout,
  __resetAccountLockoutMongoForTests: async () => {
    if (!mongoPromise) {
      return;
    }
    try {
      const { client } = await mongoPromise;
      await client.close();
    } catch {
      // ignore
    }
    mongoPromise = null;
  },
};
