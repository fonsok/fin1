@testable import FIN1
import XCTest

@MainActor
final class ReConsentViewModelTests: XCTestCase {
    func testLoadFromCurrentUserFiltersBlockingItems() {
        var user = UserFactory.createTestUser(email: "investor@example.com", password: "password")
        user.requiredReConsents = [
            RequiredReConsent(
                consentType: "terms_of_service",
                documentType: "terms",
                activeVersion: "2.0",
                userVersion: "1.0",
                blocking: true,
                requiresScrollToAccept: false
            ),
            RequiredReConsent(
                consentType: "privacy_policy",
                documentType: "privacy",
                activeVersion: "2.0",
                userVersion: "2.0",
                blocking: false,
                requiresScrollToAccept: false
            ),
        ]

        let mock = MockUserService()
        mock.currentUser = user

        let viewModel = ReConsentViewModel(
            userService: mock,
            termsAcceptanceService: TermsAcceptanceService(),
            roleAgreementConsentService: nil,
            parseAPIClient: nil
        )
        viewModel.loadFromCurrentUser()

        XCTAssertTrue(viewModel.hasLoadedFromUser)
        XCTAssertEqual(viewModel.pendingItems.count, 1)
        XCTAssertEqual(viewModel.currentItem?.consentType, "terms_of_service")
        XCTAssertTrue(viewModel.hasPendingItems)
    }
}
