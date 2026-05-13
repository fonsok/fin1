import Foundation

// MARK: - Risk Class Calculation Service Protocol
/// Defines the contract for risk class calculation operations
protocol RiskClassCalculationServiceProtocol: ServiceLifecycle {
    /// Calculate the risk class for a given sign-up data
    func calculateRiskClass(for signUpData: SignUpData) -> RiskClass

    /// Calculate financial risk score
    func calculateFinancialRiskScore(for signUpData: SignUpData) -> Int

    /// Calculate experience risk score
    func calculateExperienceRiskScore(for signUpData: SignUpData) -> Int

    /// Calculate return and asset risk score
    func calculateReturnAndAssetRiskScore(for signUpData: SignUpData) -> Int
}

// MARK: - Risk Class Calculation Service Implementation
/// Handles risk class calculation based on user financial and investment data
final class RiskClassCalculationService: RiskClassCalculationServiceProtocol {

    // MARK: - ServiceLifecycle

    func start() {
        // No initialization needed
    }

    func stop() {
        // No cleanup needed
    }

    func reset() {
        // No state to reset
    }

    // MARK: - Risk Class Calculation

    func calculateRiskClass(for signUpData: SignUpData) -> RiskClass {
        // Calculate based on ALL factors from steps 12, 13, 14
        var riskScore = 0

        // Step 12: Financial Information (Income & Assets)
        riskScore += self.calculateFinancialRiskScore(for: signUpData)

        // Step 13: Investment Experience
        riskScore += self.calculateExperienceRiskScore(for: signUpData)

        // Step 14: Desired return and other factors
        riskScore += self.calculateReturnAndAssetRiskScore(for: signUpData)

        // Map score to risk class
        let calculatedRiskClass = self.mapScoreToRiskClass(riskScore)

        // Apply special rules and safety mechanisms
        return self.applyRiskClassRules(calculatedRiskClass, for: signUpData)
    }

    // MARK: - Financial Risk Score Calculation

    func calculateFinancialRiskScore(for signUpData: SignUpData) -> Int {
        var score = 0

        // Income range (higher income = higher risk tolerance)
        switch signUpData.incomeRange {
        case .low: score += 0
        case .lowMiddle: score += 1
        case .middle: score += 2
        case .highMiddle: score += 3
        case .high: score += 4
        case .veryHigh: score += 5
        }

        // Cash and liquid assets (higher assets = higher risk tolerance)
        switch signUpData.cashAndLiquidAssets {
        case .lessThan10k: score += 0
        case .tenKToFiftyK: score += 1
        case .fiftyKToTwoHundredK: score += 2
        case .twoHundredKToFiveHundredK: score += 3
        case .fiveHundredKToOneMillion: score += 4
        case .oneMillionPlus: score += 5
        }

        // Income sources (some indicate higher risk tolerance)
        if signUpData.incomeSources["Assets"] == true { score += 2 }
        if signUpData.incomeSources["Inheritance"] == true { score += 1 }
        if signUpData.incomeSources["Settlement"] == true { score += 1 }

        return score
    }

    // MARK: - Experience Risk Score Calculation

    func calculateExperienceRiskScore(for signUpData: SignUpData) -> Int {
        var score = 0

        // Stocks experience
        switch signUpData.stocksTransactionsCount {
        case .none: score += 0
        case .oneToTen: score += 1
        case .tenToFifty: score += 2
        case .fiftyPlus: score += 3
        }

        // ETFs experience
        switch signUpData.etfsTransactionsCount {
        case .none: score += 0
        case .oneToTen: score += 1
        case .tenToTwenty: score += 2
        case .moreThanTwenty: score += 3
        }

        // Derivatives experience (different weights for investors vs traders)
        score += self.calculateDerivativesExperienceScore(for: signUpData)

        // Investment amounts (use maximum of all investment types)
        score += self.calculateInvestmentAmountScore(for: signUpData)

        // Derivatives holding period
        score += self.calculateHoldingPeriodScore(for: signUpData)

        return score
    }

    // MARK: - Derivatives Experience Score

    private func calculateDerivativesExperienceScore(for signUpData: SignUpData) -> Int {
        switch signUpData.derivativesTransactionsCount {
        case .none: return 0
        case .oneToTen:
            return signUpData.userRole == .investor ? 1 : 3
        case .tenToFifty:
            return signUpData.userRole == .investor ? 2 : 6
        case .fiftyPlus:
            return signUpData.userRole == .investor ? 3 : 8
        }
    }

    // MARK: - Investment Amount Score

    private func calculateInvestmentAmountScore(for signUpData: SignUpData) -> Int {
        let stocksAmountScore = self.getStocksAmountScore(for: signUpData)
        let etfsAmountScore = self.getETFsAmountScore(for: signUpData)
        let derivativesAmountScore = self.getDerivativesAmountScore(for: signUpData)

        // Use the maximum score since derivatives are riskier
        return max(stocksAmountScore, etfsAmountScore, derivativesAmountScore)
    }

    private func getStocksAmountScore(for signUpData: SignUpData) -> Int {
        switch signUpData.stocksInvestmentAmount {
        case .hundredToTenThousand: return 0
        case .tenThousandToHundredThousand: return 1
        case .hundredThousandToMillion: return 2
        case .moreThanMillion: return 4
        }
    }

