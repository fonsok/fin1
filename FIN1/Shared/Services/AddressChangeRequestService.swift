import Combine
import Foundation

// MARK: - Address Change Request Service

/// Service handling KYC-compliant address change requests.
/// Implements ongoing due diligence requirements for AML compliance.
@MainActor
final class AddressChangeRequestService: AddressChangeRequestServiceProtocol {

    // MARK: - Published Properties

    @Published private(set) var pendingRequests: [AddressChangeRequest] = []
    @Published private(set) var requestHistory: [AddressChangeRequest] = []
    @Published private(set) var isLoading = false

    // MARK: - Private Storage

    /// In-memory storage for demo purposes. In production, this would be persisted.
    private var allRequests: [AddressChangeRequest] = []

    // MARK: - Initialization

    init() {}

    func reset() {
        self.allRequests = []
        self.pendingRequests = []
        self.requestHistory = []
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
        if self.hasPendingRequest(for: userId) {
            throw AppError.validationError(
                "You already have a pending address change request. Please wait for it to be reviewed or cancel it first."
            )
        }

        await MainActor.run {
            self.isLoading = true
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
            self.allRequests.append(request)
            self.updateRequestLists(for: userId)
            self.isLoading = false
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
            name: .addressChangeRequestCancelled,
            object: requestId
        )
    }

    func getPendingRequest(for userId: String) -> AddressChangeRequest? {
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

        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let userId = self.allRequests[index].userId

        await MainActor.run {
            self.allRequests[index].status = .approved
            self.allRequests[index].reviewedAt = Date()
            self.allRequests[index].reviewedBy = reviewerId
            self.updateRequestLists(for: userId)
            self.isLoading = false
        }

        NotificationCenter.default.post(
            name: .addressChangeRequestApproved,
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
            name: .addressChangeRequestRejected,
            object: self.allRequests[index]
        )
    }

    func fetchAllPendingRequests() async throws -> [AddressChangeRequest] {
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
    static let addressChangeRequestSubmitted = Notification.Name("addressChangeRequestSubmitted")
    static let addressChangeRequestCancelled = Notification.Name("addressChangeRequestCancelled")
    static let addressChangeRequestApproved = Notification.Name("addressChangeRequestApproved")
    static let addressChangeRequestRejected = Notification.Name("addressChangeRequestRejected")
}

