@testable import FIN1
import XCTest

final class SignUpRiskClass5DerivativesGateTests: XCTestCase {
    private let service = RiskClassCalculationService()

    func testTraderRiskClass5RequiresStrictStep16CDerivativesAnswers() {
        let signUpData = self.makeBaseSignUpData(role: .trader)

        signUpData.derivativesTransactionsCount = .fiftyPlus
        signUpData.derivativesInvestmentAmount = .tenThousandToHundredThousand
        signUpData.derivativesHoldingPeriod = .minutesToHours

        XCTAssertTrue(signUpData.meetsTraderRiskClass5DerivativesExperienceCriteria)
        XCTAssertTrue(signUpData.meetsRiskClass5DerivativesExperienceCriteria)
        XCTAssertEqual(signUpData.cappedForRiskClass5DerivativesGate(.riskClass5), .riskClass5)
    }

    func testInvestorRiskClass5RequiresRelaxedStep16CDerivativesAnswers() {
        let signUpData = self.makeBaseSignUpData(role: .investor)

        signUpData.derivativesTransactionsCount = .oneToTen
        signUpData.derivativesInvestmentAmount = .thousandToTenThousand
        signUpData.derivativesHoldingPeriod = .daysToWeeks

        XCTAssertTrue(signUpData.meetsInvestorRiskClass5DerivativesExperienceCriteria)
        XCTAssertTrue(signUpData.meetsRiskClass5DerivativesExperienceCriteria)
        XCTAssertEqual(signUpData.cappedForRiskClass5DerivativesGate(.riskClass5), .riskClass5)
    }

    func testInvestorGateAcceptsHigherDerivativesProfileThanMinimum() {
        let signUpData = self.makeBaseSignUpData(role: .investor)

        signUpData.derivativesTransactionsCount = .fiftyPlus
        signUpData.derivativesInvestmentAmount = .moreThanHundredThousand
        signUpData.derivativesHoldingPeriod = .minutesToHours

        XCTAssertTrue(signUpData.meetsInvestorRiskClass5DerivativesExperienceCriteria)
    }

    func testTraderScoreBasedRiskClass5IsCappedTo4WithoutStrictDerivativesProfile() {
        let signUpData = SignUpData(riskClassCalculationService: RiskClassCalculationService())
        signUpData.userRole = .trader
        signUpData.incomeRange = .highMiddle
        signUpData.cashAndLiquidAssets = .fiftyKToTwoHundredK
        signUpData.stocksTransactionsCount = .tenToFifty
        signUpData.etfsTransactionsCount = .oneToTen
        signUpData.derivativesTransactionsCount = .fiftyPlus
        signUpData.stocksInvestmentAmount = .tenThousandToHundredThousand
        signUpData.etfsInvestmentAmount = .hundredToTenThousand
        signUpData.derivativesInvestmentAmount = .tenThousandToHundredThousand
        signUpData.derivativesHoldingPeriod = .daysToWeeks
        signUpData.desiredReturn = .atLeastFiftyPercent

        XCTAssertFalse(signUpData.meetsTraderRiskClass5DerivativesExperienceCriteria)
        XCTAssertEqual(self.service.calculateRiskClass(for: signUpData), .riskClass4)
    }

    func testInvestorScoreBasedRiskClass5IsCappedTo4WithoutRelaxedDerivativesProfile() {
        let signUpData = self.makeBaseSignUpData(role: .investor)
        signUpData.derivativesTransactionsCount = .oneToTen
        signUpData.derivativesInvestmentAmount = .zeroToThousand
        signUpData.derivativesHoldingPeriod = .daysToWeeks

        XCTAssertFalse(signUpData.meetsInvestorRiskClass5DerivativesExperienceCriteria)
        XCTAssertEqual(signUpData.cappedForRiskClass5DerivativesGate(.riskClass5), .riskClass4)
    }

    func testInvestorSpecialPathwayRequiresRelaxedDerivativesProfile() {
        let signUpData = self.makeBaseSignUpData(role: .investor)
        signUpData.employmentStatus = .employed
        signUpData.desiredReturn = .atLeastFiftyPercent
        signUpData.derivativesTransactionsCount = .oneToTen
        signUpData.derivativesInvestmentAmount = .zeroToThousand
        signUpData.derivativesHoldingPeriod = .monthsToYears

        XCTAssertLessThan(self.service.calculateRiskClass(for: signUpData).rawValue, RiskClass.riskClass5.rawValue)
    }

    func testInvestorSpecialPathwayPassesWithRelaxedDerivativesProfile() {
        let signUpData = self.makeBaseSignUpData(role: .investor)
        signUpData.employmentStatus = .employed
        signUpData.desiredReturn = .atLeastFiftyPercent
        signUpData.derivativesTransactionsCount = .oneToTen
        signUpData.derivativesInvestmentAmount = .thousandToTenThousand
        signUpData.derivativesHoldingPeriod = .daysToWeeks

        XCTAssertEqual(self.service.calculateRiskClass(for: signUpData), .riskClass5)
    }

    private func makeBaseSignUpData(role: UserRole) -> SignUpData {
        let signUpData = SignUpData(riskClassCalculationService: RiskClassCalculationService())
        signUpData.userRole = role
        signUpData.employmentStatus = .employed
        signUpData.desiredReturn = .atLeastFiftyPercent
        return signUpData
    }
}
