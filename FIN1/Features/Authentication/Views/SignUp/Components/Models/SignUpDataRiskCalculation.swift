import Foundation

// MARK: - SignUp Data Risk Calculation Extensions

extension SignUpData {
    // MARK: - Computed Properties for Risk Class
    var calculatedRiskClass: RiskClass {
        if let service = riskClassCalculationService {
            return service.calculateRiskClass(for: self)
        }
        // Fallback to old implementation for backward compatibility
        return calculateRiskClassLegacy()
    }

    var finalRiskClass: RiskClass {
        return userSelectedRiskClass ?? calculatedRiskClass
    }

    // MARK: - Risk Class Calculation (Legacy - kept for backward compatibility)
    private func calculateRiskClassLegacy() -> RiskClass {
        // Calculate based on ALL factors from steps 12, 13, 14
        var riskScore = 0

        // Step 12: Financial Information (Income & Assets)
        riskScore += calculateFinancialRiskScore()

        // Step 13: Investment Experience
        riskScore += calculateExperienceRiskScore()

        // Step 14: Desired return and other factors
        riskScore += calculateReturnAndAssetRiskScore()

        // Map score to risk class
        let calculatedRiskClass = mapScoreToRiskClass(riskScore)

        // Apply special rules and safety mechanisms
        return applyRiskClassRules(calculatedRiskClass)
    }

    // MARK: - Financial Risk Score Calculation
    private func calculateFinancialRiskScore() -> Int {
        var score = 0

        // Income range (higher income = higher risk tolerance)
        switch incomeRange {
        case .low: score += 0
        case .lowMiddle: score += 1
        case .middle: score += 2
        case .highMiddle: score += 3
        case .high: score += 4
        case .veryHigh: score += 5
        }

        // Cash and liquid assets (higher assets = higher risk tolerance)
        switch cashAndLiquidAssets {
        case .lessThan10k: score += 0
        case .tenKToFiftyK: score += 1
        case .fiftyKToTwoHundredK: score += 2
        case .twoHundredKToFiveHundredK: score += 3
        case .fiveHundredKToOneMillion: score += 4
        case .oneMillionPlus: score += 5
        }

        // Income sources (some indicate higher risk tolerance)
        if incomeSources["Assets"] == true { score += 2 }
        if incomeSources["Inheritance"] == true { score += 1 }
        if incomeSources["Settlement"] == true { score += 1 }

        return score
    }

    // MARK: - Experience Risk Score Calculation
    private func calculateExperienceRiskScore() -> Int {
        var score = 0

        // Stocks experience
        switch stocksTransactionsCount {
        case .none: score += 0
        case .oneToTen: score += 1
        case .tenToFifty: score += 2
        case .fiftyPlus: score += 3
        }

        // ETFs experience
        switch etfsTransactionsCount {
        case .none: score += 0
        case .oneToTen: score += 1
        case .tenToTwenty: score += 2
        case .moreThanTwenty: score += 3
        }

        // Derivatives experience (different weights for investors vs traders)
        score += calculateDerivativesExperienceScore()

        // Investment amounts (use maximum of all investment types)
        score += calculateInvestmentAmountScore()

        // Derivatives holding period
        score += calculateHoldingPeriodScore()

        return score
    }

    // MARK: - Derivatives Experience Score
    private func calculateDerivativesExperienceScore() -> Int {
        switch derivativesTransactionsCount {
        case .none: return 0
        case .oneToTen:
            return userRole == .investor ? 1 : 3
        case .tenToFifty:
            return userRole == .investor ? 2 : 6
        case .fiftyPlus:
            return userRole == .investor ? 3 : 8
        }
    }

    // MARK: - Investment Amount Score
    private func calculateInvestmentAmountScore() -> Int {
        let stocksAmountScore = getStocksAmountScore()
        let etfsAmountScore = getETFsAmountScore()
        let derivativesAmountScore = getDerivativesAmountScore()

        // Use the maximum score since derivatives are riskier
        return max(stocksAmountScore, etfsAmountScore, derivativesAmountScore)
    }

    private func getStocksAmountScore() -> Int {
        switch stocksInvestmentAmount {
        case .hundredToTenThousand: return 0
        case .tenThousandToHundredThousand: return 1
        case .hundredThousandToMillion: return 2
        case .moreThanMillion: return 4
        }
    }

