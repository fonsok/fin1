import Combine
import Foundation

extension SellOrderViewModel {

    func reloadPrice() {
        let changeFactor = Double.random(in: 0.98...1.02)
        let newPrice = self.holding.currentPrice * changeFactor

        self.currentBidPrice = newPrice
        self.startPriceValidityTimer()

        if self.orderMode == .limit, let price = limitPrice, price > 0, !isMonitoringLimitOrder {
            #if DEBUG
            print("🔄 User manually refreshed price - starting automatic limit order monitoring")
            #endif
            self.startLimitOrderMonitoring()
        }
    }

    func startPriceValidityTimer() {
        self.timerCancellable?.cancel()
        self.priceValidityProgress = 1.0

        self.timerCancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }

                let decrement = 0.25 / 8.0
                self.priceValidityProgress -= decrement

                if self.priceValidityProgress <= 0 {
                    self.priceValidityProgress = 0
                    self.timerCancellable?.cancel()
                }
            }

        self.timerCancellable?.store(in: &self.cancellables)
    }
}
