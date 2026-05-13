import Foundation

// MARK: - Four-Eyes Approval Queue ViewModel

/// ViewModel for the 4-Augen approval queue dashboard
@MainActor
final class FourEyesApprovalQueueViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var pendingRequests: [FourEyesApprovalRequest] = []
    @Published var statistics: ApprovalQueueStats?
    @Published var selectedFilter: ApprovalRiskLevel?
    @Published var selectedRequest: FourEyesApprovalRequest?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    @Published var successMessage: String?

    // MARK: - Dependencies

    private let approvalService: FourEyesApprovalServiceProtocol
    private let auditService: AuditLoggingServiceProtocol
    private let currentAgentId: String
    private let currentAgentName: String
    private let currentAgentRole: CSRRole

    // MARK: - Computed Properties

    var filteredRequests: [FourEyesApprovalRequest] {
        guard let filter = selectedFilter else {
            return self.pendingRequests
        }
        return self.pendingRequests.filter { $0.requestType.riskLevel == filter }
    }

    // MARK: - Initialization

    init(
        approvalService: FourEyesApprovalServiceProtocol,
        auditService: AuditLoggingServiceProtocol,
        currentAgentId: String,
        currentAgentName: String,
        currentAgentRole: CSRRole
    ) {
        self.approvalService = approvalService
        self.auditService = auditService
        self.currentAgentId = currentAgentId
        self.currentAgentName = currentAgentName
        self.currentAgentRole = currentAgentRole
    }

    // MARK: - Data Loading

    func loadRequests() async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            // Load requests that this agent can approve
            self.pendingRequests = try await self.approvalService.getPendingRequestsForApprover(
                approverRole: self.currentAgentRole
            )

            // Load statistics
            self.statistics = try await self.approvalService.getQueueStatistics()
        } catch {
            self.handleError(error)
        }
    }

    // MARK: - Approval Actions

    func approveRequest(_ request: FourEyesApprovalRequest, notes: String?) async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            _ = try await self.approvalService.approveRequest(
                requestId: request.id,
                approverId: self.currentAgentId,
                approverName: self.currentAgentName,
                approverRole: self.currentAgentRole,
                notes: notes
            )

            // Remove from local list
            self.pendingRequests.removeAll { $0.id == request.id }

            // Refresh statistics
            self.statistics = try await self.approvalService.getQueueStatistics()

            self.showSuccessMessage("Anfrage erfolgreich genehmigt")
        } catch {
            self.handleError(error)
        }
    }

    func rejectRequest(_ request: FourEyesApprovalRequest, reason: String) async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            _ = try await self.approvalService.rejectRequest(
                requestId: request.id,
                approverId: self.currentAgentId,
                approverName: self.currentAgentName,
                approverRole: self.currentAgentRole,
                reason: reason
            )

            // Remove from local list
            self.pendingRequests.removeAll { $0.id == request.id }

            // Refresh statistics
            self.statistics = try await self.approvalService.getQueueStatistics()

            self.showSuccessMessage("Anfrage abgelehnt")
        } catch {
            self.handleError(error)
        }
    }

    // MARK: - Validation

    func canApproveRequest(_ request: FourEyesApprovalRequest) -> Bool {
        // Check 4-Augen principle (different person)
        guard self.approvalService.validateFourEyesPrinciple(
            requesterId: request.requesterId,
            approverId: self.currentAgentId
        ) else {
            return false
        }

        // Check role permission
        return self.approvalService.canApprove(
            agentRole: self.currentAgentRole,
            requestType: request.requestType
        )
    }

    // MARK: - Error Handling

    func clearError() {
        self.showError = false
        self.errorMessage = nil
    }

    func clearSuccess() {
        self.showSuccess = false
        self.successMessage = nil
    }

    private func handleError(_ error: Error) {
        self.errorMessage = self.mapToAppError(error).errorDescription
        self.showError = true
    }

    private func showSuccessMessage(_ message: String) {
        self.successMessage = message
        self.showSuccess = true
    }

    private func mapToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let approvalError = error as? FourEyesApprovalError {
            switch approvalError {
            case .requestNotFound:
                return .service(.dataNotFound)
            case .requestAlreadyProcessed:
                return .validation("Anfrage bereits bearbeitet")
            case .requestExpired:
                return .validation("Anfrage abgelaufen")
            case .insufficientPermissions, .invalidApproverRole:
                return .service(.permissionDenied)
            case .samePersonApproval:
                return .validation("4-Augen-Prinzip verletzt")
            case .cancellationNotAllowed:
                return .validation("Stornierung nicht erlaubt")
            }
        }

        return .unknown(error.localizedDescription)
    }
}
