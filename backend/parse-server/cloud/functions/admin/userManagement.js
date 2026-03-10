'use strict';

const { requireAdminRole } = require('../../utils/permissions');

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

  return {
    success: true,
    message: `Password reset for ${email}`,
    newPassword: newPassword,
    objectId: user.id
  };
});

Parse.Cloud.define('createTestUsers', async (request) => {
  console.log('📊 Creating test users...');

  const testUsers = [
    { username: 'trader3@test.com', email: 'trader3@test.com', role: 'trader', status: 'active' },
    { username: 'investor1@test.com', email: 'investor1@test.com', role: 'investor', status: 'active' },
    { username: 'investor2@test.com', email: 'investor2@test.com', role: 'investor', status: 'active' },
  ];

  const created = [];
  for (const userData of testUsers) {
    const existingQuery = new Parse.Query(Parse.User);
    existingQuery.equalTo('email', userData.email);
    const existing = await existingQuery.first({ useMasterKey: true });

    if (existing) {
      created.push({ email: userData.email, status: 'already exists', objectId: existing.id });
      continue;
    }

    const user = new Parse.User();
    user.set('username', userData.username);
    user.set('email', userData.email);
    user.set('password', 'TestPassword123!Secure');
    user.set('role', userData.role);
    user.set('status', userData.status);

    await user.signUp(null, { useMasterKey: true });
    created.push({ email: userData.email, status: 'created', objectId: user.id });
  }

  return { success: true, users: created };
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
