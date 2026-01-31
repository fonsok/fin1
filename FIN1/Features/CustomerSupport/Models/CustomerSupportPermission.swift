import Foundation

// MARK: - Customer Support Permission System (RBAC)
/// Role-Based Access Control for Customer Service Representatives
/// Compliant with AML, GDPR, PSD2 and least privilege principle

/// Defines granular permissions for customer support actions
enum CustomerSupportPermission: String, CaseIterable, Codable {
    // MARK: - Customer Data Viewing (Read-Only)
    case viewCustomerProfile
    case viewCustomerKYCStatus
    case viewCustomerInvestments
    case viewCustomerTrades
    case viewCustomerDocuments
    case viewCustomerNotifications
    case viewCustomerSupportHistory

    // MARK: - Limited Write Access (Requires Approval)
    case updateCustomerContact
    case updateCustomerAddress
    case updateCustomerName
    case resetCustomerPassword
    case unlockCustomerAccount

    // MARK: - Support Operations
    case createSupportTicket
    case respondToSupportTicket
    case escalateToAdmin
    case addInternalNote

    // MARK: - Compliance Operations
    case initiateKYCReview
    case requestComplianceCheck
    case viewAuditLogs

    // MARK: - Fraud Operations (🔒 Sensitive)
    case viewFraudAlerts
    case suspendAccountTemporary      // <24h, no approval needed
    case suspendAccountExtended       // >24h, requires 4-Augen
    case blockPaymentCard
    case initiateChargeback
    case viewTransactionPatterns
    case flagSuspiciousActivity

    // MARK: - AML/Compliance Operations (🔒 Sensitive)
    case createSARReport              // Suspicious Activity Report
    case viewSARReports
    case approveKYCDecision           // 4-Augen for manual KYC
    case processGDPRRequest           // Art. 15/17 DSGVO
    case approveGDPRDeletion          // 4-Augen for deletion
    case viewAMLFlags

    // MARK: - Approval Authority (Teamlead/Supervisor)
    case approveAccountSuspension     // 4-Augen approver
    case approveChargeback            // 4-Augen approver
    case approveSARSubmission         // 4-Augen approver
    case manageAgentPermissions

    var displayName: String {
        switch self {
        case .viewCustomerProfile: return "Kundenprofil anzeigen"
        case .viewCustomerKYCStatus: return "KYC-Status anzeigen"
        case .viewCustomerInvestments: return "Investments anzeigen"
        case .viewCustomerTrades: return "Trades anzeigen"
        case .viewCustomerDocuments: return "Dokumente anzeigen"
        case .viewCustomerNotifications: return "Benachrichtigungen anzeigen"
        case .viewCustomerSupportHistory: return "Support-Verlauf anzeigen"
        case .updateCustomerContact: return "Kontaktdaten aktualisieren"
        case .updateCustomerAddress: return "Adresse aktualisieren"
        case .updateCustomerName: return "Name aktualisieren"
        case .resetCustomerPassword: return "Passwort zurücksetzen"
        case .unlockCustomerAccount: return "Konto entsperren"
        case .createSupportTicket: return "Support-Ticket erstellen"
        case .respondToSupportTicket: return "Support-Ticket beantworten"
        case .escalateToAdmin: return "An Admin eskalieren"
        case .addInternalNote: return "Interne Notiz hinzufügen"
        case .initiateKYCReview: return "KYC-Prüfung einleiten"
        case .requestComplianceCheck: return "Compliance-Prüfung anfordern"
        case .viewAuditLogs: return "Audit-Protokolle anzeigen"
        // Fraud Operations
        case .viewFraudAlerts: return "Fraud-Alerts anzeigen"
        case .suspendAccountTemporary: return "Konto temporär sperren (<24h)"
        case .suspendAccountExtended: return "Konto erweitert sperren (>24h)"
        case .blockPaymentCard: return "Zahlungskarte sperren"
        case .initiateChargeback: return "Chargeback einleiten"
        case .viewTransactionPatterns: return "Transaktionsmuster anzeigen"
        case .flagSuspiciousActivity: return "Verdächtige Aktivität melden"
        // AML/Compliance
        case .createSARReport: return "SAR-Meldung erstellen"
        case .viewSARReports: return "SAR-Meldungen anzeigen"
        case .approveKYCDecision: return "KYC-Entscheidung genehmigen"
        case .processGDPRRequest: return "DSGVO-Anfrage bearbeiten"
        case .approveGDPRDeletion: return "DSGVO-Löschung genehmigen"
        case .viewAMLFlags: return "AML-Flags anzeigen"
        // Approval Authority
        case .approveAccountSuspension: return "Kontosperrung genehmigen"
        case .approveChargeback: return "Chargeback genehmigen"
        case .approveSARSubmission: return "SAR-Einreichung genehmigen"
        case .manageAgentPermissions: return "Agenten-Berechtigungen verwalten"
        }
    }

    /// Whether this permission requires 4-Augen approval before execution
    var requiresApproval: Bool {
        switch self {
        case .updateCustomerAddress, .updateCustomerName,
             .suspendAccountExtended, .initiateChargeback,
             .createSARReport, .approveGDPRDeletion:
            return true
        default:
            return false
        }
    }

    /// Whether this permission triggers a compliance check
    var triggersComplianceCheck: Bool {
        switch self {
        case .updateCustomerAddress, .updateCustomerName, .resetCustomerPassword,
             .suspendAccountTemporary, .suspendAccountExtended,
             .blockPaymentCard, .flagSuspiciousActivity:
            return true
        default:
            return false
        }
    }

    /// Whether this permission requires AML documentation
    var requiresAMLDocumentation: Bool {
        switch self {
        case .createSARReport, .flagSuspiciousActivity,
             .suspendAccountExtended, .viewAMLFlags:
            return true
        default:
            return false
        }
    }

    /// Whether this permission is read-only
    var isReadOnly: Bool {
        switch self {
        case .viewCustomerProfile, .viewCustomerKYCStatus, .viewCustomerInvestments,
             .viewCustomerTrades, .viewCustomerDocuments, .viewCustomerNotifications,
             .viewCustomerSupportHistory, .viewAuditLogs, .viewFraudAlerts,
             .viewTransactionPatterns, .viewSARReports, .viewAMLFlags:
            return true
        default:
            return false
        }
    }

    /// Category for UI grouping
    var category: PermissionCategory {
        switch self {
        case .viewCustomerProfile, .viewCustomerKYCStatus, .viewCustomerInvestments,
             .viewCustomerTrades, .viewCustomerDocuments, .viewCustomerNotifications,
             .viewCustomerSupportHistory:
            return .viewing
        case .updateCustomerContact, .updateCustomerAddress, .updateCustomerName,
             .resetCustomerPassword, .unlockCustomerAccount:
            return .modification
        case .createSupportTicket, .respondToSupportTicket, .escalateToAdmin, .addInternalNote:
            return .support
        case .initiateKYCReview, .requestComplianceCheck, .viewAuditLogs,
             .approveKYCDecision, .processGDPRRequest, .approveGDPRDeletion,
             .viewAMLFlags, .createSARReport, .viewSARReports, .approveSARSubmission:
            return .compliance
        case .viewFraudAlerts, .suspendAccountTemporary, .suspendAccountExtended,
             .blockPaymentCard, .initiateChargeback, .viewTransactionPatterns,
             .flagSuspiciousActivity, .approveChargeback:
            return .fraud
        case .approveAccountSuspension, .manageAgentPermissions:
            return .administration
        }
    }
}
