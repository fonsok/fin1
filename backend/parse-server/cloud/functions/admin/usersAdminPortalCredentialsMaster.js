'use strict';

const { clearAccountLockoutForUserObjectId } = require('./usersAdminAccountLockout');

const PORTAL_PASSWORD_RESET_ROLES = [
  'admin',
  'business_admin',
  'security_officer',
  'compliance',
  'customer_service',
];

/**
 * Master key only — production-safe operator path when a portal user cannot log in:
 * always sets a new password, normalizes email/username, ensures active status, clears Parse account lockout.
 * Does not echo the password in the response.
 *
 * Params: { email, password, role? (default: keep existing if already portal role; else required), firstName?, lastName? }
 */
async function handleResetPortalUserCredentialsMaster(request) {
  if (!request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Master key required');
  }

  const params = request.params || {};
  const emailRaw = params.email;
  const password = params.password;

  if (!emailRaw || typeof emailRaw !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'email is required');
  }
  if (!password || typeof password !== 'string' || password.length < 8) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'password is required (min 8 characters)');
  }

  const emailNorm = emailRaw.toLowerCase().trim();
  let targetRole = params.role;

  const q = new Parse.Query(Parse.User);
  q.equalTo('email', emailNorm);
  let user = await q.first({ useMasterKey: true });
  if (!user) {
    const qu = new Parse.Query(Parse.User);
    qu.equalTo('username', emailNorm);
    user = await qu.first({ useMasterKey: true });
  }
  if (!user) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, `User not found: ${emailNorm}`);
  }

  const currentRole = user.get('role');
  if (!targetRole) {
    if (!PORTAL_PASSWORD_RESET_ROLES.includes(currentRole)) {
      throw new Parse.Error(
        Parse.Error.OPERATION_FORBIDDEN,
        `User role '${currentRole}' is not a portal role; pass role in params`
      );
    }
    targetRole = currentRole;
  }
  if (!PORTAL_PASSWORD_RESET_ROLES.includes(targetRole)) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      `role must be one of: ${PORTAL_PASSWORD_RESET_ROLES.join(', ')}`
    );
  }

  user.set('username', emailNorm);
  user.set('email', emailNorm);
  user.set('role', targetRole);
  user.set('status', 'active');
  user.set('password', password);
  if (params.firstName) {
    user.set('firstName', params.firstName);
  }
  if (params.lastName) {
    user.set('lastName', params.lastName);
  }

  await user.save(null, { useMasterKey: true });
  await clearAccountLockoutForUserObjectId(user.id);

  return {
    success: true,
    message: `Portal credentials reset for ${user.get('email')}`,
    user: {
      objectId: user.id,
      email: user.get('email'),
      username: user.get('username'),
      role: user.get('role'),
      status: user.get('status'),
    },
  };
}

module.exports = {
  handleResetPortalUserCredentialsMaster,
};
