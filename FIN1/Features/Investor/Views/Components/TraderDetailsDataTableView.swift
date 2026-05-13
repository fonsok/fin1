import SwiftUI

// MARK: - Trader Details Data Table View
/// Displays trader performance data in a table matching Top Recent Trades style

struct TraderDetailsDataTableView: View {
    let trader: MockTrader
    @Environment(\.appServices) private var appServices
    @State private var watchlistTick: UInt8 = 0

    private func createTableRow() -> TableRowData {
        let watchlistStatus = WatchlistHelper.getWatchlistStatus(
            watchlistService: self.appServices.watchlistService,
            traderDataService: self.appServices.traderDataService
        )
        let traderID = self.trader.id.uuidString

        // Calculate average trades per week (mock calculation based on total trades)
        // Assuming average trader has been active for ~52 weeks (1 year)
        let avgTradesPerWeek = self.trader.totalTrades > 0 ? Double(self.trader.totalTrades) / 52.0 : 0.0
        let avgTradesPerWeekString = String(format: "%.1f", avgTradesPerWeek)

        return TableRowData(
            id: self.trader.username,
            cells: [
                "trader": self.trader.username,
                "return": String(format: "%.1f%%", self.trader.performance),
                "avgReturn": String(format: "%.1f%%", self.trader.averageReturnLastNTrades),
                "successRate": String(format: "%.1f%%", min(max(self.trader.winRate, 0), 100)),
                "avgReturnPerTrade": String(format: "%.1f%%", self.trader.averageReturn),
                "avgTrades": avgTradesPerWeekString
            ],
            isPositive: self.trader.performance >= 0,
            onTap: {},
            onWatchlistToggle: WatchlistHelper.createWatchlistToggleHandler(
                traderID: traderID,
                traderDataService: self.appServices.traderDataService,
                watchlistService: self.appServices.watchlistService
            ),
            isInWatchlist: watchlistStatus[self.trader.username] ?? false,
            isWatchlistBusy: false
        )
    }

    var body: some View {
        _ = self.watchlistTick // Use watchlistTick to trigger re-render

        return VStack(spacing: ResponsiveDesign.spacing(16)) {
            DataTable.traderPerformanceTable(
                rows: [self.createTableRow()],
                showTraderColumn: false,
                isInteractive: false
            )
        }
        .onChange(of: self.appServices.watchlistService.watchlist.count) { _, _ in
            // Trigger view refresh when watchlist changes
            self.watchlistTick &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("WatchlistUpdated"))) { _ in
            // Also listen to watchlist update notifications
            self.watchlistTick &+= 1
        }
    }
}
