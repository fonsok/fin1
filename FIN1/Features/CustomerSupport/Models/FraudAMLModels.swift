import Foundation

// MARK: - Account Suspension

/// Represents an account suspension action
struct AccountSuspension: Identifiable, Codable {
    let id: String
    let customerId: String
    let customerName: String
    let suspensionType: SuspensionType
    let reason: String
    let initiatedBy: String
    let initiatedAt: Date
    var approvedBy: String?
    var approvalTimestamp: Date?
    var expiresAt: Date?
    var liftedAt: Date?
    var liftedBy: String?
    let relatedTicketId: String?

    /// Whether this suspension requires 4-Augen approval
    var requiresApproval: Bool {
        suspensionType == .extended || suspensionType == .permanent
    }

    /// Current status of the suspension
    var status: SuspensionStatus {
        if liftedAt != nil {
            return .lifted
        }
        if requiresApproval && approvedBy == nil {
            return .pendingApproval
        }
        if let expiresAt = expiresAt, Date() > expiresAt {
            return .expired
        }
        return .active
    }

    init(
        id: String = UUID().uuidString,
        customerId: String,
        customerName: String,
        suspensionType: SuspensionType,
        reason: String,
        initiatedBy: String,
        relatedTicketId: String? = nil
    ) {
        self.id = id
        self.customerId = customerId
        self.customerName = customerName
        self.suspensionType = suspensionType
        self.reason = reason
        self.initiatedBy = initiatedBy
        self.initiatedAt = Date()
        self.approvedBy = nil
        self.approvalTimestamp = nil
        self.expiresAt = suspensionType.defaultExpiration
        self.liftedAt = nil
        self.liftedBy = nil
        self.relatedTicketId = relatedTicketId
    }
}

// MARK: - Suspension Type

enum SuspensionType: String, Codable, CaseIterable {
    case temporary    // <24h, no approval needed
    case extended     // >24h, requires 4-Augen approval
    case permanent    // Permanent, requires 4-Augen approval

    var displayName: String {
        switch self {
        case .temporary: return "Temporär (<24h)"
        case .extended: return "Erweitert (>24h)"
        case .permanent: return "Dauerhaft"
        }
    }

    var defaultExpiration: Date? {
        switch self {
        case .temporary:
            return Calendar.current.date(byAdding: .hour, value: 24, to: Date())
        case .extended:
            return Calendar.current.date(byAdding: .day, value: 7, to: Date())
        case .permanent:
            return nil
        }
    }

    /// Whether this type requires 4-Augen approval
    var requiresFourEyesApproval: Bool {
        switch self {
        case .temporary: return false
        case .extended, .permanent: return true
        }
    }
}

// MARK: - Suspension Status

enum SuspensionStatus: String, Codable {
    case pendingApproval = "Genehmigung ausstehend"
    case active = "Aktiv"
    case expired = "Abgelaufen"
    case lifted = "Aufgehoben"
}

// MARK: - SAR Report (Suspicious Activity Report)

/// AML-compliant Suspicious Activity Report for FIU submission
/// 🔒 SENSITIVE: Requires 4-Augen approval before submission
struct SARReport: Identifiable, Codable {
    let id: String
    let customerId: String
    let customerName: String
    let reportType: SARReportType
    let suspicionCategory: SuspicionCategory
    let description: String
    let transactionIds: [String]
    let totalAmount: Decimal
    let currency: String
    let createdBy: String
    let createdAt: Date
    var approvedBy: String?
    var approvalTimestamp: Date?
    var submittedToFIU: Bool
    var fiuReferenceNumber: String?
    var fiuSubmissionDate: Date?
    let relatedTicketId: String?

    /// Current status of the SAR
    var status: SARStatus {
        if submittedToFIU {
            return .submitted
        }
        if approvedBy != nil {
            return .approved
        }
        return .draft
    }

