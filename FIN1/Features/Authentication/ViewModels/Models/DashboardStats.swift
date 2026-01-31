import Foundation

// MARK: - Dashboard Statistics Model
struct DashboardStats {
    var totalPortfolioValue: Double = 0
    var dailyChange: Double = 0
    var dailyChangePercentage: Double = 0
    var totalInvestments: Int = 0
    var activeTraders: String = "-"

    var isPositiveChange: Bool {
        dailyChange >= 0
    }

    var formattedPortfolioValue: String {
        totalPortfolioValue.formattedAsLocalizedCurrency()
    }

    var formattedDailyChange: String {
        let prefix = isPositiveChange ? "+" : ""
        return "\(prefix)\(dailyChange.formattedAsLocalizedCurrency())"
    }

    var formattedDailyChangePercentage: String {
        let prefix = isPositiveChange ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", dailyChangePercentage))%"
    }
}
