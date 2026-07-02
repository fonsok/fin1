import Foundation

// MARK: - Unified Order Completion Handler

/// Handles order completion logic for UnifiedOrderService
/// Separated to reduce main service file size and improve maintainability
@MainActor
final class UnifiedOrderCompletionHandler: @unchecked Sendable {
    private let tradingNotificationService: any TradingNotificationServiceProtocol
    private let cashBalanceService: any CashBalanceServiceProtocol
    private let invoiceService: any InvoiceServiceProtocol
    private let tradeNumberService: any TradeNumberServiceProtocol
    private let tradeAPIService: (any TradeAPIServiceProtocol)?

    init(
        tradingNotificationService: any TradingNotificationServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        tradeNumberService: any TradeNumberServiceProtocol,
        tradeAPIService: (any TradeAPIServiceProtocol)? = nil
    ) {
        self.tradingNotificationService = tradingNotificationService
        self.cashBalanceService = cashBalanceService
        self.invoiceService = invoiceService
        self.tradeNumberService = tradeNumberService
        self.tradeAPIService = tradeAPIService
    }

    /// Handles order completion
    func handleOrderCompletion(order: Order, completedTrades: [Trade]) async {
        if order.type == .buy {
            await self.handleBuyOrderCompletion(order: order, completedTrades: completedTrades)
        } else {
            await self.handleSellOrderCompletion(order: order, completedTrades: completedTrades)
        }
    }

    /// Handles buy order completion
    private func handleBuyOrderCompletion(order: Order, completedTrades: [Trade]) async {
        let buyOrder = OrderBuy(from: order)
        let trade = try? await createTrade(from: buyOrder)

        if let trade = trade {
            // Show buy confirmation
            await self.tradingNotificationService.showBuyConfirmation(for: trade)

            // Generate invoice
            await self.tradingNotificationService.generateInvoiceAndNotification(
                for: order,
                tradeId: trade.id,
                tradeNumber: trade.tradeNumber,
                tradeNumberYear: trade.resolvedTradeNumberYear
            )
        }
    }

    /// Handles sell order completion
    private func handleSellOrderCompletion(order: Order, completedTrades: [Trade]) async {
        let sellOrder = OrderSell(from: order)

        // Find matching trade
        let matchingTrade = self.findMatchingTrade(for: sellOrder, in: completedTrades)

        if let trade = matchingTrade {
            let updatedTrade = try? await addSellOrderToTrade(trade.id, sellOrder: sellOrder, in: completedTrades)

            if let updatedTrade = updatedTrade {
                // Show sell confirmation
                await self.tradingNotificationService.showSellConfirmation(for: updatedTrade)

                // Generate invoice
                await self.tradingNotificationService.generateInvoiceAndNotification(
                    for: order,
                    tradeId: updatedTrade.id,
                    tradeNumber: updatedTrade.tradeNumber,
                    tradeNumberYear: updatedTrade.resolvedTradeNumberYear
                )

                // Check if trade is now fully completed and generate Collection Bill
                if updatedTrade.isCompleted {
                    print("🎯 Trade #\(updatedTrade.tradeNumber) is now fully completed - generating Collection Bill")
                    await self.tradingNotificationService.generateCollectionBillDocument(for: updatedTrade)
                }
            }
        } else {
            // Generate invoice even if no trade found
            await self.tradingNotificationService.generateInvoiceAndNotification(
                for: order,
                tradeId: nil,
                tradeNumber: nil,
                tradeNumberYear: nil
            )
        }
    }

    /// Creates a trade from a buy order
    func createTrade(from buyOrder: OrderBuy) async throws -> Trade {
        // Server assigns tradeNumber/tradeNumberYear atomically on upsert (local counter is cache-only).
        let initialTrade = Trade.from(buyOrder: buyOrder, tradeNumber: 0)

        // Save to Parse Server if available
        let finalTrade: Trade
        if let tradeAPIService = tradeAPIService {
            do {
                finalTrade = try await tradeAPIService.saveTrade(initialTrade)
                print(
                    "✅ UnifiedOrderCompletionHandler: Trade #\(finalTrade.tradeNumber) saved to Parse Server with objectId: \(finalTrade.id)"
                )
            } catch {
                print("❌ UnifiedOrderCompletionHandler: Failed to save trade to Parse Server: \(error)")
                throw AppError.validationError(
                    "Trade konnte nicht auf dem Server gespeichert werden. Pool-Investments bleiben sonst reserviert. Bitte erneut versuchen oder Support kontaktieren."
                )
            }
        } else {
            print("⚠️ UnifiedOrderCompletionHandler: No tradeAPIService - trade only saved locally")
            finalTrade = initialTrade
        }

        if finalTrade.tradeNumber > 0 {
            self.tradeNumberService.synchronizeTradeNumbers(from: [finalTrade])
        }

        // Update cash balance
        await self.cashBalanceService.processBuyOrderExecution(amount: buyOrder.totalAmount)

        return finalTrade
    }

    /// Adds a sell order to an existing trade
    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell, in completedTrades: [Trade]) async throws -> Trade {
        guard let trade = completedTrades.first(where: { $0.id == tradeId }) else {
            throw AppError.tradeNotFound(tradeId)
        }
        let updatedTrade = trade.withPartialSellOrder(sellOrder).updateStatus()
        let allInvoices = self.invoiceService.getInvoicesForTrade(trade.id)
        let buyInvoice = allInvoices.first { $0.transactionType == .buy }
        let sellInvoices = allInvoices.filter { $0.transactionType == .sell }
        let finalTrade = ProfitCalculationService.tradeWithStoredRealizedProfit(
            updatedTrade,
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        // Update on Parse Server if available
        if let tradeAPIService = tradeAPIService {
            do {
                _ = try await tradeAPIService.updateTrade(finalTrade)
                print("✅ UnifiedOrderCompletionHandler: Trade #\(finalTrade.tradeNumber) updated on Parse Server (sell order added)")
            } catch {
                print("⚠️ UnifiedOrderCompletionHandler: Failed to update trade on Parse Server: \(error)")
            }
        }

        // Update cash balance
        await self.cashBalanceService.processSellOrderExecution(amount: sellOrder.totalAmount)

        return finalTrade
    }

    /// Finds matching trade for a sell order
    private func findMatchingTrade(for sellOrder: OrderSell, in completedTrades: [Trade]) -> Trade? {
        // Try to match by originalHoldingId first
        if let originalHoldingId = sellOrder.originalHoldingId {
            if let trade = completedTrades.first(where: { $0.buyOrder.id == originalHoldingId }) {
                return trade
            }
        }

        // Fallback to WKN matching - find trade with matching WKN that still has remaining quantity
        // The previous implementation would find the FIRST trade with matching WKN (possibly
        // already completed), causing the sell order to be added to the wrong trade
        return completedTrades.first { trade in
            guard trade.wkn == sellOrder.wkn else { return false }
            // Only match trades that still have quantity available for selling
            return trade.remainingQuantity > 0
        }
    }
}

