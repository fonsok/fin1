import Foundation

// MARK: - GDPR Request

/// DSGVO-compliant data subject request (Art. 15, 17, 20)
struct GDPRRequest: Identifiable, Codable {
    let id: String
    let customerId: String
    let customerName: String
    let customerEmail: String
    let requestType: GDPRRequestType
    let description: String
    let identityVerified: Bool
    let identityVerifiedBy: String?
    let identityVerifiedAt: Date?
    let createdAt: Date
    let deadlineAt: Date
    var extendedDeadlineAt: Date?
    var extensionReason: String?
    var status: GDPRRequestStatus
    var assignedTo: String?
    var processedBy: String?
    var processedAt: Date?
    var approvedBy: String?
    var approvalTimestamp: Date?
    var completedAt: Date?
    var responseDocument: String?
    var retentionConflicts: [RetentionConflict]
    let relatedTicketId: String?

    /// DSGVO Art. 12(3): 30 days deadline, extendable by 60 days
    var isOverdue: Bool {
        let effectiveDeadline = self.extendedDeadlineAt ?? self.deadlineAt
        return Date() > effectiveDeadline && !self.status.isFinal
    }

    /// Days remaining until deadline
    var daysRemaining: Int {
        let effectiveDeadline = self.extendedDeadlineAt ?? self.deadlineAt
        let days = Calendar.current.dateComponents([.day], from: Date(), to: effectiveDeadline).day ?? 0
        return max(0, days)
    }

    /// Whether this request can still be extended
    var canExtendDeadline: Bool {
        self.extendedDeadlineAt == nil && !self.status.isFinal
    }

    /// Whether this request requires 4-Augen approval
    var requiresApproval: Bool {
        self.requestType == .erasure || self.requestType == .restriction
    }

    init(
        id: String = UUID().uuidString,
        customerId: String,
        customerName: String,
        customerEmail: String,
        requestType: GDPRRequestType,
        description: String,
        relatedTicketId: String? = nil
    ) {
        self.id = id
        self.customerId = customerId
        self.customerName = customerName
        self.customerEmail = customerEmail
        self.requestType = requestType
        self.description = description
        self.identityVerified = false
        self.identityVerifiedBy = nil
        self.identityVerifiedAt = nil
        self.createdAt = Date()
        // DSGVO Art. 12(3): 30 days deadline
        self.deadlineAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        self.extendedDeadlineAt = nil
        self.extensionReason = nil
        self.status = .received
        self.assignedTo = nil
        self.processedBy = nil
        self.processedAt = nil
        self.approvedBy = nil
        self.approvalTimestamp = nil
        self.completedAt = nil
        self.responseDocument = nil
        self.retentionConflicts = []
        self.relatedTicketId = relatedTicketId
    }
}

// MARK: - GDPR Request Type

enum GDPRRequestType: String, Codable, CaseIterable {
    case access = "Auskunft (Art. 15)"
    case rectification = "Berichtigung (Art. 16)"
    case erasure = "Löschung (Art. 17)"
    case restriction = "Einschränkung (Art. 18)"
    case portability = "Datenübertragung (Art. 20)"
    case objection = "Widerspruch (Art. 21)"

    var displayName: String { rawValue }

    var articleNumber: String {
        switch self {
        case .access: return "Art. 15 DSGVO"
        case .rectification: return "Art. 16 DSGVO"
        case .erasure: return "Art. 17 DSGVO"
        case .restriction: return "Art. 18 DSGVO"
        case .portability: return "Art. 20 DSGVO"
        case .objection: return "Art. 21 DSGVO"
        }
    }

    /// Whether this request type requires 4-Augen approval
    var requiresFourEyesApproval: Bool {
        switch self {
        case .erasure, .restriction:
            return true
        default:
            return false
        }
    }

    /// Whether data must be provided in machine-readable format
    var requiresMachineReadableFormat: Bool {
        switch self {
        case .portability:
            return true
        default:
            return false
        }
    }
}

// MARK: - GDPR Request Status

enum GDPRRequestStatus: String, Codable, CaseIterable {
    case received = "Empfangen"
    case identityPending = "Identitätsprüfung ausstehend"
    case identityVerified = "Identität verifiziert"
    case inProgress = "In Bearbeitung"
    case pendingApproval = "Genehmigung ausstehend"
    case approved = "Genehmigt"
    case completed = "Abgeschlossen"
    case rejected = "Abgelehnt"
    case partiallyCompleted = "Teilweise abgeschlossen"

    var displayName: String { rawValue }

    var isFinal: Bool {
        switch self {
        case .completed, .rejected, .partiallyCompleted:
            return true
        default:
            return false
        }
    }
}

// MARK: - Retention Conflict

/// Documents legal retention requirements that conflict with deletion requests
struct RetentionConflict: Identifiable, Codable {
    let id: String
    let dataCategory: GDPRDataCategory
    let legalBasis: String
    let retentionPeriod: String
    let retentionEndDate: Date?
    let explanation: String

