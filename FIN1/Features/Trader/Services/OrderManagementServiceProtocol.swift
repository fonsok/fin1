import Combine
import Foundation

// MARK: - Order Management Service Protocol
/// Defines the contract for order placement, status updates, and management
protocol OrderManagementServiceProtocol: ObservableObject, Sendable {
    var activeOrders: [Order] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // Publishers for observation (MVVM-friendly)
    var activeOrdersPublisher: AnyPublisher<[Order], Never> { get }

    // MARK: - Order Management
    func placeBuyOrder(
        symbol: String,
        quantity: Int,
        price: Double,
        optionDirection: String?,
        description: String?,
        orderInstruction: String?,
        limitPrice: Double?,
        strike: Double?,
        subscriptionRatio: Double?,
        denomination: Int?,
        isMirrorPoolOrder: Bool?
    ) async throws -> OrderBuy
    func placeSellOrder(symbol: String, quantity: Int, price: Double) async throws -> OrderSell
    func cancelOrder(_ orderId: String) async throws
    func removeActiveOrder(_ orderId: String) async
    func updateOrderStatus(_ orderId: String, status: String) async throws
    func addOrderToActiveOrders(_ order: Order) async
    func persistSellOrder(_ order: OrderSell, tradeId: String?) async throws -> OrderSell
    func syncActiveOrderToBackend(_ orderId: String) async
    func registerSellOrderTradeLink(orderId: String, tradeId: String)
    func registerPairedBuyExecutionLink(orderId: String, pairExecutionId: String)
    func pairedBuyExecutionId(for orderId: String) -> String?
    func finalizePairedBuyExecution(for orderId: String) async throws
    @MainActor func reportOrderStatusFailure(_ message: String)

    // MARK: - Order Data Management
    func loadActiveOrders() async throws
    func refreshActiveOrders() async throws

    // MARK: - Backend Synchronization
    func syncToBackend() async
}
