import SwiftUI

// MARK: - Holding Sell Order Status
/// Helper for managing sell order status logic for holdings
struct HoldingSellOrderStatus {
    let holding: DepotHolding
    let ongoingOrders: [Order]

    /// Checks if there's an active sell order for this holding
    var hasActiveSellOrder: Bool {
        return activeSellOrder != nil
    }

    /// Gets the active sell order for this holding (if any)
    var activeSellOrder: Order? {
        return ongoingOrders.first { order in
            guard order.type == .sell else { return false }
            // Check both originalHoldingId and WKN symbol for compatibility
            let holdingId = holding.id.uuidString
            let holdingWkn = holding.wkn
            return order.originalHoldingId == holdingId ||
                   order.originalHoldingId == holdingWkn ||
                   order.symbol == holdingWkn
        }
    }

    /// Gets the display status of the active sell order
    var activeSellOrderStatus: String {
        guard let order = activeSellOrder else { return "N/A" }
        return order.currentStatusDisplayName
    }
}
