@testable import FIN1
import XCTest

final class TermsAcceptanceServiceDeviceConsentTests: XCTestCase {
    override func setUp() {
        super.setUp()
        self.clearDeviceLegalConsentStore()
    }

    override func tearDown() {
        self.clearDeviceLegalConsentStore()
        super.tearDown()
    }

    private func clearDeviceLegalConsentStore() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("FIN1.deviceLegalConsent") {
            defaults.removeObject(forKey: key)
        }
    }

    func testFreshInstallRequiresDeviceAcknowledgementEvenWhenAccountVersionMatches() {
        let service = TermsAcceptanceService()
        let user = User(
            id: "user-1",
            customerNumber: "ANL-2026-00001",
            accountType: .individual,
            email: "investor1@test.com",
            username: "inv1",
            phoneNumber: "+491234567890",
            password: "secret",
            salutation: .mr,
            academicTitle: "",
            firstName: "Test",
            lastName: "User",
            streetAndNumber: "Street 1",
            postalCode: "10115",
            city: "Berlin",
            state: "BE",
            country: "Germany",
            dateOfBirth: Date(),
            placeOfBirth: "Berlin",
            countryOfBirth: "Germany",
            role: .investor,
            employmentStatus: .employed,
            income: 50_000,
            incomeRange: .middle,
            riskTolerance: 3,
            address: "Street 1",
            nationality: "German",
            additionalNationalities: "",
            taxNumber: "DE123",
            additionalTaxResidences: "",
            isNotUSCitizen: true,
            identificationType: .passport,
            identificationConfirmed: true,
            addressConfirmed: true,
            leveragedProductsExperience: false,
            financialProductsExperience: true,
            desiredReturn: .atLeastTenPercent,
            moneyLaunderingDeclaration: true,
            assetType: .privateAssets,
            isEmailVerified: true,
            isKYCCompleted: true,
            acceptedTerms: true,
            acceptedPrivacyPolicy: true,
            acceptedMarketingConsent: false,
            acceptedTermsVersion: "1.0",
            acceptedTermsDate: Date(),
            acceptedPrivacyPolicyVersion: "1.0",
            acceptedPrivacyPolicyDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )

        XCTAssertTrue(service.needsToAcceptTerms(user: user, currentServerVersion: "1.0"))
        XCTAssertTrue(service.needsToAcceptPrivacyPolicy(user: user, currentServerVersion: "1.0"))

        _ = service.recordTermsAcceptance(user: user, version: "1.0")
        _ = service.recordPrivacyPolicyAcceptance(user: user, version: "1.0")

        XCTAssertFalse(service.needsToAcceptTerms(user: user, currentServerVersion: "1.0"))
        XCTAssertFalse(service.needsToAcceptPrivacyPolicy(user: user, currentServerVersion: "1.0"))
    }

    func testSecondUserOnSameInstallStillRequiresOwnDeviceAcknowledgement() {
        let service = TermsAcceptanceService()
        let userA = self.makeUser(id: "user-a", email: "trader1@test.com")
        let userB = self.makeUser(id: "user-b", email: "investor5@test.com")

        _ = service.recordTermsAcceptance(user: userA, version: "1.0")
        _ = service.recordPrivacyPolicyAcceptance(user: userA, version: "1.0")

        XCTAssertTrue(service.needsToAcceptTerms(user: userB, currentServerVersion: "1.0"))
        XCTAssertTrue(service.needsToAcceptPrivacyPolicy(user: userB, currentServerVersion: "1.0"))
    }

    func testDeviceAcknowledgementSurvivesParseObjectIdAlias() {
        let service = TermsAcceptanceService()
        let parseUser = self.makeUser(id: "uLxVZveIpl", email: "trader1@test.com")

        _ = service.recordTermsAcceptance(user: parseUser, version: "1.0")
        _ = service.recordPrivacyPolicyAcceptance(user: parseUser, version: "1.0")

        let stableIdUser = self.makeUser(
            id: UserFactory.stableUserId(for: "trader1@test.com"),
            email: "trader1@test.com"
        )

        XCTAssertFalse(service.needsToAcceptTerms(user: stableIdUser, currentServerVersion: "1.0"))
        XCTAssertFalse(service.needsToAcceptPrivacyPolicy(user: stableIdUser, currentServerVersion: "1.0"))
    }

    func testReLoginSkipsPromptWhenDeviceAckExistsDespiteStaleProfileVersion() {
        let service = TermsAcceptanceService()
        var user = self.makeUser(id: "uLxVZveIpl", email: "trader1@test.com")
        user.acceptedTermsVersion = "1.0.2"
        user.acceptedPrivacyPolicyVersion = "1.0"

        _ = service.recordTermsAcceptance(user: user, version: "1.0")
        _ = service.recordPrivacyPolicyAcceptance(user: user, version: "1.0")

        XCTAssertFalse(service.needsToAcceptTerms(user: user, currentServerVersion: "1.0"))
        XCTAssertFalse(service.needsToAcceptPrivacyPolicy(user: user, currentServerVersion: "1.0"))
    }

    func testResolvedVersionFallsBackToProfileWhenServerUnavailable() async {
        let user = self.makeUser(id: "uLxVZveIpl", email: "trader1@test.com")

        let termsVersion = await LegalConsentVersionResolver.resolveVersion(
            user: user,
            documentType: .terms,
            termsContentService: nil
        )
        let privacyVersion = await LegalConsentVersionResolver.resolveVersion(
            user: user,
            documentType: .privacy,
            termsContentService: nil
        )

        XCTAssertEqual(termsVersion, "1.0")
        XCTAssertEqual(privacyVersion, "1.0")
    }

    func testAcceptingOnlyTermsStillRequiresPrivacyOnDevice() {
        let service = TermsAcceptanceService()
        let user = self.makeUser(id: "user-partial", email: "partial@test.com")

        _ = service.recordTermsAcceptance(user: user, version: "1.0")

        XCTAssertFalse(service.needsToAcceptTerms(user: user, currentServerVersion: "1.0"))
        XCTAssertTrue(service.needsToAcceptPrivacyPolicy(user: user, currentServerVersion: "1.0"))
    }

    private func makeUser(id: String, email: String) -> User {
        User(
            id: id,
            customerNumber: "ANL-2026-00001",
            accountType: .individual,
            email: email,
            username: email,
            phoneNumber: "+491234567890",
            password: "secret",
            salutation: .mr,
            academicTitle: "",
            firstName: "Test",
            lastName: "User",
            streetAndNumber: "Street 1",
            postalCode: "10115",
            city: "Berlin",
            state: "BE",
            country: "Germany",
            dateOfBirth: Date(),
            placeOfBirth: "Berlin",
            countryOfBirth: "Germany",
            role: .investor,
            employmentStatus: .employed,
            income: 50_000,
            incomeRange: .middle,
            riskTolerance: 3,
            address: "Street 1",
            nationality: "German",
            additionalNationalities: "",
            taxNumber: "DE123",
            additionalTaxResidences: "",
            isNotUSCitizen: true,
            identificationType: .passport,
            identificationConfirmed: true,
            addressConfirmed: true,
            leveragedProductsExperience: false,
            financialProductsExperience: true,
            desiredReturn: .atLeastTenPercent,
            moneyLaunderingDeclaration: true,
            assetType: .privateAssets,
            isEmailVerified: true,
            isKYCCompleted: true,
            acceptedTerms: true,
            acceptedPrivacyPolicy: true,
            acceptedMarketingConsent: false,
            acceptedTermsVersion: "1.0",
            acceptedTermsDate: Date(),
            acceptedPrivacyPolicyVersion: "1.0",
            acceptedPrivacyPolicyDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
