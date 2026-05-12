import Foundation

@MainActor
extension InvestorInvestmentStatementViewModel {
    /// Refreshes statement items using backend-authoritative collection bill data when configured; otherwise resolves participations/trades from Parse and builds locally (same as settlement-off builds).
    func refreshFromBackend() async {
        isRefreshingFromBackend = true
        backendRefreshMessage = nil
        defer { isRefreshingFromBackend = false }

        print("🔍 InvestorCB-refresh: start investmentId=\(investment.id) batchId=\(investment.batchId ?? "nil") investorId=\(investment.investorId)")

        let resolvedContext: InvestorInvestmentStatementResolvedContext
        if let statementDataProvider {
            resolvedContext = await statementDataProvider.resolveContext(
                for: investment,
                localParticipations: poolTradeParticipationService.getParticipations(forInvestmentId: investment.id),
                localTrades: tradeService.completedTrades
            )
        } else {
            let localParticipations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)
            resolvedContext = InvestorInvestmentStatementResolvedContext(
                participations: localParticipations,
                tradesById: Dictionary(uniqueKeysWithValues: tradeService.completedTrades.map { ($0.id, $0) })
            )
        }

        let participations = resolvedContext.participations
        print("🔍 InvestorCB-refresh: resolved participations=\(participations.count) trades=\(resolvedContext.tradesById.count)")
        for p in participations {
            let hasTrade = resolvedContext.tradesById[p.tradeId] != nil
            print("   • participation tradeId=\(p.tradeId) ownership=\(p.ownershipPercentage) hasLocalTrade=\(hasTrade)")
        }

        guard !participations.isEmpty else {
            backendRefreshMessage = "Collection Bill konnte nicht geladen werden (keine Beteiligungen gefunden)"
            print("⚠️ InvestorCB-refresh: aborted (no participations)")
            return
        }

        guard let settlementAPIService else {
            let localItems = buildStatementItems(
                participations: participations,
                tradesById: resolvedContext.tradesById
            )
            if !localItems.isEmpty {
                statementItems = localItems
                print("✅ InvestorCB-refresh: settlementAPI nil → built \(localItems.count) local items")
            } else {
                backendRefreshMessage = "Collection Bill konnte nicht aufgebaut werden (Trades fehlen lokal — bitte erneut öffnen oder Sync prüfen)"
                print("⚠️ InvestorCB-refresh: settlementAPI nil & no local items")
            }
            return
        }

        let totalInvestmentCapital = investment.amount
        let trades = resolvedContext.tradesById
        var items: [InvestorInvestmentStatementItem] = []
        var skippedNoTrade = 0
        var failedCalculations = 0
        let effectiveRate = effectiveCommissionRate

        for participation in participations {
            guard let trade = trades[participation.tradeId] else {
                skippedNoTrade += 1
                print("⚠️ InvestorCB-refresh: skipping participation tradeId=\(participation.tradeId) — trade not in resolved set")
                continue
            }

            let allInvoices = invoiceService.getInvoicesForTrade(trade.id)
            let buyInvoice = allInvoices.first { $0.transactionType == .buy }
            let sellInvoices = allInvoices.filter { $0.transactionType == .sell }

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
                buyInvoice: buyInvoice,
                sellInvoices: sellInvoices,
                investorAllocatedAmount: participation.allocatedAmount
            )

            do {
                let output = try await calculationService.calculateCollectionBillWithBackend(
                    input: input,
                    settlementAPIService: settlementAPIService,
                    tradeId: trade.id,
                    investmentId: investment.id
                )
                if output.usedLocalFallbackDueToBackendError {
                    backendRefreshMessage = "Daten werden aus dem lokalen Speicher angezeigt (Server nicht erreichbar)"
                }

                let commission = commissionCalculationService.calculateCommission(
                    grossProfit: output.grossProfit,
                    rate: effectiveRate
                )
                let netAfterComm = commissionCalculationService.calculateNetProfitAfterCommission(
                    grossProfit: output.grossProfit,
                    rate: effectiveRate
                )

                let item = InvestorInvestmentStatementItem(
                    id: trade.id,
                    tradeNumber: trade.tradeNumber,
                    symbol: trade.symbol,
                    tradeDate: trade.completedAt ?? trade.updatedAt,
                    buyQuantity: output.buyQuantity,
                    buyPrice: output.buyPrice,
                    buyTotal: output.buyAmount,
                    buyFees: output.buyFees,
                    buyFeeDetails: output.buyFeeDetails,
                    sellQuantity: output.sellQuantity,
                    sellAveragePrice: output.sellAveragePrice,
                    sellTotal: output.sellAmount,
                    sellFees: output.sellFees,
                    sellFeeDetails: output.sellFeeDetails,
                    grossProfit: output.grossProfit,
                    ownershipPercentage: participation.ownershipPercentage,
                    roiGrossProfit: output.roiGrossProfit,
                    roiInvestedAmount: output.roiInvestedAmount,
                    tradeROI: trade.displayROI,
                    commission: commission,
                    grossProfitAfterCommission: netAfterComm,
                    residualAmount: output.residualAmount
                )
                items.append(item)
                print("✅ InvestorCB-refresh: built item for trade \(trade.tradeNumber) buyAmt=\(output.buyAmount) sellAmt=\(output.sellAmount) gp=\(output.grossProfit)")
            } catch {
                failedCalculations += 1
                print("⚠️ InvestorCB-refresh: calculation failed for trade \(trade.tradeNumber): \(error.localizedDescription)")
            }
        }

        print("🔍 InvestorCB-refresh: done — items=\(items.count) skippedNoTrade=\(skippedNoTrade) failedCalcs=\(failedCalculations) priorStatementItems=\(statementItems.count)")

        if !items.isEmpty {
            statementItems = items.sorted { $0.tradeDate < $1.tradeDate }
        } else if statementItems.isEmpty {
            backendRefreshMessage = "Collection Bill enthält keine Positionen (Server lieferte keine verwertbaren Metadaten — bitte Logs prüfen)"
        }
    }
}
