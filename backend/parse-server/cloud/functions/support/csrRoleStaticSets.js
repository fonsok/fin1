'use strict';

/**
 * Canonical CSR RBAC definitions (Parse CSRRole.key + CSRPermission rows).
 * Keep aligned with:
 * - iOS: CustomerSupportPermissionSet.swift, CustomerSupportPermission enum, CSRRole
 * - admin-portal: PermissionsSection getCSRRoleDisplay keys (level1, level2, fraud, compliance, techSupport, teamlead)
 *
 * Single source for seedCSRPermissions / getCSRRolePermissions static fallback.
 */

/** @typedef {{ key: string, displayName: string, category: string, isReadOnly: boolean, requiresApproval: boolean, triggersComplianceCheck: boolean, requiresAMLDocumentation: boolean }} CsrPermissionDef */

/** @type {CsrPermissionDef[]} */
const CSR_PERMISSION_DEFINITIONS = [
  { key: 'viewCustomerProfile', displayName: 'Kundenprofil anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'viewCustomerKYCStatus', displayName: 'KYC-Status anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'viewCustomerInvestments', displayName: 'Investments anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'viewCustomerTrades', displayName: 'Trades anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'viewCustomerDocuments', displayName: 'Dokumente anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'viewCustomerNotifications', displayName: 'Benachrichtigungen anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'viewCustomerSupportHistory', displayName: 'Support-Verlauf anzeigen', category: 'viewing', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'updateCustomerContact', displayName: 'Kontaktdaten aktualisieren', category: 'modification', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'updateCustomerAddress', displayName: 'Adresse aktualisieren', category: 'modification', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: true, requiresAMLDocumentation: false },
  { key: 'updateCustomerName', displayName: 'Name aktualisieren', category: 'modification', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: true, requiresAMLDocumentation: false },
  { key: 'resetCustomerPassword', displayName: 'Passwort zurücksetzen', category: 'modification', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: false },
  { key: 'unlockCustomerAccount', displayName: 'Konto entsperren', category: 'modification', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'createSupportTicket', displayName: 'Support-Ticket erstellen', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'respondToSupportTicket', displayName: 'Support-Ticket beantworten', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'escalateToAdmin', displayName: 'An Admin eskalieren', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'addInternalNote', displayName: 'Interne Notiz hinzufügen', category: 'support', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'initiateKYCReview', displayName: 'KYC-Prüfung einleiten', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'requestComplianceCheck', displayName: 'Compliance-Prüfung anfordern', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'viewAuditLogs', displayName: 'Audit-Protokolle anzeigen', category: 'compliance', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'viewFraudAlerts', displayName: 'Fraud-Alerts anzeigen', category: 'fraud', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'suspendAccountTemporary', displayName: 'Konto temporär sperren (<24h)', category: 'fraud', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: false },
  { key: 'suspendAccountExtended', displayName: 'Konto erweitert sperren (>24h)', category: 'fraud', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: true, requiresAMLDocumentation: true },
  { key: 'blockPaymentCard', displayName: 'Zahlungskarte sperren', category: 'fraud', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: false },
  { key: 'initiateChargeback', displayName: 'Chargeback einleiten', category: 'fraud', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'viewTransactionPatterns', displayName: 'Transaktionsmuster anzeigen', category: 'fraud', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'flagSuspiciousActivity', displayName: 'Verdächtige Aktivität melden', category: 'fraud', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: true, requiresAMLDocumentation: true },
  { key: 'createSARReport', displayName: 'SAR-Meldung erstellen', category: 'compliance', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: false, requiresAMLDocumentation: true },
  { key: 'viewSARReports', displayName: 'SAR-Meldungen anzeigen', category: 'compliance', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'approveKYCDecision', displayName: 'KYC-Entscheidung genehmigen', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'processGDPRRequest', displayName: 'DSGVO-Anfrage bearbeiten', category: 'compliance', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'approveGDPRDeletion', displayName: 'DSGVO-Löschung genehmigen', category: 'compliance', isReadOnly: false, requiresApproval: true, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'viewAMLFlags', displayName: 'AML-Flags anzeigen', category: 'compliance', isReadOnly: true, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: true },
  { key: 'approveAccountSuspension', displayName: 'Kontosperrung genehmigen', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'approveChargeback', displayName: 'Chargeback genehmigen', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'approveSARSubmission', displayName: 'SAR-Einreichung genehmigen', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
  { key: 'manageAgentPermissions', displayName: 'Agenten-Berechtigungen verwalten', category: 'administration', isReadOnly: false, requiresApproval: false, triggersComplianceCheck: false, requiresAMLDocumentation: false },
];

const level1Permissions = [
  'viewCustomerProfile', 'viewCustomerKYCStatus', 'viewCustomerInvestments',
  'viewCustomerDocuments', 'viewCustomerNotifications', 'viewCustomerSupportHistory',
  'createSupportTicket', 'respondToSupportTicket', 'addInternalNote',
  'updateCustomerContact',
];

const level2Permissions = [
  ...level1Permissions,
  'viewCustomerTrades',
  'updateCustomerAddress', 'updateCustomerName', 'resetCustomerPassword', 'unlockCustomerAccount',
  'escalateToAdmin', 'initiateKYCReview',
];

const fraudAnalystPermissions = [
  ...level1Permissions,
  'viewFraudAlerts', 'viewTransactionPatterns', 'flagSuspiciousActivity',
  'suspendAccountTemporary', 'suspendAccountExtended', 'blockPaymentCard', 'initiateChargeback',
  'viewAMLFlags', 'escalateToAdmin',
];

const complianceOfficerPermissions = [
  ...level1Permissions,
  'viewCustomerTrades', 'viewAuditLogs', 'requestComplianceCheck', 'initiateKYCReview',
  'approveKYCDecision', 'viewAMLFlags', 'viewSARReports', 'createSARReport',
  'processGDPRRequest', 'approveGDPRDeletion', 'approveSARSubmission', 'approveAccountSuspension',
];

const techSupportPermissions = [
  ...level1Permissions,
  'viewAuditLogs', 'escalateToAdmin',
];

const teamleadPermissions = [
  ...level2Permissions,
  'viewFraudAlerts', 'viewTransactionPatterns', 'viewAMLFlags',
  'viewAuditLogs', 'viewSARReports', 'requestComplianceCheck',
  'approveAccountSuspension', 'approveChargeback', 'approveSARSubmission',
  'approveKYCDecision', 'approveGDPRDeletion', 'manageAgentPermissions',
];

/** Role rows for Parse CSRRole (key matches portal + iOS). */
const CSR_ROLE_DEFINITIONS = [
  {
    key: 'level1',
    displayName: 'Level 1 Support',
    shortName: 'L1',
    icon: '1.circle.fill',
    color: '#5AC8FA',
    permissions: level1Permissions,
    canApprove: false,
    description: 'Ticketaufnahme, Standardantworten, Basis-Troubleshooting. Kein Zugriff auf Trades.',
    sortOrder: 10,
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
    sortOrder: 20,
  },
  {
    key: 'fraud',
    displayName: 'Fraud Analyst',
    shortName: 'Fraud',
    icon: 'exclamationmark.shield.fill',
    color: '#FF3B30',
    permissions: fraudAnalystPermissions,
    canApprove: false,
    description: 'Fraud Alerts, Transaction Patterns, Sperren, Chargeback-Flow.',
    sortOrder: 30,
  },
  {
    key: 'compliance',
    displayName: 'Compliance Officer',
    shortName: 'Compliance',
    icon: 'checkmark.shield.fill',
    color: '#34C759',
    permissions: complianceOfficerPermissions,
    canApprove: true,
    description: 'KYC/AML/GDPR Vorgänge, Audit Logs, SAR Reports, Approval Authority.',
    sortOrder: 40,
  },
  {
    key: 'techSupport',
    displayName: 'Tech Support',
    shortName: 'Tech',
    icon: 'wrench.and.screwdriver.fill',
    color: '#FF9500',
    permissions: techSupportPermissions,
    canApprove: false,
    description: 'Technische Analyse, Audit Logs. Keine Kundendaten-Änderungen.',
    sortOrder: 50,
  },
  {
    key: 'teamlead',
    displayName: 'Teamlead',
    shortName: 'Lead',
    icon: 'star.fill',
    color: '#FFD60A',
    permissions: teamleadPermissions,
    canApprove: true,
    description: 'Operatives Steering, Eskalationsentscheidungen, 4-Augen Genehmigungen, Permission-Management.',
    sortOrder: 60,
  },
];

const CANONICAL_CSR_ROLE_KEYS = new Set(CSR_ROLE_DEFINITIONS.map((r) => r.key));

function getCSRPermissionDefinitionMap() {
  const m = new Map();
  for (const p of CSR_PERMISSION_DEFINITIONS) {
    m.set(p.key, p);
  }
  return m;
}

function resolveCsrRoleDefinitionByKey(canonicalKey) {
  return CSR_ROLE_DEFINITIONS.find((r) => r.key === canonicalKey) || null;
}

module.exports = {
  CSR_PERMISSION_DEFINITIONS,
  CSR_ROLE_DEFINITIONS,
  CANONICAL_CSR_ROLE_KEYS,
  getCSRPermissionDefinitionMap,
  resolveCsrRoleDefinitionByKey,
};
