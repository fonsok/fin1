import Foundation

// MARK: - Investment Cash Distributor

/// Handles cash distribution when an investment completes
/// Distributes: Net Sell Amount (credit), Commission (debit), and Residual Amount (credit)
enum InvestmentCashDistributor {

    // MARK: - Duplicate Prevention

    /// Resets the distribution tracking (for testing or if needed)
    static func resetDistributionTracking() async {
        await distributionState.reset()
        print("🔄 InvestmentCashDistributor: Distribution tracking reset")
    }

    // MARK: - Public Methods

    /// Distributes cash for a completed investment
    /// - Parameters:
    ///   - investment: The completed investment
    ///   - investmentReservation: The investment reservation
    ///   - investorCashBalanceService: Service to update investor cash balance
    ///   - poolTradeParticipationService: Service to get trade participations
    ///   - tradeLifecycleService: Service to get trade data
    ///   - invoiceService: Service to get invoices
    ///   - configurationService: Service to get commission rate
    @MainActor
    static func distributeCash(
        investment: Investment,
        investmentReservation: InvestmentReservation,
        investorCashBalanceService: any InvestorCashBalanceServiceProtocol,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?,
        tradeLifecycleService: (any TradeLifecycleServiceProtocol)?,
        invoiceService: (any InvoiceServiceProtocol)?,
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) async {
        let isNew = await distributionState.insertIfNew(investment.id)
        if !isNew {
            print("⚠️ InvestmentCashDistributor: Cash already distributed for investment \(investment.id) - skipping")
            return
        }

        print("💰 InvestmentCashDistributor: Starting cash distribution for investment \(investment.id)")

        let commissionRate = configurationService.effectiveCommissionRate

        // Phase 3: Try backend-authoritative amounts first
        let amounts: DistributionAmounts
        if let backendAmounts = await fetchBackendAmounts(
            investment: investment,
            commissionRate: commissionRate,
            settlementAPIService: settlementAPIService
        ) {
            print("✅ InvestmentCashDistributor: Using backend-authoritative amounts")
            amounts = backendAmounts
        } else {
            amounts = calculateDistributionAmounts(
                investment: investment,
                investmentReservation: investmentReservation,
                poolTradeParticipationService: poolTradeParticipationService,
                tradeLifecycleService: tradeLifecycleService,
                invoiceService: invoiceService,
                commissionRate: commissionRate
            )
        }

        if amounts.netSellAmount > 0 {
            await investorCashBalanceService.processProfitDistribution(
                investorId: investment.investorId,
                profitAmount: amounts.netSellAmount,
                investmentId: investment.id
            )
        }

        if amounts.commissionAmount > 0 {
            let commissionDetails = CommissionDeductionDetails(
                investmentSequenceNumber: investment.sequenceNumber,
                traderName: investment.traderName,
                tradeNumbers: amounts.tradeNumbers,
                grossProfit: amounts.grossProfit,
                commissionRate: commissionRate
            )
            await investorCashBalanceService.processCommissionDeduction(
                investorId: investment.investorId,
                commissionAmount: amounts.commissionAmount,
                investmentId: investment.id,
                details: commissionDetails
            )
        }

        if amounts.residualAmount > 0 {
            await investorCashBalanceService.processRemainingBalanceDistribution(
                investorId: investment.investorId,
                amount: amounts.residualAmount,
                investmentId: investment.id
            )
        }

        logDistribution(investment: investment, investmentReservation: investmentReservation, amounts: amounts)
    }

    // MARK: - Private Types

    private struct DistributionAmounts {
        let netSellAmount: Double
        let commissionAmount: Double
        let grossProfit: Double
        let tradeNumbers: [String]
        let residualAmount: Double // Leftover amount after rounding quantities to whole numbers
    }

    // MARK: - Backend Integration

