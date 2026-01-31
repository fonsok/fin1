import Foundation

// MARK: - Audit Action
/// Represents an action performed by a customer support representative

struct AuditAction: Codable, Identifiable {
    let id: String
    let agentId: String
    let agentRole: String
    let customerId: String?
    let actionType: AuditActionType
    let permission: String
    let description: String
    let previousValue: String?
    let newValue: String?
    let ipAddress: String?
    let deviceInfo: String?
    let timestamp: Date
    let sessionId: String?
    let approvedBy: String?
    let approvalTimestamp: Date?

    init(
        agentId: String,
        agentRole: String,
        customerId: String? = nil,
        actionType: AuditActionType,
        permission: CustomerSupportPermission,
        description: String,
        previousValue: String? = nil,
        newValue: String? = nil,
        ipAddress: String? = nil,
        deviceInfo: String? = nil,
        sessionId: String? = nil,
        approvedBy: String? = nil,
        approvalTimestamp: Date? = nil
    ) {
        self.id = UUID().uuidString
        self.agentId = agentId
        self.agentRole = agentRole
        self.customerId = customerId
        self.actionType = actionType
        self.permission = permission.rawValue
        self.description = description
        self.previousValue = previousValue
        self.newValue = newValue
        self.ipAddress = ipAddress
        self.deviceInfo = deviceInfo
        self.timestamp = Date()
        self.sessionId = sessionId
        self.approvedBy = approvedBy
        self.approvalTimestamp = approvalTimestamp
    }
}

// MARK: - Audit Action Type

enum AuditActionType: String, Codable, CaseIterable {
    case view
    case create
    case update
    case delete
    case export
    case login
    case logout
    case escalation
    case complianceCheck
    case approval
    case rejection

    var displayName: String {
        switch self {
        case .view: return "Anzeigen"
        case .create: return "Erstellen"
        case .update: return "Aktualisieren"
        case .delete: return "Löschen"
        case .export: return "Exportieren"
        case .login: return "Anmelden"
        case .logout: return "Abmelden"
        case .escalation: return "Eskalation"
        case .complianceCheck: return "Compliance-Prüfung"
        case .approval: return "Genehmigung"
        case .rejection: return "Ablehnung"
        }
    }

    var isSensitive: Bool {
        switch self {
        case .update, .delete, .export, .complianceCheck:
            return true
        default:
            return false
        }
    }
}

// MARK: - Data Access Log
/// Logs access to sensitive customer data for GDPR compliance

struct DataAccessLog: Codable, Identifiable {
    let id: String
    let agentId: String
    let customerId: String
    let dataCategory: DataCategory
    let accessType: DataAccessType
    let fields: [String]
    let purpose: String
    let legalBasis: LegalBasis
    let timestamp: Date

    init(
        agentId: String,
        customerId: String,
        dataCategory: DataCategory,
        accessType: DataAccessType,
        fields: [String],
        purpose: String,
        legalBasis: LegalBasis
    ) {
        self.id = UUID().uuidString
        self.agentId = agentId
        self.customerId = customerId
        self.dataCategory = dataCategory
        self.accessType = accessType
        self.fields = fields
        self.purpose = purpose
        self.legalBasis = legalBasis
        self.timestamp = Date()
    }
}

// MARK: - Data Category (GDPR Art. 9 categories)

enum DataCategory: String, Codable, CaseIterable {
    case personalIdentification
    case contactInformation
    case financialInformation
    case identityDocuments
    case tradingData
    case investmentData
    case kycAmlData
    case communicationData

    var displayName: String {
        switch self {
        case .personalIdentification: return "Persönliche Identifikation"
        case .contactInformation: return "Kontaktdaten"
        case .financialInformation: return "Finanzinformationen"
        case .identityDocuments: return "Ausweisdokumente"
        case .tradingData: return "Handelsdaten"
        case .investmentData: return "Investmentdaten"
        case .kycAmlData: return "KYC/AML-Daten"
        case .communicationData: return "Kommunikationsdaten"
        }
    }

    /// Whether this is special category data under GDPR Art. 9
    var isSpecialCategory: Bool {
        switch self {
        case .identityDocuments, .kycAmlData:
            return true
        default:
            return false
        }
    }
}

// MARK: - Data Access Type

enum DataAccessType: String, Codable {
    case read
    case export
    case search

