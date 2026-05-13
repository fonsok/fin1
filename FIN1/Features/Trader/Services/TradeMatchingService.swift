import Foundation

// MARK: - Trade Matching Service Implementation
/// Handles complex business logic for matching sell orders with existing trades
/// Extracted from TraderService to improve maintainability and testability
final class TradeMatchingService: TradeMatchingServiceProtocol, @unchecked Sendable {
    private let holdingsConversionService: HoldingsConversionServiceProtocol

    init(holdingsConversionService: HoldingsConversionServiceProtocol = HoldingsConversionService.shared) {
        self.holdingsConversionService = holdingsConversionService
    }

    // MARK: - Trade Matching

    func findAndUpdateTradeWithSellOrder(
        sellOrder: OrderSell,
        trades: [Trade],
        tradeLifecycleService: any TradeLifecycleServiceProtocol
    ) async -> Trade? {
        // Try primary matching by originalHoldingId
        if let trade = await matchByOriginalHoldingId(
            sellOrder: sellOrder,
            trades: trades,
            tradeLifecycleService: tradeLifecycleService
        ) {
            return trade
        }

        // Fallback to WKN and timestamp matching
        return await self.matchByWknAndTimestamp(
            sellOrder: sellOrder,
            trades: trades,
            tradeLifecycleService: tradeLifecycleService
        )
    }

    /// Adds a partial sell order to an existing trade
    func addPartialSellOrderToTrade(
        tradeId: String,
        sellOrder: OrderSell,
        trades: [Trade],
        tradeLifecycleService: any TradeLifecycleServiceProtocol
    ) async -> Trade? {
        guard let tradeIndex = trades.firstIndex(where: { $0.id == tradeId }) else {
            print("❌ DEBUG: Trade with ID \(tradeId) not found")
            return nil
        }

        let trade = trades[tradeIndex]

        // Validate that the sell quantity doesn't exceed remaining quantity
        let remainingQuantity = trade.remainingQuantity
        if sellOrder.quantity > remainingQuantity {
            print("❌ DEBUG: Sell quantity \(sellOrder.quantity) exceeds remaining quantity \(remainingQuantity)")
            return nil
        }

        // Add the partial sell order to the trade
        let updatedTrade = trade.withPartialSellOrder(sellOrder)

        do {
            try await tradeLifecycleService.addPartialSellOrderToTrade(tradeId, sellOrder: sellOrder)
            self.logSuccessfulPartialSale(trade: trade, sellOrder: sellOrder)
            return updatedTrade
        } catch {
            self.logPartialSaleError(trade: trade, sellOrder: sellOrder, error: error)
            return nil
        }
    }

    // MARK: - Holdings Conversion

    func getHoldingsFromTrades(_ trades: [Trade]) -> [DepotHolding] {
        var positionCounter = 1
        return trades.map { trade in
            defer { positionCounter += 1 }
            return DepotHolding.from(completedOrder: trade.buyOrder, position: positionCounter)
        }
    }

    /// Creates a DepotBestand from a trade, accounting for partial sales
    /// Uses centralized HoldingsConversionService as SINGLE SOURCE OF TRUTH
    private func createHoldingFromTrade(_ trade: Trade, position: Int) -> DepotHolding {
        return self.holdingsConversionService.createHolding(
            from: trade,
            position: position,
            ongoingOrders: []  // No ongoing orders context in matching service
        )
    }

    // MARK: - Private Matching Methods

    private func matchByOriginalHoldingId(
        sellOrder: OrderSell,
        trades: [Trade],
        tradeLifecycleService: any TradeLifecycleServiceProtocol
    ) async -> Trade? {
        guard let originalHoldingId = sellOrder.originalHoldingId else {
            print("❌ DEBUG: matchByOriginalHoldingId - sellOrder has no originalHoldingId")
            return nil
        }

        print("🔍 DEBUG: matchByOriginalHoldingId - looking for originalHoldingId: \(originalHoldingId)")

        // Create holdings using the same logic as TraderDepotViewModel.createHoldingFromTrade
        // This ensures we account for partial sales when matching
        var positionCounter = 1
        let holdings = trades.map { trade in
            defer { positionCounter += 1 }
            return self.createHoldingFromTrade(trade, position: positionCounter)
        }

        print("🔍 DEBUG: Available holdings orderIds: \(holdings.map { $0.orderId })")

        guard let holding = holdings.first(where: { $0.orderId == originalHoldingId }),
              let buyOrderId = holding.orderId else {
            print("❌ DEBUG: No holding found with originalHoldingId \(originalHoldingId)")
            return nil
        }

        print("🔍 DEBUG: Found holding with orderId: \(buyOrderId)")

        return await self.findAndUpdateTradeByBuyOrderId(
            buyOrderId: buyOrderId,
            sellOrder: sellOrder,
            trades: trades,
            tradeLifecycleService: tradeLifecycleService,
            matchType: "originalHoldingId \(originalHoldingId)"
        )
    }

