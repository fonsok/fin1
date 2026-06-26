'use strict';

const { requireAdminRole } = require('../../utils/permissions');

const PASSWORD = 'TestPassword123!';
const SCHEMA_VERSION = 1;

const VALID_STEPS = [
  'legal_entity',
  'registered_address',
  'tax_compliance',
  'beneficial_owners',
  'authorized_representatives',
  'documents',
  'declarations',
  'submission',
];

/** Shared KYB payload (valid per companyKybStepSchemas.test.js). */
const KYB_STEP_DATA = {
  legal_entity: {
    legalName: 'FIN1 Test GmbH',
    legalForm: 'GmbH',
    registerType: 'HRB',
    registerNumber: 'KYB-TEST-001',
    registerCourt: 'Frankfurt am Main',
    incorporationCountry: 'DE',
  },
  registered_address: {
    streetAndNumber: 'Kaiserstraße 31',
    postalCode: '60311',
    city: 'Frankfurt am Main',
    country: 'DE',
  },
  tax_compliance: {
    vatId: 'DE123456789',
    nationalTaxNumber: '12/345/67890',
  },
  beneficial_owners: {
    ubos: [{
      fullName: 'David Braun',
      dateOfBirth: '1982-09-18',
      nationality: 'DE',
      ownershipPercent: 100,
      directOrIndirect: 'direct',
    }],
  },
  authorized_representatives: {
    representatives: [{
      fullName: 'David Braun',
      roleTitle: 'Geschäftsführer',
      signingAuthority: true,
    }],
    appAccountHolderIsRepresentative: true,
  },
  documents: {
    tradeRegisterExtractReference: 'REF-HR-KYB-TEST',
    documentsAcknowledged: true,
  },
  declarations: {
    isPoliticallyExposed: false,
    sanctionsSelfDeclarationAccepted: true,
    accuracyDeclarationAccepted: true,
    noTrustThirdPartyDeclarationAccepted: true,
  },
  submission: {
    confirmedSummary: true,
  },
};

/** Canonical company investor test accounts for KYB gate / wizard QA. */
const COMPANY_INVESTOR_VARIANTS = [
  {
    email: 'company1-draft@test.com',
    username: 'cinvdraft',
    firstName: 'Draft',
    lastName: 'CompanyInvestor',
    kybProfile: 'draft',
  },
  {
    email: 'company1-pending@test.com',
    username: 'cinvpend',
    firstName: 'Pending',
    lastName: 'CompanyInvestor',
    kybProfile: 'pending_review',
  },
  {
    email: 'company1-approved@test.com',
    username: 'cinvappr',
    firstName: 'Approved',
    lastName: 'CompanyInvestor',
    kybProfile: 'approved',
  },
];

const BASE_USER = {
  salutation: 'mr',
  dateOfBirth: '1982-09-18',
  streetAndNumber: 'Kaiserstraße 31',
  postalCode: '60311',
  city: 'Frankfurt am Main',
  state: 'Hessen',
  phoneNumber: '+49 69 56789099',
  nationality: 'DE',
  placeOfBirth: 'Frankfurt am Main',
  countryOfBirth: 'Deutschland',
  taxNumber: 'DE-KYB-COMP-001',
  employmentStatus: 'self_employed',
  incomeRange: 'range_100k_plus',
  riskTolerance: 5,
  investmentExperience: 5,
  financialProductsExperience: true,
};

async function findUserByEmail(email) {
  const q = new Parse.Query(Parse.User);
  q.equalTo('email', email);
  return q.first({ useMasterKey: true });
}

async function clearKybArtifacts(userId) {
  for (const className of ['CompanyKybAudit', 'CompanyKybProgress']) {
    const q = new Parse.Query(className);
    q.equalTo('userId', userId);
    q.limit(1000);
    const rows = await q.find({ useMasterKey: true });
    if (rows.length > 0) {
      await Parse.Object.destroyAll(rows, { useMasterKey: true });
    }
  }
}

async function writeKybAudits(userId, throughStepInclusive) {
  const endIndex = VALID_STEPS.indexOf(throughStepInclusive);
  if (endIndex < 0) return;

  const now = new Date();
  for (let i = 0; i <= endIndex; i += 1) {
    const step = VALID_STEPS[i];
    const data = KYB_STEP_DATA[step];
    const audit = new Parse.Object('CompanyKybAudit');
    audit.set('userId', userId);
    audit.set('step', step);
    audit.set('completedAt', now);
    audit.set('schemaVersion', SCHEMA_VERSION);
    audit.set('fullData', data);
    await audit.save(null, { useMasterKey: true });
  }
}

async function writeKybProgress(userId, step, mergedData) {
  const progress = new Parse.Object('CompanyKybProgress');
  progress.set('userId', userId);
  progress.set('step', step);
  progress.set('data', mergedData);
  progress.set('isPartial', false);
  progress.set('updatedAt', new Date());
  await progress.save(null, { useMasterKey: true });
}

