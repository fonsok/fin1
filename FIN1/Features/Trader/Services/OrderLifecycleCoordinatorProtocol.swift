import Foundation
import Combine

// MARK: - Order Parameters
struct BuyOrderParameters {
    let symbol: String
    let quantity: Int
    let price: Double
    let optionDirection: String?
    let description: String?
    let orderInstruction: String?
    let limitPrice: Double?
    let strike: Double?
    let subscriptionRatio: Double?
    let denomination: Int?
    let isMirrorPoolOrder: Bool?
}

// MARK: - Order Lifecycle Coordinator Protocol
/// Defines the contract for order lifecycle management
/// Handles order creation, status progression, and completion logic
@MainActor
protocol OrderLifecycleCoordinatorProtocol: Sendable {
    // MARK: - Order Management
    func placeBuyOrder(parameters: BuyOrderParameters) async throws -> OrderBuy
    func placeSellOrder(symbol: String, quantity: Int, price: Double) async throws -> OrderSell
    func submitOrder(_ order: OrderSell) async throws
    func cancelOrder(_ orderId: String) async throws
    func updateOrderStatus(_ orderId: String, status: String) async throws

    // MARK: - Order Completion Handling
    func handleOrderCompletion(orderId: String, status: String, order: Order) async
    func handleSellOrderCompletion(orderId: String, order: Order) async
}
