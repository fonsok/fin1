'use strict';

const { requireAdminRole } = require('../../utils/permissions');

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
Parse.Cloud.define('unlockParseAccountLockout', async (request) => {
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
});

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
Parse.Cloud.define('resetPortalUserCredentialsMaster', async (request) => {
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
});

Parse.Cloud.define('getTestUserDetails', async (request) => {
  const { userId } = request.params;
  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId required');
  }

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
  const role = user.get('role');

  let trades = [];
  let tradeSummary = null;
  if (role === 'trader') {
    const tradeQuery = new Parse.Query('Trade');
    tradeQuery.equalTo('traderId', `user:${user.get('email')}`);
    tradeQuery.descending('createdAt');
    tradeQuery.limit(10);
    const rawTrades = await tradeQuery.find({ useMasterKey: true });

    trades = await Promise.all(rawTrades.map(async (t) => {
      const participationQuery = new Parse.Query('PoolTradeParticipation');
      participationQuery.equalTo('tradeId', t.id);
      const participations = await participationQuery.find({ useMasterKey: true });

      const createdAt = t.get('createdAt');
      const completedAt = t.get('completedAt');
      return {
        objectId: t.id,
        tradeNumber: t.get('tradeNumber'),
        symbol: t.get('symbol'),
        description: t.get('description'),
        status: t.get('status'),
        grossProfit: t.get('grossProfit'),
        totalFees: t.get('totalFees'),
        createdAt: createdAt instanceof Date ? createdAt.toISOString() : createdAt,
        completedAt: completedAt instanceof Date ? completedAt.toISOString() : completedAt,
        investors: participations.map(p => ({
          investorId: p.get('investorId'),
          investorName: p.get('investorName'),
          ownershipPercentage: p.get('ownershipPercentage'),
          investedAmount: p.get('allocatedAmount'),
          profitShare: p.get('profitShare'),
          isSettled: p.get('isSettled')
        }))
      };
    }));

    const completedTrades = rawTrades.filter(t => t.get('status') === 'completed');
    tradeSummary = {
      totalTrades: rawTrades.length,
      completedTrades: completedTrades.length,
      activeTrades: rawTrades.filter(t => ['pending', 'active', 'partial'].includes(t.get('status'))).length,
      totalProfit: completedTrades.reduce((sum, t) => sum + (t.get('grossProfit') || 0), 0),
      totalCommission: completedTrades.reduce((sum, t) => sum + (t.get('totalFees') || 0), 0),
    };
  }

  const userCreatedAt = user.get('createdAt');
  return {
    user: {
      objectId: user.id,
      email: user.get('email'),
      username: user.get('username'),
      role: user.get('role'),
      status: user.get('status') || 'active',
      createdAt: userCreatedAt instanceof Date ? userCreatedAt.toISOString() : userCreatedAt,
    },
    tradeSummary,
    trades,
  };
});

Parse.Cloud.define('resetDevUserPassword', async (request) => {
  const { email } = request.params;
  const newPassword = 'DevTest123!Secure';

  const query = new Parse.Query(Parse.User);
  query.equalTo('email', email);
  const user = await query.first({ useMasterKey: true });

  if (!user) {
    return { success: false, message: 'User not found' };
  }

  user.set('password', newPassword);
  await user.save(null, { useMasterKey: true });
  await clearAccountLockoutForUserObjectId(user.id);

  return {
    success: true,
    message: `Password reset for ${email}`,
    newPassword: newPassword,
    objectId: user.id
  };
});

Parse.Cloud.define('createTestUsers', async (request) => {
  console.log('📊 Redirecting to seedTestUsers for full user provisioning...');
  return await Parse.Cloud.run('seedTestUsers', {}, { sessionToken: request.user?.getSessionToken?.() || undefined });
});

Parse.Cloud.define('createAdminUser', async (request) => {
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
});

Parse.Cloud.define('createCSRUser', async (request) => {
  if (request.user && !request.master) {
    requireAdminRole(request);
  }

  const { email, password, firstName, lastName } = request.params;

  if (!email || !password) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'Email and password are required');
  }

  const emailLower = email.toLowerCase();
  let csrSubRole = null;

  if (emailLower.includes('l1@') || emailLower.includes('level1@') || emailLower.includes('csr1@')) {
    csrSubRole = 'level_1';
  } else if (emailLower.includes('l2@') || emailLower.includes('level2@') || emailLower.includes('csr2@')) {
    csrSubRole = 'level_2';
  } else if (emailLower.includes('fraud@')) {
    csrSubRole = 'fraud_analyst';
  } else if (emailLower.includes('compliance@')) {
    csrSubRole = 'compliance_officer';
  } else if (emailLower.includes('tech@') || emailLower.includes('technical@')) {
    csrSubRole = 'tech_support';
  } else if (emailLower.includes('lead@') || emailLower.includes('teamlead@')) {
    csrSubRole = 'teamlead';
  }

  const existingQuery = new Parse.Query(Parse.User);
  existingQuery.equalTo('email', email.toLowerCase().trim());
  const existing = await existingQuery.first({ useMasterKey: true });

  if (existing) {
    if (existing.get('role') !== 'customer_service') {
      existing.set('role', 'customer_service');
      existing.set('status', 'active');
      if (password) {
        existing.set('password', password);
      }
    }
    if (csrSubRole) {
      existing.set('csrSubRole', csrSubRole);
    }
    await existing.save(null, { useMasterKey: true });
    return {
      success: true,
      message: `User ${email} updated to CSR role${csrSubRole ? ` (${csrSubRole})` : ''}`,
      user: {
        objectId: existing.id,
        email: existing.get('email'),
        role: existing.get('role'),
        csrSubRole: existing.get('csrSubRole'),
        status: existing.get('status')
      }
    };
  }

  const user = new Parse.User();
  user.set('username', email.toLowerCase().trim());
  user.set('email', email.toLowerCase().trim());
  user.set('password', password);
  user.set('role', 'customer_service');
  user.set('status', 'active');
  user.set('emailVerified', true);
  user.set('onboardingCompleted', true);
  user.set('kycStatus', 'verified');

  if (csrSubRole) {
    user.set('csrSubRole', csrSubRole);
  }

  if (firstName) {
    user.set('firstName', firstName);
  }
  if (lastName) {
    user.set('lastName', lastName);
  }

  await user.signUp(null, { useMasterKey: true });

  return {
    success: true,
    message: `CSR user ${email} created successfully${csrSubRole ? ` with sub-role ${csrSubRole}` : ''}`,
    user: {
      objectId: user.id,
      email: user.get('email'),
      username: user.get('username'),
      role: user.get('role'),
      csrSubRole: user.get('csrSubRole'),
      status: user.get('status')
    }
  };
});
