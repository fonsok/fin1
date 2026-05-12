'use strict';

const { clearAccountLockoutForUserObjectId } = require('./usersAdminAccountLockout');

async function handleCreateAdminUser(request) {
  const { email, password, firstName, lastName, forcePasswordReset, role: requestedRole } = request.params;

  if (!email || !password) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'Email and password are required');
  }

  const ALLOWED_PORTAL_ROLES = ['admin', 'business_admin', 'security_officer', 'compliance'];
  const targetRole = requestedRole || 'admin';
  if (!ALLOWED_PORTAL_ROLES.includes(targetRole)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Role must be one of: ${ALLOWED_PORTAL_ROLES.join(', ')}`);
  }

  const emailNorm = email.toLowerCase().trim();

  const existingQuery = new Parse.Query(Parse.User);
  existingQuery.equalTo('email', emailNorm);
  let existing = await existingQuery.first({ useMasterKey: true });
  if (!existing) {
    const usernameQuery = new Parse.Query(Parse.User);
    usernameQuery.equalTo('username', emailNorm);
    existing = await usernameQuery.first({ useMasterKey: true });
  }

  if (existing) {
    const currentRole = existing.get('role');
    const roleChanged = currentRole !== targetRole;
    const updatePassword = forcePasswordReset === true || roleChanged;

    existing.set('role', targetRole);
    existing.set('status', 'active');
    existing.set('username', emailNorm);
    existing.set('email', emailNorm);
    if (updatePassword) {
      existing.set('password', password);
    }
    if (firstName) existing.set('firstName', firstName);
    if (lastName) existing.set('lastName', lastName);
    await existing.save(null, { useMasterKey: true });
    await clearAccountLockoutForUserObjectId(existing.id);

    return {
      success: true,
      message: roleChanged
        ? `User ${email} wurde auf Rolle '${targetRole}' aktualisiert`
        : (updatePassword ? `${targetRole} ${email} – Passwort wurde zurückgesetzt` : `${targetRole} ${email} existiert bereits`),
      user: {
        objectId: existing.id,
        email: existing.get('email'),
        username: existing.get('username'),
        role: existing.get('role'),
        status: existing.get('status'),
      },
    };
  }

  const user = new Parse.User();
  user.set('username', emailNorm);
  user.set('email', emailNorm);
  user.set('password', password);
  user.set('role', targetRole);
  user.set('status', 'active');
  user.set('emailVerified', true);
  user.set('onboardingCompleted', true);
  user.set('kycStatus', 'verified');

  if (firstName) user.set('firstName', firstName);
  if (lastName) user.set('lastName', lastName);

  await user.signUp(null, { useMasterKey: true });
  await clearAccountLockoutForUserObjectId(user.id);

  return {
    success: true,
    message: `${targetRole} user ${email} created successfully`,
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
  handleCreateAdminUser,
};
