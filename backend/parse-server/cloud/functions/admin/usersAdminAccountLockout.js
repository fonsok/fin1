'use strict';

/**
 * Clears Parse Server account-lockout fields on _User (see node_modules/parse-server/lib/AccountLockout.js).
 * Master-key PUT on /users/:id with Delete ops — same mechanism as unlockAccount() when unlockOnPasswordReset is true.
 */
async function clearAccountLockoutForUserObjectId(objectId) {
  if (!objectId) {
    return;
  }
  const port = String(process.env.PORT || '1337');
  const basePath = (process.env.PARSE_SERVER_INTERNAL_PARSE_PATH || '/parse').replace(/\/$/, '');
  const host = process.env.PARSE_SERVER_LOCKOUT_CLEAR_HOST || '127.0.0.1';
  const url = `http://${host}:${port}${basePath}/users/${objectId}`;
  const appId = process.env.PARSE_SERVER_APPLICATION_ID || 'fin1-app-id';
  const masterKey = process.env.PARSE_SERVER_MASTER_KEY || 'fin1-master-key';

  const res = await fetch(url, {
    method: 'PUT',
    headers: {
      'X-Parse-Application-Id': appId,
      'X-Parse-Master-Key': masterKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      _failed_login_count: { __op: 'Delete' },
      _account_lockout_expires_at: { __op: 'Delete' },
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    console.error(`clearAccountLockoutForUserObjectId failed: ${res.status} ${body}`);
    throw new Parse.Error(
      Parse.Error.INTERNAL_SERVER_ERROR,
      `Account lockout could not be cleared (HTTP ${res.status}). Check parse logs.`
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
};
