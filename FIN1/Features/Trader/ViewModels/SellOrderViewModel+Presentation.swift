import Foundation

extension SellOrderViewModel {

    var formattedCurrentPrice: String {
        self.currentPrice.formattedAsLocalizedCurrency()
    }

    var formattedEstimatedProceeds: String {
        self.estimatedProceeds.formattedAsLocalizedCurrency()
    }

    var formattedMaxQuantity: String {
        self.maxQuantity.formattedAsLocalizedInteger()
    }

    func startLimitOrderMonitoring() {
        self.limitOrderMonitor?.startLimitOrderMonitoring()
    }

    func stopLimitOrderMonitoring() {
        self.limitOrderMonitor?.stopLimitOrderMonitoring()
    }

    func onLimitPriceChanged() {
        if self.isMonitoringLimitOrder {
            #if DEBUG
            print("🛑 Limit price changed - stopping automatic monitoring")
            #endif
            self.stopLimitOrderMonitoring()
        }

        #if DEBUG
        print("💰 Limit price changed to: \(self.limit) - waiting for user to refresh price to start monitoring")
        #endif
    }
}
