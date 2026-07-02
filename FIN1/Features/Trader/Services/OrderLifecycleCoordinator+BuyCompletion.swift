import Foundation

// MARK: - Buy order completion (trade creation, cash, documents)

extension OrderLifecycleCoordinator {

    func handleBuyOrderCompletion(orderId: String, order: Order) async {
        if self.orderManagementService.pairedBuyExecutionId(for: orderId) != nil {
            try? await self.tradeLifecycleService.refreshCompletedTrades()
            if let trade = self.resolveTraderLegTrade(forBuyOrderId: orderId) {
                if order.isMirrorPoolOrder != true {
                    await self.cashBalanceService.processBuyOrderExecution(amount: order.totalAmount)
                }
                await self.tradingNotificationService.showBuyConfirmation(for: trade)
                await self.syncPairedBuySettlementDocuments(for: order, traderTrade: trade)
            } else {
                print(
                    "⚠️ OrderLifecycleCoordinator: paired buy completed but TRADER leg trade not found for order \(orderId)"
                )
            }
            await self.refreshInvestmentsAfterPoolMirrorActivation()
            await self.orderManagementService.removeActiveOrder(orderId)
            return
        }

        if order.isMirrorPoolOrder != true,
           await self.legacyBuyBlockedByPoolMirrorRequirement(for: order) {
            let message = String(
                localized: "Kauf ohne Paired-Buy blockiert: Pool-Kapital erfordert executePairedBuy. Bitte Order stornieren und nach Pool-Refresh erneut kaufen."
            )
            print("❌ OrderLifecycleCoordinator: \(message) (order \(orderId))")
            self.orderManagementService.reportOrderStatusFailure(message)
            await self.orderManagementService.removeActiveOrder(orderId)
            return
        }

        let buyOrder = OrderBuy(
            id: order.id,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: .completed,
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
            subscriptionRatio: order.subscriptionRatio,
            denomination: order.denomination,
            isMirrorPoolOrder: order.isMirrorPoolOrder
        )

        try? await self.tradeLifecycleService.refreshCompletedTrades()
        let serverLinkedTrade = self.tradeLifecycleService.completedTrades.first(where: { $0.buyOrder.id == orderId })
        let trade: Trade?
        if let serverLinkedTrade {
            trade = serverLinkedTrade
        } else {
            trade = try? await self.tradeLifecycleService.createNewTrade(buyOrder: buyOrder)
        }

        if let trade = trade {
            if order.isMirrorPoolOrder != true {
                await self.cashBalanceService.processBuyOrderExecution(amount: order.totalAmount)
            }

            if order.isMirrorPoolOrder == true {
                print(
                    "ℹ️ OrderLifecycleCoordinator: skip local pool activation for mirror order \(order.id) — server SSOT"
                )
            }

            await self.tradingNotificationService.showBuyConfirmation(for: trade)

            let bookedByBackend = await self.checkBackendSettlement(for: trade)
            if bookedByBackend {
                await self.syncBuyOrderDocumentsFromBackend(for: order, trade: trade)
            } else {
                await self.tradingNotificationService.generateInvoiceAndNotification(
                    for: order,
                    tradeId: trade.id,
                    tradeNumber: trade.tradeNumber,
                    tradeNumberYear: trade.resolvedTradeNumberYear
                )
            }

            await self.orderManagementService.removeActiveOrder(orderId)
        }
    }
}
