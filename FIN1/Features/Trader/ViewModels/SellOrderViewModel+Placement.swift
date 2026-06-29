import Foundation

extension SellOrderViewModel {

    var currentTraderId: String {
        self.userService?.currentUser?.id ?? "unknown_trader"
    }

    func placeOrder() async {
        #if DEBUG
        print("🔘 DEBUG: placeOrder called - canPlaceOrder: \(self.canPlaceOrder)")
        #endif

        guard self.canPlaceOrder else {
            #if DEBUG
            print("❌ DEBUG: Order validation failed")
            #endif
            await MainActor.run {
                self.errorMessage = "Bitte überprüfen Sie Ihre Eingaben"
                self.showError = true
            }
            return
        }

        #if DEBUG
        print("✅ DEBUG: Order validation passed, proceeding with order creation")
        #endif

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            let order = self.createSellOrder()
            #if DEBUG
            print("📤 DEBUG: Submitting order to trader service")
            #endif
            try await self.traderService.submitOrder(order)
            #if DEBUG
            print("✅ DEBUG: Order submitted successfully")
            #endif
            await MainActor.run {
                self.isLoading = false
                self.shouldShowDepotView = true
            }
        } catch {
            #if DEBUG
            print("❌ DEBUG: Order submission failed with error: \(error.localizedDescription)")
            #endif
            await MainActor.run {
                self.isLoading = false
                let appError = error.toAppError()
                self.errorMessage = "Fehler beim Platzieren der Order: \(appError.errorDescription ?? "An error occurred")"
                self.showError = true
            }
        }
    }

    func createSellOrder() -> OrderSell {
        let orderPrice = self.orderMode == .market ? self.currentPrice : (self.limitPrice ?? self.currentPrice)
        #if DEBUG
        print(
            "🔧 DEBUG: Creating sell order with quantity: \(self.quantity), orderMode: \(self.orderMode), orderPrice: \(orderPrice), limitPrice: \(self.limitPrice ?? 0), totalAmount: \(self.estimatedProceeds)"
        )
        print("🔧 DEBUG: Holding orderId: \(self.holding.orderId ?? "nil"), wkn: \(self.holding.wkn)")
        print("🔧 DEBUG: Using traderId: \(self.currentTraderId)")
        #endif

        return OrderSell(
            id: UUID().uuidString,
            traderId: self.currentTraderId,
            symbol: self.holding.wkn,
            description: self.holding.designation,
            quantity: Double(self.quantity),
            price: orderPrice,
            totalAmount: self.estimatedProceeds,
            status: .submitted,
            createdAt: Date(),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date(),
            optionDirection: self.holding.direction,
            underlyingAsset: self.holding.underlyingAsset,
            wkn: self.holding.wkn,
            category: nil,
            strike: self.holding.strike,
            orderInstruction: self.orderMode == .market ? "market" : "limit",
            limitPrice: self.limitPrice,
            originalHoldingId: self.holding.orderId
        )
    }
}
