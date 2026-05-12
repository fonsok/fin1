import Foundation
import Combine

// MARK: - Address Change Request Service Protocol

/// Protocol defining the contract for address change request operations.
/// Implements KYC-compliant address change verification workflow.
@MainActor
protocol AddressChangeRequestServiceProtocol: ObservableObject {

    // MARK: - Published Properties

    /// Currently pending address change requests for the user
    var pendingRequests: [AddressChangeRequest] { get }

    /// Historical address change requests (approved/rejected/cancelled)
    var requestHistory: [AddressChangeRequest] { get }

    /// Whether an operation is in progress
    var isLoading: Bool { get }

    // MARK: - Request Submission

    /// Submits a new address change request for compliance review.
    /// - Parameters:
    ///   - currentAddress: The user's current verified address
    ///   - newAddress: The requested new address
    ///   - documentURL: URL to the uploaded verification document
    ///   - documentType: Type of verification document provided
    ///   - userDeclaration: User's declaration that the information is accurate
    /// - Returns: The created AddressChangeRequest
    /// - Throws: AppError if submission fails
    func submitAddressChangeRequest(
        userId: String,
        currentAddress: AddressComponents,
        newAddress: AddressComponents,
        documentURL: String?,
        documentType: AddressVerificationDocumentType,
        userDeclaration: Bool
    ) async throws -> AddressChangeRequest

    // MARK: - Request Management

    /// Fetches all address change requests for a user
    /// - Parameter userId: The user's ID
    func fetchRequests(for userId: String) async throws

    /// Cancels a pending address change request
    /// - Parameter requestId: ID of the request to cancel
    /// - Throws: AppError if cancellation fails or request is not cancellable
    func cancelRequest(_ requestId: String) async throws

    /// Gets the most recent pending request for a user (if any)
    /// - Parameter userId: The user's ID
    /// - Returns: The most recent pending request or nil
    func getPendingRequest(for userId: String) -> AddressChangeRequest?

    /// Checks if user has any pending address change requests
    /// - Parameter userId: The user's ID
    /// - Returns: True if there are pending requests
    func hasPendingRequest(for userId: String) -> Bool

    // MARK: - Admin Operations (for compliance review)

    /// Approves an address change request (admin only)
    /// - Parameters:
    ///   - requestId: ID of the request to approve
    ///   - reviewerId: ID of the admin performing the review
    /// - Throws: AppError if approval fails
    func approveRequest(_ requestId: String, reviewerId: String) async throws

    /// Rejects an address change request (admin only)
    /// - Parameters:
    ///   - requestId: ID of the request to reject
    ///   - reviewerId: ID of the admin performing the review
    ///   - reason: Reason for rejection
    /// - Throws: AppError if rejection fails
    func rejectRequest(_ requestId: String, reviewerId: String, reason: String) async throws

    /// Fetches all pending requests for admin review
    /// - Returns: Array of pending address change requests
    func fetchAllPendingRequests() async throws -> [AddressChangeRequest]
}
