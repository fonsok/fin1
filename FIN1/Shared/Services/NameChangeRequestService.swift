import Foundation
import Combine

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
        allRequests = []
        pendingRequests = []
        requestHistory = []
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
        if hasPendingRequest(for: userId) {
            throw AppError.validationError(
                "You already have a pending name change request. Please wait for it to be reviewed or cancel it first."
            )
        }

        await MainActor.run {
            isLoading = true
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
            allRequests.append(request)
            updateRequestLists(for: userId)
            isLoading = false
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
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)

        await MainActor.run {
            updateRequestLists(for: userId)
            isLoading = false
        }
    }

    func cancelRequest(_ requestId: String) async throws {
        guard let index = allRequests.firstIndex(where: { $0.id == requestId }) else {
            throw AppError.serviceError(.dataNotFound)
        }

        guard allRequests[index].canCancel else {
            throw AppError.validationError(
                "This request cannot be cancelled. It may already be under review or processed."
            )
        }

        await MainActor.run {
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)

        let userId = allRequests[index].userId

        await MainActor.run {
            allRequests[index].status = .cancelled
            updateRequestLists(for: userId)
            isLoading = false
        }

        NotificationCenter.default.post(
            name: .nameChangeRequestCancelled,
            object: requestId
        )
    }

    func getPendingRequest(for userId: String) -> NameChangeRequest? {
        allRequests.first { $0.userId == userId && $0.isPending }
    }

    func hasPendingRequest(for userId: String) -> Bool {
        allRequests.contains { $0.userId == userId && $0.isPending }
    }

    // MARK: - Admin Operations

    func approveRequest(_ requestId: String, reviewerId: String) async throws {
        guard let index = allRequests.firstIndex(where: { $0.id == requestId }) else {
            throw AppError.serviceError(.dataNotFound)
        }

        guard allRequests[index].isPending else {
            throw AppError.validationError(
                "This request has already been processed."
            )
        }

        await MainActor.run {
            isLoading = true
        }

        // Simulate API call (longer review for significant life events)
        let delay: UInt64 = allRequests[index].isSignificantLifeEvent ? 1_500_000_000 : 1_000_000_000
        try await Task.sleep(nanoseconds: delay)

        let userId = allRequests[index].userId

        await MainActor.run {
            allRequests[index].status = .approved
            allRequests[index].reviewedAt = Date()
            allRequests[index].reviewedBy = reviewerId
            updateRequestLists(for: userId)
            isLoading = false
        }

        NotificationCenter.default.post(
            name: .nameChangeRequestApproved,
            object: allRequests[index]
        )
    }

    func rejectRequest(_ requestId: String, reviewerId: String, reason: String) async throws {
        guard let index = allRequests.firstIndex(where: { $0.id == requestId }) else {
            throw AppError.serviceError(.dataNotFound)
        }

        guard allRequests[index].isPending else {
            throw AppError.validationError(
                "This request has already been processed."
            )
        }

        await MainActor.run {
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let userId = allRequests[index].userId

        await MainActor.run {
            allRequests[index].status = .rejected
            allRequests[index].reviewedAt = Date()
            allRequests[index].reviewedBy = reviewerId
            allRequests[index].rejectionReason = reason
            updateRequestLists(for: userId)
            isLoading = false
        }

        NotificationCenter.default.post(
            name: .nameChangeRequestRejected,
            object: allRequests[index]
        )
    }

    func fetchAllPendingRequests() async throws -> [NameChangeRequest] {
        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)
        return allRequests.filter { $0.isPending }
    }

    // MARK: - Private Methods

    private func updateRequestLists(for userId: String) {
        let userRequests = allRequests.filter { $0.userId == userId }
        pendingRequests = userRequests.filter { $0.isPending }
            .sorted { $0.submittedAt > $1.submittedAt }
        requestHistory = userRequests.filter { $0.status.isTerminal }
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

