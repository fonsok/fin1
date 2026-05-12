import Foundation

// MARK: - Investment Completion Service Implementation
/// Handles investment completion checking, profit calculation, and cash distribution
/// Delegates to focused helper services for specific functionality
@MainActor
final class InvestmentCompletionService: InvestmentCompletionServiceProtocol {

    // MARK: - Dependencies
    private let poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    private let telemetryService: (any TelemetryServiceProtocol)?
    private let investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    private let tradeLifecycleService: (any TradeLifecycleServiceProtocol)?
    private let invoiceService: (any InvoiceServiceProtocol)?
    private let transactionIdService: (any TransactionIdServiceProtocol)?
    private let userService: (any UserServiceProtocol)?
    private let documentService: (any DocumentServiceProtocol)?
    private let configurationService: any ConfigurationServiceProtocol
    private let settlementAPIService: (any SettlementAPIServiceProtocol)?

    // MARK: - Initialization
    init(
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        telemetryService: (any TelemetryServiceProtocol)? = nil,
        investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)? = nil,
        tradeLifecycleService: (any TradeLifecycleServiceProtocol)? = nil,
        invoiceService: (any InvoiceServiceProtocol)? = nil,
        transactionIdService: (any TransactionIdServiceProtocol)? = nil,
        userService: (any UserServiceProtocol)? = nil,
        documentService: (any DocumentServiceProtocol)? = nil,
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) {
        self.poolTradeParticipationService = poolTradeParticipationService
        self.telemetryService = telemetryService
        self.investorCashBalanceService = investorCashBalanceService
        self.tradeLifecycleService = tradeLifecycleService
        self.invoiceService = invoiceService
        self.transactionIdService = transactionIdService
        self.userService = userService
        self.documentService = documentService
        self.configurationService = configurationService
        self.settlementAPIService = settlementAPIService
    }

    // MARK: - Investment Completion Checking

    func checkAndUpdateInvestmentCompletion(
        in investments: [Investment],
        specificInvestmentIds: [String]? = nil
    ) -> [Investment] {
        let investmentsToCheck = filterInvestmentsToCheck(investments, specificInvestmentIds: specificInvestmentIds)
        var updatedInvestments: [Investment] = []

        for investment in investmentsToCheck {
            guard investment.status == .active else {
                print("   ⏭️ Investment \(investment.id): status=\(investment.status.rawValue), skipping")
                continue
            }

            if let updatedInvestment = checkAndMarkCompletion(for: investment) {
                updatedInvestments.append(updatedInvestment)
            }
        }

        logCompletionResults(updatedInvestments: updatedInvestments)
        return updatedInvestments
    }

    // MARK: - Profit Updates

    func updateInvestmentProfitsFromTrades(in investments: [Investment]) -> [Investment] {
        guard let poolTradeParticipationService = poolTradeParticipationService else {
            print("⚠️ InvestmentCompletionService.updateInvestmentProfitsFromTrades: poolTradeParticipationService is nil")
            return []
        }

        var updatedInvestments: [Investment] = []

        for investment in investments {
            if let updatedInvestment = updateProfitForInvestment(
                investment,
                poolTradeParticipationService: poolTradeParticipationService
            ) {
                updatedInvestments.append(updatedInvestment)
            }
        }

        if !updatedInvestments.isEmpty {
            print("✅ InvestmentCompletionService: Updated \(updatedInvestments.count) investment profits from trades")
        }

        return updatedInvestments
    }

    // MARK: - Cash Distribution

    func distributeInvestmentCompletionCash(
        investment: Investment,
        investmentReservation: InvestmentReservation
    ) async {
        guard let investorCashBalanceService = investorCashBalanceService else {
            print("⚠️ InvestmentCompletionService.distributeInvestmentCompletionCash: investorCashBalanceService is nil")
            return
        }

        await InvestmentCashDistributor.distributeCash(
            investment: investment,
            investmentReservation: investmentReservation,
            investorCashBalanceService: investorCashBalanceService,
            poolTradeParticipationService: poolTradeParticipationService,
            tradeLifecycleService: tradeLifecycleService,
            invoiceService: invoiceService,
            configurationService: configurationService,
            settlementAPIService: settlementAPIService
        )
    }

    // MARK: - Private Helpers

    private func filterInvestmentsToCheck(
        _ investments: [Investment],
        specificInvestmentIds: [String]?
    ) -> [Investment] {
        if let specificIds = specificInvestmentIds {
            let filtered = investments.filter { specificIds.contains($0.id) }
            print("🔍 InvestmentCompletionService: Checking \(filtered.count) specific investments (out of \(investments.count) total)")
            return filtered
        } else {
            print("🔍 InvestmentCompletionService: Checking \(investments.count) investments")
            return investments
        }
    }

    private func checkAndMarkCompletion(for investment: Investment) -> Investment? {
        print("   🔍 Investment \(investment.id): checking reservation status")
        print("      Reservation Status: \(investment.reservationStatus.rawValue)")

        guard investment.reservationStatus == .completed else {
            return nil
        }

        // Verify investment participated in trades
        guard verifyTradeParticipation(for: investment) else {
            print("   ⚠️ Investment \(investment.id): pool status is completed but has no trade participations - skipping")
            return nil
        }

        // Calculate profits
        let (accumulatedProfit, calculatedReturn) = calculateProfits(for: investment)

        let updatedInvestment = investment.markAsCompleted(
            calculatedProfit: accumulatedProfit,
            calculatedReturn: calculatedReturn
        )

        logCompletionDetails(
            original: investment,
            updated: updatedInvestment,
            accumulatedProfit: accumulatedProfit,
            calculatedReturn: calculatedReturn
        )

        telemetryService?.trackEvent(name: "investment_status_updated", properties: [
            "investment_id": investment.id,
            "new_status": updatedInvestment.status.rawValue,
            "accumulated_profit": accumulatedProfit
        ])

        return updatedInvestment
    }

    private func verifyTradeParticipation(for investment: Investment) -> Bool {
        guard let poolTradeParticipationService = poolTradeParticipationService else {
            return true // Fallback: assume valid
        }

        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)
        print("   📊 Investment \(investment.id): has \(participations.count) trade participations")
        return !participations.isEmpty
    }

    private func calculateProfits(for investment: Investment) -> (profit: Double, return: Double) {
        guard let poolTradeParticipationService = poolTradeParticipationService else {
            // Fallback calculation
            let baseReturnRate = 0.05
            return (investment.amount * baseReturnRate, baseReturnRate)
        }

        let accumulatedProfit = poolTradeParticipationService.getAccumulatedProfit(for: investment.id)
        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)

        // Use trade's ROI directly - same for trader and all investors
        // This ensures consistency: if trade returns 100%, all participants see 100%
        let calculatedReturn: Double
        if let tradeLifecycleService = tradeLifecycleService,
           let tradeROI = InvestmentProfitCalculator.getTradeROI(
               for: participations,
               tradeLifecycleService: tradeLifecycleService
           ) {
            // Trade ROI is already in percent format (e.g., 42.04)
            calculatedReturn = tradeROI
        } else {
            // Keep persisted value if trade ROI is temporarily unavailable.
            // This avoids introducing a second competing formula.
            calculatedReturn = investment.performance
        }

        print("💰 InvestmentCompletionService: Profit calculation")
        print("   📊 Accumulated profit (net): €\(String(format: "%.2f", accumulatedProfit))")
        print("   📊 Investment capital: €\(String(format: "%.2f", investment.amount))")
        print("   📈 Return (trade-led): \(String(format: "%.2f", calculatedReturn))%")

        return (accumulatedProfit, calculatedReturn)
    }

    private func updateProfitForInvestment(
        _ investment: Investment,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    ) -> Investment? {
        let accumulatedProfit = poolTradeParticipationService.getAccumulatedProfit(for: investment.id)
        let newCurrentValue = investment.amount + accumulatedProfit

        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)

        // Use trade's ROI directly - same for trader and all investors
        // This ensures consistency: if trade returns 100%, all participants see 100%
        let returnPercentage: Double
        if let tradeLifecycleService = tradeLifecycleService,
           let tradeROI = InvestmentProfitCalculator.getTradeROI(
               for: participations,
               tradeLifecycleService: tradeLifecycleService
           ) {
            // Trade ROI is already in percent format (e.g., 42.04)
            returnPercentage = tradeROI
        } else {
            // Keep persisted value if trade ROI is temporarily unavailable.
            // This avoids introducing a second competing formula.
            returnPercentage = investment.performance
        }

        // Only update if values have changed
        guard abs(investment.currentValue - newCurrentValue) > 0.01 ||
              abs(investment.performance - returnPercentage) > 0.01 else {
            return nil
        }

        let updatedInvestment = Investment(
            id: investment.id,
            investmentNumber: investment.investmentNumber,
            batchId: investment.batchId,
            investorId: investment.investorId,
            investorName: investment.investorName,
            traderId: investment.traderId,
            traderName: investment.traderName,
            amount: investment.amount,
            currentValue: newCurrentValue,
            date: investment.date,
            status: investment.status,
            performance: returnPercentage,
            numberOfTrades: investment.numberOfTrades,
            sequenceNumber: investment.sequenceNumber,
            createdAt: investment.createdAt,
            updatedAt: Date(),
            completedAt: investment.completedAt,
            specialization: investment.specialization,
            reservationStatus: investment.reservationStatus,
            partialSellCount: investment.partialSellCount,
            realizedSellQuantity: investment.realizedSellQuantity,
            realizedSellAmount: investment.realizedSellAmount,
            lastPartialSellAt: investment.lastPartialSellAt,
            tradeSellVolumeProgress: investment.tradeSellVolumeProgress
        )

        print("💰 InvestmentCompletionService: Updated investment \(investment.id) with profit")
        print("   📊 Accumulated profit: €\(String(format: "%.2f", accumulatedProfit))")
        print("   💵 New currentValue: €\(String(format: "%.2f", newCurrentValue))")
        print("   📈 New performance: \(String(format: "%.2f", returnPercentage))%")

        return updatedInvestment
    }

    private func logCompletionDetails(
        original: Investment,
        updated: Investment,
        accumulatedProfit: Double,
        calculatedReturn: Double
    ) {
        print("✅ InvestmentCompletionService: Investment \(original.id) marked as completed")
        print("   📊 Investment status: \(original.status.rawValue) -> \(updated.status.rawValue)")
        print("   📊 Investment completedAt: \(updated.completedAt?.description ?? "nil")")
        print("   💰 Calculated profit: €\(String(format: "%.2f", accumulatedProfit))")
        print("   📈 Calculated return: \(String(format: "%.2f", calculatedReturn))%")
        print("   💵 New currentValue: €\(String(format: "%.2f", updated.currentValue))")
    }

    private func logCompletionResults(updatedInvestments: [Investment]) {
        if !updatedInvestments.isEmpty {
            print("   📡 InvestmentCompletionService: Updated \(updatedInvestments.count) investments")
        } else {
            print("   ℹ️ No investments needed to be marked as completed")
        }
    }
}
