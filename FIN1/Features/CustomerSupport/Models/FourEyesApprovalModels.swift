import Foundation

// MARK: - Four-Eyes Approval Request

/// 4-Augen-Prinzip: Request that requires approval from a second authorized person
/// Compliant with AML, PSD2, and GDPR requirements
struct FourEyesApprovalRequest: Identifiable, Codable {
    let id: String
    let requestType: ApprovalRequestType
    let requesterId: String
    let requesterName: String
    let requesterRole: CSRRole
    let customerId: String?
    let customerName: String?
    let description: String
    let sensitiveAction: String
    let justification: String
    let metadata: [String: String]
    let createdAt: Date
    let expiresAt: Date
    var status: ApprovalStatus
    var approvedBy: String?
    var approverName: String?
    var approverRole: CSRRole?
    var approvalTimestamp: Date?
    var approvalNotes: String?
    var rejectionReason: String?
    let relatedEntityId: String?
    let relatedEntityType: String?

    /// Whether this request has expired
    var isExpired: Bool {
        Date() > expiresAt && status == .pending
    }

    /// Remaining time until expiration
    var timeRemaining: TimeInterval? {
        guard status == .pending else { return nil }
        let remaining = expiresAt.timeIntervalSince(Date())
        return remaining > 0 ? remaining : nil
    }

    init(
        id: String = UUID().uuidString,
        requestType: ApprovalRequestType,
        requesterId: String,
        requesterName: String,
        requesterRole: CSRRole,
        customerId: String? = nil,
        customerName: String? = nil,
        description: String,
        sensitiveAction: String,
        justification: String,
        metadata: [String: String] = [:],
        relatedEntityId: String? = nil,
        relatedEntityType: String? = nil
    ) {
        self.id = id
        self.requestType = requestType
        self.requesterId = requesterId
        self.requesterName = requesterName
        self.requesterRole = requesterRole
        self.customerId = customerId
        self.customerName = customerName
        self.description = description
        self.sensitiveAction = sensitiveAction
        self.justification = justification
        self.metadata = metadata
        self.createdAt = Date()
        // Default expiration: 24 hours for most requests, 4 hours for urgent
        self.expiresAt = requestType.defaultExpiration
        self.status = .pending
        self.approvedBy = nil
        self.approverName = nil
        self.approverRole = nil
        self.approvalTimestamp = nil
        self.approvalNotes = nil
        self.rejectionReason = nil
        self.relatedEntityId = relatedEntityId
        self.relatedEntityType = relatedEntityType
    }
}

// MARK: - Approval Request Type

enum ApprovalRequestType: String, Codable, CaseIterable {
    // Account Actions
    case accountSuspensionExtended = "Erweiterte Kontosperrung"
    case accountSuspensionPermanent = "Dauerhafte Kontosperrung"
    case accountReactivation = "Kontofreigabe"

    // Financial Actions
    case chargebackOver50 = "Chargeback >50€"
    case chargebackOver500 = "Chargeback >500€"
    case refundOver100 = "Rückerstattung >100€"

    // Compliance/AML Actions
    case sarSubmission = "SAR-Einreichung an FIU"
    case manualKYCApproval = "Manuelle KYC-Genehmigung"
    case kycRejection = "KYC-Ablehnung"

    // GDPR Actions
    case gdprDataDeletion = "DSGVO-Datenlöschung"
    case gdprDataExport = "DSGVO-Datenexport"

    // Customer Data Modifications
    case addressChange = "Adressänderung"
    case nameChange = "Namensänderung"

    var displayName: String { rawValue }

    /// Which roles can approve this request type
    var approverRoles: Set<CSRRole> {
        switch self {
        case .sarSubmission, .manualKYCApproval, .kycRejection,
             .gdprDataDeletion, .gdprDataExport:
            return [.compliance, .teamlead]
        case .chargebackOver50, .chargebackOver500, .refundOver100:
            return [.fraud, .compliance, .teamlead]
        case .accountSuspensionExtended, .accountSuspensionPermanent, .accountReactivation:
            return [.fraud, .teamlead]
        case .addressChange, .nameChange:
            return [.level2, .compliance, .teamlead]
        }
    }

