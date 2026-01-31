import Foundation
import Combine

// MARK: - Investor Watchlist View Model
/// ViewModel for InvestorWatchlistView following MVVM architecture
@MainActor
final class InvestorWatchlistViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var watchedTraders: [MockTrader] = []

    // MARK: - Dependencies
    private let watchlistService: any InvestorWatchlistServiceProtocol
    private let traderDataService: any TraderDataServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(watchlistService: any InvestorWatchlistServiceProtocol, traderDataService: any TraderDataServiceProtocol) {
        self.watchlistService = watchlistService
        self.traderDataService = traderDataService
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe watchlist changes via NotificationCenter (service posts notifications)
        NotificationCenter.default.publisher(for: .init("WatchlistUpdated"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateWatchedTraders()
            }
            .store(in: &cancellables)

        // Initial load
        updateWatchedTraders()
    }

    private func updateWatchedTraders() {
        watchedTraders = mapWatchlistToTraders()
    }

    // MARK: - Business Logic Methods

    /// Maps watchlist items to MockTrader objects
    private func mapWatchlistToTraders() -> [MockTrader] {
        watchlistService.watchlist.map { trader in
            // Preserve the original ID from WatchlistTraderData
            let originalID = UUID(uuidString: trader.id) ?? UUID()
            return MockTrader(
                id: originalID,
                name: trader.name,
                username: trader.name.replacingOccurrences(of: " ", with: "").lowercased(),
                specialization: trader.tradingStrategy,
                experienceYears: 0,
                isVerified: true,
                performance: trader.performance,
                totalTrades: 0,
                winRate: 0,
                averageReturn: trader.performance,
                totalReturn: trader.performance,
                riskLevel: .medium,
                recentTrades: [],
                lastNTrades: 0,
                successfulTradesInLastN: 0,
                averageReturnLastNTrades: 0,
                consecutiveWinningTrades: 0,
                maxDrawdown: 0,
                sharpeRatio: 0
            )
        }
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
    }

    func showError(_ error: AppError) {
        errorMessage = error.errorDescription ?? "An error occurred"
    }
}
