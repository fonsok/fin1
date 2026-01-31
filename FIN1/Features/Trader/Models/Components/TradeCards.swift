import SwiftUI

// MARK: - Trade Cards Preview
/// This file now serves as a preview container for the extracted card components.
/// Individual card components have been moved to separate files for better organization.

struct TradeCards_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Active Order Card Preview
            ActiveOrderCard(order: MockActiveOrder(
                symbol: "AAPL",
                type: "buy",
                quantity: 100,
                price: 150.0,
                totalAmount: 15000.0,
                status: "active",
                currentPnl: 250.0,
                durationDays: 2
            ))

            // Completed Trade Card Preview
            CompletedTradeCard(trade: MockCompletedTrade(
                symbol: "TSLA",
                buyOrder: MockOrderBuy(
                    symbol: "TSLA",
                    description: "Tesla Inc.",
                    quantity: 50,
                    price: 200.0,
                    totalAmount: 10000.0,
                    status: "completed",
                    createdAt: Date(),
                    executedAt: Date(),
                    confirmedAt: Date(),
                    updatedAt: Date(),
                    optionDirection: nil,
                    underlyingAsset: "Tesla",
                    wkn: "A1CX3T"
                ),
                sellOrder: MockOrderSell(
                    symbol: "TSLA",
                    description: "Tesla Inc.",
                    quantity: 50,
                    price: 220.0,
                    totalAmount: 11000.0,
                    status: "completed",
                    createdAt: Date(),
                    executedAt: Date(),
                    confirmedAt: Date(),
                    updatedAt: Date()
                ),
                entryPrice: 200.0,
                exitPrice: 220.0,
                quantity: 50,
                finalPnl: 1000.0,
                roi: 10.0,
                completedDate: Date()
            ))

            // Order Card Preview
            OrderCard(order: Order(
                id: "preview",
                traderId: "preview",
                symbol: "AAPL",
                description: "Apple Inc.",
                type: .buy,
                quantity: 100,
                price: 150.0,
                totalAmount: 15000.0,
                createdAt: Date(),
                executedAt: nil,
                confirmedAt: nil,
                updatedAt: Date(),
                originalHoldingId: nil, // Preview data
                status: "submitted"
            ), position: 1)
        }
        .padding()
        .background(AppTheme.screenBackground)
    }
}
