import Foundation

// MARK: - Investment Profit Calculator
/// Calculates profits for investments from trade participations
/// Provides both gross profit calculation and investor totals computation
struct InvestmentProfitCalculator {

    // MARK: - Investor Totals

    /// Calculates investor totals (gross profit and invested amount) for participations
    /// Uses the calculation service to properly compute buy amounts from investment capital
    /// - Parameters:
    ///   - participations: Trade participations for the investment
    ///   - invoiceService: Service providing invoice data
    ///   - tradeLifecycleService: Service providing completed trades
    ///   - investmentCapital: The investor's total investment amount (source of truth)
    ///   - calculationService: Service for proper fee calculations
    /// - Returns: Tuple of (grossProfit, investedAmount) or nil if calculation fails
    @MainActor
    static func calculateInvestorTotalsWithBackend(
        for participations: [PoolTradeParticipation],
        invoiceService: any InvoiceServiceProtocol,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        investmentId: String?,
        investmentCapital: Double? = nil,
        calculationService: (any InvestorCollectionBillCalculationServiceProtocol)? = nil,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) async -> (grossProfit: Double, investedAmount: Double)? {
        guard !participations.isEmpty else { return nil }

        var totalGross = 0.0
        var totalInvested = 0.0
        let trades = tradeLifecycleService.completedTrades
        let calcService = calculationService ?? InvestorCollectionBillCalculationService()

        for participation in participations {
            guard let trade = trades.first(where: { $0.id == participation.tradeId }) else { continue }
            let invoices = invoiceService.getInvoicesForTrade(trade.id)
            let buyInvoice = invoices.first { $0.transactionType == .buy }
            let sellInvoices = invoices.filter { $0.transactionType == .sell }

            let tradeCapitalShare: Double
            if let capital = investmentCapital {
                if participations.count == 1 {
                    tradeCapitalShare = capital
                } else {
                    let totalOwnership = participations.reduce(0.0) { $0 + $1.ownershipPercentage }
                    tradeCapitalShare = totalOwnership > 0
                        ? (capital * participation.ownershipPercentage / totalOwnership)
                        : (capital / Double(participations.count))
                }
            } else {
                tradeCapitalShare = participation.allocatedAmount
            }

            let input = InvestorCollectionBillInput(
                investmentCapital: tradeCapitalShare,
                buyPrice: trade.entryPrice,
                tradeTotalQuantity: trade.totalQuantity,
                ownershipPercentage: participation.ownershipPercentage,
                buyInvoice: buyInvoice,
                sellInvoices: sellInvoices,
                investorAllocatedAmount: participation.allocatedAmount
            )

            do {
                let output = try await calcService.calculateCollectionBillWithBackend(
                    input: input,
                    settlementAPIService: settlementAPIService,
                    tradeId: trade.id,
                    investmentId: investmentId
                )
                totalGross += output.grossProfit
                let totalBuyCost = output.buyAmount + output.buyFees
                totalInvested += totalBuyCost
            } catch {
                if let output = try? calcService.calculateCollectionBill(input: input) {
                    totalGross += output.grossProfit
                    totalInvested += output.buyAmount + output.buyFees
                } else {
                    let investorProfit = ProfitCalculationService.calculateInvestorTaxableProfit(
                        buyInvoice: buyInvoice,
                        sellInvoices: sellInvoices,
                        ownershipPercentage: participation.ownershipPercentage
                    )
                    totalGross += investorProfit
                    if trade.totalSoldQuantity > 0 {
                        let investorDenominator = trade.buyOrder.price * Double(trade.totalSoldQuantity) * participation.ownershipPercentage
                        totalInvested += investorDenominator
                    }
                }
            }
        }

        guard totalInvested > 0 else { return nil }
        return (totalGross, totalInvested)
    }

