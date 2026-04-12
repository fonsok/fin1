'use strict';

const { requireAdminRole } = require('../../utils/permissions');

// ============================================================================
// 5 Investors (ANL-) + 10 Traders (TRD-)
// All users are fully onboarded with KYC verified, as if they completed
// the registration process including PostIdent verification.
// ============================================================================

const INVESTORS = [
  {
    email: 'investor1@test.com', username: 'mfischer',
    firstName: 'Maximilian', lastName: 'Fischer',
    salutation: 'mr', dateOfBirth: '1985-03-15',
    streetAndNumber: 'Friedrichstraße 44', postalCode: '10117', city: 'Berlin', state: 'Berlin',
    phoneNumber: '+49 30 12345601', nationality: 'DE',
    placeOfBirth: 'Berlin', countryOfBirth: 'Deutschland',
    taxNumber: 'DE123456781', employmentStatus: 'employed', incomeRange: 'range_50k_100k',
    riskTolerance: 5, investmentExperience: 3, financialProductsExperience: true,
  },
  {
    email: 'investor2@test.com', username: 'smueller',
    firstName: 'Sophie', lastName: 'Müller',
    salutation: 'ms', dateOfBirth: '1990-07-22',
    streetAndNumber: 'Maximilianstraße 12', postalCode: '80539', city: 'München', state: 'Bayern',
    phoneNumber: '+49 89 23456702', nationality: 'DE',
    placeOfBirth: 'München', countryOfBirth: 'Deutschland',
    taxNumber: 'DE234567892', employmentStatus: 'self_employed', incomeRange: 'range_100k_plus',
    riskTolerance: 7, investmentExperience: 5, financialProductsExperience: true,
  },
  {
    email: 'investor3@test.com', username: 'oschneider',
    firstName: 'Oliver', lastName: 'Schneider',
    salutation: 'mr', dateOfBirth: '1978-11-03',
    streetAndNumber: 'Königsallee 88', postalCode: '40212', city: 'Düsseldorf', state: 'Nordrhein-Westfalen',
    phoneNumber: '+49 211 34567803', nationality: 'DE',
    placeOfBirth: 'Düsseldorf', countryOfBirth: 'Deutschland',
    taxNumber: 'DE345678903', employmentStatus: 'employed', incomeRange: 'range_50k_100k',
    riskTolerance: 3, investmentExperience: 2, financialProductsExperience: false,
  },
  {
    email: 'investor4@test.com', username: 'eweber',
    firstName: 'Emma', lastName: 'Weber',
    salutation: 'ms', dateOfBirth: '1995-01-30',
    streetAndNumber: 'Jungfernstieg 7', postalCode: '20354', city: 'Hamburg', state: 'Hamburg',
    phoneNumber: '+49 40 45678904', nationality: 'DE',
    placeOfBirth: 'Hamburg', countryOfBirth: 'Deutschland',
    taxNumber: 'DE456789014', employmentStatus: 'employed', incomeRange: 'range_25k_50k',
    riskTolerance: 4, investmentExperience: 1, financialProductsExperience: false,
  },
  {
    email: 'investor5@test.com', username: 'dbraun',
    firstName: 'David', lastName: 'Braun',
    salutation: 'mr', dateOfBirth: '1982-09-18',
    streetAndNumber: 'Kaiserstraße 31', postalCode: '60311', city: 'Frankfurt am Main', state: 'Hessen',
    phoneNumber: '+49 69 56789005', nationality: 'DE',
    placeOfBirth: 'Frankfurt am Main', countryOfBirth: 'Deutschland',
    taxNumber: 'DE567890125', employmentStatus: 'self_employed', incomeRange: 'range_100k_plus',
    riskTolerance: 8, investmentExperience: 7, financialProductsExperience: true,
  },
];

