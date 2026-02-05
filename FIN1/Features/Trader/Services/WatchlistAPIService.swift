import Foundation

// MARK: - Watchlist API Service Protocol

/// Protocol for syncing watchlist to Parse Server backend
protocol WatchlistAPIServiceProtocol {
    /// Saves a watchlist item to the Parse Server
    func saveWatchlistItem(_ item: SearchResult, userId: String) async throws -> SearchResult

    /// Removes a watchlist item from the Parse Server
    func removeWatchlistItem(_ wkn: String, userId: String) async throws

    /// Fetches all watchlist items for a user
    func fetchWatchlist(for userId: String) async throws -> [SearchResult]
}

// MARK: - Parse Watchlist Input

/// Input struct for creating watchlist items on Parse Server
private struct ParseWatchlistInput: Encodable {
    let userId: String
    let wkn: String
    let isin: String
    let valuationDate: String
    let strike: String
    let askPrice: String
    let direction: String?
    let category: String?
    let underlyingType: String?
    let underlyingAsset: String?
    let denomination: Int?
    let subscriptionRatio: Double
    let minimumOrderAmount: Double?

    static func from(item: SearchResult, userId: String) -> ParseWatchlistInput {
        return ParseWatchlistInput(
            userId: userId,
            wkn: item.wkn,
            isin: item.isin,
            valuationDate: item.valuationDate,
            strike: item.strike,
            askPrice: item.askPrice,
            direction: item.direction,
            category: item.category,
            underlyingType: item.underlyingType,
            underlyingAsset: item.underlyingAsset,
            denomination: item.denomination,
            subscriptionRatio: item.subscriptionRatio,
            minimumOrderAmount: item.minimumOrderAmount
        )
    }
}

// MARK: - Parse Watchlist Response

/// Response struct for Parse Server watchlist operations
private struct ParseWatchlistResponse: Codable {
    let objectId: String
    let userId: String
    let wkn: String
    let isin: String
    let valuationDate: String
    let strike: String
    let askPrice: String
    let direction: String?
    let category: String?
    let underlyingType: String?
    let underlyingAsset: String?
    let denomination: Int?
    let subscriptionRatio: Double
    let minimumOrderAmount: Double?

    func toSearchResult() -> SearchResult {
        return SearchResult(
            valuationDate: valuationDate,
            wkn: wkn,
            strike: strike,
            askPrice: askPrice,
            direction: direction,
            category: category,
            underlyingType: underlyingType,
            isin: isin,
            underlyingAsset: underlyingAsset,
            denomination: denomination,
            subscriptionRatio: subscriptionRatio,
            minimumOrderAmount: minimumOrderAmount
        )
    }
}

// MARK: - Watchlist API Service Implementation

/// Service for syncing watchlist with Parse Server backend
final class WatchlistAPIService: WatchlistAPIServiceProtocol {
    private let apiClient: ParseAPIClientProtocol
    private let className = "Watchlist"

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Save Watchlist Item

    func saveWatchlistItem(_ item: SearchResult, userId: String) async throws -> SearchResult {
        print("📡 WatchlistAPIService: Saving watchlist item to Parse Server")

        let input = ParseWatchlistInput.from(item: item, userId: userId)
        let response = try await apiClient.createObject(
            className: className,
            object: input
        )

        print("✅ WatchlistAPIService: Watchlist item saved with objectId: \(response.objectId)")

        // Return item (WKN is the identifier)
        return item
    }

    // MARK: - Remove Watchlist Item

    func removeWatchlistItem(_ wkn: String, userId: String) async throws {
        print("📡 WatchlistAPIService: Removing watchlist item: \(wkn)")

        // First, find the watchlist item by WKN and userId
        let items: [ParseWatchlistResponse] = try await apiClient.fetchObjects(
            className: className,
            query: [
                "userId": userId,
                "wkn": wkn
            ],
            include: nil,
            orderBy: nil,
            limit: 1
        )

        guard let item = items.first else {
            print("⚠️ WatchlistAPIService: Item not found for deletion: \(wkn)")
            return
        }

        try await apiClient.deleteObject(
            className: className,
            objectId: item.objectId
        )

        print("✅ WatchlistAPIService: Watchlist item deleted")
    }

    // MARK: - Fetch Watchlist

    func fetchWatchlist(for userId: String) async throws -> [SearchResult] {
        print("📡 WatchlistAPIService: Fetching watchlist for user: \(userId)")

        let responses: [ParseWatchlistResponse] = try await apiClient.fetchObjects(
            className: className,
            query: ["userId": userId],
            include: nil,
            orderBy: "-createdAt",
            limit: 100
        )

        print("✅ WatchlistAPIService: Fetched \(responses.count) watchlist items")
        return responses.map { $0.toSearchResult() }
    }
}