    private func getETFsAmountScore(for signUpData: SignUpData) -> Int {
        switch signUpData.etfsInvestmentAmount {
        case .hundredToTenThousand: return 0
        case .tenThousandToHundredThousand: return 1
        case .hundredThousandToMillion: return 2
        case .moreThanMillion: return 4
        }
    }

    private func getDerivativesAmountScore(for signUpData: SignUpData) -> Int {
        switch signUpData.derivativesInvestmentAmount {
        case .zeroToThousand: return 0
        case .thousandToTenThousand:
            return signUpData.userRole == .investor ? 1 : 2
        case .tenThousandToHundredThousand:
            return signUpData.userRole == .investor ? 2 : 4
        case .moreThanHundredThousand:
            return signUpData.userRole == .investor ? 3 : 6
        }
    }

    // MARK: - Holding Period Score

    private func calculateHoldingPeriodScore(for signUpData: SignUpData) -> Int {
        switch signUpData.derivativesHoldingPeriod {
        case .minutesToHours:
            return signUpData.userRole == .investor ? 2 : 4
        case .daysToWeeks:
            return signUpData.userRole == .investor ? 1 : 2
        case .monthsToYears:
            return 1 // Same weight for both (conservative)
        }
    }

    // MARK: - Return and Asset Risk Score

    func calculateReturnAndAssetRiskScore(for signUpData: SignUpData) -> Int {
        var score = 0

        // Desired return (higher expectations = higher risk tolerance)
        switch signUpData.desiredReturn {
        case .atLeastTenPercent: score += 1
        case .atLeastFiftyPercent: score += 3
        case .atLeastHundredPercent: score += 5
        }

        // Other assets (real estate and precious metals indicate higher risk tolerance)
        if signUpData.otherAssets["Real estate"] == true { score += 2 }
        if signUpData.otherAssets["Gold, silver"] == true { score += 1 }

        return score
    }

    // MARK: - Score to Risk Class Mapping

    private func mapScoreToRiskClass(_ score: Int) -> RiskClass {
        switch score {
        case 0...3: return .riskClass1
        case 4...7: return .riskClass2
        case 8...12: return .riskClass3
        case 13...18: return .riskClass4
        case 19...25: return .riskClass5
        case 26...35: return .riskClass6
        default: return .riskClass6 // Cap at 6 unless user manually selects 7
        }
    }

    // MARK: - Risk Class Rules Application

    private func applyRiskClassRules(_ calculatedRiskClass: RiskClass, for signUpData: SignUpData) -> RiskClass {
        // Special pathway for investors: Risk Class 5 if they meet specific criteria
        if signUpData.userRole == .investor && calculatedRiskClass.rawValue < 5 {
            if self.canInvestorGetRiskClass5(for: signUpData) {
                return .riskClass5
            }
        }

        // Apply safety mechanism: cap at Risk Class 2 if conservative patterns detected
        if self.hasConservativeInvestmentPattern(for: signUpData) && calculatedRiskClass.rawValue > 2 {
            return .riskClass2
        }

        return calculatedRiskClass
    }

    // MARK: - Special Investor Risk Class 5 Check

    private func canInvestorGetRiskClass5(for signUpData: SignUpData) -> Bool {
        // 1. Not unemployed
        let isEmployed = signUpData.employmentStatus != .unemployed

        // 2. Has investment experience in at least one area
        let hasStockExperience = signUpData.stocksTransactionsCount != .none
        let hasETFExperience = signUpData.etfsTransactionsCount != .none
        let hasInvestmentAmount = signUpData.stocksInvestmentAmount != .hundredToTenThousand ||
            signUpData.etfsInvestmentAmount != .hundredToTenThousand ||
            signUpData.derivativesInvestmentAmount != .zeroToThousand

        let hasInvestmentExperience = hasStockExperience || hasETFExperience || hasInvestmentAmount

        // 3. Higher desired return (at least 50% or 100%)
        let hasHigherReturn = signUpData.desiredReturn == .atLeastFiftyPercent || signUpData.desiredReturn == .atLeastHundredPercent

        return isEmployed && hasInvestmentExperience && hasHigherReturn
    }

    // MARK: - Conservative Investment Pattern Check

    private func hasConservativeInvestmentPattern(for signUpData: SignUpData) -> Bool {
        if signUpData.userRole == .investor {
            // For investors: Only check desired return (they don't actively trade)
            return signUpData.desiredReturn == .atLeastTenPercent
        } else {
            // For traders: Check all conservative patterns (they actively trade)
            let hasConservativeDerivatives = signUpData.derivativesTransactionsCount == .none ||
                signUpData.derivativesTransactionsCount == .oneToTen ||
                signUpData.derivativesTransactionsCount == .tenToFifty

            let hasConservativeAmounts = signUpData.derivativesInvestmentAmount == .zeroToThousand ||
                signUpData.derivativesInvestmentAmount == .thousandToTenThousand

            let hasConservativeHolding = signUpData.derivativesHoldingPeriod == .monthsToYears
            let hasConservativeReturn = signUpData.desiredReturn == .atLeastTenPercent

            // If ANY of these conservative patterns are detected, cap at Risk Class 2
            return hasConservativeDerivatives || hasConservativeAmounts || hasConservativeHolding || hasConservativeReturn
        }
    }
}







