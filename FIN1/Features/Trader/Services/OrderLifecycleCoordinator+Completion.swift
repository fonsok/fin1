import Foundation

// MARK: - Order completion routing (status progression callback)

extension OrderLifecycleCoordinator {

    func handleOrderCompletion(orderId: String, status: String, order: Order) async {
        if order.type == .buy, status == "executed" {
            if let pairId = order.pairExecutionId?.trimmingCharacters(in: .whitespacesAndNewlines),
               !pairId.isEmpty,
               self.orderManagementService.pairedBuyExecutionId(for: orderId) == nil {
                self.orderManagementService.registerPairedBuyExecutionLink(
                    orderId: orderId,
                    pairExecutionId: pairId
                )
            }

            if self.orderManagementService.pairedBuyExecutionId(for: orderId) != nil {
                do {
                    try await self.orderManagementService.ensurePairedBuyFinalized(for: orderId)
                    try? await self.tradeLifecycleService.refreshCompletedTrades()
                    await self.refreshInvestmentsAfterPoolMirrorActivation()
                } catch {
                    print("❌ OrderLifecycleCoordinator: Paired buy finalize failed — \(error.localizedDescription)")
                    self.orderManagementService.reportOrderStatusFailure(
                        "Pool-Mirror konnte nicht ausgeführt werden: \(error.localizedDescription). Wird erneut versucht …"
                    )
                }
            }
        }

        if order.type == .sell && status == "executed" {
            await self.orderManagementService.syncActiveOrderToBackend(orderId)
            try? await self.tradeLifecycleService.refreshCompletedTrades()
        }

        await self.tradingNotificationService.sendOrderStatusNotification(orderId: orderId, status: status)

        if status == "completed" {
            if let auditLoggingService = auditLoggingService {
                let userId = self.userService.currentUser?.id ?? order.traderId
                let orderType = order.type == .buy ? "Buy" : "Sell"
                let underlyingAsset = order.underlyingAsset ?? order.description
                let complianceEvent = ComplianceEvent(
                    eventType: .orderCompleted,
                    agentId: userId,
                    customerId: userId,
                    description: "\(orderType) order completed: \(underlyingAsset) - \(order.quantity) @ €\(order.price.formatted(.number.precision(.fractionLength(2))))",
                    severity: .medium,
                    requiresReview: false,
                    notes: "Order ID: \(orderId), Symbol: \(order.symbol), Total: €\(order.totalAmount.formatted(.number.precision(.fractionLength(2))))"
                )

                Task {
                    await auditLoggingService.logComplianceEvent(complianceEvent)
                }
            }

            if order.type == .buy {
                await self.handleBuyOrderCompletion(orderId: orderId, order: order)
            } else if order.type == .sell {
                await self.handleSellOrderCompletion(orderId: orderId, order: order)
            }
        }
    }
}
