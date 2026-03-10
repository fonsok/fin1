import Foundation

// MARK: - ⚠️ CRITICAL API CONTRACT - DO NOT SIMPLIFY ⚠️
// ═══════════════════════════════════════════════════════════════════════════════
// This file defines the API used by multiple views. Changing this structure will
// break the build. The following are REQUIRED and must not be removed:
//
// InvestorInvestmentStatementSummary REQUIRED PROPERTIES:
//   - statementGrossProfit, statementInvestedAmount
//   - statementBuyFees, statementTotalBuyCost (used by CommissionCalculationExplanationSheet)
//   - statementResidualAmount, statementSellAmount, statementSellFees, statementNetSellAmount
//   - roiGrossProfit, roiInvestedAmount
//   - statementCommission (used by CommissionCalculationExplanationSheet)
//
// summarizeInvestment() REQUIRED PARAMETERS:
//   - investmentId, poolTradeParticipationService, tradeLifecycleService, invoiceService
//   - investmentService (used by CompletedInvestmentsTable, CommissionCalculationExplanationSheet)
//   - calculationService (used by CompletedInvestmentsTable, CommissionCalculationExplanationSheet)
//   - commissionRate (used by CompletedInvestmentsTable, CommissionCalculationExplanationSheet)
//
// DEPENDENT FILES (will fail to build if this API changes):
//   - CommissionCalculationExplanationSheet.swift
//   - CompletedInvestmentsTable.swift
//   - CompletedInvestmentDetailViewModel.swift
// ═══════════════════════════════════════════════════════════════════════════════

struct InvestorInvestmentStatementSummary {
    let items: [InvestorInvestmentStatementItem]
    let statementGrossProfit: Double
    let statementInvestedAmount: Double // Buy amount (securities value, excluding fees)
    let statementBuyFees: Double // Total buy fees across all trades
    let statementTotalBuyCost: Double // Total buy cost (buy amount + fees)
    let statementResidualAmount: Double // Total residual amount across all trades (should be returned to investor)
    let statementSellAmount: Double // Sell amount (securities value, excluding fees)
    let statementSellFees: Double // Total sell fees across all trades (negative values)
    let statementNetSellAmount: Double // Net sell amount (sell amount + sell fees)
    let roiGrossProfit: Double
    let roiInvestedAmount: Double
    let statementCommission: Double // Commission calculated from gross profit (single source of truth)
}

enum InvestorInvestmentStatementAggregator {

    static func summarizeInvestment(
        investmentId: String,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        investmentService: (any InvestmentServiceProtocol)? = nil,
        calculationService: (any InvestorCollectionBillCalculationServiceProtocol)? = nil,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil,
        investment: Investment? = nil,
        commissionRate: Double = CalculationConstants.FeeRates.traderCommissionRate
    ) -> InvestorInvestmentStatementSummary? {

        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investmentId)
        guard !participations.isEmpty else {
            print("ℹ️ InvestorInvestmentStatementAggregator: No participations for investment \(investmentId)")
            return nil
        }

        // Get the actual investment to access the capital amount (source of truth)
        let investmentToUse: Investment?
        if let providedInvestment = investment {
            investmentToUse = providedInvestment
        } else if let investmentService = investmentService {
            investmentToUse = investmentService.investments.first(where: { $0.id == investmentId })
        } else {
            investmentToUse = nil
        }
        let totalInvestmentCapital = investmentToUse?.amount ?? participations.reduce(0.0) { $0 + $1.allocatedAmount }

        let trades = tradeLifecycleService.completedTrades
        let calcService = calculationService ?? InvestorCollectionBillCalculationService()
        let commissionService = commissionCalculationService ?? CommissionCalculationService()

        var items: [InvestorInvestmentStatementItem] = []
        var statementGrossProfitTotal = 0.0
        var statementInvestedAmountTotal = 0.0 // Buy amount (securities value)
        var statementBuyFeesTotal = 0.0 // Total buy fees
        var statementSellAmountTotal = 0.0 // Sell amount (securities value)
        var statementSellFeesTotal = 0.0 // Total sell fees (negative values)
        var roiGrossProfitTotal = 0.0
        var roiInvestedAmountTotal = 0.0
        var statementCommissionTotal = 0.0 // Sum of item-level commissions

