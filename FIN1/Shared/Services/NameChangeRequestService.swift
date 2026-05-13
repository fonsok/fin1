import Combine
import Foundation

// MARK: - Name Change Request Service

/// Service handling GwG-compliant name change requests.
/// Implements complete re-verification for name changes due to marriage, divorce, etc.
/// These are considered significant life events affecting identity and risk profile.
final class NameChangeRequestService: NameChangeRequestServiceProtocol, ServiceLifecycle, @unchecked Sendable {

    // MARK: - Published Properties

    @Published private(set) var pendingRequests: [NameChangeRequest] = []
    @Published private(set) var requestHistory: [NameChangeRequest] = []
    @Published private(set) var isLoading = false

    // MARK: - Private Storage

    /// In-memory storage for demo purposes. In production, this would be persisted.
    private var allRequests: [NameChangeRequest] = []

    // MARK: - Initialization

    init() {}

    // MARK: - ServiceLifecycle

    func start() {
        // Attach listeners, restore state if needed
    }

    func stop() {
        // Detach listeners
    }

    func reset() {
        self.allRequests = []
        self.pendingRequests = []
        self.requestHistory = []
    }

    // MARK: - Request Submission

    func submitNameChangeRequest(
        userId: String,
        currentName: NameComponents,
        newName: NameComponents,
        reason: NameChangeReason,
        primaryDocumentType: NameVerificationDocumentType,
        primaryDocumentURL: String?,
        identityDocumentType: NameVerificationDocumentType,
        identityDocumentURL: String?,
        userDeclaration: Bool,
        acknowledgesRiskProfileUpdate: Bool
    ) async throws -> NameChangeRequest {
        // Validate inputs
        guard newName.isComplete else {
            throw AppError.validationError("New name is incomplete. First name and last name are required.")
        }

        guard userDeclaration else {
            throw AppError.validationError("User declaration is required")
        }

        guard acknowledgesRiskProfileUpdate else {
            throw AppError.validationError("Acknowledgement of risk profile update is required")
        }

        // Validate primary document is appropriate for the reason
        guard primaryDocumentType.isPrimaryDocument else {
            throw AppError.validationError("A primary document (certificate or court decree) is required")
        }

        // Validate identity document is new ID or passport
        guard identityDocumentType == .newIdCard || identityDocumentType == .newPassport else {
            throw AppError.validationError("A new ID card or passport showing the updated name is required")
        }

        guard primaryDocumentURL != nil else {
            throw AppError.validationError("Primary verification document is required")
        }

        guard identityDocumentURL != nil else {
            throw AppError.validationError("New identity document is required")
        }

        // Check for existing pending requests
        if self.hasPendingRequest(for: userId) {
            throw AppError.validationError(
                "You already have a pending name change request. Please wait for it to be reviewed or cancel it first."
            )
        }

        await MainActor.run {
            self.isLoading = true
        }

        // Simulate API call (longer for significant life events)
        let delay: UInt64 = reason.isSignificantLifeEvent ? 2_000_000_000 : 1_500_000_000
        try await Task.sleep(nanoseconds: delay)

        let request = NameChangeRequest(
            userId: userId,
            currentSalutation: currentName.salutation,
            currentAcademicTitle: currentName.academicTitle,
            currentFirstName: currentName.firstName,
            currentLastName: currentName.lastName,
            newSalutation: newName.salutation,
            newAcademicTitle: newName.academicTitle,
            newFirstName: newName.firstName,
            newLastName: newName.lastName,
            reason: reason,
            primaryDocumentType: primaryDocumentType,
            primaryDocumentURL: primaryDocumentURL,
            identityDocumentType: identityDocumentType,
            identityDocumentURL: identityDocumentURL,
            status: .pending,
            userDeclaration: userDeclaration,
            acknowledgesRiskProfileUpdate: acknowledgesRiskProfileUpdate
        )

        await MainActor.run {
            self.allRequests.append(request)
            self.updateRequestLists(for: userId)
            self.isLoading = false
        }

        // Post notification for new request
        NotificationCenter.default.post(
            name: .nameChangeRequestSubmitted,
            object: request
        )

        return request
    }

