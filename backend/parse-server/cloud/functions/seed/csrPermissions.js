'use strict';

const { requireAdminRole } = require('../../utils/permissions');

Parse.Cloud.define('seedCSRPermissions', async (request) => {
  // Allow Master Key or admin role
  if (!request.master) {
    requireAdminRole(request);
  }

  const existingQuery = new Parse.Query('CSRPermission');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return {
      success: false,
      message: `${existingCount} permissions already exist. Use 'forceReseedCSRPermissions' to overwrite.`,
      created: 0
    };
  }

  // Permission definitions matching iOS CustomerSupportPermission enum
  const permissions = [
    // ═══════════════════════════════════════════════════════════════
    // Customer Data Viewing (Read-Only)
    // ═══════════════════════════════════════════════════════════════
    { key: 'viewCustomerProfile', displayName: 'Kundenprofil anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'viewCustomerKYCStatus', displayName: 'KYC-Status anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'viewCustomerInvestments', displayName: 'Investments anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'viewCustomerTrades', displayName: 'Trades anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'viewCustomerDocuments', displayName: 'Dokumente anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'viewCustomerNotifications', displayName: 'Benachrichtigungen anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'viewCustomerSupportHistory', displayName: 'Support-Verlauf anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },

    // ═══════════════════════════════════════════════════════════════
    // Limited Write Access (Requires Approval)
    // ═══════════════════════════════════════════════════════════════
    { key: 'updateCustomerContact', displayName: 'Kontaktdaten aktualisieren', category: 'modification', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'updateCustomerAddress', displayName: 'Adresse aktualisieren', category: 'modification', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: true, requiresAMLDocumentation: false },
    { key: 'updateCustomerName', displayName: 'Name aktualisieren', category: 'modification', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: true, requiresAMLDocumentation: false },
    { key: 'resetCustomerPassword', displayName: 'Passwort zurücksetzen', category: 'modification', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: false },
    { key: 'unlockCustomerAccount', displayName: 'Konto entsperren', category: 'modification', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },

    // ═══════════════════════════════════════════════════════════════
    // Support Operations
    // ═══════════════════════════════════════════════════════════════
    { key: 'createSupportTicket', displayName: 'Support-Ticket erstellen', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'respondToSupportTicket', displayName: 'Support-Ticket beantworten', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'escalateToAdmin', displayName: 'An Admin eskalieren', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'addInternalNote', displayName: 'Interne Notiz hinzufügen', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },

    // ═══════════════════════════════════════════════════════════════
    // Compliance Operations
    // ═══════════════════════════════════════════════════════════════
    { key: 'initiateKYCReview', displayName: 'KYC-Prüfung einleiten', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'requestComplianceCheck', displayName: 'Compliance-Prüfung anfordern', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'viewAuditLogs', displayName: 'Audit-Protokolle anzeigen', category: 'compliance', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },

    // ═══════════════════════════════════════════════════════════════
    // Fraud Operations (🔒 Sensitive)
    // ═══════════════════════════════════════════════════════════════
    { key: 'viewFraudAlerts', displayName: 'Fraud-Alerts anzeigen', category: 'fraud', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'suspendAccountTemporary', displayName: 'Konto temporär sperren (<24h)', category: 'fraud', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: false },
    { key: 'suspendAccountExtended', displayName: 'Konto erweitert sperren (>24h)', category: 'fraud', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: true, requiresAMLDocumentation: true },
    { key: 'blockPaymentCard', displayName: 'Zahlungskarte sperren', category: 'fraud', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: false },
    { key: 'initiateChargeback', displayName: 'Chargeback einleiten', category: 'fraud', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'viewTransactionPatterns', displayName: 'Transaktionsmuster anzeigen', category: 'fraud', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'flagSuspiciousActivity', displayName: 'Verdächtige Aktivität melden', category: 'fraud', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: true },

    // ═══════════════════════════════════════════════════════════════
    // AML/Compliance Operations (🔒 Sensitive)
    // ═══════════════════════════════════════════════════════════════
    { key: 'createSARReport', displayName: 'SAR-Meldung erstellen', category: 'compliance', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: false, requiresAMLDocumentation: true },
    { key: 'viewSARReports', displayName: 'SAR-Meldungen anzeigen', category: 'compliance', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'approveKYCDecision', displayName: 'KYC-Entscheidung genehmigen', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'processGDPRRequest', displayName: 'DSGVO-Anfrage bearbeiten', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'approveGDPRDeletion', displayName: 'DSGVO-Löschung genehmigen', category: 'compliance', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'viewAMLFlags', displayName: 'AML-Flags anzeigen', category: 'compliance', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: true },

    // ═══════════════════════════════════════════════════════════════
    // Approval Authority (Teamlead/Supervisor)
    // ═══════════════════════════════════════════════════════════════
    { key: 'approveAccountSuspension', displayName: 'Kontosperrung genehmigen', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'approveChargeback', displayName: 'Chargeback genehmigen', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'approveSARSubmission', displayName: 'SAR-Einreichung genehmigen', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
    { key: 'manageAgentPermissions', displayName: 'Agenten-Berechtigungen verwalten', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  ];

  const Permission = Parse.Object.extend('CSRPermission');
  let created = 0;

  for (const permData of permissions) {
    const perm = new Permission();
    perm.set('key', permData.key);
    perm.set('displayName', permData.displayName);
    perm.set('category', permData.category);
    perm.set('isReadOnly', permData.isReadOnly);
    perm.set('requiresApproval', permData.requiresApproval);
    perm.set('triggersComplianceCheck', permData.triggersComplianceCheck);
    perm.set('requiresAMLDocumentation', permData.requiresAMLDocumentation);
    perm.set('isActive', true);
    await perm.save(null, { useMasterKey: true });
    created++;
  }

  console.log(`Seeded ${created} CSR permissions`);

  // Now seed the roles
  const rolesResult = await seedCSRRolesInternal();

  return {
    success: true,
    message: `Created ${created} permissions and ${rolesResult.created} roles`,
    permissionsCreated: created,
    rolesCreated: rolesResult.created
  };
});

/**
 * Internal function to seed CSR roles with their permission sets
 */
async function seedCSRRolesInternal() {
  const existingQuery = new Parse.Query('CSRRole');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return { success: false, message: 'Roles already exist', created: 0 };
  }

  // Permission sets matching iOS CustomerSupportPermissionSet
  const level1Permissions = [
    'viewCustomerProfile', 'viewCustomerKYCStatus', 'viewCustomerInvestments',
    'viewCustomerDocuments', 'viewCustomerNotifications', 'viewCustomerSupportHistory',
    'createSupportTicket', 'respondToSupportTicket', 'addInternalNote',
    'updateCustomerContact'
  ];

  const level2Permissions = [
    ...level1Permissions,
    'viewCustomerTrades',
    'updateCustomerAddress', 'updateCustomerName', 'resetCustomerPassword', 'unlockCustomerAccount',
    'escalateToAdmin', 'initiateKYCReview'
  ];

  const fraudAnalystPermissions = [
    ...level1Permissions,
    'viewFraudAlerts', 'viewTransactionPatterns', 'flagSuspiciousActivity',
    'suspendAccountTemporary', 'suspendAccountExtended', 'blockPaymentCard', 'initiateChargeback',
    'viewAMLFlags', 'escalateToAdmin'
  ];

  const complianceOfficerPermissions = [
    ...level1Permissions,
    'viewCustomerTrades', 'viewAuditLogs', 'requestComplianceCheck', 'initiateKYCReview',
    'approveKYCDecision', 'viewAMLFlags', 'viewSARReports', 'createSARReport',
    'processGDPRRequest', 'approveGDPRDeletion', 'approveSARSubmission', 'approveAccountSuspension'
  ];

  const techSupportPermissions = [
    ...level1Permissions,
    'viewAuditLogs', 'escalateToAdmin'
  ];

  const teamleadPermissions = [
    ...level2Permissions,
    'viewFraudAlerts', 'viewTransactionPatterns', 'viewAMLFlags',
    'viewAuditLogs', 'viewSARReports', 'requestComplianceCheck',
    'approveAccountSuspension', 'approveChargeback', 'approveSARSubmission',
    'approveKYCDecision', 'approveGDPRDeletion', 'manageAgentPermissions'
  ];

  const roles = [
    {
      key: 'level1',
      displayName: 'Level 1 Support',
      shortName: 'L1',
      icon: '1.circle.fill',
      color: '#5AC8FA', // iOS accentLightBlue
      permissions: level1Permissions,
      canApprove: false,
      description: 'Ticketaufnahme, Standardantworten, Basis-Troubleshooting. Kein Zugriff auf Trades.',
      sortOrder: 10
    },
    {
      key: 'level2',
      displayName: 'Level 2 Support',
      shortName: 'L2',
      icon: '2.circle.fill',
      color: '#5AC8FA',
      permissions: level2Permissions,
      canApprove: false,
      description: 'Tieferes Troubleshooting, Trading-Fragen, Account-Aktionen, Eskalationen.',
      sortOrder: 20
    },
    {
      key: 'fraud',
      displayName: 'Fraud Analyst',
      shortName: 'Fraud',
      icon: 'exclamationmark.shield.fill',
      color: '#FF3B30', // iOS accentRed
      permissions: fraudAnalystPermissions,
      canApprove: false,
      description: 'Fraud Alerts, Transaction Patterns, Sperren, Chargeback-Flow.',
      sortOrder: 30
    },
    {
      key: 'compliance',
      displayName: 'Compliance Officer',
      shortName: 'Compliance',
      icon: 'checkmark.shield.fill',
      color: '#34C759', // iOS accentGreen
      permissions: complianceOfficerPermissions,
      canApprove: true,
      description: 'KYC/AML/GDPR Vorgänge, Audit Logs, SAR Reports, Approval Authority.',
      sortOrder: 40
    },
    {
      key: 'techSupport',
      displayName: 'Tech Support',
      shortName: 'Tech',
      icon: 'wrench.and.screwdriver.fill',
      color: '#FF9500', // iOS accentOrange
      permissions: techSupportPermissions,
      canApprove: false,
      description: 'Technische Analyse, Audit Logs. Keine Kundendaten-Änderungen.',
      sortOrder: 50
    },
    {
      key: 'teamlead',
      displayName: 'Teamlead',
      shortName: 'Lead',
      icon: 'star.fill',
      color: '#FFD60A', // Yellow
      permissions: teamleadPermissions,
      canApprove: true,
      description: 'Operatives Steering, Eskalationsentscheidungen, 4-Augen Genehmigungen, Permission-Management.',
      sortOrder: 60
    }
  ];

  const Role = Parse.Object.extend('CSRRole');
  let created = 0;

  for (const roleData of roles) {
    const role = new Role();
    role.set('key', roleData.key);
    role.set('displayName', roleData.displayName);
    role.set('shortName', roleData.shortName);
    role.set('icon', roleData.icon);
    role.set('color', roleData.color);
    role.set('permissions', roleData.permissions);
    role.set('canApprove', roleData.canApprove);
    role.set('description', roleData.description);
    role.set('sortOrder', roleData.sortOrder);
    role.set('isActive', true);
    await role.save(null, { useMasterKey: true });
    created++;
  }

  return { success: true, created };
}

/**
 * Force reseed CSR permissions (deletes existing first)
 * Can be called with Master Key or by an admin user
 */
Parse.Cloud.define('forceReseedCSRPermissions', async (request) => {
  // Allow Master Key or admin role
  if (!request.master) {
    requireAdminRole(request);
  }

  // Delete existing permissions
  const permQuery = new Parse.Query('CSRPermission');
  const existingPerms = await permQuery.find({ useMasterKey: true });
  await Parse.Object.destroyAll(existingPerms, { useMasterKey: true });

  // Delete existing roles
  const roleQuery = new Parse.Query('CSRRole');
  const existingRoles = await roleQuery.find({ useMasterKey: true });
  await Parse.Object.destroyAll(existingRoles, { useMasterKey: true });

  // Reseed
  return Parse.Cloud.run('seedCSRPermissions', {}, { sessionToken: request.user.getSessionToken() });
});

console.log('Seed Functions loaded');
