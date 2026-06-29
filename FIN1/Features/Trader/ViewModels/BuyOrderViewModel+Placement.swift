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

    func resetOrderStatus() {
        self.mutatePlacementSession { $0.resetToEditing() }
    }

    func placeOrder() async {
        guard self.placementSession.phase.canStartPlacement else {
            #if DEBUG
            print("🔍 DEBUG: placeOrder ignored - transmission already in progress")
            #endif
            return
        }

        if self.placementSession.phase.isFailed {
            self.mutatePlacementSession { $0.acknowledgeFailure() }
        }

        self.normalizeQuantityTextAfterEditing()
        let orderQuantity = Int(self.quantity)
        guard orderQuantity > 0 else {
            self.mutatePlacementSession { $0.completeFailure(.validationError("Ungültige Stückzahl.")) }
            return
        }

        self.pausePriceValidityTimer()

        let clientOrderIntentId = self.mutatePlacementSessionReturning {
            $0.ensureClientOrderIntentId()
        }
        let snapshot = BuyOrderPlacementSnapshot(
            quantity: orderQuantity,
            searchResult: self.searchResult,
            orderMode: self.orderMode,
            limit: self.limit,
            priceValidityProgress: self.priceValidityProgress,
            investmentOrderCalculation: self.investmentOrderCalculation,
            clientOrderIntentId: clientOrderIntentId
        )
        self.mutatePlacementSession { $0.beginPlacing(snapshot) }

        let placementStartedAt = Date()
        var placementOutcome = "aborted"
        var placementErrorCategory: String?
        defer {
            let durationMs = Int(Date().timeIntervalSince(placementStartedAt) * 1_000)
            BuyOrderPlacementTelemetry.placementFinished(
                intentId: snapshot.clientOrderIntentId,
                durationMs: durationMs,
                outcome: placementOutcome,
                errorCategory: placementErrorCategory
            )
        }
        BuyOrderPlacementTelemetry.placementStarted(
            intentId: snapshot.clientOrderIntentId,
            symbol: snapshot.searchResult.wkn,
            quantity: snapshot.quantity,
            orderMode: snapshot.orderMode
        )

        await self.refreshPlacementPoolContext()

        let placementCalculation = self.investmentOrderCalculation ?? snapshot.investmentOrderCalculation

        do {
            let result = try await placementService.placeOrder(
                searchResult: snapshot.searchResult,
                quantity: snapshot.quantity,
                orderMode: snapshot.orderMode,
                limit: snapshot.limit,
                priceValidityProgress: snapshot.priceValidityProgress,
                investmentOrderCalculation: placementCalculation,
                clientOrderIntentId: snapshot.clientOrderIntentId,
                traderService: self.traderService
            )

            if result.success {
                placementOutcome = "succeeded"
                self.mutatePlacementSession { $0.completeSuccess() }
                self.shouldShowDepotView = true
            } else if let error = result.error {
                placementOutcome = "failed"
                placementErrorCategory = Self.placementErrorCategory(error)
                self.mutatePlacementSession { $0.completeFailure(error) }
                self.resumePriceValidityAfterFailure()
            } else {
                placementOutcome = "failed"
                placementErrorCategory = "unknown"
                self.mutatePlacementSession {
                    $0.completeFailure(.unknown("Unbekannter Fehler bei der Orderplatzierung."))
                }
                self.resumePriceValidityAfterFailure()
            }
        } catch is CancellationError {
            placementOutcome = "cancelled"
            placementErrorCategory = "cancellation"
            #if DEBUG
            print("⚠️ BuyOrderViewModel: placeOrder cancelled — snapshot quantity \(snapshot.quantity)")
            #endif
            self.mutatePlacementSession {
                $0.completeFailure(
                    .validationError(
                        "Die Übermittlung wurde unterbrochen. Bitte prüfen Sie das Depot und versuchen Sie es ggf. erneut."
                    )
                )
            }
            self.resumePriceValidityAfterFailure()
        } catch let appError as AppError {
            placementOutcome = "failed"
            placementErrorCategory = Self.placementErrorCategory(appError)
            self.mutatePlacementSession { $0.completeFailure(appError) }
            self.resumePriceValidityAfterFailure()
        } catch {
            placementOutcome = "failed"
            placementErrorCategory = "unknown"
            self.mutatePlacementSession { $0.completeFailure(error.toAppError()) }
            self.resumePriceValidityAfterFailure()
        }
    }

    private static func placementErrorCategory(_ error: AppError) -> String {
        switch error {
        case .validation:
            return "validation"
        case .network:
            return "network"
        case .authentication:
            return "authentication"
        case .service:
            return "service"
        case .orderNotFound:
            return "order_not_found"
        case .tradeNotFound:
            return "trade_not_found"
        case .unknown:
            return "unknown"
        }
    }
}
