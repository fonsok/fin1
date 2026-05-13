import Foundation

// MARK: - Four-Eyes Approval Service

/// Implementation of 4-Augen-Prinzip approval workflows
/// Compliant with AML, PSD2, and GDPR requirements
final class FourEyesApprovalService: FourEyesApprovalServiceProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let auditService: AuditLoggingServiceProtocol

    // MARK: - State

    private var pendingRequests: [FourEyesApprovalRequest] = []
    private var processedRequests: [FourEyesApprovalRequest] = []
    private var auditEntries: [ApprovalAuditEntry] = []

    // MARK: - Initialization

    init(auditService: AuditLoggingServiceProtocol) {
        self.auditService = auditService
    }

    // MARK: - Request Creation

    func createApprovalRequest(
        type: ApprovalRequestType,
        requesterId: String,
        requesterName: String,
        requesterRole: CSRRole,
        customerId: String?,
        customerName: String?,
        description: String,
        sensitiveAction: String,
        justification: String,
        metadata: [String: String],
        relatedEntityId: String?,
        relatedEntityType: String?
    ) async throws -> FourEyesApprovalRequest {
        let request = FourEyesApprovalRequest(
            requestType: type,
            requesterId: requesterId,
            requesterName: requesterName,
            requesterRole: requesterRole,
            customerId: customerId,
            customerName: customerName,
            description: description,
            sensitiveAction: sensitiveAction,
            justification: justification,
            metadata: metadata,
            relatedEntityId: relatedEntityId,
            relatedEntityType: relatedEntityType
        )

        self.pendingRequests.append(request)

        // Create audit entry for request creation
        let auditEntry = ApprovalAuditEntry(request: request)
        self.auditEntries.append(auditEntry)

        return request
    }

    // MARK: - Request Retrieval

    func getPendingRequests() async throws -> [FourEyesApprovalRequest] {
        // Filter out expired requests
        let validRequests = self.pendingRequests.filter { !$0.isExpired }

        // Mark expired requests
        for index in self.pendingRequests.indices where self.pendingRequests[index].isExpired {
            pendingRequests[index].status = .expired
        }

        return validRequests.sorted { $0.createdAt > $1.createdAt }
    }

    func getPendingRequestsForApprover(approverRole: CSRRole) async throws -> [FourEyesApprovalRequest] {
        let allPending = try await getPendingRequests()

        return allPending.filter { request in
            request.requestType.approverRoles.contains(approverRole)
        }
    }

    func getRequestsByRequester(requesterId: String) async throws -> [FourEyesApprovalRequest] {
        let allRequests = self.pendingRequests + self.processedRequests
        return allRequests
            .filter { $0.requesterId == requesterId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func getRequest(id: String) async throws -> FourEyesApprovalRequest? {
        if let pending = pendingRequests.first(where: { $0.id == id }) {
            return pending
        }
        return self.processedRequests.first(where: { $0.id == id })
    }

    func getQueueStatistics() async throws -> ApprovalQueueStats {
        let pending = try await getPendingRequests()
        let today = Calendar.current.startOfDay(for: Date())

        let todayProcessed = self.processedRequests.filter { request in
            guard let timestamp = request.approvalTimestamp else { return false }
            return timestamp >= today
        }

        let pendingByType = Dictionary(grouping: pending, by: { $0.requestType })
            .mapValues { $0.count }

        let pendingByRisk = Dictionary(grouping: pending, by: { $0.requestType.riskLevel })
            .mapValues { $0.count }

        let approvedToday = todayProcessed.filter { $0.status == .approved }.count
        let rejectedToday = todayProcessed.filter { $0.status == .rejected }.count

        let expiredToday = self.pendingRequests.filter { request in
            request.status == .expired && request.expiresAt >= today
        }.count

        // Calculate average approval time
        let approvedWithTime = self.processedRequests.filter {
            $0.status == .approved && $0.approvalTimestamp != nil
        }
        let avgTime: Double
        if !approvedWithTime.isEmpty {
            let totalHours = approvedWithTime.reduce(0.0) { sum, request in
                guard let approvalTime = request.approvalTimestamp else { return sum }
                return sum + approvalTime.timeIntervalSince(request.createdAt) / 3_600
            }
            avgTime = totalHours / Double(approvedWithTime.count)
        } else {
            avgTime = 0
        }

        return ApprovalQueueStats(
            pendingCount: pending.count,
            pendingByType: pendingByType,
            pendingByRiskLevel: pendingByRisk,
            approvedToday: approvedToday,
            rejectedToday: rejectedToday,
            expiredToday: expiredToday,
            averageApprovalTimeHours: avgTime,
            oldestPendingRequest: pending.min { $0.createdAt < $1.createdAt }
        )
    }

    // MARK: - Approval Actions

    func approveRequest(
        requestId: String,
        approverId: String,
        approverName: String,
        approverRole: CSRRole,
        notes: String?
    ) async throws -> FourEyesApprovalRequest {
        guard let index = pendingRequests.firstIndex(where: { $0.id == requestId }) else {
            throw FourEyesApprovalError.requestNotFound
        }

        var request = self.pendingRequests[index]

        // Validate request state
        guard request.status == .pending else {
            throw FourEyesApprovalError.requestAlreadyProcessed
        }

        guard !request.isExpired else {
            throw FourEyesApprovalError.requestExpired
        }

        // Validate 4-Augen principle
        guard self.validateFourEyesPrinciple(requesterId: request.requesterId, approverId: approverId) else {
            throw FourEyesApprovalError.samePersonApproval
        }

        // Validate approver role
        guard self.canApprove(agentRole: approverRole, requestType: request.requestType) else {
            throw FourEyesApprovalError.invalidApproverRole
        }

        // Update request
        request.status = .approved
        request.approvedBy = approverId
        request.approverName = approverName
        request.approverRole = approverRole
        request.approvalTimestamp = Date()
        request.approvalNotes = notes

        // Move to processed
        self.pendingRequests.remove(at: index)
        self.processedRequests.append(request)

        // Create audit entry
        let decision = ApprovalDecision(
            requestId: requestId,
            approverId: approverId,
            approverName: approverName,
            approverRole: approverRole,
            decision: .approved,
            notes: notes
        )
        let auditEntry = ApprovalAuditEntry(request: request, decision: decision)
        self.auditEntries.append(auditEntry)

        return request
    }

    func rejectRequest(
        requestId: String,
        approverId: String,
        approverName: String,
        approverRole: CSRRole,
        reason: String
    ) async throws -> FourEyesApprovalRequest {
        guard let index = pendingRequests.firstIndex(where: { $0.id == requestId }) else {
            throw FourEyesApprovalError.requestNotFound
        }

        var request = self.pendingRequests[index]

        guard request.status == .pending else {
            throw FourEyesApprovalError.requestAlreadyProcessed
        }

        guard self.canApprove(agentRole: approverRole, requestType: request.requestType) else {
            throw FourEyesApprovalError.invalidApproverRole
        }

        // Update request
        request.status = .rejected
        request.approvedBy = approverId
        request.approverName = approverName
        request.approverRole = approverRole
        request.approvalTimestamp = Date()
        request.rejectionReason = reason

        // Move to processed
        self.pendingRequests.remove(at: index)
        self.processedRequests.append(request)

        // Create audit entry
        let decision = ApprovalDecision(
            requestId: requestId,
            approverId: approverId,
            approverName: approverName,
            approverRole: approverRole,
            decision: .rejected,
            rejectionReason: reason
        )
        let auditEntry = ApprovalAuditEntry(request: request, decision: decision)
        self.auditEntries.append(auditEntry)

        return request
    }

    func cancelRequest(requestId: String, requesterId: String) async throws {
        guard let index = pendingRequests.firstIndex(where: { $0.id == requestId }) else {
            throw FourEyesApprovalError.requestNotFound
        }

        let request = self.pendingRequests[index]

        guard request.requesterId == requesterId else {
            throw FourEyesApprovalError.cancellationNotAllowed
        }

        guard request.status == .pending else {
            throw FourEyesApprovalError.requestAlreadyProcessed
        }

        var cancelledRequest = request
        cancelledRequest.status = .cancelled

        self.pendingRequests.remove(at: index)
        self.processedRequests.append(cancelledRequest)
    }

    // MARK: - Validation

    func canApprove(agentRole: CSRRole, requestType: ApprovalRequestType) -> Bool {
        requestType.approverRoles.contains(agentRole)
    }

    func validateFourEyesPrinciple(requesterId: String, approverId: String) -> Bool {
        // 4-Augen: Different persons must be involved
        requesterId != approverId
    }

    // MARK: - Audit

    func getAuditTrail(requestId: String) async throws -> [ApprovalAuditEntry] {
        self.auditEntries
            .filter { $0.requestId == requestId }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func getCustomerAuditTrail(customerId: String) async throws -> [ApprovalAuditEntry] {
        self.auditEntries
            .filter { $0.customerId == customerId }
            .sorted { $0.timestamp > $1.timestamp }
    }
}
