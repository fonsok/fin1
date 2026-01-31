import Foundation

// MARK: - Order Notification Names
/// Centralized notification names for order-related events
extension Notification.Name {
    /// Triggered when a buy order is completed
    static let buyOrderCompleted = Notification.Name("buyOrderCompleted")

    /// Triggered when an item is added to the watchlist
    static let watchlistItemAdded = Notification.Name("watchlistItemAdded")

    /// Triggered when an order status is updated
    static let orderStatusUpdated = Notification.Name("orderStatusUpdated")

    /// Triggered when a trade is completed (buy + sell matched)
    static let tradeCompleted = Notification.Name("tradeCompleted")

    /// Triggered when an order is placed successfully
    static let orderPlacedSuccessfully = Notification.Name("orderPlacedSuccessfully")

    /// Triggered when an invoice changes
    static let invoiceDidChange = Notification.Name("invoiceDidChange")

    /// Triggered when a commission is settled
    static let commissionSettled = Notification.Name("commissionSettled")
}











