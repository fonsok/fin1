import SwiftUI

@MainActor
final class RiskClassTestViewModel: ObservableObject {
    @Published var signUpData = SignUpData()

    func calculateCurrentScore() -> Int {
        var score = 0

        // Income range
        switch signUpData.incomeRange {
        case .low: score += 0
        case .lowMiddle: score += 1
        case .middle: score += 2
        case .highMiddle: score += 3
        case .high: score += 4
        case .veryHigh: score += 5
        }

        // Cash and liquid assets
        switch signUpData.cashAndLiquidAssets {
        case .lessThan10k: score += 0
        case .tenKToFiftyK: score += 1
        case .fiftyKToTwoHundredK: score += 2
        case .twoHundredKToFiveHundredK: score += 3
        case .fiveHundredKToOneMillion: score += 4
        case .oneMillionPlus: score += 5
        }

        // Income sources
        if signUpData.incomeSources["Assets"] == true { score += 2 }
        if signUpData.incomeSources["Inheritance"] == true { score += 1 }
        if signUpData.incomeSources["Settlement"] == true { score += 1 }

        // Investment experience
        switch signUpData.stocksTransactionsCount {
        case .none: score += 0
        case .oneToTen: score += 1
        case .tenToFifty: score += 2
        case .fiftyPlus: score += 3
        }

        switch signUpData.etfsTransactionsCount {
        case .none: score += 0
        case .oneToTen: score += 1
        case .tenToTwenty: score += 2
        case .moreThanTwenty: score += 3
        }

        switch signUpData.derivativesTransactionsCount {
        case .none: score += 0
        case .oneToTen: score += 3
        case .tenToFifty: score += 6
        case .fiftyPlus: score += 8
        }

        // Investment amounts (max of all types)
        let stocksAmountScore: Int
        switch signUpData.stocksInvestmentAmount {
        case .hundredToTenThousand: stocksAmountScore = 0
        case .tenThousandToHundredThousand: stocksAmountScore = 1
        case .hundredThousandToMillion: stocksAmountScore = 2
        case .moreThanMillion: stocksAmountScore = 4
        }

        let etfsAmountScore: Int
        switch signUpData.etfsInvestmentAmount {
        case .hundredToTenThousand: etfsAmountScore = 0
        case .tenThousandToHundredThousand: etfsAmountScore = 1
        case .hundredThousandToMillion: etfsAmountScore = 2
        case .moreThanMillion: etfsAmountScore = 4
        }

        let derivativesAmountScore: Int
        switch signUpData.derivativesInvestmentAmount {
        case .zeroToThousand: derivativesAmountScore = 0
        case .thousandToTenThousand: derivativesAmountScore = 2
        case .tenThousandToHundredThousand: derivativesAmountScore = 4
        case .moreThanHundredThousand: derivativesAmountScore = 6
        }

        score += max(stocksAmountScore, etfsAmountScore, derivativesAmountScore)

        // Derivatives holding period
        switch signUpData.derivativesHoldingPeriod {
        case .monthsToYears: score += 1
        case .daysToWeeks: score += 2
        case .minutesToHours: score += 4
        }

        // Desired return
        switch signUpData.desiredReturn {
        case .atLeastTenPercent: score += 1
        case .atLeastFiftyPercent: score += 3
        case .atLeastHundredPercent: score += 5
        }

        // Other assets
        if signUpData.otherAssets["Real estate"] == true { score += 2 }
        if signUpData.otherAssets["Gold, silver"] == true { score += 1 }

        return score
    }

    func resetToDefaults() {
        signUpData.incomeRange = .middle
        signUpData.cashAndLiquidAssets = .lessThan10k
        signUpData.incomeSources = [
            "Settlement": false,
            "Inheritance": false,
            "Savings": false,
            "Financial contributions to family": false,
            "Salary": false,
            "Pension": false,
            "Assets": false,
            "Other (please specify)": false
        ]
        signUpData.stocksTransactionsCount = .none
        signUpData.etfsTransactionsCount = .none
        signUpData.derivativesTransactionsCount = .none
        signUpData.stocksInvestmentAmount = .hundredToTenThousand
        signUpData.etfsInvestmentAmount = .hundredToTenThousand
        signUpData.derivativesInvestmentAmount = .zeroToThousand
        signUpData.derivativesHoldingPeriod = .monthsToYears
        signUpData.otherAssets = ["Real estate": false, "Gold, silver": false, "No": false]
        signUpData.desiredReturn = .atLeastTenPercent
    }

    func testDerivativesExperience() {
        signUpData.derivativesTransactionsCount = .fiftyPlus
        signUpData.derivativesInvestmentAmount = .tenThousandToHundredThousand
        signUpData.derivativesHoldingPeriod = .daysToWeeks
    }

    func testHighRiskProfile() {
        signUpData.incomeRange = .veryHigh
        signUpData.cashAndLiquidAssets = .oneMillionPlus
        signUpData.incomeSources["Assets"] = true
        signUpData.derivativesTransactionsCount = .tenToFifty
        signUpData.derivativesInvestmentAmount = .moreThanHundredThousand
        signUpData.derivativesHoldingPeriod = .minutesToHours
        signUpData.desiredReturn = .atLeastFiftyPercent
        signUpData.otherAssets["Real estate"] = true
    }

    func testMaximumRisk() {
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
    }
}
