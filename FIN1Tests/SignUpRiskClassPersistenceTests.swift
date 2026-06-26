@testable import FIN1
import XCTest

final class SignUpRiskClassPersistenceTests: XCTestCase {
    func testFinalRiskClassHonorsManualRiskClassSevenSelection() {
        let signUpData = SignUpData()
        signUpData.leveragedProductsTotalLossRiskAcknowledged = true
        signUpData.leveragedProductsKnowledgeTestAnswers = ["put_dow_jones_falling": "A"]
        signUpData.userSelectedRiskClass = .riskClass7

        XCTAssertEqual(signUpData.finalRiskClass, .riskClass7)
        XCTAssertEqual(signUpData.finalRiskClass.rawValue, 7)
    }

    func testManualRiskClassSevenOverridesConservativeGateForPersistence() {
        let signUpData = SignUpData()
        signUpData.leveragedProductsTotalLossRiskAcknowledged = false
        signUpData.userSelectedRiskClass = .riskClass7

        XCTAssertEqual(signUpData.finalRiskClass, .riskClass7)
    }

    func testSyncOnboardingRiskClassSelectionDoesNotWipeManualRiskClassSeven() {
        let signUpData = SignUpData()
        signUpData.leveragedProductsTotalLossRiskAcknowledged = false
        signUpData.userSelectedRiskClass = .riskClass7

        signUpData.syncOnboardingRiskClassSelection()

        XCTAssertEqual(signUpData.userSelectedRiskClass, .riskClass7)
        XCTAssertEqual(signUpData.finalRiskClass, .riskClass7)
    }

    func testGateFieldUpdatesClearStaleConservativeRiskClassOneImmediately() {
        let signUpData = Self.makeHighRiskTraderSignUpData()
        signUpData.updateLeveragedProductsTotalLossRiskAcknowledged(false)
        XCTAssertEqual(signUpData.userSelectedRiskClass, .riskClass1)

        signUpData.updateLeveragedProductsTotalLossRiskAcknowledged(true)
        XCTAssertNil(signUpData.userSelectedRiskClass)
        XCTAssertGreaterThanOrEqual(signUpData.finalRiskClass.rawValue, RiskClass.riskClass5.rawValue)
    }

    func testConservativeRiskClassOneDoesNotStickAfterGateLifted() {
        let signUpData = Self.makeHighRiskTraderSignUpData()
        signUpData.leveragedProductsTotalLossRiskAcknowledged = false

        signUpData.syncOnboardingRiskClassSelection()
        XCTAssertEqual(signUpData.userSelectedRiskClass, .riskClass1)
        XCTAssertEqual(signUpData.finalRiskClass, .riskClass1)

        signUpData.leveragedProductsTotalLossRiskAcknowledged = true
        signUpData.leveragedProductsKnowledgeTestAnswers = ["put_dow_jones_falling": "A"]
        signUpData.syncOnboardingRiskClassSelection()

        XCTAssertNil(signUpData.userSelectedRiskClass)
        XCTAssertGreaterThanOrEqual(signUpData.finalRiskClass.rawValue, RiskClass.riskClass5.rawValue)
    }