        for participation in participations {
            guard let trade = trades.first(where: { $0.id == participation.tradeId }) else {
                print("❌ InvestorInvestmentStatementAggregator: Missing trade \(participation.tradeId) for investment \(investmentId)")
                return nil
            }

            let invoices = invoiceService.getInvoicesForTrade(trade.id)
            let buyInvoice = invoices.first { $0.transactionType == .buy }
            let sellInvoices = invoices.filter { $0.transactionType == .sell }

            // Calculate this trade's share of investment capital
            let tradeCapitalShare: Double
            if participations.count == 1 {
                tradeCapitalShare = totalInvestmentCapital
            } else {
                let totalOwnership = participations.reduce(0.0) { $0 + $1.ownershipPercentage }
                tradeCapitalShare = totalOwnership > 0
                    ? (totalInvestmentCapital * participation.ownershipPercentage / totalOwnership)
                    : (totalInvestmentCapital / Double(participations.count))
            }

            // Try to use calculation service for proper amounts
            do {
                let item = try InvestorInvestmentStatementItem.build(
                    trade: trade,
                    buyInvoice: buyInvoice,
                    sellInvoices: sellInvoices,
                    ownershipPercentage: participation.ownershipPercentage,
                    investorAllocatedAmount: participation.allocatedAmount,
                    investmentCapitalAmount: tradeCapitalShare,
                    calculationService: calcService,
                    commissionCalculationService: commissionService,
                    commissionRate: commissionRate
                )
                items.append(item)
                statementGrossProfitTotal += item.grossProfit
                statementInvestedAmountTotal += item.buyTotal
                statementBuyFeesTotal += item.buyFees
                // Note: Residual amount is calculated from totals, not summed per-trade
                statementSellAmountTotal += item.sellTotal
                statementSellFeesTotal += item.sellFees
                roiGrossProfitTotal += item.roiGrossProfit
                roiInvestedAmountTotal += item.roiInvestedAmount
                statementCommissionTotal += item.commission  // Sum item-level commission
            } catch {
                print("❌ InvestorInvestmentStatementAggregator: Calculation failed for trade \(trade.tradeNumber): \(error)")
                // Fallback to legacy build
                let item = InvestorInvestmentStatementItem.build(
                    trade: trade,
                    buyInvoice: buyInvoice,
                    sellInvoices: sellInvoices,
                    ownershipPercentage: participation.ownershipPercentage,
                    investorAllocatedAmount: participation.allocatedAmount,
                    commissionCalculationService: commissionService,
                    commissionRate: commissionRate
                )
                items.append(item)
                statementGrossProfitTotal += item.grossProfit
                statementInvestedAmountTotal += item.buyTotal
                statementBuyFeesTotal += item.buyFees
                statementSellAmountTotal += item.sellTotal
                statementSellFeesTotal += item.sellFees
                roiGrossProfitTotal += item.roiGrossProfit
                roiInvestedAmountTotal += item.roiInvestedAmount
                statementCommissionTotal += item.commission  // Sum item-level commission
            }
        }

        guard roiInvestedAmountTotal > 0 else {
            print("❌ InvestorInvestmentStatementAggregator: Total invested amount is 0 for investment \(investmentId)")
            return nil
        }

        // Total Buy Cost = Buy Amount + Buy Fees
        let statementTotalBuyCost = statementInvestedAmountTotal + statementBuyFeesTotal
        // Net Sell Amount = Sell Amount + Sell Fees (sell fees are negative)
        let statementNetSellAmount = statementSellAmountTotal + statementSellFeesTotal

        // CRITICAL FIX: Calculate residual amount from total investment capital and total buy cost
        // This ensures the accounting equation: Investment Capital = Total Buy Cost + Residual
        // Previous incorrect approach: Sum of per-trade residuals (can have rounding errors)
        let calculatedResidualAmount = totalInvestmentCapital - statementTotalBuyCost
        // Use calculated residual (ensures exact accounting match)
        let finalResidualAmount = max(0.0, calculatedResidualAmount)

        // Debug logging for residual calculation verification
        print("💰 InvestorInvestmentStatementAggregator: Residual calculation")
        print("   💵 Total Investment Capital: €\(String(format: "%.2f", totalInvestmentCapital))")
        print("   💵 Total Buy Cost: €\(String(format: "%.2f", statementTotalBuyCost))")
        print("   💵 Calculated Residual: €\(String(format: "%.2f", calculatedResidualAmount))")
        print("   💵 Final Residual Amount: €\(String(format: "%.2f", finalResidualAmount))")

        let sortedItems = items.sorted { $0.tradeDate < $1.tradeDate }
        return InvestorInvestmentStatementSummary(
            items: sortedItems,
            statementGrossProfit: statementGrossProfitTotal,
            statementInvestedAmount: statementInvestedAmountTotal,
            statementBuyFees: statementBuyFeesTotal,
            statementTotalBuyCost: statementTotalBuyCost,
            statementResidualAmount: finalResidualAmount,
            statementSellAmount: statementSellAmountTotal,
            statementSellFees: statementSellFeesTotal,
            statementNetSellAmount: statementNetSellAmount,
            roiGrossProfit: roiGrossProfitTotal,
            roiInvestedAmount: roiInvestedAmountTotal,
            statementCommission: statementCommissionTotal  // Use sum of item-level commissions
        )
    }
}
