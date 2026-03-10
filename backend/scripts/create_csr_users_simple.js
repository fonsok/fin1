const Parse = require('parse/node');

// Initialize Parse
Parse.initialize('fin1-app-id');
Parse.serverURL = 'http://localhost:1337/parse';
Parse.masterKey = process.env.PARSE_MASTER_KEY;

const CSR_USERS = [
  { email: 'L1@fin1.de', password: 'L1Secure2024!', firstName: 'Lisa', lastName: 'Level-1' },
  { email: 'L2@fin1.de', password: 'L2Secure2024!', firstName: 'Lars', lastName: 'Level-2' },
  { email: 'Fraud@fin1.de', password: 'FraudSecure2024!', firstName: 'Frank', lastName: 'Fraud-Analyst' },
  { email: 'Compliance@fin1.de', password: 'ComplianceSecure2024!', firstName: 'Claudia', lastName: 'Compliance' },
  { email: 'Tech@fin1.de', password: 'TechSecure2024!', firstName: 'Tim', lastName: 'Tech-Support' },
  { email: 'Lead@fin1.de', password: 'LeadSecure2024!', firstName: 'Tanja', lastName: 'Teamlead' },
];

async function createCSRUsers() {
  console.log('🚀 Erstelle CSR Users...\n');

  for (const userData of CSR_USERS) {
    try {
      console.log(`📧 Erstelle User: ${userData.email}...`);

      // Check if user exists
      const query = new Parse.Query(Parse.User);
      query.equalTo('email', userData.email.toLowerCase());
      const existing = await query.first({ useMasterKey: true });

      if (existing) {
        // Update existing user
        existing.set('role', 'customer_service');
        existing.set('status', 'active');
        existing.set('emailVerified', true);
        existing.set('onboardingCompleted', true);
        existing.set('kycStatus', 'verified');
        existing.set('firstName', userData.firstName);
        existing.set('lastName', userData.lastName);

        // Detect CSR sub-role from email
        const emailLower = userData.email.toLowerCase();
        let csrSubRole = null;
        if (emailLower.includes('l1@')) csrSubRole = 'level_1';
        else if (emailLower.includes('l2@')) csrSubRole = 'level_2';
        else if (emailLower.includes('fraud@')) csrSubRole = 'fraud_analyst';
        else if (emailLower.includes('compliance@')) csrSubRole = 'compliance_officer';
        else if (emailLower.includes('tech@')) csrSubRole = 'tech_support';
        else if (emailLower.includes('lead@')) csrSubRole = 'teamlead';

        if (csrSubRole) {
          existing.set('csrSubRole', csrSubRole);
        }

        await existing.save(null, { useMasterKey: true });
        console.log(`  ✅ Aktualisiert: ${userData.email} (${csrSubRole || 'keine Sub-Rolle'})`);
      } else {
        // Create new user
        const user = new Parse.User();
        user.set('username', userData.email.toLowerCase());
        user.set('email', userData.email.toLowerCase());
        user.set('password', userData.password);
        user.set('role', 'customer_service');
        user.set('status', 'active');
        user.set('emailVerified', true);
        user.set('onboardingCompleted', true);
        user.set('kycStatus', 'verified');
        user.set('firstName', userData.firstName);
        user.set('lastName', userData.lastName);

        // Detect CSR sub-role from email
        const emailLower = userData.email.toLowerCase();
        let csrSubRole = null;
        if (emailLower.includes('l1@')) csrSubRole = 'level_1';
        else if (emailLower.includes('l2@')) csrSubRole = 'level_2';
        else if (emailLower.includes('fraud@')) csrSubRole = 'fraud_analyst';
        else if (emailLower.includes('compliance@')) csrSubRole = 'compliance_officer';
        else if (emailLower.includes('tech@')) csrSubRole = 'tech_support';
        else if (emailLower.includes('lead@')) csrSubRole = 'teamlead';

        if (csrSubRole) {
          user.set('csrSubRole', csrSubRole);
        }

        await user.signUp(null, { useMasterKey: true });
        console.log(`  ✅ Erstellt: ${userData.email} (${csrSubRole || 'keine Sub-Rolle'})`);
      }
    } catch (error) {
      console.error(`  ❌ Fehler bei ${userData.email}: ${error.message}`);
    }
  }

  console.log('\n✅ Fertig!');
}

createCSRUsers().catch(console.error);