    private func matchByWknAndTimestamp(
        sellOrder: OrderSell,
        trades: [Trade],
        tradeLifecycleService: any TradeLifecycleServiceProtocol
    ) async -> Trade? {
        // Strict separation guard:
        // If originalHoldingId is missing, only allow fallback matching when it is unambiguous.
        let candidates = trades.filter { trade in
            guard trade.wkn == sellOrder.wkn else { return false }
            return trade.remainingQuantity > 0
        }

        guard !candidates.isEmpty else {
            self.logNoMatchFound(sellOrder: sellOrder)
            return nil
        }

        guard candidates.count == 1 else {
            print(
                "❌ DEBUG: Ambiguous WKN fallback match (\(candidates.count) candidates) for sell order \(sellOrder.id) - refusing cross-trade assignment"
            )
            return nil
        }

        let trade = candidates[0]
        return await self.updateTradeWithSellOrder(
            trade: trade,
            sellOrder: sellOrder,
            tradeLifecycleService: tradeLifecycleService,
            matchType: "WKN \(sellOrder.wkn ?? "unknown") and timestamp"
        )
    }

    private func findAndUpdateTradeByBuyOrderId(
        buyOrderId: String,
        sellOrder: OrderSell,
        trades: [Trade],
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        matchType: String
    ) async -> Trade? {
        guard let tradeIndex = trades.firstIndex(where: { trade in
            trade.buyOrder.id == buyOrderId
        }) else {
            return nil
        }

        let trade = trades[tradeIndex]
        return await self.updateTradeWithSellOrder(
            trade: trade,
            sellOrder: sellOrder,
            tradeLifecycleService: tradeLifecycleService,
            matchType: matchType
        )
    }

    private func updateTradeWithSellOrder(
        trade: Trade,
        sellOrder: OrderSell,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        matchType: String
    ) async -> Trade? {
        let updatedTrade = trade.withPartialSellOrder(sellOrder).updateStatus()

        do {
            try await tradeLifecycleService.addPartialSellOrderToTrade(trade.id, sellOrder: sellOrder)
            self.logSuccessfulMatch(trade: trade, sellOrder: sellOrder, matchType: matchType)
            return updatedTrade
        } catch {
            self.logUpdateError(trade: trade, sellOrder: sellOrder, error: error)
            return nil
        }
    }

    // MARK: - Logging

    private func logSuccessfulMatch(trade: Trade, sellOrder: OrderSell, matchType: String) {
        print("🔍 DEBUG: Found and updated Trade \(trade.id) with sell order \(sellOrder.id) using \(matchType)")
    }

    private func logNoMatchFound(sellOrder: OrderSell) {
        print(
            "❌ DEBUG: No matching Trade found for sell order \(sellOrder.id) with originalHoldingId \(sellOrder.originalHoldingId ?? "nil") and WKN \(sellOrder.wkn ?? "unknown")"
        )
    }

    private func logUpdateError(trade: Trade, sellOrder: OrderSell, error: Error) {
        print("❌ DEBUG: Failed to update Trade \(trade.id) with sell order \(sellOrder.id): \(error.localizedDescription)")
    }

    private func logSuccessfulPartialSale(trade: Trade, sellOrder: OrderSell) {
        print(
            "🔍 DEBUG: Successfully added partial sell order \(sellOrder.id) to Trade \(trade.id). Quantity: \(sellOrder.quantity), Remaining: \(trade.remainingQuantity)"
        )
    }

    private func logPartialSaleError(trade: Trade, sellOrder: OrderSell, error: Error) {
        print("❌ DEBUG: Failed to add partial sell order \(sellOrder.id) to Trade \(trade.id): \(error.localizedDescription)")
    }
}
