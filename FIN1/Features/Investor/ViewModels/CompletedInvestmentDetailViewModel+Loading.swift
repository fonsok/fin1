import Foundation

extension CompletedInvestmentDetailViewModel {
    func reconfigure(with services: AppServices) {
        self.poolTradeParticipationService = services.poolTradeParticipationService
        self.tradeLifecycleService = services.tradeLifecycleService
        self.invoiceService = services.invoiceService
        self.calculationService = InvestorCollectionBillCalculationService()
        self.commissionCalculationService = services.commissionCalculationService
        self.configurationService = services.configurationService
        self.settlementAPIService = services.settlementAPIService
        self.tradeAPIService = services.parseAPIClient.map { TradeAPIService(apiClient: $0) }
        self.refreshStatementSummary()
        self.refreshTradeLedReturnPercentage()
    }

    func refreshStatementSummary() {
        guard let poolTradeParticipationService,
              let tradeLifecycleService,
              let invoiceService,
              let calculationService,
              let commissionCalculationService,
              let configurationService else {
            self.statementSummary = nil
            self.tradeLineItems = []
            return
        }

        let commissionRate = configurationService.effectiveInvestorCommissionRate
        let investmentId = self.investment.id
        let tradeAPI = self.tradeAPIService
        let localTrades = tradeLifecycleService.completedTrades

        Task { @MainActor [weak self] in
            guard let self else { return }
            let tradeIds = Set(
                poolTradeParticipationService.getParticipations(forInvestmentId: investmentId).map(\.tradeId)
            )
            let tradesById = await InvestorInvestmentStatementAggregator.resolveTradesForPoolParticipations(
                investedTradeIds: tradeIds,
                localTrades: localTrades,
                tradeAPIService: tradeAPI
            )
            self.rebuildTradeLineItems(additionalTradesById: tradesById)

            if let settlementAPIService = self.settlementAPIService {
                self.statementSummary = await InvestorInvestmentStatementAggregator.summarizeInvestmentFromServer(
                    investmentId: investmentId,
                    poolTradeParticipationService: poolTradeParticipationService,
                    tradeLifecycleService: tradeLifecycleService,
                    invoiceService: invoiceService,
                    settlementAPIService: settlementAPIService,
                    calculationService: calculationService,
                    commissionCalculationService: commissionCalculationService,
                    investment: self.investment,
                    additionalTradesById: tradesById,
                    commissionRate: commissionRate,
                    monetaryServerOnly: self.monetaryServerOnly,
                    collectionBillServerLegs: self.configurationService?.collectionBillServerLegs ?? true
                )
                self.canonicalSummary = await ServerCalculatedReturnResolver.resolveCanonicalSummary(
                    investmentId: investmentId,
                    settlementAPIService: settlementAPIService,
                    allowUnweightedReturnFallback: !self.monetaryServerOnly
                )
            } else {
                self.statementSummary = nil
                self.canonicalSummary = nil
            }
        }
    }

    func rebuildTradeLineItems(additionalTradesById: [String: Trade] = [:]) {
        guard let poolTradeParticipationService, let tradeLifecycleService else {
            self.tradeLineItems = []
            return
        }

        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: self.investment.id)
        guard !participations.isEmpty else {
            self.tradeLineItems = []
            return
        }

        let trades = tradeLifecycleService.completedTrades
        var items: [TradeLineItem] = []

        for participation in participations {
            let trade = trades.first(where: { $0.id == participation.tradeId })
                ?? additionalTradesById[participation.tradeId]
            guard let trade else { continue }

            let unitPrice = trade.entryPrice
            guard unitPrice > 0 else { continue }

            let quantity = participation.allocatedAmount / unitPrice
            let totalAmount = quantity * unitPrice

            items.append(
                TradeLineItem(
                    id: participation.id,
                    tradeNumber: trade.tradeNumber,
                    tradeNumberYear: trade.tradeNumberYear,
                    symbol: trade.symbol,
                    tradeDate: trade.completedAt ?? trade.updatedAt,
                    quantity: quantity,
                    unitPrice: unitPrice,
                    totalAmount: totalAmount
                )
            )
        }

        self.tradeLineItems = items.sorted { $0.tradeDate < $1.tradeDate }
    }

    func refreshTradeLedReturnPercentage() {
        guard self.poolTradeParticipationService != nil, self.tradeLifecycleService != nil else {
            self.tradeLedReturnPercentageValue = nil
            return
        }

        let allowFallback = !(configurationService?.investorMonetaryServerOnly ?? true)
        Task {
            if let summary = await ServerCalculatedReturnResolver.resolveCanonicalSummary(
                investmentId: self.investment.id,
                settlementAPIService: self.settlementAPIService,
                allowUnweightedReturnFallback: allowFallback
            ), summary.hasReturnPercentage {
                self.tradeLedReturnPercentageValue = summary.returnPercentage
            } else {
                self.tradeLedReturnPercentageValue = nil
            }
        }
    }
}
