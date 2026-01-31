import Foundation

// MARK: - Trade API Service Protocol

/// Protocol for fetching and saving trades to Parse Server backend
protocol TradeAPIServiceProtocol {
    /// Fetches all completed trades for a specific trader
    func fetchTrades(for traderId: String) async throws -> [Trade]

    /// Fetches a single trade by ID
    func fetchTrade(tradeId: String) async throws -> Trade?

    /// Saves a trade to the Parse Server (creates or updates)
    func saveTrade(_ trade: Trade) async throws -> Trade

    /// Updates an existing trade on the Parse Server
    func updateTrade(_ trade: Trade) async throws -> Trade
}

// MARK: - Parse Trade Model

/// Parse Server representation of a Trade
/// Maps between Parse format and app Trade model
struct ParseTrade: Codable {
    let objectId: String
    let tradeNumber: Int
    let traderId: String
    let symbol: String
    let description: String
    let status: String
    let createdAt: String
    let updatedAt: String
    let completedAt: String?
    let calculatedProfit: Double?

    // Nested order data (stored as JSON in Parse)
    let buyOrder: ParseOrderBuy
    let sellOrder: ParseOrderSell?
    let sellOrders: [ParseOrderSell]?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case objectId
        case tradeNumber
        case traderId
        case symbol
        case description
        case status
        case createdAt
        case updatedAt
        case completedAt
        case calculatedProfit
        case buyOrder
        case sellOrder
        case sellOrders
    }

    // MARK: - Conversion to Trade Model

    func toTrade() throws -> Trade {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: updatedAt) ?? Date()
        let completedDate = completedAt.flatMap { dateFormatter.date(from: $0) }

        let tradeStatus = TradeStatus(rawValue: status) ?? .pending

        let buyOrderModel = try buyOrder.toOrderBuy()

        let sellOrderModel = sellOrder.flatMap { try? $0.toOrderSell() }
        let sellOrdersModel = (sellOrders ?? []).compactMap { try? $0.toOrderSell() }

        return Trade(
            id: objectId,
            tradeNumber: tradeNumber,
            traderId: traderId,
            symbol: symbol,
            description: description,
            buyOrder: buyOrderModel,
            sellOrder: sellOrderModel,
            sellOrders: sellOrdersModel,
            status: tradeStatus,
            createdAt: createdDate,
            completedAt: completedDate,
            updatedAt: updatedDate,
            calculatedProfit: calculatedProfit
        )
    }
}

// MARK: - Parse Order Models

struct ParseOrderBuy: Codable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: String
    let executedAt: String?
    let confirmedAt: String?
    let updatedAt: String
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let orderInstruction: String?
    let limitPrice: Double?

    func toOrderBuy() throws -> OrderBuy {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: updatedAt) ?? Date()
        let executedDate = executedAt.flatMap { dateFormatter.date(from: $0) }
        let confirmedDate = confirmedAt.flatMap { dateFormatter.date(from: $0) }

        // Parse status string to OrderBuyStatus enum
        let orderStatus = OrderBuyStatus(rawValue: status) ?? .submitted

        return OrderBuy(
            id: id,
            traderId: traderId,
            symbol: symbol,
            description: description,
            quantity: quantity,
            price: price,
            totalAmount: totalAmount,
            status: orderStatus,
            createdAt: createdDate,
            executedAt: executedDate,
            confirmedAt: confirmedDate,
            updatedAt: updatedDate,
            optionDirection: optionDirection,
            underlyingAsset: underlyingAsset,
            wkn: wkn,
            category: category,
            strike: strike,
            orderInstruction: orderInstruction,
            limitPrice: limitPrice
        )
    }
}

struct ParseOrderSell: Codable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: String
    let executedAt: String?
    let confirmedAt: String?
    let updatedAt: String
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let orderInstruction: String?
    let limitPrice: Double?
    let originalHoldingId: String?

    func toOrderSell() throws -> OrderSell {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: updatedAt) ?? Date()
        let executedDate = executedAt.flatMap { dateFormatter.date(from: $0) }
        let confirmedDate = confirmedAt.flatMap { dateFormatter.date(from: $0) }

        // Parse status string to OrderSellStatus enum
        let orderStatus = OrderSellStatus(rawValue: status) ?? .submitted

        return OrderSell(
            id: id,
            traderId: traderId,
            symbol: symbol,
            description: description,
            quantity: quantity,
            price: price,
            totalAmount: totalAmount,
            status: orderStatus,
            createdAt: createdDate,
            executedAt: executedDate,
            confirmedAt: confirmedDate,
            updatedAt: updatedDate,
            optionDirection: optionDirection,
            underlyingAsset: underlyingAsset,
            wkn: wkn,
            category: category,
            strike: strike,
            orderInstruction: orderInstruction,
            limitPrice: limitPrice,
            originalHoldingId: originalHoldingId
        )
    }
}

// MARK: - Trade API Service Implementation

