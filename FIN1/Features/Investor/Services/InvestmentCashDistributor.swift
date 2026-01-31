import Foundation

// MARK: - Investment Cash Distributor

/// Handles cash distribution when an investment completes
/// Distributes: Net Sell Amount (credit), Commission (debit), and Residual Amount (credit)
enum InvestmentCashDistributor {

    // MARK: - Duplicate Prevention

    /// Tracks which investments have already had cash distributed to prevent double-booking
    private static var distributedInvestments: Set<String> = []
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
    static func distributeCash(
        investment: Investment,
        investmentReservation: InvestmentReservation,
        investorCashBalanceService: any InvestorCashBalanceServiceProtocol,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?,
        tradeLifecycleService: (any TradeLifecycleServiceProtocol)?,
        invoiceService: (any InvoiceServiceProtocol)?,
        configurationService: (any ConfigurationServiceProtocol)?
    ) async {
        // CRITICAL: Prevent duplicate distribution for the same investment (async-safe)
        let isNew = await distributionState.insertIfNew(investment.id)
        if !isNew {
            print("⚠️ InvestmentCashDistributor: Cash already distributed for investment \(investment.id) - skipping to prevent double-booking")
            return
        }

        print("💰 InvestmentCashDistributor: Starting cash distribution for investment \(investment.id)")

        // Get commission rate from admin configuration
        let commissionRate = configurationService?.effectiveCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate

        // Calculate amounts
        let amounts = calculateDistributionAmounts(
            investment: investment,
            investmentReservation: investmentReservation,
            poolTradeParticipationService: poolTradeParticipationService,
            tradeLifecycleService: tradeLifecycleService,
            invoiceService: invoiceService,
            commissionRate: commissionRate
        )

        // 1. Post Net Sell Amount as deposit (only if > 0)
        if amounts.netSellAmount > 0 {
            await investorCashBalanceService.processProfitDistribution(
                investorId: investment.investorId,
                profitAmount: amounts.netSellAmount,
                investmentId: investment.id
            )
        }

        // 2. Post Commission as withdrawal (debit)
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

        // 3. Return residual amount to investor's cash balance (leftover after rounding quantities to whole numbers)
        // CRITICAL: Residual occurs when rounding down to whole units leaves unused capital
        // Example: Investment €3,000, buy price €2.51 → quantity 1,187 units → actual cost €2,999.37 → residual €0.63
        if amounts.residualAmount > 0 {
            await investorCashBalanceService.processRemainingBalanceDistribution(
                investorId: investment.investorId,
                amount: amounts.residualAmount,
                investmentId: investment.id
            )
        }

        logDistribution(
            investment: investment,
            investmentReservation: investmentReservation,
            amounts: amounts
        )
    }

    // MARK: - Private Types

    private struct DistributionAmounts {
        let netSellAmount: Double
        let commissionAmount: Double
        let grossProfit: Double
        let tradeNumbers: [String]
        let residualAmount: Double // Leftover amount after rounding quantities to whole numbers
    }

    // MARK: - Private Helpers

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
            commissionCalculationService: nil,  // Use default
            investment: investment
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
