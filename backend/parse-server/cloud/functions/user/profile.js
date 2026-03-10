'use strict';

const { sanitizeObject, validateProfileUpdate } = require('../../utils/validation');

// ============================================================================
// USER PROFILE
// ============================================================================

Parse.Cloud.define('getUserProfile', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const profileQuery = new Parse.Query('UserProfile');
  profileQuery.equalTo('userId', user.id);
  const profile = await profileQuery.first({ useMasterKey: true });

  const addressQuery = new Parse.Query('UserAddress');
  addressQuery.equalTo('userId', user.id);
  addressQuery.equalTo('isPrimary', true);
  const address = await addressQuery.first({ useMasterKey: true });

  const riskQuery = new Parse.Query('UserRiskAssessment');
  riskQuery.equalTo('userId', user.id);
  riskQuery.descending('validFrom');
  const risk = await riskQuery.first({ useMasterKey: true });

  return {
    user: {
      id: user.id,
      customerId: user.get('customerId'),
      email: user.get('email'),
      role: user.get('role'),
      status: user.get('status'),
      kycStatus: user.get('kycStatus'),
      onboardingCompleted: user.get('onboardingCompleted')
    },
    profile: profile ? profile.toJSON() : null,
    address: address ? address.toJSON() : null,
    riskAssessment: risk ? risk.toJSON() : null
  };
});

Parse.Cloud.define('updateProfile', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const params = sanitizeObject(request.params);
  const { firstName, lastName, salutation, dateOfBirth, phoneNumber } = params;

  const check = validateProfileUpdate(params);
  if (!check.valid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, check.message);
  }

  const profileQuery = new Parse.Query('UserProfile');
  profileQuery.equalTo('userId', user.id);
  let profile = await profileQuery.first({ useMasterKey: true });

  if (!profile) {
    const UserProfile = Parse.Object.extend('UserProfile');
    profile = new UserProfile();
    profile.set('userId', user.id);
  }

  if (firstName) profile.set('firstName', firstName);
  if (lastName) profile.set('lastName', lastName);
  if (salutation) profile.set('salutation', salutation);
  if (dateOfBirth) profile.set('dateOfBirth', new Date(dateOfBirth));
  if (phoneNumber) {
    profile.set('mobilePhone', phoneNumber);
    user.set('phone_number', phoneNumber);
    await user.save(null, { useMasterKey: true });
  }

  await profile.save(null, { useMasterKey: true });

  return { success: true };
});