    init(
        id: String = UUID().uuidString,
        customerId: String,
        customerName: String,
        reportType: SARReportType,
        suspicionCategory: SuspicionCategory,
        description: String,
        transactionIds: [String],
        totalAmount: Decimal,
        currency: String = "EUR",
        createdBy: String,
        relatedTicketId: String? = nil
    ) {
        self.id = id
        self.customerId = customerId
        self.customerName = customerName
        self.reportType = reportType
        self.suspicionCategory = suspicionCategory
        self.description = description
        self.transactionIds = transactionIds
        self.totalAmount = totalAmount
        self.currency = currency
        self.createdBy = createdBy
        self.createdAt = Date()
        self.approvedBy = nil
        self.approvalTimestamp = nil
        self.submittedToFIU = false
        self.fiuReferenceNumber = nil
        self.fiuSubmissionDate = nil
        self.relatedTicketId = relatedTicketId
    }
}

// MARK: - SAR Report Type

enum SARReportType: String, Codable, CaseIterable {
    case initialReport = "Erstmeldung"
    case followUp = "Folgemeldung"
    case correction = "Korrektur"

    var displayName: String { rawValue }
}

// MARK: - SAR Status

enum SARStatus: String, Codable {
    case draft = "Entwurf"
    case approved = "Genehmigt"
    case submitted = "Eingereicht"
}

// MARK: - Suspicion Category (GwG §43)

enum SuspicionCategory: String, Codable, CaseIterable {
    case moneyLaundering = "Geldwäsche (§261 StGB)"
    case terroristFinancing = "Terrorismusfinanzierung (§89c StGB)"
    case fraudSuspicion = "Betrugsverdacht (§263 StGB)"
    case taxEvasion = "Steuerhinterziehung (§370 AO)"
    case unusualTransaction = "Ungewöhnliche Transaktion"
    case structuring = "Strukturierung (Smurfing)"
    case identityFraud = "Identitätsbetrug"
    case other = "Sonstige"

    var displayName: String { rawValue }

    var requiresImmediateAction: Bool {
        switch self {
        case .terroristFinancing, .moneyLaundering:
            return true
        default:
            return false
        }
    }
}

// MARK: - Chargeback Request

/// PSD2-compliant chargeback/dispute resolution
/// 🔒 >50€ requires 4-Augen approval
struct ChargebackRequest: Identifiable, Codable {
    let id: String
    let customerId: String
    let customerName: String
    let transactionId: String
    let transactionDate: Date
    let amount: Decimal
    let currency: String
    let merchantName: String
    let reason: ChargebackReason
    let description: String
    let createdBy: String
    let createdAt: Date
    var approvedBy: String?
    var approvalTimestamp: Date?
    var status: ChargebackStatus
    var provisionalCreditIssued: Bool
    var provisionalCreditDate: Date?
    var finalResolution: String?
    var resolvedAt: Date?
    let relatedTicketId: String?

    /// Whether this chargeback requires 4-Augen approval
    var requiresApproval: Bool {
        amount >= 50
    }

    /// PSD2 deadline: 1 business day for provisional credit
    var psd2DeadlineForCredit: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: createdAt) ?? createdAt
    }

    var isPSD2DeadlineBreached: Bool {
        !provisionalCreditIssued && Date() > psd2DeadlineForCredit
    }

    init(
        id: String = UUID().uuidString,
        customerId: String,
        customerName: String,
        transactionId: String,
        transactionDate: Date,
        amount: Decimal,
        currency: String = "EUR",
        merchantName: String,
        reason: ChargebackReason,
        description: String,
        createdBy: String,
        relatedTicketId: String? = nil
    ) {
        self.id = id
        self.customerId = customerId
        self.customerName = customerName
        self.transactionId = transactionId
        self.transactionDate = transactionDate
        self.amount = amount
        self.currency = currency
        self.merchantName = merchantName
        self.reason = reason
        self.description = description
        self.createdBy = createdBy
        self.createdAt = Date()
        self.approvedBy = nil
        self.approvalTimestamp = nil
        self.status = .pending
        self.provisionalCreditIssued = false
        self.provisionalCreditDate = nil
        self.finalResolution = nil
        self.resolvedAt = nil
        self.relatedTicketId = relatedTicketId
    }
}

