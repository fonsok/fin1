import Foundation

@MainActor
extension InvestorInvestmentStatementViewModel {
    func rebuildStatement() {
        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)
        let tradesById = Dictionary(uniqueKeysWithValues: tradeService.completedTrades.map { ($0.id, $0) })
        statementItems = self.buildStatementItems(participations: participations, tradesById: tradesById)
    }

    /// Builds statement rows from participations and a trade lookup (local `Trade` models).
    func buildStatementItems(
        participations: [PoolTradeParticipation],
        tradesById: [String: Trade]
    ) -> [InvestorInvestmentStatementItem] {
        guard !participations.isEmpty else {
            return []
        }

        let totalInvestmentCapital = investment.amount
        print(
            "💰 InvestorInvestmentStatementViewModel: Investment capital (source of truth): €\(String(format: "%.2f", totalInvestmentCapital))"
        )

        var items: [InvestorInvestmentStatementItem] = []
        let effectiveRate = effectiveCommissionRate
        print("💰 InvestorInvestmentStatementViewModel: Using commission rate: \(String(format: "%.0f", effectiveRate * 100))%")

        for participation in participations {
            guard let trade = tradesById[participation.tradeId] else { continue }

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

            print(
                "💰 InvestorInvestmentStatementViewModel: Trade \(trade.tradeNumber) capital share: €\(String(format: "%.2f", tradeCapitalShare))"
            )

            do {
                let item = try InvestorInvestmentStatementItem.build(
                    trade: trade,
                    buyInvoice: buyInvoice,
                    sellInvoices: sellInvoices,
                    ownershipPercentage: participation.ownershipPercentage,
                    investorAllocatedAmount: participation.allocatedAmount,
                    investmentCapitalAmount: tradeCapitalShare,
                    calculationService: calculationService,
                    commissionCalculationService: commissionCalculationService,
                    commissionRate: effectiveRate
                )
                items.append(item)
            } catch {
                print("❌ InvestorInvestmentStatementViewModel: Failed to build statement item for trade \(trade.tradeNumber): \(error)")
                let legacyItem = InvestorInvestmentStatementItem.build(
                    trade: trade,
                    buyInvoice: buyInvoice,
                    sellInvoices: sellInvoices,
                    ownershipPercentage: participation.ownershipPercentage,
                    investorAllocatedAmount: participation.allocatedAmount,
                    commissionCalculationService: commissionCalculationService,
                    commissionRate: effectiveRate
                )
                items.append(legacyItem)
            }
        }

        return items.sorted { $0.tradeDate < $1.tradeDate }
    }
}
