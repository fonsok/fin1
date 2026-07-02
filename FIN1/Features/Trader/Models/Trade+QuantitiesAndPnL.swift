import Foundation

extension Trade {
    var isActive: Bool { !self.isFullySold }

    var isCompleted: Bool {
        self.isFullySold && self.hasCompletedSellOrders
    }

    var hasCompletedSellOrders: Bool {
        let hasSellOrders = !self.sellOrders.isEmpty || self.sellOrder != nil
        guard hasSellOrders else { return false }

        let allSellOrdersCompleted = self.sellOrders.allSatisfy { $0.status == .confirmed || $0.status == .completed }
        let legacySellOrderCompleted = self.sellOrder?.status == .confirmed || self.sellOrder?.status == .completed

        return allSellOrdersCompleted && (self.sellOrder == nil || legacySellOrderCompleted)
    }

    var totalSoldQuantity: Double {
        self.sellOrders.reduce(0) { $0 + $1.quantity }
    }

    var remainingQuantity: Double {
        self.buyOrder.quantity - self.totalSoldQuantity
    }

    var isPartiallySold: Bool {
        self.totalSoldQuantity > 0 && self.totalSoldQuantity < self.buyOrder.quantity
    }

    var isFullySold: Bool {
        self.totalSoldQuantity >= self.buyOrder.quantity
    }

    var hasExecutedSellOrders: Bool {
        let executedSellOrders = self.sellOrders.filter { $0.status == .confirmed || $0.status == .completed }
        return !executedSellOrders.isEmpty || self.sellOrder != nil
    }

    var orderBasedProfit: Double? {
        guard self.hasExecutedSellOrders else { return nil }
        return ProfitCalculationService.calculateRealizedGrossProfitFromOrders(for: self)
    }

    var currentPnL: Double? {
        if let calculatedProfit = calculatedProfit {
            return calculatedProfit
        }
        return self.orderBasedProfit
    }

    var finalPnL: Double? {
        guard self.isCompleted else { return nil }
        return self.currentPnL
    }

    var displayProfit: Double {
        if let calculated = calculatedProfit {
            return calculated
        }
        return self.currentPnL ?? 0.0
    }

    var displayROI: Double {
        self.roi ?? 0.0
    }

    var roi: Double? {
        guard let pnl = currentPnL, totalSoldQuantity > 0 else { return nil }

        let buySecuritiesValue = self.buyOrder.price * self.totalSoldQuantity
        let buyFees = FeeCalculationService.calculateTotalFees(for: buySecuritiesValue)
        let totalBuyCost = buySecuritiesValue + buyFees

        return ProfitCalculationService.calculateReturnPercentage(
            grossProfit: pnl,
            investedAmount: totalBuyCost
        )
    }
}
