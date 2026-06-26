@testable import FIN1
import XCTest

final class SignUpLegacyPickerRestoreTests: XCTestCase {
    func testNewSignUpDataStartsWithUnsetStep15And16Pickers() {
        let signUpData = SignUpData()

        XCTAssertNil(signUpData.employmentStatus)
        XCTAssertNil(signUpData.incomeRange)
        XCTAssertNil(signUpData.cashAndLiquidAssets)
        XCTAssertNil(signUpData.stocksTransactionsCount)
        XCTAssertNil(signUpData.derivativesHoldingPeriod)
    }

    func testRestoreClearsStep15PickersOnFinancialStep() {
        let signUpData = SignUpData()
        let saved = self.makeLegacyFinancialSavedData()

        signUpData.restoreFromSavedData(saved, resumeStep: .financial)

        XCTAssertNil(signUpData.employmentStatus)
        XCTAssertNil(signUpData.incomeRange)
        XCTAssertNil(signUpData.cashAndLiquidAssets)
        XCTAssertEqual(signUpData.firstName, "Ada")
    }

    func testRestoreClearsStep16PickersOnExperienceStep() {
        let signUpData = SignUpData()
        let saved = self.makeLegacyExperienceSavedData()

        signUpData.restoreFromSavedData(saved, resumeStep: .experience)

        XCTAssertNil(signUpData.stocksTransactionsCount)
        XCTAssertNil(signUpData.derivativesHoldingPeriod)
    }

    func testRestoreKeepsFinancialPickersPastStep15WithIncomeSources() {
        let signUpData = SignUpData()
        var saved = self.makeLegacyFinancialSavedData()
        saved = SavedOnboardingData(
            accountType: saved.accountType,
            userRole: saved.userRole,
            email: saved.email,
            phoneNumber: saved.phoneNumber,
            username: saved.username,
            salutation: saved.salutation,
            academicTitle: saved.academicTitle,
            firstName: saved.firstName,
            lastName: saved.lastName,
            streetAndNumber: saved.streetAndNumber,
            postalCode: saved.postalCode,
            city: saved.city,
            state: saved.state,
            country: saved.country,
            dateOfBirth: saved.dateOfBirth,
            placeOfBirth: saved.placeOfBirth,
            countryOfBirth: saved.countryOfBirth,
            isNotUSCitizen: saved.isNotUSCitizen,
            nationality: saved.nationality,
            additionalNationalities: saved.additionalNationalities,
            address: saved.address,
            taxNumber: saved.taxNumber,
            additionalResidenceCountry: saved.additionalResidenceCountry,
            identificationType: saved.identificationType,
            employmentStatus: EmploymentStatus.employed.rawValue,
            income: saved.income,
            incomeRange: IncomeRange.middle.rawValue,
            incomeSources: ["Salary": true],
            otherIncomeSource: saved.otherIncomeSource,
            cashAndLiquidAssets: CashAndLiquidAssets.lessThan10k.rawValue,
            stocksTransactionsCount: saved.stocksTransactionsCount,
            stocksInvestmentAmount: saved.stocksInvestmentAmount,
            etfsTransactionsCount: saved.etfsTransactionsCount,
            etfsInvestmentAmount: saved.etfsInvestmentAmount,
            derivativesTransactionsCount: saved.derivativesTransactionsCount,
            derivativesInvestmentAmount: saved.derivativesInvestmentAmount,
            derivativesHoldingPeriod: saved.derivativesHoldingPeriod,
            otherAssets: saved.otherAssets,
            desiredReturn: saved.desiredReturn,
            leveragedProductsTotalLossRiskAcknowledged: saved.leveragedProductsTotalLossRiskAcknowledged,
            leveragedProductsKnowledgeTestAnswers: saved.leveragedProductsKnowledgeTestAnswers,
            leveragedProductsKnowledgeTestVersion: saved.leveragedProductsKnowledgeTestVersion,
            leveragedProductsKnowledgeTestPassed: saved.leveragedProductsKnowledgeTestPassed,
            calculatedRiskClass: saved.calculatedRiskClass,
            finalRiskClass: saved.finalRiskClass,
            insiderTradingOptions: saved.insiderTradingOptions,
            moneyLaunderingDeclaration: saved.moneyLaunderingDeclaration,
            assetType: saved.assetType,
            leveragedProductsExperience: saved.leveragedProductsExperience,
            financialProductsExperience: saved.financialProductsExperience,
            acceptedTerms: saved.acceptedTerms,
            acceptedPrivacyPolicy: saved.acceptedPrivacyPolicy,
            acceptedMarketingConsent: saved.acceptedMarketingConsent,
            acceptedTraderAgreement: saved.acceptedTraderAgreement,
            acceptedInvestorAgreement: saved.acceptedInvestorAgreement,
            traderAgreementVersion: saved.traderAgreementVersion,
            investorAgreementVersion: saved.investorAgreementVersion,
            customerNumber: saved.customerNumber,
            customerId: saved.customerId,
            questionnaireVersion: saved.questionnaireVersion,
            termsVersion: saved.termsVersion,
            privacyVersion: saved.privacyVersion,
            deviceInstallId: saved.deviceInstallId,
            platform: saved.platform,
            appVersion: saved.appVersion,
            buildNumber: saved.buildNumber
        )

        signUpData.restoreFromSavedData(saved, resumeStep: .experience)

        XCTAssertEqual(signUpData.employmentStatus, .employed)
        XCTAssertEqual(signUpData.incomeRange, .middle)
        XCTAssertEqual(signUpData.cashAndLiquidAssets, .lessThan10k)
    }

