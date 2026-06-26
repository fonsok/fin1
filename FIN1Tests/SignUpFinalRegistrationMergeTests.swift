@testable import FIN1
import XCTest

final class SignUpFinalRegistrationMergeTests: XCTestCase {

    func testMergedUserForFinalRegistrationPreservesParseObjectId() throws {
        let signUpData = self.makeCompletableSignUpData()
        let parseObjectId = "flCPAlXSM6"
        let sessionUser = try signUpData.createEarlyAccountUser().withId(parseObjectId)

        let merged = try signUpData.mergedUserForFinalRegistration(base: sessionUser)

        XCTAssertEqual(merged.id, parseObjectId)
        XCTAssertNotEqual(merged.id.count, 36, "Must not replace Parse objectId with a UUID")
    }

    func testMergedUserForFinalRegistrationAppliesOnboardingAnswers() throws {
        let signUpData = self.makeCompletableSignUpData()
        signUpData.firstName = "Alex"
        signUpData.lastName = "Trader"
        signUpData.streetAndNumber = "Hauptstr. 1"
        signUpData.acceptedTraderAgreement = true

        let sessionUser = try signUpData.createEarlyAccountUser().withId("flCPAlXSM6")
        let merged = try signUpData.mergedUserForFinalRegistration(base: sessionUser)

        XCTAssertEqual(merged.firstName, "Alex")
        XCTAssertEqual(merged.lastName, "Trader")
        XCTAssertEqual(merged.streetAndNumber, "Hauptstr. 1")
        XCTAssertTrue(merged.acceptedTraderAgreement)
    }

    func testApplyUserMeResponseNeverDowngradesRoleAgreementFlags() throws {
        var user = UserFactory.createTestUser(email: "investor1@test.com", password: "Secret1!")
        user.acceptedInvestorAgreement = true

        let data = Data(#"{"acceptedInvestorAgreement":false}"#.utf8)
        let me = try JSONDecoder().decode(ParseUserMeResponse.self, from: data)

        UserFactory.applyUserMeResponse(me, to: &user)

        XCTAssertTrue(user.acceptedInvestorAgreement)
    }

    func testApplyUserMeResponseHonorsRoleAgreementAcceptedFromServer() throws {
        var user = UserFactory.createTestUser(email: "trader1@test.com", password: "Secret1!")
        user.role = .trader
        user.acceptedTraderAgreement = false

        let data = Data(#"{"role":"trader","acceptedTraderAgreement":false,"roleAgreementAccepted":true}"#.utf8)
        let me = try JSONDecoder().decode(ParseUserMeResponse.self, from: data)

        UserFactory.applyUserMeResponse(me, to: &user)

        XCTAssertTrue(user.acceptedTraderAgreement)
    }

    func testApplyUserMeResponseNeverDowngradesOnboardingCompleted() throws {
        var user = UserFactory.createTestUser(email: "trader1@test.com", password: "Secret1!")
        user.onboardingCompleted = true

        let data = Data(#"{"onboardingCompleted":false,"onboardingStep":"personal"}"#.utf8)
        let me = try JSONDecoder().decode(ParseUserMeResponse.self, from: data)

        UserFactory.applyUserMeResponse(me, to: &user)

        XCTAssertTrue(user.onboardingCompleted)
    }

    private func makeCompletableSignUpData() -> SignUpData {
        let signUpData = SignUpData(riskClassCalculationService: RiskClassCalculationService())
        signUpData.email = "trader@example.com"
        signUpData.username = "trdr1"
        signUpData.password = "Secret1!"
        signUpData.phoneNumber = "+491701234567"
        signUpData.acceptedTerms = true
        signUpData.acceptedPrivacyPolicy = true
        signUpData.userRole = .trader
        signUpData.firstName = "Test"
        signUpData.lastName = "User"
        signUpData.employmentStatus = .employed
        signUpData.incomeRange = .middle
        signUpData.cashAndLiquidAssets = .tenKToFiftyK
        signUpData.stocksTransactionsCount = .oneToTen
        signUpData.etfsTransactionsCount = .oneToTen
        signUpData.derivativesTransactionsCount = .oneToTen
        signUpData.stocksInvestmentAmount = .hundredToTenThousand
        signUpData.etfsInvestmentAmount = .hundredToTenThousand
        signUpData.derivativesInvestmentAmount = .thousandToTenThousand
        signUpData.derivativesHoldingPeriod = .daysToWeeks
        signUpData.desiredReturn = .atLeastTenPercent
        signUpData.moneyLaunderingDeclaration = true
        signUpData.insiderTradingOptions["None of the above"] = true
        return signUpData
    }
}
