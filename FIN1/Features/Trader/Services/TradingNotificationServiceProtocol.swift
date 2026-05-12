import Foundation
import Combine

// MARK: - Trading Notification Service Protocol
/// Defines the contract for trading notifications and confirmations
protocol TradingNotificationServiceProtocol: ObservableObject, Sendable {
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Trading Notifications
    func showBuyConfirmation(for trade: Trade) async
    func showSellConfirmation(for trade: Trade) async
    func generateInvoiceAndNotification(for order: Order, tradeId: String?, tradeNumber: Int?) async
    func generateCollectionBillDocument(for trade: Trade) async
    func regenerateCollectionBills(for trades: [Trade]) async
    func sendOrderStatusNotification(orderId: String, status: String) async
    func sendTradeCompletionNotification(tradeId: String) async

    // MARK: - Credit Note Generation
    /// Generates a Credit Note document for the trader's commission payment
    /// - Parameters:
    ///   - trade: The completed trade
    ///   - commissionAmount: Total commission amount for the trader
    ///   - grossProfit: Total gross profit from the trade
    func generateCreditNoteDocument(for trade: Trade, commissionAmount: Double, grossProfit: Double) async
}