    func testRestoreDoesNotRestorePickersWhenResumeStepIsUnknown() {
        let signUpData = SignUpData()
        let saved = self.makeLegacyFinancialSavedData()

        signUpData.restoreFromSavedData(saved, resumeStep: nil)

        XCTAssertNil(signUpData.employmentStatus)
        XCTAssertNil(signUpData.incomeRange)
    }

    func testCreateUserRequiresFinancialAndExperienceSelections() {
        let signUpData = SignUpData()
        signUpData.email = "user@example.com"
        signUpData.firstName = "Ada"
        signUpData.lastName = "Lovelace"
        signUpData.password = "Secret1!"
        signUpData.username = "ada1"
        signUpData.acceptedTerms = true
        signUpData.acceptedPrivacyPolicy = true

        XCTAssertThrowsError(try signUpData.createUser()) { error in
            XCTAssertEqual(error as? UserCreationError, .incompleteFinancialProfile)
        }
    }

    func testSignUpStepNumbersMatchSharedContract() throws {
        let contractURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("shared/contracts/signUpStepNumbers.json")

        let data = try Data(contentsOf: contractURL)
        let contract = try JSONDecoder().decode([String: Int].self, from: data)

        for step in SignUpStep.allCases {
            XCTAssertEqual(contract[step.backendKey], step.rawValue, "Step \(step.backendKey)")
        }
    }

    private func makeLegacyFinancialSavedData() -> SavedOnboardingData {
        SavedOnboardingData(
            accountType: nil,
            userRole: nil,
            email: nil,
            phoneNumber: nil,
            username: nil,
            salutation: nil,
            academicTitle: nil,
            firstName: "Ada",
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
            incomeRange: IncomeRange.middle.rawValue,
            incomeSources: ["Salary": false],
            otherIncomeSource: nil,
            cashAndLiquidAssets: CashAndLiquidAssets.lessThan10k.rawValue,
            stocksTransactionsCount: nil,
            stocksInvestmentAmount: nil,
            etfsTransactionsCount: nil,
            etfsInvestmentAmount: nil,
            derivativesTransactionsCount: nil,
            derivativesInvestmentAmount: nil,
            derivativesHoldingPeriod: nil,
            otherAssets: nil,
            desiredReturn: nil,
            leveragedProductsTotalLossRiskAcknowledged: nil,
            leveragedProductsKnowledgeTestAnswers: nil,
            leveragedProductsKnowledgeTestVersion: nil,
            leveragedProductsKnowledgeTestPassed: nil,
            calculatedRiskClass: nil,
            finalRiskClass: nil,
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
        )
    }

