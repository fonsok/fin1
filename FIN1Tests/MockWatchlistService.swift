import Foundation
import Combine
@testable import FIN1

// MARK: - Mock Watchlist Service
class MockWatchlistService: SecuritiesWatchlistServiceProtocol {
    @Published var watchlist: [SearchResult] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Test configuration
    var shouldThrowError = false
    var errorToThrow: AppError = AppError.unknownError("Test error")

    func loadWatchlist() async throws {
        if shouldThrowError {
            throw errorToThrow
        }

        // Create test watchlist items
        let testItems = [
            SearchResult(
                valuationDate: "31.12.2000",
                wkn: "SG3D56",
                strike: "22.200",
                askPrice: "1,23",
                direction: "Call",
                isin: "DE000SG3D56",
                underlyingAsset: "Apple"
            ),
            SearchResult(
                valuationDate: "31.12.2000",
                wkn: "SG7A89",
                strike: "15.500",
                askPrice: "2,45",
                direction: "Call",
                isin: "DE000SG7A89",
                underlyingAsset: "DAX"
            )
        ]

        await MainActor.run {
            self.watchlist = testItems
        }
    }

    func addToWatchlist(_ item: SearchResult) async throws {
        if shouldThrowError {
            throw errorToThrow
        }

        await MainActor.run {
            if !self.watchlist.contains(where: { $0.wkn == item.wkn }) {
                self.watchlist.append(item)
            }
        }
    }

    func removeFromWatchlist(_ wkn: String) async throws {
        if shouldThrowError {
            throw errorToThrow
        }

        await MainActor.run {
            self.watchlist.removeAll { $0.wkn == wkn }
        }
    }

    func clearWatchlist() async throws { watchlist.removeAll() }
    func isInWatchlist(_ wkn: String) -> Bool { watchlist.contains { $0.wkn == wkn } }
    func refreshWatchlist() async throws { /* no-op */ }
}
