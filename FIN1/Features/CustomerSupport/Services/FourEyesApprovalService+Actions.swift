import Foundation

extension FourEyesApprovalService {
    // MARK: - Approval Actions

    func approveRequest(
        requestId: String,
        approverId: String,
        approverName: String,
        approverRole: CSRRole,
        notes: String?
    ) async throws -> FourEyesApprovalRequest {
        guard let index = self.pendingRequests.firstIndex(where: { $0.id == requestId }) else {
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
        guard let index = self.pendingRequests.firstIndex(where: { $0.id == requestId }) else {
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
        guard let index = self.pendingRequests.firstIndex(where: { $0.id == requestId }) else {
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
}