    private func makeLegacyExperienceSavedData() -> SavedOnboardingData {
        var saved = self.makeLegacyFinancialSavedData()
        return SavedOnboardingData(
            accountType: saved.accountType,
            userRole: saved.userRole,
            email: saved.email,
            phoneNumber: saved.phoneNumber,
            username: saved.username,
            salutation: saved.salutation,
            academicTitle: saved.academicTitle,
            firstName: saved.firstName,
            lastName: saved.lastName,
            streetAndNumber: saved.streetAndNumber,
            postalCode: saved.postalCode,
            city: saved.city,
            state: saved.state,
            country: saved.country,
            dateOfBirth: saved.dateOfBirth,
            placeOfBirth: saved.placeOfBirth,
            countryOfBirth: saved.countryOfBirth,
            isNotUSCitizen: saved.isNotUSCitizen,
            nationality: saved.nationality,
            additionalNationalities: saved.additionalNationalities,
            address: saved.address,
            taxNumber: saved.taxNumber,
            additionalResidenceCountry: saved.additionalResidenceCountry,
            identificationType: saved.identificationType,
            employmentStatus: saved.employmentStatus,
            income: saved.income,
            incomeRange: saved.incomeRange,
            incomeSources: saved.incomeSources,
            otherIncomeSource: saved.otherIncomeSource,
            cashAndLiquidAssets: saved.cashAndLiquidAssets,
            stocksTransactionsCount: StocksTransactionCount.none.rawValue,
            stocksInvestmentAmount: InvestmentAmount.hundredToTenThousand.rawValue,
            etfsTransactionsCount: ETFsTransactionCount.none.rawValue,
            etfsInvestmentAmount: InvestmentAmount.hundredToTenThousand.rawValue,
            derivativesTransactionsCount: DerivativesTransactionCount.none.rawValue,
            derivativesInvestmentAmount: DerivativesInvestmentAmount.zeroToThousand.rawValue,
            derivativesHoldingPeriod: HoldingPeriod.monthsToYears.rawValue,
            otherAssets: ["No": false],
            desiredReturn: saved.desiredReturn,
            leveragedProductsTotalLossRiskAcknowledged: saved.leveragedProductsTotalLossRiskAcknowledged,
            leveragedProductsKnowledgeTestAnswers: saved.leveragedProductsKnowledgeTestAnswers,
            leveragedProductsKnowledgeTestVersion: saved.leveragedProductsKnowledgeTestVersion,
            leveragedProductsKnowledgeTestPassed: saved.leveragedProductsKnowledgeTestPassed,
            calculatedRiskClass: saved.calculatedRiskClass,
            finalRiskClass: saved.finalRiskClass,
            insiderTradingOptions: saved.insiderTradingOptions,
            moneyLaunderingDeclaration: saved.moneyLaunderingDeclaration,
            assetType: saved.assetType,
            leveragedProductsExperience: saved.leveragedProductsExperience,
            financialProductsExperience: saved.financialProductsExperience,
            acceptedTerms: saved.acceptedTerms,
            acceptedPrivacyPolicy: saved.acceptedPrivacyPolicy,
            acceptedMarketingConsent: saved.acceptedMarketingConsent,
            acceptedTraderAgreement: saved.acceptedTraderAgreement,
            acceptedInvestorAgreement: saved.acceptedInvestorAgreement,
            traderAgreementVersion: saved.traderAgreementVersion,
            investorAgreementVersion: saved.investorAgreementVersion,
            customerNumber: saved.customerNumber,
            customerId: saved.customerId,
            questionnaireVersion: saved.questionnaireVersion,
            termsVersion: saved.termsVersion,
            privacyVersion: saved.privacyVersion,
            deviceInstallId: saved.deviceInstallId,
            platform: saved.platform,
            appVersion: saved.appVersion,
            buildNumber: saved.buildNumber
        )
    }
}

extension UserCreationError: Equatable {
    public static func == (lhs: UserCreationError, rhs: UserCreationError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
