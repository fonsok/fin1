import Foundation

/// Step-15/16 restore rules aligned with `backend/parse-server/cloud/utils/onboardingLegacyPickerDefaults.js`.
enum SignUpLegacyPickerDefaults {
    static let financialStepNumber = SignUpStep.financial.rawValue
    static let experienceStepNumber = SignUpStep.experience.rawValue

    static func shouldRestoreFinancialPickers(resumeStep: SignUpStep?, savedData: SavedOnboardingData?) -> Bool {
        guard let resumeStep else { return false }
        guard resumeStep.rawValue > self.financialStepNumber else { return false }
        guard let savedData else { return true }
        if self.matchesLegacyFinancialAutosave(savedData),
           !self.hasSelectedIncomeSource(savedData.incomeSources) {
            return false
        }
        return true
    }

    static func shouldRestoreExperiencePickers(resumeStep: SignUpStep?, savedData: SavedOnboardingData?) -> Bool {
        guard let resumeStep else { return false }
        guard resumeStep.rawValue > self.experienceStepNumber else { return false }
        guard let savedData else { return true }
        if self.matchesLegacyExperienceAutosave(savedData),
           !self.hasSelectedOtherAsset(savedData.otherAssets) {
            return false
        }
        return true
    }

    static func matchesLegacyFinancialAutosave(_ data: SavedOnboardingData) -> Bool {
        data.employmentStatus == EmploymentStatus.employed.rawValue
            && data.incomeRange == IncomeRange.middle.rawValue
            && (data.cashAndLiquidAssets == CashAndLiquidAssets.lessThan10k.rawValue
                || data.cashAndLiquidAssets == CashAndLiquidAssets.tenKToFiftyK.rawValue)
    }

    static func matchesLegacyExperienceAutosave(_ data: SavedOnboardingData) -> Bool {
        self.matchesExperienceBundle(data, bundle: self.legacyExperienceAutosave)
            || self.matchesExperienceBundle(data, bundle: self.legacyExperienceDebugPrefill)
    }

    private static let legacyExperienceAutosave: [String: String] = [
        "stocksTransactionsCount": StocksTransactionCount.none.rawValue,
        "stocksInvestmentAmount": InvestmentAmount.hundredToTenThousand.rawValue,
        "etfsTransactionsCount": ETFsTransactionCount.none.rawValue,
        "etfsInvestmentAmount": InvestmentAmount.hundredToTenThousand.rawValue,
        "derivativesTransactionsCount": DerivativesTransactionCount.none.rawValue,
        "derivativesInvestmentAmount": DerivativesInvestmentAmount.zeroToThousand.rawValue,
        "derivativesHoldingPeriod": HoldingPeriod.monthsToYears.rawValue
    ]

    private static let legacyExperienceDebugPrefill: [String: String] = [
        "stocksTransactionsCount": StocksTransactionCount.oneToTen.rawValue,
        "stocksInvestmentAmount": InvestmentAmount.tenThousandToHundredThousand.rawValue,
        "etfsTransactionsCount": ETFsTransactionCount.oneToTen.rawValue,
        "etfsInvestmentAmount": InvestmentAmount.tenThousandToHundredThousand.rawValue,
        "derivativesTransactionsCount": DerivativesTransactionCount.none.rawValue,
        "derivativesInvestmentAmount": DerivativesInvestmentAmount.zeroToThousand.rawValue,
        "derivativesHoldingPeriod": HoldingPeriod.monthsToYears.rawValue
    ]

    private static func matchesExperienceBundle(_ data: SavedOnboardingData, bundle: [String: String]) -> Bool {
        bundle.allSatisfy { field, expected in
            self.rawValue(from: data, field: field) == expected
        }
    }

    private static func rawValue(from data: SavedOnboardingData, field: String) -> String? {
        switch field {
        case "stocksTransactionsCount": return data.stocksTransactionsCount
        case "stocksInvestmentAmount": return data.stocksInvestmentAmount
        case "etfsTransactionsCount": return data.etfsTransactionsCount
        case "etfsInvestmentAmount": return data.etfsInvestmentAmount
        case "derivativesTransactionsCount": return data.derivativesTransactionsCount
        case "derivativesInvestmentAmount": return data.derivativesInvestmentAmount
        case "derivativesHoldingPeriod": return data.derivativesHoldingPeriod
        default: return nil
        }
    }

    private static func hasSelectedIncomeSource(_ incomeSources: [String: Bool]?) -> Bool {
        incomeSources?.values.contains(true) == true
    }

    private static func hasSelectedOtherAsset(_ otherAssets: [String: Bool]?) -> Bool {
        otherAssets?.values.contains(true) == true
    }
}
