import Foundation

extension Trade {
    /// Server-persistierter Zähler, falls mit Parse synchron; sonst lokale Spiegelung.
    var authoritativePartialSellEventCount: Int {
        if let server = self.traderPartialSellEventCount, server >= 0 {
            return server
        }
        return self.completedPartialSellEventCount
    }

    /// Teil-Verkaufs-Ereignisse (Verkäufe vor vollständigem Exit) — spiegelt Server-Logik.
    var completedPartialSellEventCount: Int {
        let executed = self.sellOrders.filter { $0.status == .confirmed || $0.status == .completed }
        let sells = executed.isEmpty
            ? (self.sellOrder.map { [$0] } ?? [])
            : executed
        guard !sells.isEmpty else { return 0 }
        if self.isFullySold { return max(0, sells.count - 1) }
        return sells.count
    }

    func partialSellEventCount(afterAdding sellOrder: OrderSell) -> Int {
        self.withPartialSellOrder(sellOrder).completedPartialSellEventCount
    }

    func validatePartialSellAllowed(sellOrder: OrderSell, maxPartialSells: Int) throws {
        let maxAllowed = min(3, max(0, maxPartialSells))
        let qtyEpsilon = 0.000_1

        if maxAllowed == 0 {
            if sellOrder.quantity < self.remainingQuantity - qtyEpsilon {
                throw TradePartialSellLimitError.partialSellsDisabled
            }
            if !self.sellOrders.isEmpty || self.sellOrder != nil {
                throw TradePartialSellLimitError.onlyOneFullSellAllowed
            }
            return
        }

        let localNext = self.partialSellEventCount(afterAdding: sellOrder)
        let localBefore = self.completedPartialSellEventCount
        let nextCount: Int
        if let server = self.traderPartialSellEventCount, server == localBefore {
            nextCount = localNext - localBefore + server
        } else {
            nextCount = localNext
        }
        if nextCount > maxAllowed {
            throw TradePartialSellLimitError.limitExceeded(maxAllowed: maxAllowed)
        }

        let prevCount = self.authoritativePartialSellEventCount
        if maxAllowed > 0, prevCount == maxAllowed - 1 {
            let remaining = self.remainingQuantity
            if sellOrder.quantity < remaining - qtyEpsilon {
                throw TradePartialSellLimitError.finalPartialSellMustClearDepot(
                    maxAllowed: maxAllowed,
                    remainingQuantity: remaining
                )
            }
        }

        if maxAllowed > 0, prevCount >= maxAllowed, self.remainingQuantity > qtyEpsilon {
            if sellOrder.quantity < self.remainingQuantity - qtyEpsilon {
                throw TradePartialSellLimitError.limitExhaustedMustClearDepot(
                    maxAllowed: maxAllowed,
                    remainingQuantity: self.remainingQuantity
                )
            }
        }
    }
}

enum TradePartialSellLimitError: LocalizedError {
    case partialSellsDisabled
    case onlyOneFullSellAllowed
    case limitExceeded(maxAllowed: Int)
    case finalPartialSellMustClearDepot(maxAllowed: Int, remainingQuantity: Double)
    case limitExhaustedMustClearDepot(maxAllowed: Int, remainingQuantity: Double)

    var errorDescription: String? {
        switch self {
        case .partialSellsDisabled:
            return "Teil-Verkäufe sind deaktiviert. Bitte die gesamte Restposition verkaufen."
        case .onlyOneFullSellAllowed:
            return "Es ist nur ein vollständiger Verkauf erlaubt."
        case .limitExceeded(let maxAllowed):
            return "Maximal \(maxAllowed) Teil-Verkauf\(maxAllowed == 1 ? "" : "e") pro Trade erlaubt."
        case .finalPartialSellMustClearDepot(let maxAllowed, let remainingQuantity):
            let qty = Int(remainingQuantity.rounded())
            return "Der \(maxAllowed). Teil-Verkauf (letzter erlaubter) muss die gesamte Restposition "
                + "(\(qty) St.) verkaufen. Eine kleinere Menge ist nach Erreichen des Limits nicht möglich."
        case .limitExhaustedMustClearDepot(let maxAllowed, let remainingQuantity):
            let qty = Int(remainingQuantity.rounded())
            return "Teil-Verkaufs-Limit (\(maxAllowed)) erreicht. Verbleibende \(qty) St. "
                + "müssen in einem abschließenden Verkauf vollständig verkauft werden."
        }
    }
}