    init(
        id: String = UUID().uuidString,
        dataCategory: GDPRDataCategory,
        legalBasis: String,
        retentionPeriod: String,
        retentionEndDate: Date? = nil,
        explanation: String
    ) {
        self.id = id
        self.dataCategory = dataCategory
        self.legalBasis = legalBasis
        self.retentionPeriod = retentionPeriod
        self.retentionEndDate = retentionEndDate
        self.explanation = explanation
    }
}

// MARK: - GDPR Data Category (for GDPR inventory)

/// Categories of personal data processed (DSGVO Art. 30)
/// Note: Named GDPRDataCategory to avoid conflict with DataCategory in AuditModels
enum GDPRDataCategory: String, Codable, CaseIterable {
    case personalIdentification = "Persönliche Identifikation"
    case contactInformation = "Kontaktdaten"
    case financialInformation = "Finanzinformationen"
    case identityDocuments = "Ausweisdokumente"
    case tradingData = "Handelsdaten"
    case investmentData = "Investmentdaten"
    case kycAmlData = "KYC/AML-Daten"
    case communicationData = "Kommunikationsdaten"
    case loginData = "Anmeldedaten"
    case deviceData = "Gerätedaten"
    case locationData = "Standortdaten"

    var displayName: String { rawValue }

    /// Whether this is special category data under GDPR Art. 9
    var isSpecialCategory: Bool {
        switch self {
        case .identityDocuments, .kycAmlData:
            return true
        default:
            return false
        }
    }

    /// Legal retention period for this data category
    var legalRetentionPeriod: String? {
        switch self {
        case .kycAmlData:
            return "10 Jahre (GwG §8)"
        case .tradingData, .investmentData:
            return "10 Jahre (HGB §257)"
        case .financialInformation:
            return "10 Jahre (AO §147)"
        case .identityDocuments:
            return "5 Jahre nach Vertragsende (GwG §8)"
        default:
            return nil
        }
    }
}

// MARK: - GDPR Response Document

/// Document generated as response to GDPR request
struct GDPRResponseDocument: Identifiable, Codable {
    let id: String
    let requestId: String
    let requestType: GDPRRequestType
    let customerId: String
    let customerName: String
    let generatedAt: Date
    let generatedBy: String
    let format: GDPRResponseFormat
    let dataCategories: [GDPRDataCategory]
    let documentPath: String?
    let expiresAt: Date

    init(
        id: String = UUID().uuidString,
        requestId: String,
        requestType: GDPRRequestType,
        customerId: String,
        customerName: String,
        generatedBy: String,
        format: GDPRResponseFormat,
        dataCategories: [GDPRDataCategory],
        documentPath: String? = nil
    ) {
        self.id = id
        self.requestId = requestId
        self.requestType = requestType
        self.customerId = customerId
        self.customerName = customerName
        self.generatedAt = Date()
        self.generatedBy = generatedBy
        self.format = format
        self.dataCategories = dataCategories
        self.documentPath = documentPath
        // Document available for download for 30 days
        self.expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    }
}

// MARK: - GDPR Response Format

enum GDPRResponseFormat: String, Codable, CaseIterable {
    case pdf = "PDF"
    case json = "JSON"
    case csv = "CSV"
    case xml = "XML"

    var displayName: String { rawValue }

    var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .xml: return "application/xml"
        }
    }

    /// Whether this format is machine-readable (required for Art. 20)
    var isMachineReadable: Bool {
        switch self {
        case .json, .csv, .xml:
            return true
        case .pdf:
            return false
        }
    }
}

// MARK: - Standard Retention Conflicts (for common scenarios)

extension RetentionConflict {
    /// Standard retention conflicts for AML data
    static let amlRetention = RetentionConflict(
        dataCategory: .kycAmlData,
        legalBasis: "§ 8 GwG (Geldwäschegesetz)",
        retentionPeriod: "10 Jahre nach Vertragsende",
        explanation: "AML/KYC-Daten unterliegen einer gesetzlichen Aufbewahrungspflicht von 10 Jahren."
    )

    /// Standard retention conflicts for trading data
    static let tradingRetention = RetentionConflict(
        dataCategory: .tradingData,
        legalBasis: "§ 257 HGB (Handelsgesetzbuch)",
        retentionPeriod: "10 Jahre",
        explanation: "Handelsdaten und Geschäftskorrespondenz müssen 10 Jahre aufbewahrt werden."
    )

    /// Standard retention conflicts for tax-relevant data
    static let taxRetention = RetentionConflict(
        dataCategory: .financialInformation,
        legalBasis: "§ 147 AO (Abgabenordnung)",
        retentionPeriod: "10 Jahre",
        explanation: "Steuerlich relevante Unterlagen müssen 10 Jahre aufbewahrt werden."
    )
}
