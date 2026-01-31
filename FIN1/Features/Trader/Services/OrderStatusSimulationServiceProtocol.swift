import Foundation
import Combine

// MARK: - Order Status Simulation Service Protocol
/// Defines the contract for order status progression simulation
protocol OrderStatusSimulationServiceProtocol: ObservableObject {
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Order Status Simulation
    func startOrderStatusProgression(_ orderId: String, onStatusUpdate: @escaping (String, Order) -> Void)
    func stopOrderStatusProgression(_ orderId: String)
    func stopAllOrderStatusProgressions()

    // MARK: - Order Status Management
    func advanceOrderStatus(_ orderId: String, onStatusUpdate: @escaping (String, Order) -> Void) async
    func moveOrderToHoldings(_ orderId: String, activeOrders: [Order], onOrderMoved: @escaping (Order) -> Void) async
}
