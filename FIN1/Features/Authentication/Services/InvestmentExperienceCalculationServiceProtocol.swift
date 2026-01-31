import Foundation

// MARK: - Investment Experience Calculation Service Protocol
/// Defines the contract for investment experience calculation operations
protocol InvestmentExperienceCalculationServiceProtocol: ServiceLifecycle {
    /// Calculate investment experience level (0-10 scale)
    func calculateInvestmentExperienceLevel(for signUpData: SignUpData) -> Int

    /// Calculate trading frequency (0-10 scale)
    func calculateTradingFrequency(for signUpData: SignUpData) -> Int

    /// Calculate investment knowledge (0-10 scale)
    func calculateInvestmentKnowledge(for signUpData: SignUpData) -> Int
}

// MARK: - Investment Experience Calculation Service Implementation
/// Handles investment experience calculations based on user trading history
final class InvestmentExperienceCalculationService: InvestmentExperienceCalculationServiceProtocol {

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

    // MARK: - Experience Level Calculations

    func calculateInvestmentExperienceLevel(for signUpData: SignUpData) -> Int {
        var experience = 0

        // Stocks experience
        switch signUpData.stocksTransactionsCount {
        case .none: experience += 0
        case .oneToTen: experience += 1
        case .tenToFifty: experience += 2
        case .fiftyPlus: experience += 3
        }

        // ETFs experience
        switch signUpData.etfsTransactionsCount {
        case .none: experience += 0
        case .oneToTen: experience += 1
        case .tenToTwenty: experience += 2
        case .moreThanTwenty: experience += 3
        }

        // Derivatives experience
        switch signUpData.derivativesTransactionsCount {
        case .none: experience += 0
        case .oneToTen: experience += 1
        case .tenToFifty: experience += 2
        case .fiftyPlus: experience += 3
        }

        // Cap at 10 for the scale
        return min(experience, 10)
    }

    func calculateTradingFrequency(for signUpData: SignUpData) -> Int {
        // For traders, base on derivatives experience
        if signUpData.userRole == .trader {
            switch signUpData.derivativesTransactionsCount {
            case .none: return 0
            case .oneToTen: return 2
            case .tenToFifty: return 5
            case .fiftyPlus: return 8
            }
        }

        // For investors, base on overall experience
        let experience = calculateInvestmentExperienceLevel(for: signUpData)
        return min(experience / 2, 5) // Scale down for investors
    }

    func calculateInvestmentKnowledge(for signUpData: SignUpData) -> Int {
        var knowledge = 0

        // Base knowledge from experience
        knowledge += calculateInvestmentExperienceLevel(for: signUpData)

        // Additional knowledge from investment amounts
        if signUpData.stocksInvestmentAmount != .hundredToTenThousand { knowledge += 1 }
        if signUpData.etfsInvestmentAmount != .hundredToTenThousand { knowledge += 1 }
        if signUpData.derivativesInvestmentAmount != .zeroToThousand { knowledge += 2 }

        // Knowledge from other assets
        if signUpData.otherAssets["Real estate"] == true { knowledge += 1 }
        if signUpData.otherAssets["Gold, silver"] == true { knowledge += 1 }

        // Cap at 10 for the scale
        return min(knowledge, 10)
    }
}







