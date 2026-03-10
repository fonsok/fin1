// ============================================================================
// MongoDB Seed Script for CSR Permissions
// Run with: mongosh "mongodb://..." < seed-csr-permissions.js
// ============================================================================

// CSR Permissions matching iOS CustomerSupportPermission enum
const permissions = [
  // Customer Data Viewing (Read-Only)
  { key: 'viewCustomerProfile', displayName: 'Kundenprofil anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'viewCustomerKYCStatus', displayName: 'KYC-Status anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'viewCustomerInvestments', displayName: 'Investments anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'viewCustomerTrades', displayName: 'Trades anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'viewCustomerDocuments', displayName: 'Dokumente anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'viewCustomerNotifications', displayName: 'Benachrichtigungen anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'viewCustomerSupportHistory', displayName: 'Support-Verlauf anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },

  // Limited Write Access
  { key: 'updateCustomerContact', displayName: 'Kontaktdaten aktualisieren', category: 'modification', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'updateCustomerAddress', displayName: 'Adresse aktualisieren', category: 'modification', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: true, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'updateCustomerName', displayName: 'Name aktualisieren', category: 'modification', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: true, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'resetCustomerPassword', displayName: 'Passwort zurücksetzen', category: 'modification', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'unlockCustomerAccount', displayName: 'Konto entsperren', category: 'modification', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },

  // Support Operations
  { key: 'createSupportTicket', displayName: 'Support-Ticket erstellen', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'respondToSupportTicket', displayName: 'Support-Ticket beantworten', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'escalateToAdmin', displayName: 'An Admin eskalieren', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'addInternalNote', displayName: 'Interne Notiz hinzufügen', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },

  // Compliance Operations
  { key: 'initiateKYCReview', displayName: 'KYC-Prüfung einleiten', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'requestComplianceCheck', displayName: 'Compliance-Prüfung anfordern', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'viewAuditLogs', displayName: 'Audit-Protokolle anzeigen', category: 'compliance', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },

  // Fraud Operations
  { key: 'viewFraudAlerts', displayName: 'Fraud-Alerts anzeigen', category: 'fraud', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'suspendAccountTemporary', displayName: 'Konto temporär sperren (<24h)', category: 'fraud', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'suspendAccountExtended', displayName: 'Konto erweitert sperren (>24h)', category: 'fraud', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: true, requiresAMLDocumentation: true, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'blockPaymentCard', displayName: 'Zahlungskarte sperren', category: 'fraud', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'initiateChargeback', displayName: 'Chargeback einleiten', category: 'fraud', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'viewTransactionPatterns', displayName: 'Transaktionsmuster anzeigen', category: 'fraud', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'flagSuspiciousActivity', displayName: 'Verdächtige Aktivität melden', category: 'fraud', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: true, isActive: true, _created_at: new Date(), _updated_at: new Date() },

  // AML/Compliance Operations
  { key: 'createSARReport', displayName: 'SAR-Meldung erstellen', category: 'compliance', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: false, requiresAMLDocumentation: true, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'viewSARReports', displayName: 'SAR-Meldungen anzeigen', category: 'compliance', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'approveKYCDecision', displayName: 'KYC-Entscheidung genehmigen', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'processGDPRRequest', displayName: 'DSGVO-Anfrage bearbeiten', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'approveGDPRDeletion', displayName: 'DSGVO-Löschung genehmigen', category: 'compliance', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'viewAMLFlags', displayName: 'AML-Flags anzeigen', category: 'compliance', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: true, isActive: true, _created_at: new Date(), _updated_at: new Date() },

  // Approval Authority
  { key: 'approveAccountSuspension', displayName: 'Kontosperrung genehmigen', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'approveChargeback', displayName: 'Chargeback genehmigen', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'approveSARSubmission', displayName: 'SAR-Einreichung genehmigen', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'manageAgentPermissions', displayName: 'Agenten-Berechtigungen verwalten', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false, isActive: true, _created_at: new Date(), _updated_at: new Date() },
];

// CSR Roles matching iOS CSRRole and CustomerSupportPermissionSet
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
  { key: 'level1', displayName: 'Level 1 Support', shortName: 'L1', icon: '1.circle.fill', color: '#5AC8FA', permissions: level1Permissions, canApprove: false, description: 'Ticketaufnahme, Standardantworten, Basis-Troubleshooting. Kein Zugriff auf Trades.', sortOrder: 10, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'level2', displayName: 'Level 2 Support', shortName: 'L2', icon: '2.circle.fill', color: '#5AC8FA', permissions: level2Permissions, canApprove: false, description: 'Tieferes Troubleshooting, Trading-Fragen, Account-Aktionen, Eskalationen.', sortOrder: 20, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'fraud', displayName: 'Fraud Analyst', shortName: 'Fraud', icon: 'exclamationmark.shield.fill', color: '#FF3B30', permissions: fraudAnalystPermissions, canApprove: false, description: 'Fraud Alerts, Transaction Patterns, Sperren, Chargeback-Flow.', sortOrder: 30, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'compliance', displayName: 'Compliance Officer', shortName: 'Compliance', icon: 'checkmark.shield.fill', color: '#34C759', permissions: complianceOfficerPermissions, canApprove: true, description: 'KYC/AML/GDPR Vorgänge, Audit Logs, SAR Reports, Approval Authority.', sortOrder: 40, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'techSupport', displayName: 'Tech Support', shortName: 'Tech', icon: 'wrench.and.screwdriver.fill', color: '#FF9500', permissions: techSupportPermissions, canApprove: false, description: 'Technische Analyse, Audit Logs. Keine Kundendaten-Änderungen.', sortOrder: 50, isActive: true, _created_at: new Date(), _updated_at: new Date() },
  { key: 'teamlead', displayName: 'Teamlead', shortName: 'Lead', icon: 'star.fill', color: '#FFD60A', permissions: teamleadPermissions, canApprove: true, description: 'Operatives Steering, Eskalationsentscheidungen, 4-Augen Genehmigungen, Permission-Management.', sortOrder: 60, isActive: true, _created_at: new Date(), _updated_at: new Date() },
];

// Insert permissions
print('Inserting CSR Permissions...');
const permResult = db.CSRPermission.insertMany(permissions);
print(`Inserted ${permResult.insertedCount} permissions`);

// Insert roles
print('Inserting CSR Roles...');
const roleResult = db.CSRRole.insertMany(roles);
print(`Inserted ${roleResult.insertedCount} roles`);

print('Done!');
