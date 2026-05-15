import Foundation

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
        (self.pendingByRiskLevel[.critical] ?? 0) + (self.pendingByRiskLevel[.high] ?? 0)
    }
}