    // MARK: - Request Management

    func fetchRequests(for userId: String) async throws {
        await MainActor.run {
            self.isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)

        await MainActor.run {
            self.updateRequestLists(for: userId)
            self.isLoading = false
        }
    }

    func cancelRequest(_ requestId: String) async throws {
        guard let index = allRequests.firstIndex(where: { $0.id == requestId }) else {
            throw AppError.serviceError(.dataNotFound)
        }

        guard self.allRequests[index].canCancel else {
            throw AppError.validationError(
                "This request cannot be cancelled. It may already be under review or processed."
            )
        }

        await MainActor.run {
            self.isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)

        let userId = self.allRequests[index].userId

        await MainActor.run {
            self.allRequests[index].status = .cancelled
            self.updateRequestLists(for: userId)
            self.isLoading = false
        }

        NotificationCenter.default.post(
            name: .nameChangeRequestCancelled,
            object: requestId
        )
    }

    func getPendingRequest(for userId: String) -> NameChangeRequest? {
        self.allRequests.first { $0.userId == userId && $0.isPending }
    }

    func hasPendingRequest(for userId: String) -> Bool {
        self.allRequests.contains { $0.userId == userId && $0.isPending }
    }

    // MARK: - Admin Operations

    func approveRequest(_ requestId: String, reviewerId: String) async throws {
        guard let index = allRequests.firstIndex(where: { $0.id == requestId }) else {
            throw AppError.serviceError(.dataNotFound)
        }

        guard self.allRequests[index].isPending else {
            throw AppError.validationError(
                "This request has already been processed."
            )
        }

        await MainActor.run {
            self.isLoading = true
        }

        // Simulate API call (longer review for significant life events)
        let delay: UInt64 = self.allRequests[index].isSignificantLifeEvent ? 1_500_000_000 : 1_000_000_000
        try await Task.sleep(nanoseconds: delay)

        let userId = self.allRequests[index].userId

        await MainActor.run {
            self.allRequests[index].status = .approved
            self.allRequests[index].reviewedAt = Date()
            self.allRequests[index].reviewedBy = reviewerId
            self.updateRequestLists(for: userId)
            self.isLoading = false
        }

        NotificationCenter.default.post(
            name: .nameChangeRequestApproved,
            object: self.allRequests[index]
        )
    }

    func rejectRequest(_ requestId: String, reviewerId: String, reason: String) async throws {
        guard let index = allRequests.firstIndex(where: { $0.id == requestId }) else {
            throw AppError.serviceError(.dataNotFound)
        }

        guard self.allRequests[index].isPending else {
            throw AppError.validationError(
                "This request has already been processed."
            )
        }

        await MainActor.run {
            self.isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let userId = self.allRequests[index].userId

        await MainActor.run {
            self.allRequests[index].status = .rejected
            self.allRequests[index].reviewedAt = Date()
            self.allRequests[index].reviewedBy = reviewerId
            self.allRequests[index].rejectionReason = reason
            self.updateRequestLists(for: userId)
            self.isLoading = false
        }

        NotificationCenter.default.post(
            name: .nameChangeRequestRejected,
            object: self.allRequests[index]
        )
    }

    func fetchAllPendingRequests() async throws -> [NameChangeRequest] {
        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)
        return self.allRequests.filter { $0.isPending }
    }

    // MARK: - Private Methods

    private func updateRequestLists(for userId: String) {
        let userRequests = self.allRequests.filter { $0.userId == userId }
        self.pendingRequests = userRequests.filter { $0.isPending }
            .sorted { $0.submittedAt > $1.submittedAt }
        self.requestHistory = userRequests.filter { $0.status.isTerminal }
            .sorted { $0.submittedAt > $1.submittedAt }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let nameChangeRequestSubmitted = Notification.Name("nameChangeRequestSubmitted")
    static let nameChangeRequestCancelled = Notification.Name("nameChangeRequestCancelled")
    static let nameChangeRequestApproved = Notification.Name("nameChangeRequestApproved")
    static let nameChangeRequestRejected = Notification.Name("nameChangeRequestRejected")
}

