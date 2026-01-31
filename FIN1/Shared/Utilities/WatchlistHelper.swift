import Foundation

// MARK: - Watchlist Helper
/// Shared utilities for watchlist operations to avoid DRY violations
struct WatchlistHelper {

    // MARK: - Watchlist Status

    /// Computes watchlist status mapping usernames to boolean values
    /// - Parameters:
    ///   - watchlistService: The watchlist service containing watchlist items
    ///   - traderDataService: The trader data service to look up traders
    /// - Returns: Dictionary mapping username to true if in watchlist
    static func getWatchlistStatus(
        watchlistService: any InvestorWatchlistServiceProtocol,
        traderDataService: any TraderDataServiceProtocol
    ) -> [String: Bool] {
        var status: [String: Bool] = [:]
        for watchlistItem in watchlistService.watchlist {
            if let trader = traderDataService.getTrader(by: watchlistItem.id) {
                status[trader.username] = true
            }
        }
        return status
    }

    // MARK: - Watchlist Toggle Handler

    /// Creates a watchlist toggle handler closure for a trader
    /// - Parameters:
    ///   - traderID: The trader ID to toggle
    ///   - traderDataService: The trader data service to look up trader details
    ///   - watchlistService: The watchlist service to add/remove from
    /// - Returns: A closure that handles watchlist toggle operations
    static func createWatchlistToggleHandler(
        traderID: String,
        traderDataService: any TraderDataServiceProtocol,
        watchlistService: any InvestorWatchlistServiceProtocol
    ) -> ((Bool) -> Void) {
        return { isWatched in
            Task {
                if isWatched {
                    if let trader = traderDataService.getTrader(by: traderID) {
                        let item = WatchlistTraderData(
                            id: traderID,
                            name: trader.username,
                            image: "person.circle.fill",
                            performance: trader.totalReturn,
                            riskClass: .riskClass3,
                            totalInvestors: 0,
                            minimumInvestment: 0,
                            description: trader.specialization,
                            tradingStrategy: trader.specialization,
                            experience: "\(trader.experienceYears) years",
                            dateAdded: Date(),
                            lastUpdated: Date(),
                            isActive: true,
                            notificationsEnabled: false
                        )
                        try? await watchlistService.addToWatchlist(item)
                    }
                } else {
                    try? await watchlistService.removeFromWatchlist(traderID)
                }
            }
        }
    }
}
