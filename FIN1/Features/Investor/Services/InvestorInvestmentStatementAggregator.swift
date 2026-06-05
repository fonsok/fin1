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
//   - commissionRate — required; pass configurationService.effectiveCommissionRate (no CalculationConstants default)
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
    let statementNetSellAmount: Double // Net sell amount (sell amount − |sell fees|)
    let roiGrossProfit: Double
    let roiInvestedAmount: Double
    let statementCommission: Double // Commission calculated from gross profit (single source of truth)
}

enum InvestorInvestmentStatementAggregator {

    @MainActor
    static func summarizeInvestment(
        investmentId: String,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        investmentService: (any InvestmentServiceProtocol)? = nil,
        calculationService: (any InvestorCollectionBillCalculationServiceProtocol)? = nil,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil,
        investment: Investment? = nil,
        additionalTradesById: [String: Trade] = [:],
        commissionRate: Double
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

        // Trades may be missing from `tradeLifecycleService.completedTrades` for
        // investor sessions (the trader-centric cache is not populated for the
        // investor role). `additionalTradesById` carries server-fetched trades
        // resolved via `resolveTradesForPoolParticipations` so the investor's
        // Collection Bill / "Awaiting invoices" placeholder resolves.
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
            let resolvedTrade = trades.first(where: { $0.id == participation.tradeId })
                ?? additionalTradesById[participation.tradeId]
            guard let trade = resolvedTrade else {
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
                InvestorCollectionBillLog.warning(
                    "Aggregator skipped trade \(trade.tradeNumber): \(error.localizedDescription)"
                )
            }
        }

        guard roiInvestedAmountTotal > 0 else {
            print("❌ InvestorInvestmentStatementAggregator: Total invested amount is 0 for investment \(investmentId)")
            return nil
        }

        // Total Buy Cost = Buy Amount + Buy Fees
        let statementTotalBuyCost = statementInvestedAmountTotal + statementBuyFeesTotal
        let sortedItems = items.sorted { $0.tradeDate < $1.tradeDate }
        // Net Sell Amount = Σ per-trade (Sell Amount − |Sell Fees|); matches Collection Bill line items.
        let statementNetSellAmount = sortedItems.reduce(0) { $0 + $1.netSellAmount }

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

    /// Builds statement summary from archived collection bills only (GoB / server-only path).
    @MainActor
    static func summarizeInvestmentFromServer(
        investmentId: String,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        settlementAPIService: any SettlementAPIServiceProtocol,
        calculationService: any InvestorCollectionBillCalculationServiceProtocol,
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        investment: Investment? = nil,
        investmentService: (any InvestmentServiceProtocol)? = nil,
        additionalTradesById: [String: Trade] = [:],
        commissionRate: Double,
        monetaryServerOnly: Bool
    ) async -> InvestorInvestmentStatementSummary? {
        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investmentId)
        guard !participations.isEmpty else { return nil }

        let investmentToUse: Investment?
        if let investment {
            investmentToUse = investment
        } else if let investmentService {
            investmentToUse = investmentService.investments.first(where: { $0.id == investmentId })
        } else {
            investmentToUse = nil
        }
        let totalInvestmentCapital = investmentToUse?.amount ?? participations.reduce(0.0) { $0 + $1.allocatedAmount }

        let billsByTradeId: [String: BackendCollectionBill]
        do {
            billsByTradeId = try await InvestorCollectionBillBackendPrefetch.loadBills(
                investmentId: investmentId,
                settlementAPIService: settlementAPIService
            )
        } catch {
            return nil
        }

        let calcService = calculationService
        let commissionService = commissionCalculationService
        var items: [InvestorInvestmentStatementItem] = []

        for participation in participations {
            guard let trade = tradeLifecycleService.completedTrades.first(where: { $0.id == participation.tradeId })
                ?? additionalTradesById[participation.tradeId] else {
                if monetaryServerOnly { return nil }
                continue
            }

            let invoices = invoiceService.getInvoicesForTrade(trade.id)
            let tradeCapitalShare: Double
            if participations.count == 1 {
                tradeCapitalShare = totalInvestmentCapital
            } else {
                let totalOwnership = participations.reduce(0.0) { $0 + $1.ownershipPercentage }
                tradeCapitalShare = totalOwnership > 0
                    ? (totalInvestmentCapital * participation.ownershipPercentage / totalOwnership)
                    : (totalInvestmentCapital / Double(participations.count))
            }

            let input = InvestorCollectionBillInput(
                investmentCapital: tradeCapitalShare,
                buyPrice: trade.entryPrice,
                tradeTotalQuantity: trade.totalQuantity,
                ownershipPercentage: participation.ownershipPercentage,
                buyInvoice: invoices.first { $0.transactionType == .buy },
                sellInvoices: invoices.filter { $0.transactionType == .sell },
                investorAllocatedAmount: participation.allocatedAmount
            )

            do {
                let output = try await calcService.calculateCollectionBillWithBackend(
                    input: input,
                    settlementAPIService: settlementAPIService,
                    tradeId: trade.id,
                    investmentId: investmentId,
                    preloadedBill: billsByTradeId[trade.id],
                    monetaryServerOnly: monetaryServerOnly,
                    billResolvedFromPrefetchIndex: true
                )
                let item = InvestorInvestmentStatementItem.from(
                    trade: trade,
                    output: output,
                    ownershipPercentage: participation.ownershipPercentage,
                    commissionCalculationService: commissionService,
                    commissionRate: commissionRate
                )
                items.append(item)
            } catch {
                if monetaryServerOnly { return nil }
            }
        }

        guard !items.isEmpty else { return nil }

