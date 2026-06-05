@testable import FIN1
import XCTest

final class MonthlyAccountStatementDataSourceTests: XCTestCase {

    func testMonthlyStatementExistsMatchesUserIdAliases() {
        let email = "investor1@test.com"
        let user = Self.makeUser(id: "flCPAlXSM6", email: email, role: .investor)
        let doc = Document(
            userId: "user:\(email)",
            name: "Monthly Statement",
            type: .monthlyAccountStatement,
            status: .verified,
            fileURL: "monthly-statement://x",
            size: 1_024,
            uploadedAt: Date(),
            statementYear: 2_026,
            statementMonth: 6,
            statementRole: .investor
        )
        XCTAssertTrue(
            MonthlyAccountStatementDataSource.monthlyStatementExists(
                year: 2_026,
                month: 6,
                role: .investor,
                in: [doc],
                user: user
            )
        )
    }

    func testMonthlyStatementExistsRejectsDifferentMonth() {
        let user = Self.makeUser(id: "trader1", email: "trader1@test.com", role: .trader)
        let doc = Document(
            userId: "trader1",
            name: "Monthly Statement",
            type: .monthlyAccountStatement,
            status: .verified,
            fileURL: "monthly-statement://x",
            size: 1_024,
            uploadedAt: Date(),
            statementYear: 2_026,
            statementMonth: 5,
            statementRole: .trader
        )
        XCTAssertFalse(
            MonthlyAccountStatementDataSource.monthlyStatementExists(
                year: 2_026,
                month: 6,
                role: .trader,
                in: [doc],
                user: user
            )
        )
    }

    private static func makeUser(id: String, email: String, role: UserRole) -> User {
        User(
            id: id,
            customerNumber: "CUST001",
            accountType: .individual,
            email: email,
            username: email.components(separatedBy: "@").first ?? "user",
            phoneNumber: "+1234567890",
            password: "test",
            salutation: .mr,
            academicTitle: "",
            firstName: "Test",
            lastName: "User",
            streetAndNumber: "123 Test St",
            postalCode: "12345",
            city: "Test City",
            state: "TS",
            country: "Test Country",
            dateOfBirth: Date(),
            placeOfBirth: "Test City",
            countryOfBirth: "Test Country",
            role: role,
            csrRole: nil,
            employmentStatus: .employed,
            income: 50_000,
            incomeRange: .middle,
            riskTolerance: 3,
            address: "123 Test St",
            nationality: "Test",
            additionalNationalities: "",
            taxNumber: "123456789",
            additionalTaxResidences: "",
            isNotUSCitizen: true,
            identificationType: .passport,
            passportFrontImageURL: nil,
            passportBackImageURL: nil,
            idCardFrontImageURL: nil,
            idCardBackImageURL: nil,
            identificationConfirmed: true,
            addressConfirmed: true,
            addressVerificationDocumentURL: nil,
            leveragedProductsExperience: role == .trader,
            financialProductsExperience: true,
            investmentExperience: 2,
            tradingFrequency: role == .trader ? 1 : 0,
            investmentKnowledge: 2,
            desiredReturn: .atLeastTenPercent,
            insiderTradingOptions: ["None of the above": true],
            moneyLaunderingDeclaration: true,
            assetType: .privateAssets,
            profileImageURL: nil,
            isEmailVerified: true,
            isKYCCompleted: true,
            acceptedTerms: true,
            acceptedPrivacyPolicy: true,
            acceptedMarketingConsent: true,
            lastLoginDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
