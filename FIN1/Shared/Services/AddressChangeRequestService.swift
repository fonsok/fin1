import Foundation
import Combine

// MARK: - Address Change Request Service

/// Service handling KYC-compliant address change requests.
/// Implements ongoing due diligence requirements for AML compliance.
final class AddressChangeRequestService: AddressChangeRequestServiceProtocol, ServiceLifecycle {

    // MARK: - Published Properties

    @Published private(set) var pendingRequests: [AddressChangeRequest] = []
    @Published private(set) var requestHistory: [AddressChangeRequest] = []
    @Published private(set) var isLoading = false

    // MARK: - Private Storage

    /// In-memory storage for demo purposes. In production, this would be persisted.
    private var allRequests: [AddressChangeRequest] = []

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

    func submitAddressChangeRequest(
        userId: String,
        currentAddress: AddressComponents,
        newAddress: AddressComponents,
        documentURL: String?,
        documentType: AddressVerificationDocumentType,
        userDeclaration: Bool
    ) async throws -> AddressChangeRequest {
        // Validate inputs
        guard newAddress.isComplete else {
            throw AppError.validationError("New address is incomplete")
        }

        guard userDeclaration else {
            throw AppError.validationError("User declaration is required")
        }

        guard documentURL != nil || documentType == .officialRegistration else {
            throw AppError.validationError("Verification document is required")
        }

        // Check for existing pending requests
        if hasPendingRequest(for: userId) {
            throw AppError.validationError(
                "You already have a pending address change request. Please wait for it to be reviewed or cancel it first."
            )
        }

        await MainActor.run {
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 1_500_000_000)

        let request = AddressChangeRequest(
            userId: userId,
            currentStreetAndNumber: currentAddress.streetAndNumber,
            currentPostalCode: currentAddress.postalCode,
            currentCity: currentAddress.city,
            currentState: currentAddress.state,
            currentCountry: currentAddress.country,
            newStreetAndNumber: newAddress.streetAndNumber,
            newPostalCode: newAddress.postalCode,
            newCity: newAddress.city,
            newState: newAddress.state,
            newCountry: newAddress.country,
            verificationDocumentURL: documentURL,
            verificationDocumentType: documentType,
            status: .pending,
            userDeclaration: userDeclaration
        )

        await MainActor.run {
            allRequests.append(request)
            updateRequestLists(for: userId)
            isLoading = false
        }

        // Post notification for new request
        NotificationCenter.default.post(
            name: .addressChangeRequestSubmitted,
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
            name: .addressChangeRequestCancelled,
            object: requestId
        )
    }

    func getPendingRequest(for userId: String) -> AddressChangeRequest? {
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

        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let userId = allRequests[index].userId

        await MainActor.run {
            allRequests[index].status = .approved
            allRequests[index].reviewedAt = Date()
            allRequests[index].reviewedBy = reviewerId
            updateRequestLists(for: userId)
            isLoading = false
        }

        NotificationCenter.default.post(
            name: .addressChangeRequestApproved,
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
            name: .addressChangeRequestRejected,
            object: allRequests[index]
        )
    }

    func fetchAllPendingRequests() async throws -> [AddressChangeRequest] {
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
    static let addressChangeRequestSubmitted = Notification.Name("addressChangeRequestSubmitted")
    static let addressChangeRequestCancelled = Notification.Name("addressChangeRequestCancelled")
    static let addressChangeRequestApproved = Notification.Name("addressChangeRequestApproved")
    static let addressChangeRequestRejected = Notification.Name("addressChangeRequestRejected")
}