const TRADERS = [
  {
    email: 'trader1@test.com', username: 'jbecker',
    firstName: 'Jan', lastName: 'Becker',
    salutation: 'mr', dateOfBirth: '1980-06-10',
    streetAndNumber: 'Unter den Linden 21', postalCode: '10117', city: 'Berlin', state: 'Berlin',
    phoneNumber: '+49 30 67890101', nationality: 'DE',
    placeOfBirth: 'Berlin', countryOfBirth: 'Deutschland',
    taxNumber: 'DE678901231', employmentStatus: 'self_employed', incomeRange: 'range_100k_plus',
    riskTolerance: 9, tradingFrequency: 8, leveragedProductsExperience: true,
  },
  {
    email: 'trader2@test.com', username: 'awolf',
    firstName: 'Alexander', lastName: 'Wolf',
    salutation: 'mr', dateOfBirth: '1987-02-28',
    streetAndNumber: 'Leopoldstraße 56', postalCode: '80802', city: 'München', state: 'Bayern',
    phoneNumber: '+49 89 78901202', nationality: 'DE',
    placeOfBirth: 'München', countryOfBirth: 'Deutschland',
    taxNumber: 'DE789012342', employmentStatus: 'self_employed', incomeRange: 'range_100k_plus',
    riskTolerance: 8, tradingFrequency: 7, leveragedProductsExperience: true,
  },
  {
    email: 'trader3@test.com', username: 'lwagner',
    firstName: 'Lena', lastName: 'Wagner',
    salutation: 'ms', dateOfBirth: '1992-04-14',
    streetAndNumber: 'Schildergasse 72', postalCode: '50667', city: 'Köln', state: 'Nordrhein-Westfalen',
    phoneNumber: '+49 221 89012303', nationality: 'DE',
    placeOfBirth: 'Köln', countryOfBirth: 'Deutschland',
    taxNumber: 'DE890123453', employmentStatus: 'employed', incomeRange: 'range_50k_100k',
    riskTolerance: 6, tradingFrequency: 5, leveragedProductsExperience: true,
  },
  {
    email: 'trader4@test.com', username: 'thoffmann',
    firstName: 'Tobias', lastName: 'Hoffmann',
    salutation: 'mr', dateOfBirth: '1975-12-05',
    streetAndNumber: 'Zeil 106', postalCode: '60313', city: 'Frankfurt am Main', state: 'Hessen',
    phoneNumber: '+49 69 90123404', nationality: 'DE',
    placeOfBirth: 'Frankfurt am Main', countryOfBirth: 'Deutschland',
    taxNumber: 'DE901234564', employmentStatus: 'self_employed', incomeRange: 'range_100k_plus',
    riskTolerance: 9, tradingFrequency: 9, leveragedProductsExperience: true,
  },
  {
    email: 'trader5@test.com', username: 'jrichter',
    firstName: 'Julia', lastName: 'Richter',
    salutation: 'ms', dateOfBirth: '1988-08-20',
    streetAndNumber: 'Mönckebergstraße 18', postalCode: '20095', city: 'Hamburg', state: 'Hamburg',
    phoneNumber: '+49 40 01234505', nationality: 'DE',
    placeOfBirth: 'Hamburg', countryOfBirth: 'Deutschland',
    taxNumber: 'DE012345675', employmentStatus: 'employed', incomeRange: 'range_50k_100k',
    riskTolerance: 7, tradingFrequency: 6, leveragedProductsExperience: true,
  },
  {
    email: 'trader6@test.com', username: 'mklein',
    firstName: 'Markus', lastName: 'Klein',
    salutation: 'mr', dateOfBirth: '1983-05-11',
    streetAndNumber: 'Kurfürstendamm 195', postalCode: '10707', city: 'Berlin', state: 'Berlin',
    phoneNumber: '+49 30 12345606', nationality: 'DE',
    placeOfBirth: 'Stuttgart', countryOfBirth: 'Deutschland',
    taxNumber: 'DE123456786', employmentStatus: 'self_employed', incomeRange: 'range_100k_plus',
    riskTolerance: 8, tradingFrequency: 7, leveragedProductsExperience: true,
  },
  {
    email: 'trader7@test.com', username: 'alehmann',
    firstName: 'Anna', lastName: 'Lehmann',
    salutation: 'ms', dateOfBirth: '1991-10-25',
    streetAndNumber: 'Marienplatz 1', postalCode: '80331', city: 'München', state: 'Bayern',
    phoneNumber: '+49 89 23456707', nationality: 'DE',
    placeOfBirth: 'Nürnberg', countryOfBirth: 'Deutschland',
    taxNumber: 'DE234567897', employmentStatus: 'employed', incomeRange: 'range_50k_100k',
    riskTolerance: 6, tradingFrequency: 5, leveragedProductsExperience: true,
  },
  {
    email: 'trader8@test.com', username: 'fschmitt',
    firstName: 'Florian', lastName: 'Schmitt',
    salutation: 'mr', dateOfBirth: '1979-07-07',
    streetAndNumber: 'Breite Straße 29', postalCode: '04109', city: 'Leipzig', state: 'Sachsen',
    phoneNumber: '+49 341 34567808', nationality: 'DE',
    placeOfBirth: 'Leipzig', countryOfBirth: 'Deutschland',
    taxNumber: 'DE345678908', employmentStatus: 'self_employed', incomeRange: 'range_100k_plus',
    riskTolerance: 9, tradingFrequency: 8, leveragedProductsExperience: true,
  },
  {
    email: 'trader9@test.com', username: 'lkoch',
    firstName: 'Laura', lastName: 'Koch',
    salutation: 'ms', dateOfBirth: '1994-03-19',
    streetAndNumber: 'Schlossstraße 60', postalCode: '70176', city: 'Stuttgart', state: 'Baden-Württemberg',
    phoneNumber: '+49 711 45678909', nationality: 'DE',
    placeOfBirth: 'Stuttgart', countryOfBirth: 'Deutschland',
    taxNumber: 'DE456789019', employmentStatus: 'employed', incomeRange: 'range_50k_100k',
    riskTolerance: 7, tradingFrequency: 6, leveragedProductsExperience: true,
  },
  {
    email: 'trader10@test.com', username: 'nhartmann',
    firstName: 'Niklas', lastName: 'Hartmann',
    salutation: 'mr', dateOfBirth: '1986-11-30',
    streetAndNumber: 'Georgstraße 14', postalCode: '30159', city: 'Hannover', state: 'Niedersachsen',
    phoneNumber: '+49 511 56789010', nationality: 'DE',
    placeOfBirth: 'Hannover', countryOfBirth: 'Deutschland',
    taxNumber: 'DE567890110', employmentStatus: 'self_employed', incomeRange: 'range_100k_plus',
    riskTolerance: 8, tradingFrequency: 7, leveragedProductsExperience: true,
  },
];

