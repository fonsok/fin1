import Foundation
import SwiftUI

// MARK: - Watchlist Trader Data Model
struct WatchlistTraderData: Identifiable, Sendable {
    let id: String
    let name: String
    let image: String
    let performance: Double
    let riskClass: RiskClass
    let totalInvestors: Int
    let minimumInvestment: Double
    let description: String
    let tradingStrategy: String
    let experience: String
    let dateAdded: Date
    var lastUpdated: Date
    var isActive: Bool
    var notificationsEnabled: Bool

    var formattedPerformance: String {
        "\(String(format: "%.1f", performance))%"
    }

    var formattedMinimumInvestment: String {
        minimumInvestment.formattedAsLocalizedCurrency()
    }

    var isPositivePerformance: Bool {
        performance >= 0
    }
}