function applyKybProfile(user, profile) {
  user.set('accountType', 'company');
  user.set('role', 'investor');

  if (profile === 'draft') {
    user.set('companyKybCompleted', false);
    user.set('companyKybStatus', 'draft');
    user.set('companyKybStep', 'legal_entity');
    user.unset('companyKybCompletedAt');
    user.unset('companyKybReviewedAt');
    user.unset('companyKybReviewedBy');
    user.unset('companyKybReviewNotes');
    return;
  }

  user.set('companyKybCompleted', true);
  user.set('companyKybStep', 'submission');
  user.set('companyKybCompletedAt', new Date());

  if (profile === 'pending_review') {
    user.set('companyKybStatus', 'pending_review');
    user.unset('companyKybReviewedAt');
    user.unset('companyKybReviewedBy');
    user.unset('companyKybReviewNotes');
    return;
  }

  if (profile === 'approved') {
    user.set('companyKybStatus', 'approved');
    user.set('companyKybReviewedAt', new Date());
    user.set('companyKybReviewedBy', 'seed-company-test-users');
    user.set('companyKybReviewNotes', 'Auto-approved for dev/QA (seedCompanyTestUsers)');
  }
}

async function upsertCompanyInvestor(variant, index) {
  const year = new Date().getFullYear();
  const customerNumber = `ANL-${year}-C${String(index + 1).padStart(4, '0')}`;

  let user = await findUserByEmail(variant.email);
  const isNew = !user;

  if (isNew) {
    user = new Parse.User();
    user.set('username', variant.username);
    user.set('email', variant.email);
    user.set('password', PASSWORD);
  }

  user.set('customerNumber', customerNumber);
  user.set('firstName', variant.firstName);
  user.set('lastName', variant.lastName);
  user.set('salutation', BASE_USER.salutation);
  user.set('dateOfBirth', BASE_USER.dateOfBirth);
  user.set('streetAndNumber', BASE_USER.streetAndNumber);
  user.set('postalCode', BASE_USER.postalCode);
  user.set('city', BASE_USER.city);
  user.set('state', BASE_USER.state);
  user.set('country', 'Deutschland');
  user.set('phoneNumber', BASE_USER.phoneNumber);
  user.set('nationality', BASE_USER.nationality);
  user.set('placeOfBirth', BASE_USER.placeOfBirth);
  user.set('countryOfBirth', BASE_USER.countryOfBirth);
  user.set('taxNumber', BASE_USER.taxNumber);
  user.set('isNotUSCitizen', true);
  user.set('employmentStatus', BASE_USER.employmentStatus);
  user.set('incomeRange', BASE_USER.incomeRange);
  user.set('riskTolerance', BASE_USER.riskTolerance);
  user.set('investmentExperience', BASE_USER.investmentExperience);
  user.set('financialProductsExperience', BASE_USER.financialProductsExperience);

  user.set('status', 'active');
  user.set('emailVerified', true);
  user.set('onboardingCompleted', true);
  user.set('kycStatus', 'verified');
  user.set('acceptedTerms', true);
  user.set('acceptedPrivacyPolicy', true);
  user.set('acceptedInvestorAgreement', true);
  user.set('acceptedInvestorAgreementVersion', '1.0');
  user.set('acceptedInvestorAgreementDate', new Date());
  user.set('moneyLaunderingDeclaration', true);
  user.set('identificationType', 'id_card');
  user.set('identificationConfirmed', true);
  user.set('addressConfirmed', true);

  applyKybProfile(user, variant.kybProfile);

  if (isNew) {
    await user.signUp(null, { useMasterKey: true });
  } else {
    await user.save(null, { useMasterKey: true });
  }

  await clearKybArtifacts(user.id);

  if (variant.kybProfile === 'draft') {
    await writeKybProgress(user.id, 'legal_entity', { ...KYB_STEP_DATA.legal_entity });
  } else {
    await writeKybAudits(user.id, 'submission');
    await writeKybProgress(user.id, 'submission', { ...KYB_STEP_DATA });
  }

  return {
    email: variant.email,
    objectId: user.id,
    customerNumber,
    companyKybStatus: user.get('companyKybStatus'),
    companyKybCompleted: user.get('companyKybCompleted'),
    kybProfile: variant.kybProfile,
    created: isNew,
  };
}

/**
 * Seeds company investor test users for KYB wizard + product gate QA.
 * Does not delete individual investor1..5 accounts.
 */
Parse.Cloud.define('seedCompanyTestUsers', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }

  const created = [];
  for (let i = 0; i < COMPANY_INVESTOR_VARIANTS.length; i += 1) {
    created.push(await upsertCompanyInvestor(COMPANY_INVESTOR_VARIANTS[i], i));
  }

  console.log(`✅ Seeded ${created.length} company investor test users.`);
  return {
    success: true,
    passwordHint: 'TestConstants.password / TestPassword123!',
    users: created,
  };
});

module.exports = {
  COMPANY_INVESTOR_VARIANTS,
  COMPANY_TEST_USER_EMAIL_REGEX: '^company1-(draft|pending|approved)@test\\.com$',
};