    /// Fetches distribution amounts from backend AccountStatement entries for the investment.
    /// Returns nil if the backend has no data or the call fails (triggering local fallback).
    private static func fetchBackendAmounts(
        investment: Investment,
        commissionRate: Double,
        settlementAPIService: (any SettlementAPIServiceProtocol)?
    ) async -> DistributionAmounts? {
        guard let api = settlementAPIService else { return nil }
        do {
            let response = try await api.fetchAccountStatement(limit: 200, skip: 0, entryType: nil)
            let investmentEntries = response.entries.filter { $0.investmentId == investment.id }
            guard !investmentEntries.isEmpty else { return nil }

            var netSell: Double = 0
            var commission: Double = 0
            var grossProfit: Double = 0
            var residual: Double = 0
            var tradeNumbers: [String] = []

            for entry in investmentEntries {
                switch entry.entryType {
                case "sell_proceeds", "profit_distribution":
                    netSell += entry.amount
                case "commission_debit":
                    commission += abs(entry.amount)
                case "residual_return":
                    residual += entry.amount
                default:
                    break
                }
                if let tn = entry.tradeNumber, !tradeNumbers.contains(String(format: "%03d", tn)) {
                    tradeNumbers.append(String(format: "%03d", tn))
                }
            }

            // Gross profit = net sell + commission (commission was deducted from gross)
            grossProfit = netSell + commission

            return DistributionAmounts(
                netSellAmount: netSell,
                commissionAmount: commission,
                grossProfit: grossProfit,
                tradeNumbers: tradeNumbers,
                residualAmount: residual
            )
        } catch {
            print("⚠️ InvestmentCashDistributor: Backend fetch failed — using local fallback: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private Helpers

    @MainActor
    private static func calculateDistributionAmounts(
        investment: Investment,
        investmentReservation: InvestmentReservation,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?,
        tradeLifecycleService: (any TradeLifecycleServiceProtocol)?,
        invoiceService: (any InvoiceServiceProtocol)?,
        commissionRate: Double
    ) -> DistributionAmounts {

        // Initialize residual amount
        var residualAmount: Double = 0.0

        // Guard against nil services
        guard let potTradeService = poolTradeParticipationService,
              let tradeService = tradeLifecycleService,
              let invoiceSvc = invoiceService else {
            print("⚠️ InvestmentCashDistributor: Missing required services for investment \(investment.id)")
            return DistributionAmounts(
                netSellAmount: 0,
                commissionAmount: 0,
                grossProfit: 0,
                tradeNumbers: [],
                residualAmount: 0
            )
        }

        // Get statement summary from aggregator
        guard let summary = InvestorInvestmentStatementAggregator.summarizeInvestment(
            investmentId: investment.id,
            poolTradeParticipationService: potTradeService,
            tradeLifecycleService: tradeService,
            invoiceService: invoiceSvc,
            commissionCalculationService: nil,
            investment: investment,
            commissionRate: commissionRate
        ) else {
            print("⚠️ InvestmentCashDistributor: Could not get statement summary for investment \(investment.id)")
            return DistributionAmounts(
                netSellAmount: 0,
                commissionAmount: 0,
                grossProfit: 0,
                tradeNumbers: [],
                residualAmount: 0
            )
        }

        // Get residual amount from the statement summary
        residualAmount = summary.statementResidualAmount

        // Debug logging to verify residual amount
        print("💰 InvestmentCashDistributor: Retrieved residual amount from summary")
        print("   💵 Residual Amount: €\(String(format: "%.2f", residualAmount))")
        print("   💵 Investment Capital: €\(String(format: "%.2f", investment.amount))")
        print("   💵 Total Buy Cost: €\(String(format: "%.2f", summary.statementTotalBuyCost))")
        print("   💵 Expected Residual: €\(String(format: "%.2f", investment.amount - summary.statementTotalBuyCost))")

        // Net Sell Amount = Total Sell Value - Total Sell Fees (already calculated in summary)
        let netSellAmount = summary.statementNetSellAmount

        // Use statement gross profit
        let grossProfit = summary.statementGrossProfit

        // Commission is based on gross profit (only if profit > 0)
        let commissionAmount = grossProfit > 0 ? grossProfit * commissionRate : 0.0

        // Get trade numbers for commission details
        let tradeNumbers = summary.items.map { String(format: "%03d", $0.tradeNumber) }

        return DistributionAmounts(
            netSellAmount: netSellAmount,
            commissionAmount: commissionAmount,
            grossProfit: grossProfit,
            tradeNumbers: tradeNumbers,
            residualAmount: residualAmount
        )
    }

    private static func logDistribution(
        investment: Investment,
        investmentReservation: InvestmentReservation,
        amounts: DistributionAmounts
    ) {
        print("💰 InvestmentCashDistributor: Distributing cash for investment \(investment.id)")
        print("   📊 Net Sell Amount: €\(String(format: "%.2f", amounts.netSellAmount))")
        print("   📊 Gross Profit: €\(String(format: "%.2f", amounts.grossProfit))")
        print("   📊 Commission: €\(String(format: "%.2f", amounts.commissionAmount))")
        print("   📊 Residual Amount: €\(String(format: "%.2f", amounts.residualAmount))")
        print("   📊 Trade Numbers: \(amounts.tradeNumbers.joined(separator: ", "))")
    }
}

private actor DistributionState {
    private var ids = Set<String>()
    func insertIfNew(_ id: String) -> Bool {
        let existed = ids.contains(id)
        if !existed { ids.insert(id) }
        return !existed
    }
    func reset() { ids.removeAll() }
}

private let distributionState = DistributionState()
