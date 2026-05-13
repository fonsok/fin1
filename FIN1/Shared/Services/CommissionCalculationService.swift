import Foundation

// MARK: - Commission Calculation Service Protocol

/// Centralized service for all commission calculations
/// Provides a single source of truth for commission calculation logic
protocol CommissionCalculationServiceProtocol: ServiceLifecycle, Sendable {
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

final class CommissionCalculationService: CommissionCalculationServiceProtocol, @unchecked Sendable {

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
        let commission = self.calculateCommission(grossProfit: grossProfit, rate: rate)
        return grossProfit - commission
    }

    func calculateCommissionAndNetProfit(grossProfit: Double, rate: Double) -> (commission: Double, netProfit: Double) {
        let commission = self.calculateCommission(grossProfit: grossProfit, rate: rate)
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
        return self.calculateCommission(grossProfit: grossProfit, rate: commissionRate)
    }

    func calculateTotalCommissionForTrade(
        tradeId: String,
        commissionRate: Double
    ) async throws -> Double {
        // Backend-authoritative.
        //
        // `getAccountStatement` is per-user (filters on the logged-in user's
        // stableId), so:
        //   * The TRADER sees their own `commission_credit` (= total
        //     commission they earned on the trade — the canonical answer
        //     for the "Abgeschlossene Trades" → Commission column).
        //   * INVESTORS see their own `commission_debit` (the part they
        //     paid). Summing across investors only works for an admin /
        //     master-key view, which this client-call does not have.
        // Try the trader path first (commission_credit on the current user
        // for this trade); fall back to commission_debit for investor
        // contexts; finally fall back to local estimation.
        if let api = settlementAPIService {
            do {
                let creditResponse = try await api.fetchAccountStatement(limit: 200, skip: 0, entryType: "commission_credit")
                let allTradeIds = creditResponse.entries.compactMap { $0.tradeId }
                NSLog("🧮 CommissionCalc[trade=\(tradeId)] credit fetched count=\(creditResponse.entries.count) tradeIds=\(allTradeIds)")
                let creditEntries = creditResponse.entries.filter { $0.tradeId == tradeId }
                NSLog("🧮 CommissionCalc[trade=\(tradeId)] credit matched=\(creditEntries.count)")
                if !creditEntries.isEmpty {
                    let total = creditEntries.reduce(0.0) { $0 + abs($1.amount) }
                    NSLog("🧮 CommissionCalc[trade=\(tradeId)] credit total=\(total)")
                    return total
                }
            } catch {
                NSLog("⚠️ CommissionCalc[trade=\(tradeId)] commission_credit failed: \(error.localizedDescription)")
            }

            do {
                let debitResponse = try await api.fetchAccountStatement(limit: 200, skip: 0, entryType: "commission_debit")
                let allTradeIds = debitResponse.entries.compactMap { $0.tradeId }
                NSLog("🧮 CommissionCalc[trade=\(tradeId)] debit fetched count=\(debitResponse.entries.count) tradeIds=\(allTradeIds)")
                let debitEntries = debitResponse.entries.filter { $0.tradeId == tradeId }
                NSLog("🧮 CommissionCalc[trade=\(tradeId)] debit matched=\(debitEntries.count)")
                if !debitEntries.isEmpty {
                    let total = debitEntries.reduce(0.0) { $0 + abs($1.amount) }
                    NSLog("🧮 CommissionCalc[trade=\(tradeId)] debit total=\(total)")
                    return total
                }
            } catch {
                NSLog("⚠️ CommissionCalc[trade=\(tradeId)] commission_debit failed: \(error.localizedDescription)")
            }
        } else {
            NSLog("⚠️ CommissionCalc[trade=\(tradeId)] settlementAPIService is nil")
        }

        // Fallback: local estimation
        guard let investorGrossProfitService else {
            throw AppError.serviceError(.serviceUnavailable)
        }
        let grossProfits = try await investorGrossProfitService.getGrossProfitsForTrade(tradeId: tradeId)
        guard !grossProfits.isEmpty else { return 0.0 }
        return grossProfits.values.reduce(0.0) { $0 + self.calculateCommission(grossProfit: $1, rate: commissionRate) }
    }
}
