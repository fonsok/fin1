import Combine
import Foundation

// MARK: - Order Status Simulation Service Protocol
/// Defines the contract for order status progression simulation
@MainActor
protocol OrderStatusSimulationServiceProtocol: ObservableObject {
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Order Status Simulation
    func startOrderStatusProgression(_ orderId: String, onStatusUpdate: @escaping @Sendable (String, Order) async -> Void)
    func stopOrderStatusProgression(_ orderId: String)
    func stopAllOrderStatusProgressions()

    // MARK: - Order Status Management
    func advanceOrderStatus(_ orderId: String, onStatusUpdate: @escaping @Sendable (String, Order) async -> Void) async
    func moveOrderToHoldings(_ orderId: String, activeOrders: [Order], onOrderMoved: @escaping (Order) -> Void) async
}