    /// Sync version – uses local calculation only. Prefer `calculateInvestorTotalsWithBackend` when backend data is available.
    @MainActor
    static func calculateInvestorTotals(
        for participations: [PoolTradeParticipation],
        invoiceService: any InvoiceServiceProtocol,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        investmentCapital: Double? = nil,
        calculationService: (any InvestorCollectionBillCalculationServiceProtocol)? = nil
    ) -> (grossProfit: Double, investedAmount: Double)? {
        guard !participations.isEmpty else {
            return nil
        }

        var totalGross = 0.0
        var totalInvested = 0.0
        let trades = tradeLifecycleService.completedTrades
        let calcService = calculationService ?? InvestorCollectionBillCalculationService()

        for participation in participations {
            guard let trade = trades.first(where: { $0.id == participation.tradeId }) else { continue }
            let invoices = invoiceService.getInvoicesForTrade(trade.id)
            let buyInvoice = invoices.first { $0.transactionType == .buy }
            let sellInvoices = invoices.filter { $0.transactionType == .sell }

            // Calculate this trade's share of investment capital
            let tradeCapitalShare: Double
            if let capital = investmentCapital {
                if participations.count == 1 {
                    tradeCapitalShare = capital
                } else {
                    let totalOwnership = participations.reduce(0.0) { $0 + $1.ownershipPercentage }
                    tradeCapitalShare = totalOwnership > 0
                        ? (capital * participation.ownershipPercentage / totalOwnership)
                        : (capital / Double(participations.count))
                }
            } else {
                // Fallback: use allocated amount if investment capital not provided
                tradeCapitalShare = participation.allocatedAmount
            }

            // Use calculation service to get proper buy amount and profit
            let input = InvestorCollectionBillInput(
                investmentCapital: tradeCapitalShare,
                buyPrice: trade.entryPrice,
                tradeTotalQuantity: trade.totalQuantity,
                ownershipPercentage: participation.ownershipPercentage,
                buyInvoice: buyInvoice,
                sellInvoices: sellInvoices,
                investorAllocatedAmount: participation.allocatedAmount
            )

            do {
                let output = try calcService.calculateCollectionBill(input: input)
                totalGross += output.grossProfit
                // Use Total Buy Cost (buyAmount + buyFees) as denominator for return calculation
                // This is what was actually invested/deployed (accounting principle)
                let totalBuyCost = output.buyAmount + output.buyFees
                totalInvested += totalBuyCost

                print("💰 InvestmentProfitCalculator: Trade \(trade.tradeNumber)")
                print("   📊 Capital share: €\(String(format: "%.2f", tradeCapitalShare))")
                print("   📊 Total Buy Cost (base for ROI): €\(String(format: "%.2f", totalBuyCost))")
                print("   📊 Gross Profit: €\(String(format: "%.2f", output.grossProfit))")
            } catch {
                print("❌ InvestmentProfitCalculator: Calculation failed for trade \(trade.tradeNumber): \(error)")
                // Fallback to legacy calculation
                let investorProfit = ProfitCalculationService.calculateInvestorTaxableProfit(
                    buyInvoice: buyInvoice,
                    sellInvoices: sellInvoices,
                    ownershipPercentage: participation.ownershipPercentage
                )
                totalGross += investorProfit

                // Legacy denominator (scaled from trader) - only as fallback
                if trade.totalSoldQuantity > 0 {
                    let traderDenominator = trade.buyOrder.price * Double(trade.totalSoldQuantity)
                    let investorDenominator = traderDenominator * participation.ownershipPercentage
                    totalInvested += investorDenominator
                }
            }
        }

        guard totalInvested > 0 else {
            return nil
        }

        return (totalGross, totalInvested)
    }

    // MARK: - Trade ROI

    /// Returns the trade's ROI for single-trade investments, or weighted average for multi-trade
    /// This ensures investor sees the same return % as the trader for the same trade
    /// - Parameters:
    ///   - participations: Trade participations for the investment
    ///   - tradeLifecycleService: Service providing completed trades
    /// - Returns: The trade's ROI percentage, or nil if no trades found
    static func getTradeROI(
        for participations: [PoolTradeParticipation],
        tradeLifecycleService: any TradeLifecycleServiceProtocol
    ) -> Double? {
        guard !participations.isEmpty else { return nil }

        let trades = tradeLifecycleService.completedTrades
        var weightedROI = 0.0
        var totalWeight = 0.0

        for participation in participations {
            guard let trade = trades.first(where: { $0.id == participation.tradeId }) else { continue }

            // Use the trade's displayed ROI
            let tradeROI = trade.displayROI
            let weight = participation.ownershipPercentage

            weightedROI += tradeROI * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }

        // For single trade, this returns the trade's exact ROI
        // For multiple trades, this returns weighted average
        return weightedROI / totalWeight
    }

    // MARK: - Gross Profit from Trades

    /// Calculates gross profit from actual trade data
    /// This matches how trader calculates gross profit
    /// - Parameters:
    ///   - investmentId: ID of the investment
    ///   - participations: Trade participations for the investment
    ///   - tradeLifecycleService: Service providing completed trades
    ///   - potTradeParticipationService: Fallback service for accumulated profit
    /// - Returns: Gross profit amount
    static func calculateGrossProfitFromTrades(
        for investmentId: String,
        participations: [PoolTradeParticipation],
        tradeLifecycleService: (any TradeLifecycleServiceProtocol)?,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?,
        commissionRate: Double
    ) -> Double {
        guard let tradeLifecycleService = tradeLifecycleService,
              !participations.isEmpty else {
            // Fallback to reverse calculation if trade service not available
            return calculateGrossProfitFromAccumulatedProfit(
                investmentId: investmentId,
                poolTradeParticipationService: poolTradeParticipationService,
                commissionRate: commissionRate
            )
        }

        // Calculate gross profit from each trade proportionally
        var totalGrossProfit: Double = 0.0
        let completedTrades = tradeLifecycleService.completedTrades

        for participation in participations {
            guard let trade = completedTrades.first(where: { $0.id == participation.tradeId }) else { continue }

            // Calculate trade's gross profit using the same method as trader
            let tradeGrossProfit = ProfitCalculationService.calculateGrossProfitFromOrders(for: trade)

            // Investor's share of gross profit = trade gross profit * ownership percentage
            let investorGrossProfitShare = tradeGrossProfit * participation.ownershipPercentage
            totalGrossProfit += investorGrossProfitShare
        }

        return totalGrossProfit
    }

    // MARK: - Private Helpers

    private static func calculateGrossProfitFromAccumulatedProfit(
        investmentId: String,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?,
        commissionRate: Double
    ) -> Double {
        guard let poolTradeParticipationService = poolTradeParticipationService else {
            return 0.0
        }

        let accumulatedProfit = poolTradeParticipationService.getAccumulatedProfit(for: investmentId)
        return accumulatedProfit > 0 ?
            accumulatedProfit / (1.0 - commissionRate) :
            accumulatedProfit
    }
}
