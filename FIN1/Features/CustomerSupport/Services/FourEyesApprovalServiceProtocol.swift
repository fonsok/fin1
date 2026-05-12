import Foundation

// MARK: - Four-Eyes Approval Service Protocol

/// Service for managing 4-Augen-Prinzip approval workflows
/// Ensures compliance with AML, PSD2, and GDPR requirements
protocol FourEyesApprovalServiceProtocol: AnyObject, Sendable {
    // MARK: - Request Creation

    /// Create a new approval request
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
    ) async throws -> FourEyesApprovalRequest

    // MARK: - Request Retrieval

    /// Get all pending approval requests
    func getPendingRequests() async throws -> [FourEyesApprovalRequest]

    /// Get pending requests that the current agent can approve
    func getPendingRequestsForApprover(approverRole: CSRRole) async throws -> [FourEyesApprovalRequest]

    /// Get requests created by a specific agent
    func getRequestsByRequester(requesterId: String) async throws -> [FourEyesApprovalRequest]

    /// Get a specific approval request by ID
    func getRequest(id: String) async throws -> FourEyesApprovalRequest?

    /// Get approval queue statistics
    func getQueueStatistics() async throws -> ApprovalQueueStats

    // MARK: - Approval Actions

    /// Approve a request (4-Augen second approval)
    func approveRequest(
        requestId: String,
        approverId: String,
        approverName: String,
        approverRole: CSRRole,
        notes: String?
    ) async throws -> FourEyesApprovalRequest

    /// Reject a request
    func rejectRequest(
        requestId: String,
        approverId: String,
        approverName: String,
        approverRole: CSRRole,
        reason: String
    ) async throws -> FourEyesApprovalRequest

    /// Cancel a pending request (by the requester)
    func cancelRequest(requestId: String, requesterId: String) async throws

    // MARK: - Validation

    /// Check if an agent can approve a specific request type
    func canApprove(agentRole: CSRRole, requestType: ApprovalRequestType) -> Bool

    /// Validate that the approver is different from the requester (4-Augen)
    func validateFourEyesPrinciple(requesterId: String, approverId: String) -> Bool

    // MARK: - Audit

    /// Get audit trail for a specific request
    func getAuditTrail(requestId: String) async throws -> [ApprovalAuditEntry]

    /// Get all audit entries for a customer
    func getCustomerAuditTrail(customerId: String) async throws -> [ApprovalAuditEntry]
}

// MARK: - Four-Eyes Approval Error

enum FourEyesApprovalError: Error, LocalizedError {
    case requestNotFound
    case requestAlreadyProcessed
    case requestExpired
    case insufficientPermissions
    case samePersonApproval
    case invalidApproverRole
    case cancellationNotAllowed

    var errorDescription: String? {
        switch self {
        case .requestNotFound:
            return "Genehmigungsanfrage nicht gefunden"
        case .requestAlreadyProcessed:
            return "Diese Anfrage wurde bereits bearbeitet"
        case .requestExpired:
            return "Diese Anfrage ist abgelaufen"
        case .insufficientPermissions:
            return "Keine Berechtigung für diese Genehmigung"
        case .samePersonApproval:
            return "4-Augen-Prinzip: Der Genehmiger muss eine andere Person sein"
        case .invalidApproverRole:
            return "Diese Rolle kann diesen Anfragetyp nicht genehmigen"
        case .cancellationNotAllowed:
            return "Stornierung nicht möglich"
        }
    }
}
