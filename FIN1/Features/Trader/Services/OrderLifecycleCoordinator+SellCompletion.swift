import Foundation

// MARK: - Sell order completion (trade matching, settlement, pool completion)

extension OrderLifecycleCoordinator {

    func handleSellOrderCompletion(orderId: String, order: Order) async {
        let sellOrder = OrderSell(
            id: order.id,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: .confirmed,
            createdAt: order.createdAt,
            executedAt: order.executedAt,
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice,
            originalHoldingId: order.originalHoldingId
        )

        let allTrades = self.tradeLifecycleService.completedTrades
        let trades = allTrades.filter { $0.traderId == sellOrder.traderId }

        let updatedTrade = await tradeMatchingService.findAndUpdateTradeWithSellOrder(
            sellOrder: sellOrder,
            trades: trades,
            tradeLifecycleService: self.tradeLifecycleService
        )

        try? await self.tradeLifecycleService.refreshCompletedTrades()

        await self.orderManagementService.removeActiveOrder(orderId)

        await MainActor.run {
            NotificationCenter.default.post(
                name: .sellOrderCompleted,
                object: nil,
                userInfo: ["order": order]
            )
        }

        let latestTrade = self.tradeLifecycleService.completedTrades.first(where: { $0.id == updatedTrade?.id })
            ?? updatedTrade

        if let trade = latestTrade ?? updatedTrade {
            if TraderDepotTradeFilter.isPoolMirrorLeg(trade) {
                print("ℹ️ OrderLifecycleCoordinator: skip trader completion docs for MIRROR_POOL leg")
                await self.tradingNotificationService.showSellConfirmation(for: trade)
                return
            }

            await self.cashBalanceService.processSellOrderExecution(amount: order.totalAmount)

            await self.tradingNotificationService.generateInvoiceAndNotification(
                for: order,
                tradeId: trade.id,
                tradeNumber: trade.tradeNumber,
                tradeNumberYear: trade.resolvedTradeNumberYear
            )

            await self.syncTraderSellDocumentsIntoInboxAfterSell(for: trade)

            if trade.isCompleted {
                let settledByBackend = await self.checkBackendSettlement(for: trade)

                if settledByBackend {
                    print("🎯 Trade #\(trade.tradeNumber) settled by backend — syncing settlement documents to inbox")
                    await self.syncSettlementDocumentsIntoInbox(for: trade)
                } else if let documentService = documentService,
                          documentService.documentExists(for: trade.id, ofType: .traderCollectionBill) {
                    print(
                        "ℹ️ Trade #\(trade.tradeNumber): buy bill in cache — pull sell Belege from server inbox SSOT"
                    )
                    await self.syncTraderSellDocumentsIntoInboxAfterSell(for: trade)
                    await self.tradingNotificationService.showSellConfirmation(for: trade)
                    return
                } else {
                    print("🎯 Trade #\(trade.tradeNumber) is now fully completed - generating local documents")
                    await self.tradingNotificationService.generateCollectionBillDocument(for: trade)
                    await self.generateCreditNoteIfCommissionExists(for: trade)
                    NotificationCenter.default.post(
                        name: .userDocumentInboxShouldRefresh,
                        object: nil,
                        userInfo: ["force": true]
                    )
                }

                if let profitDistributionService = profitDistributionService, !settledByBackend {
                    _ = await profitDistributionService.distributeProfit(for: trade, order: order)
                }

                if let investmentService = investmentService, let poolTradeParticipationService = poolTradeParticipationService {
                    let participations = poolTradeParticipationService.getParticipations(forTradeId: trade.id)
                    if participations.isEmpty {
                        print("ℹ️ No pool participations recorded for trade \(trade.id); fallback to trader-based completion")
                        await investmentService.markInvestmentAsCompleted(for: trade.traderId)
                    } else {
                        for participation in participations {
                            await investmentService.markActiveInvestmentAsCompleted(for: participation.investmentId)
                            print(
                                "✅ OrderLifecycleCoordinator: Marked completed pool for investment \(participation.investmentId) (trade \(trade.id))"
                            )
                        }
                    }
                } else {
                    print("⚠️ OrderLifecycleCoordinator: services unavailable - pool completion skipped!")
                }
            }

            await self.tradingNotificationService.showSellConfirmation(for: trade)
        } else {
            await self.tradingNotificationService.generateInvoiceAndNotification(
                for: order,
                tradeId: nil,
                tradeNumber: nil,
                tradeNumberYear: nil
            )
        }
    }
}
