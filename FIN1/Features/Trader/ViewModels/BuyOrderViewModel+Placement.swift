import Foundation

extension BuyOrderViewModel {

    /// Prevents quantity bindings from overwriting user input while an order is in flight.
    var isPlacementLocked: Bool {
        self.placementSession.isInputLocked
    }

    var lockedPlacementQuantity: Int? {
        self.placementSession.lockedQuantity
    }

    /// Quantity used for pool calculations — respects the placement lock.
    var effectiveQuantityForCalculation: Double {
        if let locked = lockedPlacementQuantity {
            return Double(locked)
        }
        return self.quantity
    }

    func loadPoolInvestmentsIfNeeded() async {
        guard !self.didLoadPoolInvestments else { return }
        self.pausePriceValidityTimer()
        await self.refreshInvestmentsFromBackend()
        self.didLoadPoolInvestments = true
        self.reloadPrice()
        self.scheduleInvestmentOrderRecalc()
    }

    /// Call synchronously on Kaufen before `placeOrder()` — freezes staleness ramp during transmission.
    func prepareForPlacement() {
        self.pausePriceValidityTimer()
    }

    func pausePriceValidityTimer() {
        self.priceValidityTimerManager.pauseTimer()
    }

    func resumePriceValidityAfterFailure() {
        self.priceValidityTimerManager.resumeTimer()
    }

    var hasOrderFailure: Bool {
        self.placementSession.phase.isFailed
    }

    var orderFailureMessage: String? {
        guard case .failed(let error) = self.placementSession.phase else { return nil }
        return error.userFacingBuyOrderMessage
    }

    func acknowledgeOrderFailure() {
        self.mutatePlacementSession { $0.acknowledgeFailure() }
        self.resumePriceValidityAfterFailure()
    }

    /// Refreshes pool selection locally when backend data was loaded in `.task`.
    func refreshPlacementPoolContext() async {
        if self.didLoadPoolInvestments {
            self.updateReservedInvestments()
        } else {
            await self.refreshInvestmentsFromBackend()
        }
        await self.calculateInvestmentOrder()
    }
}
