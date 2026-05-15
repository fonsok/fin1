import Foundation

extension InvestmentCompletionService {
    // MARK: - Helpers

    func filterInvestmentsToCheck(
        _ investments: [Investment],
        specificInvestmentIds: [String]?
    ) -> [Investment] {
        if let specificIds = specificInvestmentIds {
            let filtered = investments.filter { specificIds.contains($0.id) }
            print("🔍 InvestmentCompletionService: Checking \(filtered.count) specific investments (out of \(investments.count) total)")
            return filtered
        }
        print("🔍 InvestmentCompletionService: Checking \(investments.count) investments")
        return investments
    }

    func checkAndMarkCompletion(for investment: Investment) -> Investment? {
        print("   🔍 Investment \(investment.id): checking reservation status")
        print("      Reservation Status: \(investment.reservationStatus.rawValue)")

        guard investment.reservationStatus == .completed else {
            return nil
        }

        guard self.verifyTradeParticipation(for: investment) else {
            print("   ⚠️ Investment \(investment.id): pool status is completed but has no trade participations - skipping")
            return nil
        }

        let (accumulatedProfit, calculatedReturn) = self.calculateProfits(for: investment)

        let updatedInvestment = investment.markAsCompleted(
            calculatedProfit: accumulatedProfit,
            calculatedReturn: calculatedReturn
        )

        self.logCompletionDetails(
            original: investment,
            updated: updatedInvestment,
            accumulatedProfit: accumulatedProfit,
            calculatedReturn: calculatedReturn
        )

        self.telemetryService?.trackEvent(name: "investment_status_updated", properties: [
            "investment_id": investment.id,
            "new_status": updatedInvestment.status.rawValue,
            "accumulated_profit": accumulatedProfit
        ])

        return updatedInvestment
    }

    func verifyTradeParticipation(for investment: Investment) -> Bool {
        guard let poolTradeParticipationService = poolTradeParticipationService else {
            return true
        }

        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)
        print("   📊 Investment \(investment.id): has \(participations.count) trade participations")
        return !participations.isEmpty
    }

    func calculateProfits(for investment: Investment) -> (profit: Double, return: Double) {
        guard let poolTradeParticipationService = poolTradeParticipationService else {
            let baseReturnRate = 0.05
            return (investment.amount * baseReturnRate, baseReturnRate)
        }

        let accumulatedProfit = poolTradeParticipationService.getAccumulatedProfit(for: investment.id)
        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)

        let calculatedReturn: Double
        if let tradeLifecycleService = tradeLifecycleService,
           let tradeROI = InvestmentProfitCalculator.getTradeROI(
               for: participations,
               tradeLifecycleService: tradeLifecycleService
           ) {
            calculatedReturn = tradeROI
        } else {
            calculatedReturn = investment.performance
        }

        print("💰 InvestmentCompletionService: Profit calculation")
        print("   📊 Accumulated profit (net): €\(String(format: "%.2f", accumulatedProfit))")
        print("   📊 Investment capital: €\(String(format: "%.2f", investment.amount))")
        print("   📈 Return (trade-led): \(String(format: "%.2f", calculatedReturn))%")

        return (accumulatedProfit, calculatedReturn)
    }

    func updateProfitForInvestment(
        _ investment: Investment,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    ) -> Investment? {
        let accumulatedProfit = poolTradeParticipationService.getAccumulatedProfit(for: investment.id)
        let newCurrentValue = investment.amount + accumulatedProfit

        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)

        let returnPercentage: Double
        if let tradeLifecycleService = tradeLifecycleService,
           let tradeROI = InvestmentProfitCalculator.getTradeROI(
               for: participations,
               tradeLifecycleService: tradeLifecycleService
           ) {
            returnPercentage = tradeROI
        } else {
            returnPercentage = investment.performance
        }

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

    func logCompletionDetails(
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

    func logCompletionResults(updatedInvestments: [Investment]) {
        if !updatedInvestments.isEmpty {
            print("   📡 InvestmentCompletionService: Updated \(updatedInvestments.count) investments")
        } else {
            print("   ℹ️ No investments needed to be marked as completed")
        }
    }
}