    private func getETFsAmountScore() -> Int {
        switch etfsInvestmentAmount {
        case .hundredToTenThousand: return 0
        case .tenThousandToHundredThousand: return 1
        case .hundredThousandToMillion: return 2
        case .moreThanMillion: return 4
        }
    }

    private func getDerivativesAmountScore() -> Int {
        switch derivativesInvestmentAmount {
        case .zeroToThousand: return 0
        case .thousandToTenThousand:
            return userRole == .investor ? 1 : 2
        case .tenThousandToHundredThousand:
            return userRole == .investor ? 2 : 4
        case .moreThanHundredThousand:
            return userRole == .investor ? 3 : 6
        }
    }

    // MARK: - Holding Period Score
    private func calculateHoldingPeriodScore() -> Int {
        switch derivativesHoldingPeriod {
        case .minutesToHours:
            return userRole == .investor ? 2 : 4
        case .daysToWeeks:
            return userRole == .investor ? 1 : 2
        case .monthsToYears:
            return 1 // Same weight for both (conservative)
        }
    }

    // MARK: - Return and Asset Risk Score
    private func calculateReturnAndAssetRiskScore() -> Int {
        var score = 0

        // Desired return (higher expectations = higher risk tolerance)
        switch desiredReturn {
        case .atLeastTenPercent: score += 1
        case .atLeastFiftyPercent: score += 3
        case .atLeastHundredPercent: score += 5
        }

        // Other assets (real estate and precious metals indicate higher risk tolerance)
        if otherAssets["Real estate"] == true { score += 2 }
        if otherAssets["Gold, silver"] == true { score += 1 }

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
    private func applyRiskClassRules(_ calculatedRiskClass: RiskClass) -> RiskClass {
        // Special pathway for investors: Risk Class 5 if they meet specific criteria
        if userRole == .investor && calculatedRiskClass.rawValue < 5 {
            if canInvestorGetRiskClass5() {
                return .riskClass5
            }
        }

        // Apply safety mechanism: cap at Risk Class 2 if conservative patterns detected
        if hasConservativeInvestmentPattern() && calculatedRiskClass.rawValue > 2 {
            return .riskClass2
        }

        return calculatedRiskClass
    }

    // MARK: - Special Investor Risk Class 5 Check
    private func canInvestorGetRiskClass5() -> Bool {
        // 1. Not unemployed
        let isEmployed = employmentStatus != .unemployed

        // 2. Has investment experience in at least one area
        let hasStockExperience = stocksTransactionsCount != .none
        let hasETFExperience = etfsTransactionsCount != .none
        let hasInvestmentAmount = stocksInvestmentAmount != .hundredToTenThousand ||
                                 etfsInvestmentAmount != .hundredToTenThousand ||
                                 derivativesInvestmentAmount != .zeroToThousand

        let hasInvestmentExperience = hasStockExperience || hasETFExperience || hasInvestmentAmount

        // 3. Higher desired return (at least 50% or 100%)
        let hasHigherReturn = desiredReturn == .atLeastFiftyPercent || desiredReturn == .atLeastHundredPercent

        return isEmployed && hasInvestmentExperience && hasHigherReturn
    }

    // MARK: - Conservative Investment Pattern Check
    private func hasConservativeInvestmentPattern() -> Bool {
        if userRole == .investor {
            // For investors: Only check desired return (they don't actively trade)
            return desiredReturn == .atLeastTenPercent
        } else {
            // For traders: Check all conservative patterns (they actively trade)
            let hasConservativeDerivatives = derivativesTransactionsCount == .none ||
                                            derivativesTransactionsCount == .oneToTen ||
                                            derivativesTransactionsCount == .tenToFifty

            let hasConservativeAmounts = derivativesInvestmentAmount == .zeroToThousand ||
                                        derivativesInvestmentAmount == .thousandToTenThousand

            let hasConservativeHolding = derivativesHoldingPeriod == .monthsToYears
            let hasConservativeReturn = desiredReturn == .atLeastTenPercent

            // If ANY of these conservative patterns are detected, cap at Risk Class 2
            return hasConservativeDerivatives || hasConservativeAmounts || hasConservativeHolding || hasConservativeReturn
        }
    }
}
