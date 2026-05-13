import SwiftUI

@MainActor
final class RiskClassTestViewModel: ObservableObject {
    @Published var signUpData = SignUpData()

    func calculateCurrentScore() -> Int {
        var score = 0

        // Income range
        switch self.signUpData.incomeRange {
        case .low: score += 0
        case .lowMiddle: score += 1
        case .middle: score += 2
        case .highMiddle: score += 3
        case .high: score += 4
        case .veryHigh: score += 5
        }

        // Cash and liquid assets
        switch self.signUpData.cashAndLiquidAssets {
        case .lessThan10k: score += 0
        case .tenKToFiftyK: score += 1
        case .fiftyKToTwoHundredK: score += 2
        case .twoHundredKToFiveHundredK: score += 3
        case .fiveHundredKToOneMillion: score += 4
        case .oneMillionPlus: score += 5
        }

        // Income sources
        if self.signUpData.incomeSources["Assets"] == true { score += 2 }
        if self.signUpData.incomeSources["Inheritance"] == true { score += 1 }
        if self.signUpData.incomeSources["Settlement"] == true { score += 1 }

        // Investment experience
        switch self.signUpData.stocksTransactionsCount {
        case .none: score += 0
        case .oneToTen: score += 1
        case .tenToFifty: score += 2
        case .fiftyPlus: score += 3
        }

        switch self.signUpData.etfsTransactionsCount {
        case .none: score += 0
        case .oneToTen: score += 1
        case .tenToTwenty: score += 2
        case .moreThanTwenty: score += 3
        }

        switch self.signUpData.derivativesTransactionsCount {
        case .none: score += 0
        case .oneToTen: score += 3
        case .tenToFifty: score += 6
        case .fiftyPlus: score += 8
        }

        // Investment amounts (max of all types)
        let stocksAmountScore: Int
        switch self.signUpData.stocksInvestmentAmount {
        case .hundredToTenThousand: stocksAmountScore = 0
        case .tenThousandToHundredThousand: stocksAmountScore = 1
        case .hundredThousandToMillion: stocksAmountScore = 2
        case .moreThanMillion: stocksAmountScore = 4
        }

        let etfsAmountScore: Int
        switch self.signUpData.etfsInvestmentAmount {
        case .hundredToTenThousand: etfsAmountScore = 0
        case .tenThousandToHundredThousand: etfsAmountScore = 1
        case .hundredThousandToMillion: etfsAmountScore = 2
        case .moreThanMillion: etfsAmountScore = 4
        }

        let derivativesAmountScore: Int
        switch self.signUpData.derivativesInvestmentAmount {
        case .zeroToThousand: derivativesAmountScore = 0
        case .thousandToTenThousand: derivativesAmountScore = 2
        case .tenThousandToHundredThousand: derivativesAmountScore = 4
        case .moreThanHundredThousand: derivativesAmountScore = 6
        }

        score += max(stocksAmountScore, etfsAmountScore, derivativesAmountScore)

        // Derivatives holding period
        switch self.signUpData.derivativesHoldingPeriod {
        case .monthsToYears: score += 1
        case .daysToWeeks: score += 2
        case .minutesToHours: score += 4
        }

        // Desired return
        switch self.signUpData.desiredReturn {
        case .atLeastTenPercent: score += 1
        case .atLeastFiftyPercent: score += 3
        case .atLeastHundredPercent: score += 5
        }

        // Other assets
        if self.signUpData.otherAssets["Real estate"] == true { score += 2 }
        if self.signUpData.otherAssets["Gold, silver"] == true { score += 1 }

        return score
    }

    func resetToDefaults() {
        self.signUpData.incomeRange = .middle
        self.signUpData.cashAndLiquidAssets = .lessThan10k
        self.signUpData.incomeSources = [
            "Settlement": false,
            "Inheritance": false,
            "Savings": false,
            "Financial contributions to family": false,
            "Salary": false,
            "Pension": false,
            "Assets": false,
            "Other (please specify)": false
        ]
        self.signUpData.stocksTransactionsCount = .none
        self.signUpData.etfsTransactionsCount = .none
        self.signUpData.derivativesTransactionsCount = .none
        self.signUpData.stocksInvestmentAmount = .hundredToTenThousand
        self.signUpData.etfsInvestmentAmount = .hundredToTenThousand
        self.signUpData.derivativesInvestmentAmount = .zeroToThousand
        self.signUpData.derivativesHoldingPeriod = .monthsToYears
        self.signUpData.otherAssets = ["Real estate": false, "Gold, silver": false, "No": false]
        self.signUpData.desiredReturn = .atLeastTenPercent
    }

    func testDerivativesExperience() {
        self.signUpData.derivativesTransactionsCount = .fiftyPlus
        self.signUpData.derivativesInvestmentAmount = .tenThousandToHundredThousand
        self.signUpData.derivativesHoldingPeriod = .daysToWeeks
    }

    func testHighRiskProfile() {
        self.signUpData.incomeRange = .veryHigh
        self.signUpData.cashAndLiquidAssets = .oneMillionPlus
        self.signUpData.incomeSources["Assets"] = true
        self.signUpData.derivativesTransactionsCount = .tenToFifty
        self.signUpData.derivativesInvestmentAmount = .moreThanHundredThousand
        self.signUpData.derivativesHoldingPeriod = .minutesToHours
        self.signUpData.desiredReturn = .atLeastFiftyPercent
        self.signUpData.otherAssets["Real estate"] = true
    }

    func testMaximumRisk() {
        self.signUpData.incomeRange = .veryHigh
        self.signUpData.cashAndLiquidAssets = .oneMillionPlus
        self.signUpData.incomeSources["Assets"] = true
        self.signUpData.stocksTransactionsCount = .fiftyPlus
        self.signUpData.etfsTransactionsCount = .moreThanTwenty
        self.signUpData.derivativesTransactionsCount = .fiftyPlus
        self.signUpData.stocksInvestmentAmount = .moreThanMillion
        self.signUpData.etfsInvestmentAmount = .moreThanMillion
        self.signUpData.derivativesInvestmentAmount = .moreThanHundredThousand
        self.signUpData.derivativesHoldingPeriod = .minutesToHours
        self.signUpData.desiredReturn = .atLeastHundredPercent
        self.signUpData.otherAssets["Real estate"] = true
        self.signUpData.otherAssets["Gold, silver"] = true
    }
}
