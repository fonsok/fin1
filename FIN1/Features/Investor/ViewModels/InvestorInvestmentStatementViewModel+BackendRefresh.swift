import Foundation

@MainActor
extension InvestorInvestmentStatementViewModel {
    /// Refreshes statement items using backend-authoritative collection bill data when configured; otherwise resolves participations/trades from Parse and builds locally (same as settlement-off builds).
    func refreshFromBackend() async {
        isRefreshingFromBackend = true
        backendRefreshMessage = nil
        belegIntegrityBanner = nil
        defer { isRefreshingFromBackend = false }

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
        guard !participations.isEmpty else {
            backendRefreshMessage = "Collection Bill konnte nicht geladen werden (keine Beteiligungen gefunden)"
            return
        }

        let serverOnly = configurationService.investorMonetaryServerOnly

        guard let settlementAPIService else {
            backendRefreshMessage = InvestorMonetaryMessages.serverUnavailable
            statementItems = []
            return
        }

        let totalInvestmentCapital = investment.amount
        let trades = resolvedContext.tradesById
        var items: [InvestorInvestmentStatementItem] = []
        var skippedNoTrade = 0
        var failedCalculations = 0
        let effectiveRate = effectiveCommissionRate

        let backendBillsByTradeId: [String: BackendCollectionBill]
        do {
            backendBillsByTradeId = try await calculationService.prefetchBackendBills(
                for: investment.id,
                settlementAPIService: settlementAPIService
            )
        } catch {
            backendRefreshMessage = InvestorMonetaryMessages.serverUnavailable
            return
        }

        for participation in participations {
            guard let trade = trades[participation.tradeId] else {
                skippedNoTrade += 1
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
                    investmentId: investment.id,
                    preloadedBill: backendBillsByTradeId[trade.id],
                    monetaryServerOnly: serverOnly,
                    billResolvedFromPrefetchIndex: true
                )

                let item = InvestorInvestmentStatementItem.from(
                    trade: trade,
                    output: output,
                    ownershipPercentage: participation.ownershipPercentage,
                    commissionCalculationService: commissionCalculationService,
                    commissionRate: effectiveRate
                )
                items.append(item)
            } catch let error as InvestorMonetaryServerOnlyError {
                failedCalculations += 1
                if backendRefreshMessage == nil {
                    backendRefreshMessage = error.localizedDescription
                }
            } catch let error as InvestorCollectionBillBelegError {
                failedCalculations += 1
                backendRefreshMessage = error.localizedDescription
                InvestorCollectionBillLog.warning(
                    "Beleg unmappable trade \(trade.tradeNumber): \(error.localizedDescription)"
                )
            } catch {
                failedCalculations += 1
                InvestorCollectionBillLog.warning(
                    "Statement build failed trade \(trade.tradeNumber): \(error.localizedDescription)"
                )
            }
        }

        if !items.isEmpty {
            statementItems = items.sorted { $0.tradeDate < $1.tradeDate }
            self.updateBelegIntegrityBanner(from: items)
        } else if statementItems.isEmpty {
            backendRefreshMessage = "Collection Bill enthält keine Positionen (Server lieferte keine verwertbaren Metadaten — bitte Logs prüfen)"
        }

        if failedCalculations > 0, backendRefreshMessage == nil {
            backendRefreshMessage = "\(failedCalculations) Trade(s) konnten nicht aus dem Server-Beleg geladen werden"
        }

        _ = skippedNoTrade
    }

    private func updateBelegIntegrityBanner(from items: [InvestorInvestmentStatementItem]) {
        let inconsistent = items.compactMap(\.belegInconsistencyMessage)
        let provisional = items.contains(where: \.isProvisionalLocalEstimate)

        if !inconsistent.isEmpty {
            self.belegIntegrityBanner =
                "GoB-Hinweis: Mindestens ein archivierter Collection Bill ist intern inkonsistent (Legs ≠ gebuchte Summen). Angezeigte Summen folgen dem Beleg; bitte Admin-Audit auslösen."
        } else if provisional {
            self.belegIntegrityBanner =
                "Vorläufige Werte (lokale Schätzung). Maßgeblich ist der archivierte Collection Bill auf dem Server nach Trade-Abschluss."
        }
    }
}
