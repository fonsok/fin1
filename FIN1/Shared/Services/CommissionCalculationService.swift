import Foundation

// MARK: - Commission Calculation Service Protocol

/// Centralized service for all commission calculations
/// Provides a single source of truth for commission calculation logic
protocol CommissionCalculationServiceProtocol: ServiceLifecycle {
    // MARK: - Basic Commission Calculations

    /// Calculates commission from gross profit and rate
    /// - Parameters:
    ///   - grossProfit: Gross profit amount
    ///   - rate: Commission rate (0.0 to 1.0)
    /// - Returns: Commission amount (0 if gross profit <= 0)
    func calculateCommission(grossProfit: Double, rate: Double) -> Double

    /// Calculates net profit after deducting commission
    /// - Parameters:
    ///   - grossProfit: Gross profit amount
    ///   - rate: Commission rate (0.0 to 1.0)
    /// - Returns: Net profit after commission
    func calculateNetProfitAfterCommission(grossProfit: Double, rate: Double) -> Double

    /// Calculates both commission and net profit in one call
    /// - Parameters:
    ///   - grossProfit: Gross profit amount
    ///   - rate: Commission rate (0.0 to 1.0)
    /// - Returns: Tuple with commission and net profit
    func calculateCommissionAndNetProfit(grossProfit: Double, rate: Double) -> (commission: Double, netProfit: Double)

    // MARK: - Investor-Specific Commission Calculations

    /// Calculates commission for a specific investor's investment in a trade
    /// Uses the investor's gross profit from Collection Bill calculation
    /// - Parameters:
    ///   - investmentId: The investment ID
    ///   - tradeId: The trade ID
    ///   - commissionRate: Commission rate (0.0 to 1.0)
    /// - Returns: Commission amount for this investor
    func calculateCommissionForInvestor(
        investmentId: String,
        tradeId: String,
        commissionRate: Double
    ) async throws -> Double

    /// Calculates total commission for all investors in a trade
    /// - Parameters:
    ///   - tradeId: The trade ID
    ///   - commissionRate: Commission rate (0.0 to 1.0)
    /// - Returns: Total commission amount
    func calculateTotalCommissionForTrade(
        tradeId: String,
        commissionRate: Double
    ) async throws -> Double
}

// MARK: - Commission Calculation Service Implementation

final class CommissionCalculationService: CommissionCalculationServiceProtocol {

    // MARK: - Dependencies
    private let investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?

    // MARK: - Initialization
    init(investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)? = nil) {
        self.investorGrossProfitService = investorGrossProfitService
    }

    // MARK: - ServiceLifecycle
    func start() {
        print("💰 CommissionCalculationService started")
    }

    func stop() {
        print("💰 CommissionCalculationService stopped")
    }

    func reset() {
        print("💰 CommissionCalculationService reset")
    }

    // MARK: - Basic Commission Calculations

    func calculateCommission(grossProfit: Double, rate: Double) -> Double {
        guard grossProfit > 0 else { return 0.0 }
        return grossProfit * rate
    }

    func calculateNetProfitAfterCommission(grossProfit: Double, rate: Double) -> Double {
        let commission = calculateCommission(grossProfit: grossProfit, rate: rate)
        return grossProfit - commission
    }

    func calculateCommissionAndNetProfit(grossProfit: Double, rate: Double) -> (commission: Double, netProfit: Double) {
        let commission = calculateCommission(grossProfit: grossProfit, rate: rate)
        return (commission, grossProfit - commission)
    }

    // MARK: - Investor-Specific Commission Calculations

    func calculateCommissionForInvestor(
        investmentId: String,
        tradeId: String,
        commissionRate: Double
    ) async throws -> Double {
        guard let investorGrossProfitService = investorGrossProfitService else {
            throw AppError.serviceError(.serviceUnavailable)
        }

        // Get gross profit using the single source of truth
        let grossProfit = try await investorGrossProfitService.getGrossProfit(
            for: investmentId,
            tradeId: tradeId
        )

        // Calculate commission from gross profit
        return calculateCommission(grossProfit: grossProfit, rate: commissionRate)
    }

    func calculateTotalCommissionForTrade(
        tradeId: String,
        commissionRate: Double
    ) async throws -> Double {
        guard let investorGrossProfitService = investorGrossProfitService else {
            throw AppError.serviceError(.serviceUnavailable)
        }

        // Get gross profits for all investments in this trade
        // This method includes validation to ensure all investments are accounted for
        let grossProfits = try await investorGrossProfitService.getGrossProfitsForTrade(tradeId: tradeId)

        guard !grossProfits.isEmpty else {
            print("ℹ️ CommissionCalculationService: No investor gross profits found for trade \(tradeId) - returning 0")
            return 0.0
        }
        
        // Calculate total commission from all investor gross profits
        let totalCommission = grossProfits.values.reduce(0.0) { total, grossProfit in
            total + calculateCommission(grossProfit: grossProfit, rate: commissionRate)
        }
        
        print("💰 CommissionCalculationService: Calculated total commission for trade \(tradeId)")
        print("   📊 Number of investments: \(grossProfits.count)")
        print("   💰 Total commission: €\(String(format: "%.2f", totalCommission))")
        
        return totalCommission
    }
}