    var displayName: String {
        switch self {
        case .read: return "Lesen"
        case .export: return "Exportieren"
        case .search: return "Suchen"
        }
    }
}

// MARK: - Legal Basis (GDPR Art. 6)

enum LegalBasis: String, Codable, CaseIterable {
    case contractPerformance      // Art. 6(1)(b)
    case legalObligation          // Art. 6(1)(c) - KYC/AML
    case legitimateInterests      // Art. 6(1)(f) - Support
    case consent                  // Art. 6(1)(a)

    var displayName: String {
        switch self {
        case .contractPerformance: return "Vertragserfüllung (Art. 6(1)(b))"
        case .legalObligation: return "Rechtliche Verpflichtung (Art. 6(1)(c))"
        case .legitimateInterests: return "Berechtigtes Interesse (Art. 6(1)(f))"
        case .consent: return "Einwilligung (Art. 6(1)(a))"
        }
    }
}

// MARK: - Compliance Event
/// Represents a compliance-relevant event that requires tracking

struct ComplianceEvent: Codable, Identifiable {
    let id: String
    let eventType: ComplianceEventType
    let agentId: String
    let customerId: String
    let description: String
    let severity: ComplianceSeverity
    let requiresReview: Bool
    let reviewedBy: String?
    let reviewedAt: Date?
    let notes: String?
    let timestamp: Date

    init(
        eventType: ComplianceEventType,
        agentId: String,
        customerId: String,
        description: String,
        severity: ComplianceSeverity,
        requiresReview: Bool = true,
        notes: String? = nil
    ) {
        self.id = UUID().uuidString
        self.eventType = eventType
        self.agentId = agentId
        self.customerId = customerId
        self.description = description
        self.severity = severity
        self.requiresReview = requiresReview
        self.reviewedBy = nil
        self.reviewedAt = nil
        self.notes = notes
        self.timestamp = Date()
    }
}

// MARK: - Compliance Event Type

enum ComplianceEventType: String, Codable, CaseIterable {
    case addressChange
    case nameChange
    case kycUpdate
    case suspiciousActivity
    case accountUnlock
    case passwordReset
    case dataExport
    case escalation
    // MARK: - Trading Events (MiFID II Compliance)
    case orderPlaced
    case orderExecuted
    case orderCompleted
    case orderCancelled
    case tradeCompleted
    case deposit
    case withdrawal
    case riskCheck

    var displayName: String {
        switch self {
        case .addressChange: return "Adressänderung"
        case .nameChange: return "Namensänderung"
        case .kycUpdate: return "KYC-Aktualisierung"
        case .suspiciousActivity: return "Verdächtige Aktivität"
        case .accountUnlock: return "Kontoentsperrung"
        case .passwordReset: return "Passwort-Zurücksetzung"
        case .dataExport: return "Datenexport"
        case .escalation: return "Eskalation"
        case .orderPlaced: return "Order platziert"
        case .orderExecuted: return "Order ausgeführt"
        case .orderCompleted: return "Order abgeschlossen"
        case .orderCancelled: return "Order storniert"
        case .tradeCompleted: return "Trade abgeschlossen"
        case .deposit: return "Einzahlung"
        case .withdrawal: return "Auszahlung"
        case .riskCheck: return "Risiko-Prüfung"
        }
    }

    /// Default severity for this event type
    var defaultSeverity: ComplianceSeverity {
        switch self {
        case .suspiciousActivity:
            return .high
        case .addressChange, .nameChange, .kycUpdate:
            return .medium
        case .orderPlaced, .orderExecuted, .tradeCompleted, .deposit, .withdrawal:
            return .medium // MiFID II requires logging but medium severity
        case .riskCheck:
            return .low
        default:
            return .low
        }
    }
}

// MARK: - Compliance Severity

enum ComplianceSeverity: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case critical

    var displayName: String {
        switch self {
        case .low: return "Niedrig"
        case .medium: return "Mittel"
        case .high: return "Hoch"
        case .critical: return "Kritisch"
        }
    }
}

// MARK: - Audit Log Entry
/// Combined audit log entry for display and export

struct AuditLogEntry: Codable, Identifiable {
    let id: String
    let entryType: AuditLogEntryType
    let agentId: String
    let agentName: String?
    let customerId: String?
    let customerName: String?
    let action: String
    let description: String
    let timestamp: Date
    let metadata: [String: String]

    enum AuditLogEntryType: String, Codable {
        case action
        case dataAccess
        case compliance
    }
}





