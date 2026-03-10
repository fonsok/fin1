// ============================================================================
// Parse Cloud Code
// triggers/user.js - User Triggers
// ============================================================================

'use strict';

const { generateCustomerId } = require('../utils/helpers');
const { encryptFields } = require('../utils/fieldEncryption');

// Fields encrypted at rest (see also triggers/encryption.js for other classes)
const USER_PII_FIELDS = ['phone_number'];

// ============================================================================
// BEFORE SAVE
// ============================================================================

Parse.Cloud.beforeSave(Parse.User, async (request) => {
  const user = request.object;
  const isNew = !user.existed();

  // Encrypt PII before persisting (no-op when key is not configured)
  if (!(request.context && request.context.skipEncryptionTrigger)) {
    encryptFields(user, USER_PII_FIELDS);
  }

  // ========== NEW USER ==========
  if (isNew) {
    // Generate customer ID
    if (!user.get('customerId')) {
      const role = user.get('role') || 'investor';
      const customerId = await generateCustomerId(role);
      user.set('customerId', customerId);
    }

    // Set defaults
    user.set('status', user.get('status') || 'pending');
    user.set('kycStatus', user.get('kycStatus') || 'pending');
    user.set('emailVerified', false);
    user.set('onboardingCompleted', false);
    user.set('loginCount', 0);
    user.set('failedLoginCount', 0);
  }

  // ========== EMAIL VALIDATION ==========
  const email = user.get('email');
  if (email) {
    const emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
    if (!emailRegex.test(email)) {
      throw new Parse.Error(Parse.Error.INVALID_EMAIL_ADDRESS, 'Invalid email format');
    }
    // Normalize email
    user.set('email', email.toLowerCase().trim());
  }

  // ========== ROLE VALIDATION ==========
  // Roles:
  //   - investor: End-user (Anleger)
  //   - trader: End-user (Händler)
  //   - admin: Full app-level admin
  //   - customer_service: User support, tickets
  //   - compliance: Audit, 4-eyes approvals
  //   - business_admin: Accounting/financial oversight (no tech admin)
  //   - security_officer: Security reviews, release gatekeeper
  //   - system: Automated processes
  const role = user.get('role');
  const validRoles = [
    'investor',
    'trader',
    'admin',
    'customer_service',
    'compliance',
    'business_admin',
    'security_officer',
    'system'
  ];
  if (role && !validRoles.includes(role)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid role: ${role}`);
  }

  // ========== CSR SUB-ROLE AUTO-DETECTION ==========
  // Automatically detect CSR sub-role from email for customer_service users
  if (role === 'customer_service' && !user.get('csrSubRole')) {
    const emailLower = email ? email.toLowerCase() : '';
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

    if (csrSubRole) {
      user.set('csrSubRole', csrSubRole);
    }
  }

  // ========== STATUS VALIDATION ==========
  const status = user.get('status');
  const validStatuses = ['pending', 'active', 'suspended', 'locked', 'closed', 'deleted'];
  if (status && !validStatuses.includes(status)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid status: ${status}`);
  }
});

// ============================================================================
// AFTER SAVE
// ============================================================================

