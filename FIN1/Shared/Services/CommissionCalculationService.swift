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
    private var settlementAPIService: (any SettlementAPIServiceProtocol)?

    // MARK: - Initialization
    init(
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)? = nil,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) {
        self.investorGrossProfitService = investorGrossProfitService
        self.settlementAPIService = settlementAPIService
    }

    /// Late-binding for settlement API (avoids circular init)
    func configure(settlementAPIService: any SettlementAPIServiceProtocol) {
        self.settlementAPIService = settlementAPIService
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
    //
    // Phase 3: These methods try backend AccountStatement first. The backend
    // `settleCompletedTrade` already recorded `commission_debit` entries per
    // investor.  If the backend is unreachable, we fall back to the local
    // InvestorGrossProfitService path (labelled "estimate/fallback").

    func calculateCommissionForInvestor(
        investmentId: String,
        tradeId: String,
        commissionRate: Double
    ) async throws -> Double {
        // Backend-authoritative: read commission_debit entry
        if let api = settlementAPIService {
            do {
                let response = try await api.fetchAccountStatement(limit: 50, skip: 0, entryType: "commission_debit")
                if let entry = response.entries.first(where: { $0.tradeId == tradeId && $0.investmentId == investmentId }) {
                    let amount = abs(entry.amount)
                    return amount
                }
            } catch {
                print("⚠️ CommissionCalculationService: Backend fetch failed, falling back to local: \(error.localizedDescription)")
            }
        }

        // Fallback: local estimation
        guard let investorGrossProfitService else {
            throw AppError.serviceError(.serviceUnavailable)
        }
        let grossProfit = try await investorGrossProfitService.getGrossProfit(for: investmentId, tradeId: tradeId)
        return calculateCommission(grossProfit: grossProfit, rate: commissionRate)
    }

    func calculateTotalCommissionForTrade(
        tradeId: String,
        commissionRate: Double
    ) async throws -> Double {
        // Backend-authoritative: sum all commission_debit entries for this trade
        if let api = settlementAPIService {
            do {
                let response = try await api.fetchAccountStatement(limit: 200, skip: 0, entryType: "commission_debit")
                let tradeEntries = response.entries.filter { $0.tradeId == tradeId }
                if !tradeEntries.isEmpty {
                    let total = tradeEntries.reduce(0.0) { $0 + abs($1.amount) }
                    return total
                }
            } catch {
                print("⚠️ CommissionCalculationService: Backend fetch failed, falling back to local: \(error.localizedDescription)")
            }
        }

        // Fallback: local estimation
        guard let investorGrossProfitService else {
            throw AppError.serviceError(.serviceUnavailable)
        }
        let grossProfits = try await investorGrossProfitService.getGrossProfitsForTrade(tradeId: tradeId)
        guard !grossProfits.isEmpty else { return 0.0 }
        return grossProfits.values.reduce(0.0) { $0 + calculateCommission(grossProfit: $1, rate: commissionRate) }
    }
}
