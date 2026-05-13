import Foundation

// MARK: - Unchecked bridges (Swift 6 strict concurrency)
/// FAQ and name-change services are not `Sendable`, but the app uses them from the main actor only.

final class UncheckedFAQContentServiceBridge: @unchecked Sendable {
    private let service: any FAQContentServiceProtocol

    init(service: any FAQContentServiceProtocol) {
        self.service = service
    }

    func clearCache(location: String?, userRole: String?) async {
        await self.service.clearCache(location: location, userRole: userRole)
    }

    func fetchFAQCategories(location: String, userRole: String?) async throws -> [FAQCategoryContent] {
        try await self.service.fetchFAQCategories(location: location, userRole: userRole)
    }

    func fetchFAQsForHelpCenter(userRole: String?) async throws -> [FAQContentItem] {
        try await self.service.fetchFAQsForHelpCenter(userRole: userRole)
    }
}

final class UncheckedNameChangeRequestServiceBridge: @unchecked Sendable {
    private let service: any NameChangeRequestServiceProtocol

    init(_ service: any NameChangeRequestServiceProtocol) {
        self.service = service
    }

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
        try await self.service.submitNameChangeRequest(
            userId: userId,
            currentName: currentName,
            newName: newName,
            reason: reason,
            primaryDocumentType: primaryDocumentType,
            primaryDocumentURL: primaryDocumentURL,
            identityDocumentType: identityDocumentType,
            identityDocumentURL: identityDocumentURL,
            userDeclaration: userDeclaration,
            acknowledgesRiskProfileUpdate: acknowledgesRiskProfileUpdate
        )
    }

    func cancelRequest(_ requestId: String) async throws {
        try await self.service.cancelRequest(requestId)
    }

    func getPendingRequest(for userId: String) -> NameChangeRequest? {
        self.service.getPendingRequest(for: userId)
    }
}