// MARK: - Chargeback Reason

enum ChargebackReason: String, Codable, CaseIterable {
    case unauthorized = "Nicht autorisierte Transaktion"
    case duplicateCharge = "Doppelte Abbuchung"
    case wrongAmount = "Falscher Betrag"
    case serviceNotReceived = "Leistung nicht erhalten"
    case goodsNotReceived = "Ware nicht erhalten"
    case qualityDispute = "Qualitätsmangel"
    case subscriptionCancelled = "Abo bereits gekündigt"
    case fraudulent = "Betrügerische Transaktion"
    case other = "Sonstige"

    var displayName: String { rawValue }
}

// MARK: - Chargeback Status

enum ChargebackStatus: String, Codable {
    case pending = "Ausstehend"
    case pendingApproval = "Genehmigung ausstehend"
    case approved = "Genehmigt"
    case provisionalCreditIssued = "Vorläufige Gutschrift erteilt"
    case underInvestigation = "In Prüfung"
    case resolvedInFavor = "Zugunsten Kunde entschieden"
    case resolvedAgainst = "Abgelehnt"
    case cancelled = "Storniert"
}

// MARK: - Fraud Alert

/// Automatic or manual fraud detection alert
struct FraudAlert: Identifiable, Codable {
    let id: String
    let customerId: String
    let customerName: String
    let alertType: FraudAlertType
    let severity: FraudAlertSeverity
    let description: String
    let detectedAt: Date
    let detectedBy: FraudDetectionSource
    var reviewedBy: String?
    var reviewedAt: Date?
    var resolution: FraudAlertResolution?
    var resolutionNotes: String?
    let relatedTransactionIds: [String]

    var isReviewed: Bool { reviewedBy != nil }

    init(
        id: String = UUID().uuidString,
        customerId: String,
        customerName: String,
        alertType: FraudAlertType,
        severity: FraudAlertSeverity,
        description: String,
        detectedBy: FraudDetectionSource,
        relatedTransactionIds: [String] = []
    ) {
        self.id = id
        self.customerId = customerId
        self.customerName = customerName
        self.alertType = alertType
        self.severity = severity
        self.description = description
        self.detectedAt = Date()
        self.detectedBy = detectedBy
        self.reviewedBy = nil
        self.reviewedAt = nil
        self.resolution = nil
        self.resolutionNotes = nil
        self.relatedTransactionIds = relatedTransactionIds
    }
}

// MARK: - Fraud Alert Type

enum FraudAlertType: String, Codable, CaseIterable {
    case unusualActivity = "Ungewöhnliche Aktivität"
    case locationAnomaly = "Standort-Anomalie"
    case velocityCheck = "Geschwindigkeitsprüfung"
    case deviceChange = "Gerätewechsel"
    case ipAnomaly = "IP-Anomalie"
    case transactionPattern = "Transaktionsmuster"
    case accountTakeover = "Kontoübernahme-Versuch"
    case cardNotPresent = "Card-Not-Present Verdacht"
    case manualReport = "Manuelle Meldung"

    var displayName: String { rawValue }
}

// MARK: - Fraud Alert Severity

enum FraudAlertSeverity: String, Codable, CaseIterable {
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

// MARK: - Fraud Detection Source

enum FraudDetectionSource: String, Codable {
    case automaticRule = "Automatische Regel"
    case mlModel = "ML-Modell"
    case manualReview = "Manuelle Prüfung"
    case customerReport = "Kundenmeldung"
    case externalSource = "Externe Quelle"

    var displayName: String { rawValue }
}

// MARK: - Fraud Alert Resolution

enum FraudAlertResolution: String, Codable, CaseIterable {
    case falsePositive = "False Positive"
    case confirmed = "Betrug bestätigt"
    case escalated = "Eskaliert"
    case noActionRequired = "Keine Aktion erforderlich"

    var displayName: String { rawValue }
}
