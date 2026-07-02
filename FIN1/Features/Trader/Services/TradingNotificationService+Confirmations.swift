import Foundation

extension TradingNotificationService {
    func showBuyConfirmation(for trade: Trade) async {
        await MainActor.run {
            NotificationCenter.default.post(name: .buyOrderCompleted, object: trade)
        }
        print("✅ Buy Confirmation: \(trade.symbol) - \(trade.totalQuantity) shares at €\(trade.entryPrice) each")
    }

    func showSellConfirmation(for trade: Trade) async {
        await MainActor.run {
            NotificationCenter.default.post(name: .sellOrderCompleted, object: trade)
        }
        print("✅ Sell Confirmation: \(trade.symbol) - \(trade.totalQuantity) shares sold at €\(trade.exitPrice ?? 0) each")
    }

    func sendOrderStatusNotification(orderId: String, status: String) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .orderStatusUpdated,
                object: ["orderId": orderId, "status": status]
            )
        }
        print("🔔 Order Status Notification: Order \(orderId) status updated to \(status)")
    }

    func sendTradeCompletionNotification(tradeId: String) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .tradeCompleted,
                object: ["tradeId": tradeId]
            )
        }
        print("🔔 Trade Completion Notification: Trade \(tradeId) completed")
    }

    func sendCommissionSettlementNotification(
        for trade: Trade,
        commissionAmount: Double,
        commissionRate: Double,
        grossProfit: Double,
        netProfit: Double
    ) async {
        let commissionRecord = CommissionRecord(
            tradeId: trade.id,
            traderId: trade.traderId,
            grossProfit: grossProfit,
            commissionRate: commissionRate,
            commissionAmount: commissionAmount,
            netProfit: netProfit
        )

        await MainActor.run {
            NotificationCenter.default.post(
                name: .commissionSettled,
                object: commissionRecord,
                userInfo: [
                    "tradeId": trade.id,
                    "tradeNumber": trade.tradeNumber,
                    "commissionAmount": commissionAmount,
                    "grossProfit": grossProfit,
                    "netProfit": netProfit
                ]
            )
        }

        print("💰 Commission Settlement Notification: Trade #\(trade.tradeNumber)")
        print("   📊 Gross Profit: €\(String(format: "%.2f", grossProfit))")
        print("   💰 Commission: €\(String(format: "%.2f", commissionAmount))")
        print("   💵 Net Profit Distributed: €\(String(format: "%.2f", netProfit))")
        print("   ✅ Commission settled and paid to trader")
    }
}