const PASSWORD = 'TestPassword123!';

/**
 * Seeds 5 investors + 10 traders with fully completed onboarding profiles.
 * Removes all existing investor/trader users first (preserves admin/CSR).
 */
Parse.Cloud.define('seedTestUsers', async (request) => {
  requireAdminRole(request);

  // ── Step 1: Remove old investor/trader users ──
  const deleteQuery = new Parse.Query(Parse.User);
  deleteQuery.containedIn('role', ['investor', 'trader']);
  deleteQuery.limit(1000);
  const oldUsers = await deleteQuery.find({ useMasterKey: true });

  let deleted = 0;
  for (const u of oldUsers) {
    await u.destroy({ useMasterKey: true });
    deleted++;
  }

  // ── Step 2: Create investors ──
  const year = new Date().getFullYear();
  const created = [];
  for (let i = 0; i < INVESTORS.length; i++) {
    const data = INVESTORS[i];
    const customerNumber = `ANL-${year}-${String(i + 1).padStart(5, '0')}`;
    const user = await createFullUser(data, 'investor', customerNumber);
    created.push({ email: data.email, customerNumber, role: 'investor', objectId: user.id });
  }

  // ── Step 3: Create traders ──
  for (let i = 0; i < TRADERS.length; i++) {
    const data = TRADERS[i];
    const customerNumber = `TRD-${year}-${String(i + 1).padStart(5, '0')}`;
    const user = await createFullUser(data, 'trader', customerNumber);
    created.push({ email: data.email, customerNumber, role: 'trader', objectId: user.id });
  }

  console.log(`✅ Seeded ${created.length} test users (deleted ${deleted} old).`);
  return { success: true, deleted, created };
});

async function createFullUser(data, role, customerNumber) {
  const user = new Parse.User();

  user.set('username', data.username);
  user.set('email', data.email);
  user.set('password', PASSWORD);
  user.set('role', role);
  user.set('customerNumber', customerNumber);

  user.set('status', 'active');
  user.set('emailVerified', true);
  user.set('onboardingCompleted', true);
  user.set('kycStatus', 'verified');

  user.set('salutation', data.salutation);
  user.set('firstName', data.firstName);
  user.set('lastName', data.lastName);
  user.set('phoneNumber', data.phoneNumber);
  user.set('dateOfBirth', data.dateOfBirth);
  user.set('streetAndNumber', data.streetAndNumber);
  user.set('postalCode', data.postalCode);
  user.set('city', data.city);
  user.set('state', data.state);
  user.set('country', 'Deutschland');
  user.set('nationality', data.nationality);
  user.set('placeOfBirth', data.placeOfBirth);
  user.set('countryOfBirth', data.countryOfBirth);
  user.set('taxNumber', data.taxNumber);
  user.set('isNotUSCitizen', true);
  user.set('employmentStatus', data.employmentStatus);
  user.set('incomeRange', data.incomeRange);
  user.set('riskTolerance', data.riskTolerance);

  if (role === 'investor') {
    user.set('investmentExperience', data.investmentExperience || 0);
    user.set('financialProductsExperience', data.financialProductsExperience || false);
  } else {
    user.set('tradingFrequency', data.tradingFrequency || 0);
    user.set('leveragedProductsExperience', data.leveragedProductsExperience || false);
  }

  user.set('acceptedTerms', true);
  user.set('acceptedPrivacyPolicy', true);
  user.set('moneyLaunderingDeclaration', true);
  user.set('identificationType', 'id_card');
  user.set('identificationConfirmed', true);
  user.set('addressConfirmed', true);
  user.set('accountType', 'individual');

  await user.signUp(null, { useMasterKey: true });
  return user;
}
