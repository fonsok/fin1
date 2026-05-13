import Combine
import SwiftUI

// MARK: - Trades Overview Filtering View Model

@MainActor
final class TradesOverviewFilteringViewModel: ObservableObject {
    @Published var filteredOngoingTrades: [TradeOverviewItem] = []
    @Published var filteredCompletedTrades: [TradeOverviewItem] = []

    private var ongoingTrades: [TradeOverviewItem] = []
    private var completedTrades: [TradeOverviewItem] = []

    /// Updates the trade lists and applies current filters
    func updateTrades(ongoing: [TradeOverviewItem], completed: [TradeOverviewItem]) {
        self.ongoingTrades = ongoing
        self.completedTrades = completed
    }

    /// Filters trades by time period
    /// - Parameter period: Time period to filter by
    func filterTrades(by period: TradeTimePeriod) async {
        // Filter ongoing trades (always show all ongoing trades regardless of time period)
        self.filteredOngoingTrades = self.ongoingTrades

        // Filter completed trades by time period
        // When "Alle" is selected, show all trades without date filtering
        if period == .allTime {
            self.filteredCompletedTrades = self.completedTrades
        } else {
            let cutoffDate = self.getCutoffDate(for: period)
            self.filteredCompletedTrades = self.completedTrades.filter { $0.endDate >= cutoffDate }
        }
    }

    /// Gets the cutoff date for a given time period
    private func getCutoffDate(for period: TradeTimePeriod) -> Date {
        let calendar = Calendar.current
        switch period {
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        case .last90Days:
            return calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        case .allTime:
            return Calendar.current.date(from: DateComponents(year: 2_000, month: 1, day: 1)) ?? Date()
        }
    }
}







