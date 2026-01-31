// ============================================================================
// FIN1 Parse Cloud Code
// functions/user.js - User Functions
// ============================================================================

'use strict';

// Get user profile
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

// Update profile
Parse.Cloud.define('updateProfile', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { firstName, lastName, salutation, dateOfBirth, phoneNumber } = request.params;

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

// Complete onboarding step
Parse.Cloud.define('completeOnboardingStep', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { step, data } = request.params;

  const validSteps = ['personal', 'address', 'tax', 'experience', 'risk', 'consents', 'verification'];
  if (!validSteps.includes(step)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid step');
  }

  user.set('onboardingStep', step);

  // If last step, mark complete
  if (step === 'verification') {
    user.set('onboardingCompleted', true);
    user.set('onboardingCompletedAt', new Date());

    // If KYC was auto-approved
    if (data && data.kycApproved) {
      user.set('kycStatus', 'verified');
      user.set('kycVerifiedAt', new Date());
    } else {
      user.set('kycStatus', 'in_progress');
    }
  }

  await user.save(null, { useMasterKey: true });

  return {
    success: true,
    nextStep: validSteps[validSteps.indexOf(step) + 1] || null,
    onboardingCompleted: user.get('onboardingCompleted')
  };
});

// Get FAQ
Parse.Cloud.define('getFAQs', async (request) => {
  const { categorySlug, isPublic } = request.params;

  const query = new Parse.Query('FAQ');
  query.equalTo('isPublished', true);
  query.equalTo('isArchived', false);

  if (isPublic) {
    query.equalTo('isPublic', true);
  } else if (request.user) {
    query.equalTo('isUserVisible', true);
  } else {
    query.equalTo('isPublic', true);
  }

  if (categorySlug) {
    const catQuery = new Parse.Query('FAQCategory');
    catQuery.equalTo('slug', categorySlug);
    const category = await catQuery.first({ useMasterKey: true });
    if (category) {
      query.equalTo('categoryId', category.id);
    }
  }

  query.ascending('sortOrder');
  const faqs = await query.find({ useMasterKey: true });

  return { faqs: faqs.map(f => f.toJSON()) };
});

// Get FAQ categories
Parse.Cloud.define('getFAQCategories', async (request) => {
  const { location } = request.params; // 'landing', 'help_center', 'csr'

  const query = new Parse.Query('FAQCategory');
  query.equalTo('isActive', true);

  if (location === 'landing') {
    query.equalTo('showOnLanding', true);
  } else if (location === 'help_center') {
    query.equalTo('showInHelpCenter', true);
  } else if (location === 'csr') {
    query.equalTo('showInCSR', true);
  }

  query.ascending('sortOrder');
  const categories = await query.find({ useMasterKey: true });

  return { categories: categories.map(c => c.toJSON()) };
});
