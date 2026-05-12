'use strict';

const { requireAdminRole } = require('../../utils/permissions');

async function handleCreateCsrUser(request) {
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
}

module.exports = {
  handleCreateCsrUser,
};
