import Foundation
import Combine

// MARK: - Limit Order Monitoring Service Protocol
/// Service protocol for managing limit order monitoring lifecycle
protocol LimitOrderMonitoringServiceProtocol {
    func createBuyOrderMonitor(for viewModel: BuyOrderViewModel) -> BuyOrderMonitorImpl
    func createSellOrderMonitor(for viewModel: SellOrderViewModel) -> SellOrderMonitorImpl
}

// MARK: - Limit Order Monitoring Service
/// Service for creating and managing limit order monitors
final class LimitOrderMonitoringService: LimitOrderMonitoringServiceProtocol {

    func createBuyOrderMonitor(for viewModel: BuyOrderViewModel) -> BuyOrderMonitorImpl {
        return BuyOrderMonitorImpl(buyOrderViewModel: viewModel)
    }

    func createSellOrderMonitor(for viewModel: SellOrderViewModel) -> SellOrderMonitorImpl {
        return SellOrderMonitorImpl(sellOrderViewModel: viewModel)
    }
}
