import Foundation
import SwiftUI

// MARK: - Dashboard Trader Overview ViewModel
/// Provides cached rows for the trader performance table and watchlist interactions
@MainActor
final class DashboardTraderOverviewViewModel: ObservableObject {
    // MARK: - Dependencies
    private let traderDataService: any TraderDataServiceProtocol
    private let watchlistService: any InvestorWatchlistServiceProtocol

    // MARK: - Outputs
    @Published var cachedRows: [TableRowData] = []
    @Published var busyUsernames: Set<String> = []
    @Published var lastWatchlistError: String?

    // MARK: - Callbacks
    var onTraderTap: ((String) -> Void)?

    // MARK: - Init
    init(
        traderDataService: any TraderDataServiceProtocol,
        watchlistService: any InvestorWatchlistServiceProtocol
    ) {
        self.traderDataService = traderDataService
        self.watchlistService = watchlistService
        self.updateCachedData()
    }

    // MARK: - Public API
    func updateCachedData() {
        let traders = self.traderDataService.traders
            .sorted { $0.performance > $1.performance }

        let watchlistStatus = self.getWatchlistStatus()

        print("📊 [Dashboard] updateCachedData traders=\(traders.count), watchlistStatus.true=\(watchlistStatus.filter { $0.value }.count)")
        self.cachedRows = TableDataFactory.createTraderPerformanceRows(
            from: traders.map { mock in
                TraderData(
                    traderName: mock.username,
                    returnPercentage: String(format: "%.1f%%", mock.performance),
                    successRate: String(format: "%.1f%%", min(max(mock.winRate, 0), 100)),
                    avgReturnPerTrade: String(format: "%.1f%%", mock.averageReturn),
                    isPositive: mock.performance >= 0
                )
            },
            onTraderTap: { [weak self] username in
                self?.onTraderTap?(username)
            },
            onWatchlistToggle: { [weak self] username, isWatched in
                guard let self else { return }
                print("⭐️ [Dashboard] onWatchlistToggle username=\(username), isWatched(next)=\(isWatched)")
                if let trader = self.traderDataService.traders.first(where: { $0.username == username }) {
                    Task { @MainActor in
                        self.busyUsernames.insert(username)
                        self.updateCachedData()
                    }
                    self.handleWatchlistToggle(traderID: trader.id.uuidString, isWatched: isWatched, username: username)
                }
            },
            watchlistStatus: watchlistStatus,
            busyStatus: Dictionary(uniqueKeysWithValues: self.busyUsernames.map { ($0, true) })
        )
    }

    func getTraderID(username: String) -> String? {
        return self.traderDataService.traders.first(where: { $0.username == username })?.id.uuidString
    }

    // MARK: - Private Helpers
    private func getWatchlistStatus() -> [String: Bool] {
        let status = WatchlistHelper.getWatchlistStatus(
            watchlistService: self.watchlistService,
            traderDataService: self.traderDataService
        )
        let ids = self.watchlistService.watchlist.map { $0.id }
        print("🧮 [Dashboard] computing watchlistStatus for ids=\(ids)")
        print("🧮 [Dashboard] watchlistStatus usernames=true -> \(Array(status.keys))")
        return status
    }

    private func handleWatchlistToggle(traderID: String, isWatched: Bool, username: String) {
        print("➡️ [Dashboard] handleWatchlistToggle traderID=\(traderID), isWatched(next)=\(isWatched)")

        // Set busy state immediately
        Task { @MainActor in
            self.busyUsernames.insert(username)
            self.updateCachedData()
        }

        // Use shared helper for core toggle logic, but wrap with error handling
        let toggleHandler = WatchlistHelper.createWatchlistToggleHandler(
            traderID: traderID,
            traderDataService: self.traderDataService,
            watchlistService: self.watchlistService
        )

        // Execute toggle with error handling
        Task {
            if isWatched {
                print("➕ [Dashboard] adding to watchlist: id=\(traderID)")
                toggleHandler(true)
                try? await Task.sleep(nanoseconds: 100_000_000)
                print("✅ [Dashboard] add completed. currentIds=\(self.watchlistService.watchlist.map { $0.id })")
            } else {
                print("➖ [Dashboard] removing from watchlist: id=\(traderID)")
                toggleHandler(false)
                try? await Task.sleep(nanoseconds: 100_000_000)
                print("✅ [Dashboard] remove completed. currentIds=\(self.watchlistService.watchlist.map { $0.id })")
            }

            await MainActor.run {
                self.busyUsernames.remove(username)
                self.updateCachedData()
            }
        }
    }
}
