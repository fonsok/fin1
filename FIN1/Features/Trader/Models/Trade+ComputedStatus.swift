import Foundation

extension Trade {
    var computedStatus: TradeStatus {
        if self.buyOrder.status == .cancelled {
            return .cancelled
        }

        if self.sellOrders.contains(where: { $0.status == .cancelled }) {
            return .cancelled
        }

        if let sellOrder = sellOrder, sellOrder.status == .cancelled {
            return .cancelled
        }

        if self.buyOrder.status == .completed {
            if self.isFullySold {
                if self.hasCompletedSellOrders {
                    return .completed
                }
                return .active
            }
            return .active
        }

        return .pending
    }
}
