@testable import FIN1
import XCTest

final class TermsAcceptanceServiceDeviceConsentTests: XCTestCase {
    private let suiteName = "TermsAcceptanceServiceDeviceConsentTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        self.defaults = UserDefaults(suiteName: self.suiteName)!
        self.defaults.removePersistentDomain(forName: self.suiteName)
    }

    override func tearDown() {
        self.defaults.removePersistentDomain(forName: self.suiteName)
        super.tearDown()
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
            acceptedTermsVersion: "1.0.2",
            acceptedTermsDate: Date(),
            acceptedPrivacyPolicyVersion: "1.0.2",
            acceptedPrivacyPolicyDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )

        XCTAssertTrue(service.needsToAcceptTerms(user: user, currentServerVersion: "1.0.2"))
        XCTAssertTrue(service.needsToAcceptPrivacyPolicy(user: user, currentServerVersion: "1.0.2"))

        _ = service.recordTermsAcceptance(user: user, version: "1.0.2")
        _ = service.recordPrivacyPolicyAcceptance(user: user, version: "1.0.2")

        XCTAssertFalse(service.needsToAcceptTerms(user: user, currentServerVersion: "1.0.2"))
        XCTAssertFalse(service.needsToAcceptPrivacyPolicy(user: user, currentServerVersion: "1.0.2"))
    }
}
