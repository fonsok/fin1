import SwiftUI

// MARK: - Trader Details Data Table View
/// Displays trader performance data in a table matching Top Recent Trades style

struct TraderDetailsDataTableView: View {
    let trader: MockTrader
    @Environment(\.appServices) private var appServices
    @State private var watchlistTick: UInt8 = 0

    private func createTableRow() -> TableRowData {
        let watchlistStatus = WatchlistHelper.getWatchlistStatus(
            watchlistService: appServices.watchlistService,
            traderDataService: appServices.traderDataService
        )
        let traderID = trader.id.uuidString

        // Calculate average trades per week (mock calculation based on total trades)
        // Assuming average trader has been active for ~52 weeks (1 year)
        let avgTradesPerWeek = trader.totalTrades > 0 ? Double(trader.totalTrades) / 52.0 : 0.0
        let avgTradesPerWeekString = String(format: "%.1f", avgTradesPerWeek)

        return TableRowData(
            id: trader.username,
            cells: [
                "trader": trader.username,
                "return": String(format: "%.1f%%", trader.performance),
                "avgReturn": String(format: "%.1f%%", trader.averageReturnLastNTrades),
                "successRate": String(format: "%.1f%%", min(max(trader.winRate, 0), 100)),
                "avgReturnPerTrade": String(format: "%.1f%%", trader.averageReturn),
                "avgTrades": avgTradesPerWeekString
            ],
            isPositive: trader.performance >= 0,
            onTap: {},
            onWatchlistToggle: WatchlistHelper.createWatchlistToggleHandler(
                traderID: traderID,
                traderDataService: appServices.traderDataService,
                watchlistService: appServices.watchlistService
            ),
            isInWatchlist: watchlistStatus[trader.username] ?? false,
            isWatchlistBusy: false
        )
    }

    var body: some View {
        _ = watchlistTick // Use watchlistTick to trigger re-render

        return VStack(spacing: ResponsiveDesign.spacing(16)) {
            DataTable.traderPerformanceTable(
                rows: [createTableRow()],
                showTraderColumn: false,
                isInteractive: false
            )
        }
        .onChange(of: appServices.watchlistService.watchlist.count) { _, _ in
            // Trigger view refresh when watchlist changes
            watchlistTick &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("WatchlistUpdated"))) { _ in
            // Also listen to watchlist update notifications
            watchlistTick &+= 1
        }
    }
}
