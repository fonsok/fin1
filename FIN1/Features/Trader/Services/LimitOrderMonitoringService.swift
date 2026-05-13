import Combine
import Foundation

// MARK: - Limit Order Monitoring Service Protocol
/// Service protocol for managing limit order monitoring lifecycle
@MainActor
protocol LimitOrderMonitoringServiceProtocol: AnyObject {
    func createBuyOrderMonitor(for viewModel: BuyOrderViewModel) -> BuyOrderMonitorImpl
    func createSellOrderMonitor(for viewModel: SellOrderViewModel) -> SellOrderMonitorImpl
}

// MARK: - Limit Order Monitoring Service
/// Service for creating and managing limit order monitors
@MainActor
final class LimitOrderMonitoringService: LimitOrderMonitoringServiceProtocol {

    func createBuyOrderMonitor(for viewModel: BuyOrderViewModel) -> BuyOrderMonitorImpl {
        return BuyOrderMonitorImpl(buyOrderViewModel: viewModel)
    }

    func createSellOrderMonitor(for viewModel: SellOrderViewModel) -> SellOrderMonitorImpl {
        return SellOrderMonitorImpl(sellOrderViewModel: viewModel)
    }
}