    /// Default expiration time for this request type
    var defaultExpiration: Date {
        switch self {
        case .accountSuspensionExtended, .accountSuspensionPermanent:
            // Urgent: 4 hours
            return Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        case .chargebackOver50, .chargebackOver500:
            // PSD2 requirement: Must process within 1 business day
            return Calendar.current.date(byAdding: .hour, value: 8, to: Date()) ?? Date()
        case .sarSubmission:
            // SAR should be reviewed promptly
            return Calendar.current.date(byAdding: .hour, value: 12, to: Date()) ?? Date()
        default:
            // Standard: 24 hours
            return Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
        }
    }

    /// Risk level of this action
    var riskLevel: ApprovalRiskLevel {
        switch self {
        case .sarSubmission, .accountSuspensionPermanent, .gdprDataDeletion:
            return .critical
        case .accountSuspensionExtended, .chargebackOver500, .manualKYCApproval, .kycRejection:
            return .high
        case .chargebackOver50, .gdprDataExport, .accountReactivation:
            return .medium
        case .addressChange, .nameChange, .refundOver100:
            return .low
        }
    }
}

// MARK: - Approval Status

enum ApprovalStatus: String, Codable, CaseIterable {
    case pending = "Ausstehend"
    case approved = "Genehmigt"
    case rejected = "Abgelehnt"
    case expired = "Abgelaufen"
    case cancelled = "Storniert"

    var isFinal: Bool {
        switch self {
        case .pending: return false
        case .approved, .rejected, .expired, .cancelled: return true
        }
    }
}

// MARK: - Approval Risk Level

enum ApprovalRiskLevel: String, Codable, CaseIterable {
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

    /// Recommended review time in hours
    var recommendedReviewTime: Int {
        switch self {
        case .low: return 24
        case .medium: return 12
        case .high: return 4
        case .critical: return 2
        }
    }
}

// MARK: - Approval Decision

/// Records the decision made by the approver
struct ApprovalDecision: Codable {
    let requestId: String
    let approverId: String
    let approverName: String
    let approverRole: CSRRole
    let decision: ApprovalStatus
    let notes: String?
    let rejectionReason: String?
    let timestamp: Date

    init(
        requestId: String,
        approverId: String,
        approverName: String,
        approverRole: CSRRole,
        decision: ApprovalStatus,
        notes: String? = nil,
        rejectionReason: String? = nil
    ) {
        self.requestId = requestId
        self.approverId = approverId
        self.approverName = approverName
        self.approverRole = approverRole
        self.decision = decision
        self.notes = notes
        self.rejectionReason = rejectionReason
        self.timestamp = Date()
    }
}

// MARK: - Approval Audit Entry

/// Immutable audit trail entry for 4-Augen decisions
struct ApprovalAuditEntry: Identifiable, Codable {
    let id: String
    let requestId: String
    let requestType: ApprovalRequestType
    let requesterId: String
    let requesterName: String
    let customerId: String?
    let customerName: String?
    let action: String
    let justification: String
    let approverId: String?
    let approverName: String?
    let decision: ApprovalStatus
    let decisionNotes: String?
    let timestamp: Date
    let ipAddress: String?
    let sessionId: String?

    init(
        request: FourEyesApprovalRequest,
        decision: ApprovalDecision? = nil,
        ipAddress: String? = nil,
        sessionId: String? = nil
    ) {
        self.id = UUID().uuidString
        self.requestId = request.id
        self.requestType = request.requestType
        self.requesterId = request.requesterId
        self.requesterName = request.requesterName
        self.customerId = request.customerId
        self.customerName = request.customerName
        self.action = request.sensitiveAction
        self.justification = request.justification
        self.approverId = decision?.approverId ?? request.approvedBy
        self.approverName = decision?.approverName ?? request.approverName
        self.decision = decision?.decision ?? request.status
        self.decisionNotes = decision?.notes ?? request.approvalNotes
        self.timestamp = Date()
        self.ipAddress = ipAddress
        self.sessionId = sessionId
    }
}

// MARK: - Approval Queue Statistics

/// Statistics for the approval queue dashboard
struct ApprovalQueueStats {
    let pendingCount: Int
    let pendingByType: [ApprovalRequestType: Int]
    let pendingByRiskLevel: [ApprovalRiskLevel: Int]
    let approvedToday: Int
    let rejectedToday: Int
    let expiredToday: Int
    let averageApprovalTimeHours: Double
    let oldestPendingRequest: FourEyesApprovalRequest?

    /// Requests that need urgent attention
    var urgentRequests: Int {
        (pendingByRiskLevel[.critical] ?? 0) + (pendingByRiskLevel[.high] ?? 0)
    }
}