    func testRestoreDoesNotPinConservativeRiskClassOneAsManualSelection() {
        let signUpData = SignUpData(riskClassCalculationService: RiskClassCalculationService())
        signUpData.userRole = .trader
        signUpData.restoreFromSavedData(
            SavedOnboardingData(
                accountType: nil,
                userRole: UserRole.trader.rawValue,
                email: nil,
                phoneNumber: nil,
                username: nil,
                salutation: nil,
                academicTitle: nil,
                firstName: nil,
                lastName: nil,
                streetAndNumber: nil,
                postalCode: nil,
                city: nil,
                state: nil,
                country: nil,
                dateOfBirth: nil,
                placeOfBirth: nil,
                countryOfBirth: nil,
                isNotUSCitizen: nil,
                nationality: nil,
                additionalNationalities: nil,
                address: nil,
                taxNumber: nil,
                additionalResidenceCountry: nil,
                identificationType: nil,
                employmentStatus: EmploymentStatus.employed.rawValue,
                income: nil,
                incomeRange: IncomeRange.veryHigh.rawValue,
                incomeSources: ["Assets": true],
                otherIncomeSource: nil,
                cashAndLiquidAssets: CashAndLiquidAssets.oneMillionPlus.rawValue,
                stocksTransactionsCount: StocksTransactionCount.fiftyPlus.rawValue,
                stocksInvestmentAmount: InvestmentAmount.moreThanMillion.rawValue,
                etfsTransactionsCount: ETFsTransactionCount.moreThanTwenty.rawValue,
                etfsInvestmentAmount: InvestmentAmount.moreThanMillion.rawValue,
                derivativesTransactionsCount: DerivativesTransactionCount.fiftyPlus.rawValue,
                derivativesInvestmentAmount: DerivativesInvestmentAmount.moreThanHundredThousand.rawValue,
                derivativesHoldingPeriod: HoldingPeriod.minutesToHours.rawValue,
                otherAssets: ["Real estate": true, "Gold, silver": true, "No": false],
                desiredReturn: DesiredReturn.atLeastHundredPercent.rawValue,
                leveragedProductsTotalLossRiskAcknowledged: true,
                leveragedProductsKnowledgeTestAnswers: ["put_dow_jones_falling": "A"],
                leveragedProductsKnowledgeTestVersion: nil,
                leveragedProductsKnowledgeTestPassed: true,
                calculatedRiskClass: RiskClass.riskClass6.rawValue,
                finalRiskClass: RiskClass.riskClass1.rawValue,
                insiderTradingOptions: nil,
                moneyLaunderingDeclaration: nil,
                assetType: nil,
                leveragedProductsExperience: nil,
                financialProductsExperience: nil,
                acceptedTerms: nil,
                acceptedPrivacyPolicy: nil,
                acceptedMarketingConsent: nil,
                acceptedTraderAgreement: nil,
                acceptedInvestorAgreement: nil,
                traderAgreementVersion: nil,
                investorAgreementVersion: nil,
                customerNumber: nil,
                customerId: nil,
                questionnaireVersion: nil,
                termsVersion: nil,
                privacyVersion: nil,
                deviceInstallId: nil,
                platform: nil,
                appVersion: nil,
                buildNumber: nil
            ),
            resumeStep: .summary
        )

        XCTAssertNil(signUpData.userSelectedRiskClass)
        XCTAssertGreaterThanOrEqual(signUpData.finalRiskClass.rawValue, RiskClass.riskClass5.rawValue)
    }

    func testEarlyAccountUserRiskClassReflectsPrefilledQuestionnaire() throws {
        let signUpData = SignUpData()
        signUpData.userRole = .trader
        signUpData.email = "user@example.com"
        signUpData.username = "user1"
        signUpData.password = "Secret1!"
        signUpData.acceptedTerms = true
        signUpData.acceptedPrivacyPolicy = true
        signUpData.employmentStatus = .employed
        signUpData.incomeRange = .veryHigh
        signUpData.cashAndLiquidAssets = .oneMillionPlus
        signUpData.incomeSources["Assets"] = true
        signUpData.stocksTransactionsCount = .fiftyPlus
        signUpData.etfsTransactionsCount = .moreThanTwenty
        signUpData.derivativesTransactionsCount = .fiftyPlus
        signUpData.stocksInvestmentAmount = .moreThanMillion
        signUpData.etfsInvestmentAmount = .moreThanMillion
        signUpData.derivativesInvestmentAmount = .moreThanHundredThousand
        signUpData.derivativesHoldingPeriod = .minutesToHours
        signUpData.desiredReturn = .atLeastHundredPercent
        signUpData.leveragedProductsTotalLossRiskAcknowledged = true
        signUpData.leveragedProductsKnowledgeTestAnswers = ["put_dow_jones_falling": "A"]

        let user = try signUpData.createEarlyAccountUser()

        XCTAssertGreaterThanOrEqual(user.riskTolerance, RiskClass.riskClass5.rawValue)
    }

    private static func makeHighRiskTraderSignUpData() -> SignUpData {
        let signUpData = SignUpData(riskClassCalculationService: RiskClassCalculationService())
        signUpData.userRole = .trader
        signUpData.employmentStatus = .employed
        signUpData.incomeRange = .veryHigh
        signUpData.cashAndLiquidAssets = .oneMillionPlus
        signUpData.incomeSources["Assets"] = true
        signUpData.stocksTransactionsCount = .fiftyPlus
        signUpData.etfsTransactionsCount = .moreThanTwenty
        signUpData.derivativesTransactionsCount = .fiftyPlus
        signUpData.stocksInvestmentAmount = .moreThanMillion
        signUpData.etfsInvestmentAmount = .moreThanMillion
        signUpData.derivativesInvestmentAmount = .moreThanHundredThousand
        signUpData.derivativesHoldingPeriod = .minutesToHours
        signUpData.desiredReturn = .atLeastHundredPercent
        signUpData.otherAssets["Real estate"] = true
        signUpData.otherAssets["Gold, silver"] = true
        return signUpData
    }
}
