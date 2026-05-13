import SwiftUI

// MARK: - Mock Data Models

struct MockPosition: Identifiable {
    let id = UUID()
    let symbol: String
    let companyName: String
    let quantity: Int
    let averagePrice: Double
    let currentPrice: Double
    let marketValue: Double
    let pnl: Double
    let pnlPercent: Double
    let priceChange: Double
}

struct MockDepotHistory: Identifiable {
    let id = UUID()
    let action: String
    let details: String
    let amount: Double
    let icon: String
    let date: Date
}

// MARK: - Mock Data

let mockPositions = [
    MockPosition(
        symbol: "AAPL",
        companyName: "Apple Inc.",
        quantity: 25,
        averagePrice: 170.50,
        currentPrice: 175.43,
        marketValue: 4_386,
        pnl: 123,
        pnlPercent: 2.9,
        priceChange: 4.93
    ),
    MockPosition(
        symbol: "TSLA",
        companyName: "Tesla Inc.",
        quantity: 10,
        averagePrice: 235.00,
        currentPrice: 242.54,
        marketValue: 2_425,
        pnl: 75,
        pnlPercent: 3.2,
        priceChange: 7.54
    ),
    MockPosition(
        symbol: "GOOGL",
        companyName: "Alphabet Inc.",
        quantity: 15,
        averagePrice: 135.00,
        currentPrice: 138.21,
        marketValue: 2_073,
        pnl: 48,
        pnlPercent: 2.4,
        priceChange: 3.21
    )
]

let mockDepotHistory = [
    MockDepotHistory(
        action: "Buy Order Executed",
        details: "AAPL - 25 shares @ $170.50",
        amount: -4_263,
        icon: "arrow.down.circle.fill",
        date: Date().addingTimeInterval(-86_400 * 3)
    ),
    MockDepotHistory(
        action: "Sell Order Executed",
        details: "MSFT - 20 shares @ $320.50",
        amount: 6_410,
        icon: "arrow.up.circle.fill",
        date: Date().addingTimeInterval(-86_400 * 5)
    ),
    MockDepotHistory(
        action: "Dividend Received",
        details: "AAPL - Quarterly dividend",
        amount: 125,
        icon: "dollarsign.circle.fill",
        date: Date().addingTimeInterval(-86_400 * 7)
    )
]
