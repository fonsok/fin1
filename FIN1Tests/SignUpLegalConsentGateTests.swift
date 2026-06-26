@testable import FIN1
import XCTest

final class SignUpLegalConsentGateTests: XCTestCase {
    func testHasRequiredLegalConsentsRequiresBothDocuments() {
        let signUpData = SignUpData()

        XCTAssertFalse(signUpData.hasRequiredLegalConsents)

        signUpData.acceptedTerms = true
        XCTAssertFalse(signUpData.hasRequiredLegalConsents)

        signUpData.acceptedPrivacyPolicy = true
        XCTAssertTrue(signUpData.hasRequiredLegalConsents)
    }

    func testCreateEarlyAccountUserRequiresLegalGateOne() throws {
        let signUpData = SignUpData()
        signUpData.email = "user@example.com"
        signUpData.username = "user1"
        signUpData.password = "Secret1!"

        XCTAssertThrowsError(try signUpData.createEarlyAccountUser()) { error in
            guard case UserCreationError.legalConsentsIncomplete = error else {
                return XCTFail("Expected legalConsentsIncomplete, got \(error)")
            }
        }

        signUpData.acceptedTerms = true
        signUpData.acceptedPrivacyPolicy = true
        XCTAssertNoThrow(try signUpData.createEarlyAccountUser())
    }

    func testEarlyParseSignUpPersistsLegalConsents() throws {
        let signUpData = SignUpData()
        signUpData.email = "user@example.com"
        signUpData.username = "user1"
        signUpData.password = "Secret1!"
        signUpData.acceptedTerms = true
        signUpData.acceptedPrivacyPolicy = true

        let user = try signUpData.createEarlyAccountUser()
        let body = UserFactory.parseSignUpParameters(from: user)

        XCTAssertEqual(body["acceptedTerms"] as? Bool, true)
        XCTAssertEqual(body["acceptedPrivacyPolicy"] as? Bool, true)
        XCTAssertEqual(body["acceptedTermsVersion"] as? String, TermsVersionConstants.currentTermsVersion)
        XCTAssertEqual(
            body["acceptedPrivacyPolicyVersion"] as? String,
            TermsVersionConstants.currentPrivacyPolicyVersion
        )
    }
}