/// Service for fetching trades from Parse Server backend
final class TradeAPIService: TradeAPIServiceProtocol {

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

        // Build Parse query: fetch all trades for this trader
        let query: [String: Any] = [
            "traderId": traderId
        ]

        // Order by creation date (newest first)
        let orderBy = "-createdAt"

        // Fetch from Parse Server
        let parseTrades: [ParseTrade] = try await apiClient.fetchObjects(
            className: className,
            query: query,
            include: nil,
            orderBy: orderBy,
            limit: 1000 // Max limit for Parse Server
        )

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
            let parseTrade: ParseTrade = try await apiClient.fetchObject(
                className: className,
                objectId: tradeId,
                include: nil
            )

            return try parseTrade.toTrade()
        } catch {
            print("⚠️ TradeAPIService: Failed to fetch trade \(tradeId): \(error)")
            return nil
        }
    }

    func saveTrade(_ trade: Trade) async throws -> Trade {
        print("📡 TradeAPIService: Saving trade #\(trade.tradeNumber) to Parse Server")

        let parseInput = ParseTradeInput.from(trade: trade)

        let response = try await apiClient.createObject(
            className: className,
            object: parseInput
        )

        print("✅ TradeAPIService: Trade saved with objectId: \(response.objectId)")

        // Return trade with Parse objectId
        return Trade(
            id: response.objectId,
            tradeNumber: trade.tradeNumber,
            traderId: trade.traderId,
            symbol: trade.symbol,
            description: trade.description,
            buyOrder: trade.buyOrder,
            sellOrder: trade.sellOrder,
            sellOrders: trade.sellOrders,
            status: trade.status,
            createdAt: trade.createdAt,
            completedAt: trade.completedAt,
            updatedAt: trade.updatedAt,
            calculatedProfit: trade.calculatedProfit
        )
    }

    func updateTrade(_ trade: Trade) async throws -> Trade {
        print("📡 TradeAPIService: Updating trade #\(trade.tradeNumber) on Parse Server")

        let parseInput = ParseTradeInput.from(trade: trade)

        _ = try await apiClient.updateObject(
            className: className,
            objectId: trade.id,
            object: parseInput
        )

        print("✅ TradeAPIService: Trade #\(trade.tradeNumber) updated successfully")
        return trade
    }
}

// MARK: - Parse Trade Input Model

/// Model for sending trade data to Parse Server
private struct ParseTradeInput: Encodable {
    let tradeNumber: Int
    let traderId: String
    let symbol: String
    let description: String
    let status: String
    let calculatedProfit: Double?
    let completedAt: String?
    let buyOrder: ParseOrderBuyInput
    let sellOrder: ParseOrderSellInput?
    let sellOrders: [ParseOrderSellInput]?

    static func from(trade: Trade) -> ParseTradeInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return ParseTradeInput(
            tradeNumber: trade.tradeNumber,
            traderId: trade.traderId,
            symbol: trade.symbol,
            description: trade.description,
            status: trade.status.rawValue,
            calculatedProfit: trade.calculatedProfit,
            completedAt: trade.completedAt.map { dateFormatter.string(from: $0) },
            buyOrder: ParseOrderBuyInput.from(order: trade.buyOrder),
            sellOrder: trade.sellOrder.map { ParseOrderSellInput.from(order: $0) },
            sellOrders: trade.sellOrders.isEmpty ? nil : trade.sellOrders.map { ParseOrderSellInput.from(order: $0) }
        )
    }
}

private struct ParseOrderBuyInput: Encodable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: String
    let executedAt: String?
    let confirmedAt: String?
    let updatedAt: String
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let orderInstruction: String?
    let limitPrice: Double?

    static func from(order: OrderBuy) -> ParseOrderBuyInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return ParseOrderBuyInput(
            id: order.id,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: order.status.rawValue,
            createdAt: dateFormatter.string(from: order.createdAt),
            executedAt: order.executedAt.map { dateFormatter.string(from: $0) },
            confirmedAt: order.confirmedAt.map { dateFormatter.string(from: $0) },
            updatedAt: dateFormatter.string(from: order.updatedAt),
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice
        )
    }
}

private struct ParseOrderSellInput: Encodable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: String
    let executedAt: String?
    let confirmedAt: String?
    let updatedAt: String
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let orderInstruction: String?
    let limitPrice: Double?
    let originalHoldingId: String?

    static func from(order: OrderSell) -> ParseOrderSellInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return ParseOrderSellInput(
            id: order.id,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: order.status.rawValue,
            createdAt: dateFormatter.string(from: order.createdAt),
            executedAt: order.executedAt.map { dateFormatter.string(from: $0) },
            confirmedAt: order.confirmedAt.map { dateFormatter.string(from: $0) },
            updatedAt: dateFormatter.string(from: order.updatedAt),
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice,
            originalHoldingId: order.originalHoldingId
        )
    }
}