Parse.Cloud.afterSave(Parse.User, async (request) => {
  const user = request.object;
  const isNew = !request.original;
  const context = request.context || {};
  const platformName = (process.env.FIN1_LEGAL_PLATFORM_NAME || '').trim() || 'Platform';

  // ========== NEW USER: CREATE RELATED OBJECTS ==========
  if (isNew) {
    // Create UserProfile
    const UserProfile = Parse.Object.extend('UserProfile');
    const profile = new UserProfile();
    profile.set('userId', user.id);
    profile.set('preferredLanguage', 'de');
    await profile.save(null, { useMasterKey: true });

    // Create NotificationPreference
    const NotificationPreference = Parse.Object.extend('NotificationPreference');
    const notifPref = new NotificationPreference();
    notifPref.set('userId', user.id);
    notifPref.set('notificationsEnabled', true);
    notifPref.set('inAppEnabled', true);
    notifPref.set('pushEnabled', true);
    notifPref.set('emailEnabled', true);
    await notifPref.save(null, { useMasterKey: true });

    // Log compliance event
    await logComplianceEvent(user.id, 'account_created', 'info',
      'New user account created', { role: user.get('role') });

    // Send welcome notification
    await createNotification(user.id, 'system', 'account',
      `Willkommen bei ${platformName}!`,
      'Ihr Konto wurde erfolgreich erstellt. Bitte vervollständigen Sie Ihr Profil.');
  }

  // ========== STATUS CHANGE ==========
  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = user.get('status');

    if (oldStatus !== newStatus) {
      // Log status change
      await logComplianceEvent(user.id,
        newStatus === 'suspended' ? 'account_suspended' :
        newStatus === 'active' ? 'account_reactivated' : 'account_closed',
        'medium',
        `Account status changed from ${oldStatus} to ${newStatus}`,
        { oldStatus, newStatus }
      );

      // Notify user
      if (newStatus === 'active') {
        await createNotification(user.id, 'system', 'account',
          'Konto aktiviert',
          'Ihr Konto ist jetzt aktiv. Sie können nun alle Funktionen nutzen.');
      } else if (newStatus === 'suspended') {
        await createNotification(user.id, 'system', 'account',
          'Konto gesperrt',
          'Ihr Konto wurde vorübergehend gesperrt. Bitte kontaktieren Sie den Support.',
          'high');
      }
    }

    // KYC Status Change
    const oldKyc = request.original.get('kycStatus');
    const newKyc = user.get('kycStatus');

    if (oldKyc !== newKyc) {
      await logComplianceEvent(user.id,
        newKyc === 'verified' ? 'kyc_verified' :
        newKyc === 'rejected' ? 'kyc_rejected' : 'kyc_initiated',
        newKyc === 'verified' ? 'low' : 'medium',
        `KYC status changed from ${oldKyc} to ${newKyc}`,
        { oldKyc, newKyc }
      );

      if (newKyc === 'verified') {
        await createNotification(user.id, 'kyc_approved', 'account',
          'KYC verifiziert',
          'Ihre Identität wurde erfolgreich verifiziert.');
      } else if (newKyc === 'rejected') {
        await createNotification(user.id, 'kyc_rejected', 'account',
          'KYC abgelehnt',
          'Ihre Identitätsprüfung konnte nicht abgeschlossen werden. Bitte prüfen Sie Ihre Dokumente.',
          'high');
      }
    }
  }
});

// ============================================================================
// BEFORE DELETE
// ============================================================================

Parse.Cloud.beforeDelete(Parse.User, async (request) => {
  const user = request.object;

  // Check for active investments
  const Investment = Parse.Object.extend('Investment');
  const investmentQuery = new Parse.Query(Investment);
  investmentQuery.equalTo('investorId', user.id);
  investmentQuery.containedIn('status', ['active', 'executing']);
  const activeInvestments = await investmentQuery.count({ useMasterKey: true });

  if (activeInvestments > 0) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN,
      'Cannot delete user with active investments');
  }

  // Check for active trades (for traders)
  if (user.get('role') === 'trader') {
    const Trade = Parse.Object.extend('Trade');
    const tradeQuery = new Parse.Query(Trade);
    tradeQuery.equalTo('traderId', user.id);
    tradeQuery.containedIn('status', ['pending', 'active', 'partial']);
    const activeTrades = await tradeQuery.count({ useMasterKey: true });

    if (activeTrades > 0) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN,
        'Cannot delete user with active trades');
    }
  }

  // Check for pending transactions
  const WalletTransaction = Parse.Object.extend('WalletTransaction');
  const txQuery = new Parse.Query(WalletTransaction);
  txQuery.equalTo('userId', user.id);
  txQuery.containedIn('status', ['pending', 'processing']);
  const pendingTx = await txQuery.count({ useMasterKey: true });

  if (pendingTx > 0) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN,
      'Cannot delete user with pending transactions');
  }
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

async function logComplianceEvent(userId, eventType, severity, description, metadata = {}) {
  const ComplianceEvent = Parse.Object.extend('ComplianceEvent');
  const event = new ComplianceEvent();
  event.set('userId', userId);
  event.set('eventType', eventType);
  event.set('severity', severity);
  event.set('description', description);
  event.set('metadata', metadata);
  event.set('occurredAt', new Date());
  await event.save(null, { useMasterKey: true });
}

async function createNotification(userId, type, category, title, message, priority = 'normal') {
  const Notification = Parse.Object.extend('Notification');
  const notif = new Notification();
  notif.set('userId', userId);
  notif.set('type', type);
  notif.set('category', category);
  notif.set('title', title);
  notif.set('message', message);
  notif.set('priority', priority);
  notif.set('isRead', false);
  notif.set('channels', ['in_app']);
  await notif.save(null, { useMasterKey: true });
}