        if let canonical = ServerCalculatedReturnResolver.canonicalSummary(
            fromCollectionBills: Array(billsByTradeId.values)
        ) {
            return self.summary(
                fromCanonical: canonical,
                items: items.sorted { $0.tradeDate < $1.tradeDate },
                investmentCapital: totalInvestmentCapital
            )
        }

        return self.summarizeFromItemsOnly(items: items, investmentCapital: totalInvestmentCapital)
    }

    /// Maps server-aggregated bill metadata to statement totals (SSOT for list/detail when server-only).
    static func summary(
        fromCanonical canonical: ServerInvestmentCanonicalSummary,
        items: [InvestorInvestmentStatementItem],
        investmentCapital: Double
    ) -> InvestorInvestmentStatementSummary {
        let statementInvestedAmountTotal = items.reduce(0) { $0 + $1.buyTotal }
        let statementBuyFeesTotal = items.reduce(0) { $0 + $1.buyFees }
        let statementTotalBuyCost = canonical.totalBuyCost > 0 ? canonical.totalBuyCost : (
            statementInvestedAmountTotal + statementBuyFeesTotal
        )
        let statementSellAmountTotal = items.reduce(0) { $0 + $1.sellTotal }
        let statementSellFeesTotal = items.reduce(0) { $0 + $1.sellFees }
        let statementNetSellAmount = items.reduce(0) { $0 + $1.netSellAmount }
        let finalResidualAmount = max(0, investmentCapital - statementTotalBuyCost)

        return InvestorInvestmentStatementSummary(
            items: items,
            statementGrossProfit: canonical.grossProfit,
            statementInvestedAmount: statementInvestedAmountTotal,
            statementBuyFees: statementBuyFeesTotal,
            statementTotalBuyCost: statementTotalBuyCost,
            statementResidualAmount: finalResidualAmount,
            statementSellAmount: statementSellAmountTotal,
            statementSellFees: statementSellFeesTotal,
            statementNetSellAmount: statementNetSellAmount,
            roiGrossProfit: items.reduce(0) { $0 + $1.roiGrossProfit },
            roiInvestedAmount: items.reduce(0) { $0 + $1.roiInvestedAmount },
            statementCommission: canonical.commission
        )
    }

    private static func summarizeFromItemsOnly(
        items: [InvestorInvestmentStatementItem],
        investmentCapital: Double
    ) -> InvestorInvestmentStatementSummary? {
        guard !items.isEmpty else { return nil }
        let sorted = items.sorted { $0.tradeDate < $1.tradeDate }
        let statementInvestedAmountTotal = sorted.reduce(0) { $0 + $1.buyTotal }
        let statementBuyFeesTotal = sorted.reduce(0) { $0 + $1.buyFees }
        let statementTotalBuyCost = statementInvestedAmountTotal + statementBuyFeesTotal
        let statementGrossProfitTotal = sorted.reduce(0) { $0 + $1.grossProfit }
        let statementCommissionTotal = sorted.reduce(0) { $0 + $1.commission }

        return InvestorInvestmentStatementSummary(
            items: sorted,
            statementGrossProfit: statementGrossProfitTotal,
            statementInvestedAmount: statementInvestedAmountTotal,
            statementBuyFees: statementBuyFeesTotal,
            statementTotalBuyCost: statementTotalBuyCost,
            statementResidualAmount: max(0, investmentCapital - statementTotalBuyCost),
            statementSellAmount: sorted.reduce(0) { $0 + $1.sellTotal },
            statementSellFees: sorted.reduce(0) { $0 + $1.sellFees },
            statementNetSellAmount: sorted.reduce(0) { $0 + $1.netSellAmount },
            roiGrossProfit: sorted.reduce(0) { $0 + $1.roiGrossProfit },
            roiInvestedAmount: sorted.reduce(0) { $0 + $1.roiInvestedAmount },
            statementCommission: statementCommissionTotal
        )
    }
}

// MARK: - Trade Resolution (Investor view)
//
// Investors do not own a populated `tradeLifecycleService.completedTrades`
// cache (that publisher is fed by trader-side `getOpenTrades` /
// `getTradeHistory` flows). The investor only carries `PoolTradeParticipation`
// records, which reference `tradeId`. To hydrate the related Trades for
// "Trade Nr." display and statement aggregation we ask the server lazily.
//
// The resolver:
//   1. Returns any locally-cached trades immediately (no roundtrip needed).
//   2. Fetches the missing ones via `TradeAPIService.fetchTrade(tradeId:)`.
//   3. Fails soft per-trade — a missing or unauthorised trade simply stays
//      out of the result map, the aggregator falls back to "Awaiting invoices"
//      for that single line item without breaking the rest.
extension InvestorInvestmentStatementAggregator {
    @MainActor
    static func resolveTradesForPoolParticipations(
        investedTradeIds: Set<String>,
        localTrades: [Trade],
        tradeAPIService: (any TradeAPIServiceProtocol)?
    ) async -> [String: Trade] {
        var result: [String: Trade] = [:]
        var missingIds: [String] = []
        for tradeId in investedTradeIds {
            if let trade = localTrades.first(where: { $0.id == tradeId }) {
                result[tradeId] = trade
            } else {
                missingIds.append(tradeId)
            }
        }
        guard !missingIds.isEmpty, let api = tradeAPIService else {
            return result
        }
        for id in missingIds {
            do {
                if let trade = try await api.fetchTrade(tradeId: id) {
                    result[id] = trade
                }
            } catch {
                print("⚠️ InvestorInvestmentStatementAggregator: fetchTrade \(id) failed: \(error.localizedDescription)")
            }
        }
        return result
    }
}
