import Combine
import Foundation

// MARK: - Name Change Request Service Protocol

/// Protocol defining the contract for name change request operations.
/// Implements GwG-compliant name change verification workflow.
/// Name changes due to marriage, divorce, or other life events require complete re-verification.
protocol NameChangeRequestServiceProtocol: ObservableObject {

    // MARK: - Published Properties

    /// Currently pending name change requests for the user
    var pendingRequests: [NameChangeRequest] { get }

    /// Historical name change requests (approved/rejected/cancelled)
    var requestHistory: [NameChangeRequest] { get }

    /// Whether an operation is in progress
    var isLoading: Bool { get }

    // MARK: - Request Submission

    /// Submits a new name change request for compliance review.
    /// Per GwG, requires official documentation (marriage certificate, new ID, etc.)
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - currentName: The user's current verified name
    ///   - newName: The requested new name
    ///   - reason: Reason for name change (marriage, divorce, etc.)
    ///   - primaryDocumentType: Type of primary document (certificate, decree)
    ///   - primaryDocumentURL: URL to the uploaded primary document
    ///   - identityDocumentType: Type of new identity document (new ID card or passport)
    ///   - identityDocumentURL: URL to the uploaded new identity document
    ///   - userDeclaration: User's declaration that the information is accurate
    ///   - acknowledgesRiskProfileUpdate: User acknowledges risk profile may change
    /// - Returns: The created NameChangeRequest
    /// - Throws: AppError if submission fails
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
    ) async throws -> NameChangeRequest

    // MARK: - Request Management

    /// Fetches all name change requests for a user
    /// - Parameter userId: The user's ID
    func fetchRequests(for userId: String) async throws

    /// Cancels a pending name change request
    /// - Parameter requestId: ID of the request to cancel
    /// - Throws: AppError if cancellation fails or request is not cancellable
    func cancelRequest(_ requestId: String) async throws

    /// Gets the most recent pending request for a user (if any)
    /// - Parameter userId: The user's ID
    /// - Returns: The most recent pending request or nil
    func getPendingRequest(for userId: String) -> NameChangeRequest?

    /// Checks if user has any pending name change requests
    /// - Parameter userId: The user's ID
    /// - Returns: True if there are pending requests
    func hasPendingRequest(for userId: String) -> Bool

    // MARK: - Admin Operations (for compliance review)

    /// Approves a name change request (admin only)
    /// - Parameters:
    ///   - requestId: ID of the request to approve
    ///   - reviewerId: ID of the admin performing the review
    /// - Throws: AppError if approval fails
    func approveRequest(_ requestId: String, reviewerId: String) async throws

    /// Rejects a name change request (admin only)
    /// - Parameters:
    ///   - requestId: ID of the request to reject
    ///   - reviewerId: ID of the admin performing the review
    ///   - reason: Reason for rejection
    /// - Throws: AppError if rejection fails
    func rejectRequest(_ requestId: String, reviewerId: String, reason: String) async throws

    /// Fetches all pending requests for admin review
    /// - Returns: Array of pending name change requests
    func fetchAllPendingRequests() async throws -> [NameChangeRequest]
}





