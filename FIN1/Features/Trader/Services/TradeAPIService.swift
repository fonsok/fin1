import Foundation

// MARK: - Trade API Service Protocol

/// Protocol for fetching and saving trades to Parse Server backend
protocol TradeAPIServiceProtocol: Sendable {
    /// Fetches all completed trades for a specific trader
    func fetchTrades(for traderId: String) async throws -> [Trade]

    /// Fetches a single trade by ID
    func fetchTrade(tradeId: String) async throws -> Trade?

    /// Saves a trade to the Parse Server (creates or updates)
    func saveTrade(_ trade: Trade) async throws -> Trade

    /// Updates an existing trade on the Parse Server
    func updateTrade(_ trade: Trade) async throws -> Trade
}

// MARK: - Trade API Service Implementation

/// Service for fetching trades from Parse Server backend
final class TradeAPIService: TradeAPIServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let apiClient: ParseAPIClientProtocol
    private let className = "Trade"

    // MARK: - Initialization

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Public Methods

    func fetchTrades(for traderId: String) async throws -> [Trade] {
        print("📡 TradeAPIService: Fetching trades for trader \(traderId)")
        let response: TradeHistoryFunctionResponse = try await apiClient.callFunction(
            "getTradeHistory",
            parameters: ["limit": 1_000, "skip": 0]
        )
        let parseTrades = response.trades

        print("📡 TradeAPIService: Fetched \(parseTrades.count) trades from Parse Server")

        // Convert Parse models to app Trade models
        var trades: [Trade] = []
        for parseTrade in parseTrades {
            do {
                let trade = try parseTrade.toTrade()
                trades.append(trade)
            } catch {
                print("⚠️ TradeAPIService: Failed to convert Parse trade \(parseTrade.objectId): \(error)")
                // Continue with other trades even if one fails
            }
        }

        print("✅ TradeAPIService: Successfully converted \(trades.count) trades")
        return trades
    }

    func fetchTrade(tradeId: String) async throws -> Trade? {
        print("📡 TradeAPIService: Fetching trade \(tradeId)")

        do {
            let parseTrade: ParseTrade = try await apiClient.callFunction(
                "getTradeById",
                parameters: ["tradeId": tradeId]
            )

            return try parseTrade.toTrade()
        } catch {
            print("⚠️ TradeAPIService: Failed to fetch trade \(tradeId): \(error)")
            return nil
        }
    }

    func saveTrade(_ trade: Trade) async throws -> Trade {
        print("📡 TradeAPIService: Saving trade #\(trade.tradeNumber) via upsertTrade")
        let parseTrade: ParseTrade = try await apiClient.callFunction(
            "upsertTrade",
            parameters: ["trade": makeTradePayload(from: trade, includeObjectId: false)]
        )
        return try parseTrade.toTrade()
    }

    func updateTrade(_ trade: Trade) async throws -> Trade {
        print("📡 TradeAPIService: Updating trade #\(trade.tradeNumber) via upsertTrade")
        let parseTrade: ParseTrade = try await apiClient.callFunction(
            "upsertTrade",
            parameters: ["trade": makeTradePayload(from: trade, includeObjectId: true)]
        )
        return try parseTrade.toTrade()
    }
}

struct TradeHistoryFunctionResponse: Decodable {
    let trades: [ParseTrade]
}
