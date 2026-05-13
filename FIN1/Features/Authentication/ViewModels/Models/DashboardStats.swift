import Foundation

// MARK: - Dashboard Statistics Model
struct DashboardStats {
    var totalInvestmentsValue: Double = 0
    var dailyChange: Double = 0
    var dailyChangePercentage: Double = 0
    var totalInvestments: Int = 0
    var activeTraders: String = "-"

    var isPositiveChange: Bool {
        self.dailyChange >= 0
    }

    var formattedInvestmentsValue: String {
        self.totalInvestmentsValue.formattedAsLocalizedCurrency()
    }

    var formattedDailyChange: String {
        let prefix = self.isPositiveChange ? "+" : ""
        return "\(prefix)\(self.dailyChange.formattedAsLocalizedCurrency())"
    }

    var formattedDailyChangePercentage: String {
        let prefix = self.isPositiveChange ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", self.dailyChangePercentage))%"
    }
}
