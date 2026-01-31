import SwiftUI

// MARK: - Trader Data Model
struct TraderData {
    let traderName: String
    let returnPercentage: String
    let successRate: String
    let avgReturnPerTrade: String
    let isPositive: Bool
}

// Intentionally rely on synthesized memberwise initializer

// MARK: - Data Conversion Helpers
extension TraderData {
    func toTableRowData(
        onTraderTap: @escaping () -> Void,
        onWatchlistToggle: @escaping (Bool) -> Void,
        isInWatchlist: Bool = false,
        isWatchlistBusy: Bool = false
    ) -> TableRowData {
        return TableRowData(
            id: traderName,
            cells: [
                "trader": traderName,
                "return": returnPercentage,
                "successRate": successRate,
                "avgReturnPerTrade": avgReturnPerTrade
            ],
            isPositive: isPositive,
            onTap: onTraderTap,
            onWatchlistToggle: onWatchlistToggle,
            isInWatchlist: isInWatchlist,
            isWatchlistBusy: isWatchlistBusy
        )
    }
}

// MARK: - Table Data Factory
struct TableDataFactory {
    static func createTraderPerformanceRows(
        from traders: [TraderData],
        onTraderTap: @escaping (String) -> Void,
        onWatchlistToggle: @escaping (String, Bool) -> Void,
        watchlistStatus: [String: Bool] = [:],
        busyStatus: [String: Bool] = [:]
    ) -> [TableRowData] {
        return traders.map { trader in
            trader.toTableRowData(
                onTraderTap: {
                    // Pass the traderName as-is (may include "@" prefix)
                    onTraderTap(trader.traderName)
                },
                onWatchlistToggle: { isWatched in
                    // Pass the traderName as-is (may include "@" prefix)
                    onWatchlistToggle(trader.traderName, isWatched)
                },
                isInWatchlist: watchlistStatus[trader.traderName] ?? false,
                isWatchlistBusy: busyStatus[trader.traderName] ?? false
            )
        }
    }

    static func createSingleTraderRow(
        traderName: String,
        returnPercentage: String,
        successRate: String,
        avgReturnPerTrade: String,
        isPositive: Bool = true,
        onWatchlistToggle: @escaping (Bool) -> Void,
        isInWatchlist: Bool = false
    ) -> TableRowData {
        return TableRowData(
            id: traderName,
            cells: [
                "trader": traderName,
                "return": returnPercentage,
                "successRate": successRate,
                "avgReturnPerTrade": avgReturnPerTrade
            ],
            isPositive: isPositive,
            onWatchlistToggle: onWatchlistToggle,
            isInWatchlist: isInWatchlist
        )
    }

    // MARK: - Trader Details Table Row Factory
    static func createTraderDetailsRow(
        traderID: String,
        returnLastTrade: String,
        successRate: String,
        avgReturnPerTrade: String,
        isPositive: Bool = true,
        onWatchlistToggle: ((Bool) -> Void)? = nil,
        isInWatchlist: Bool = false,
        isWatchlistBusy: Bool = false
    ) -> TableRowData {
        // Generate random number between 1 and 10 (inclusive)
        let randomSuccessfulTrades = Int.random(in: 1...10)

        return TableRowData(
            id: traderID,
            cells: [
                "returnLastTrade": returnLastTrade,
                "successRate": successRate,
                "avgReturnPerTrade": avgReturnPerTrade,
                "successfulTradesInLastN": "\(randomSuccessfulTrades)"
            ],
            isPositive: isPositive,
            onWatchlistToggle: onWatchlistToggle,
            isInWatchlist: isInWatchlist,
            isWatchlistBusy: isWatchlistBusy
        )
    }
}
