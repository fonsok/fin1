import Combine
import Foundation

// MARK: - Order Status Configuration
/// Centralized configuration for order status progression timing
struct OrderStatusConfig {
    /// Time interval between order status updates (in seconds)
    static let progressionInterval: TimeInterval = 1.0 // changing? set different value here, currently 1 sec

    /// Time interval in nanoseconds for Task.sleep
    static var progressionIntervalNanoseconds: UInt64 {
        UInt64(progressionInterval * 1_000_000_000)
    }
}

// MARK: - Simplified Order Service
/// Single service that handles all order operations
/// Replaces the complex chain: TraderService → TradingCoordinator → OrderLifecycleCoordinator → OrderManagementService

@MainActor
protocol NewOrderServiceProtocol: ObservableObject {
    var activeOrders: [NewOrder] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    func placeBuyOrder(_ request: NewBuyOrderRequest) async throws -> NewOrder
    func placeSellOrder(_ request: NewSellOrderRequest) async throws -> NewOrder
    func cancelOrder(_ orderId: String) async throws
    func updateOrderStatus(_ orderId: String, status: NewOrderStatus) async throws
}

@MainActor
final class NewOrderService: NewOrderServiceProtocol {
    @Published var activeOrders: [NewOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var orderStatusTimers: [String: Timer] = [:]
    private let userService: (any UserServiceProtocol)?

    // MARK: - Current Trader ID
    /// Returns the current trader's ID from the user service
    private var currentTraderId: String {
        self.userService?.currentUser?.id ?? "unknown_trader"
    }

    init(userService: (any UserServiceProtocol)? = nil) {
        self.userService = userService
    }

    // MARK: - Order Operations
    func placeBuyOrder(_ request: NewBuyOrderRequest) async throws -> NewOrder {
        self.isLoading = true
        defer { isLoading = false }

        let order = NewOrder(
            traderId: currentTraderId, // Use actual logged-in trader ID
            symbol: request.symbol,
            description: request.description ?? "Optionsschein",
            type: .buy,
            quantity: Double(request.quantity),
            price: request.price,
            optionDirection: request.optionDirection,
            underlyingAsset: request.description,
            wkn: request.symbol,
            category: "Optionsschein",
            strike: request.strike,
            orderInstruction: request.orderInstruction,
            limitPrice: request.limitPrice
        )

        self.activeOrders.append(order)
        print("🔍 DEBUG: Added buy order \(order.id) to activeOrders. Total: \(self.activeOrders.count)")

        // Start status progression
        self.startOrderStatusProgression(order.id)

        return order
    }

    func placeSellOrder(_ request: NewSellOrderRequest) async throws -> NewOrder {
        self.isLoading = true
        defer { isLoading = false }

        let order = NewOrder(
            traderId: currentTraderId, // Use actual logged-in trader ID
            symbol: request.symbol,
            description: request.description ?? "Optionsschein",
            type: .sell,
            quantity: Double(request.quantity),
            price: request.price,
            optionDirection: request.optionDirection,
            underlyingAsset: request.description,
            wkn: request.symbol,
            category: "Optionsschein",
            strike: request.strike,
            orderInstruction: request.orderInstruction,
            limitPrice: request.limitPrice,
            originalHoldingId: request.originalHoldingId
        )

        self.activeOrders.append(order)
        print("🔍 DEBUG: Added sell order \(order.id) to activeOrders. Total: \(self.activeOrders.count)")

        // Start status progression
        self.startOrderStatusProgression(order.id)

        return order
    }

    func cancelOrder(_ orderId: String) async throws {
        if let index = activeOrders.firstIndex(where: { $0.id == orderId }) {
            let order = self.activeOrders[index]
            let cancelledOrder = order.withStatus(.cancelled)
            self.activeOrders[index] = cancelledOrder

            // Stop status progression
            self.orderStatusTimers[orderId]?.invalidate()
            self.orderStatusTimers.removeValue(forKey: orderId)

            print("🔍 DEBUG: Cancelled order \(orderId)")
        }
    }

    func updateOrderStatus(_ orderId: String, status: NewOrderStatus) async throws {
        if let index = activeOrders.firstIndex(where: { $0.id == orderId }) {
            let order = self.activeOrders[index]
            let updatedOrder = order.withStatus(status)
            self.activeOrders[index] = updatedOrder

            print("🔍 DEBUG: Updated order \(orderId) status to \(status.rawValue)")

            // Stop progression if completed
            if status == .completed {
                self.orderStatusTimers[orderId]?.invalidate()
                self.orderStatusTimers.removeValue(forKey: orderId)
            }
        }
    }

    // MARK: - Private Methods
    private func startOrderStatusProgression(_ orderId: String) {
        // Cancel any existing timer
        self.orderStatusTimers[orderId]?.invalidate()

        // Start progression timer using centralized configuration
        self.orderStatusTimers[orderId] = Timer.scheduledTimer(withTimeInterval: OrderStatusConfig.progressionInterval, repeats: true) { [
            weak self
        ] _ in
            Task { @MainActor in
                await self?.advanceOrderStatus(orderId)
            }
        }
    }

    private func advanceOrderStatus(_ orderId: String) async {
        guard let index = activeOrders.firstIndex(where: { $0.id == orderId }) else {
            self.orderStatusTimers[orderId]?.invalidate()
            self.orderStatusTimers.removeValue(forKey: orderId)
            return
        }

        let order = self.activeOrders[index]
        let nextStatus: NewOrderStatus

        switch order.status {
        case .submitted:
            nextStatus = .suspended
        case .suspended:
            nextStatus = .executed
        case .executed:
            nextStatus = .confirmed
        case .confirmed:
            nextStatus = .completed
        case .completed, .cancelled:
            // Stop progression
            self.orderStatusTimers[orderId]?.invalidate()
            self.orderStatusTimers.removeValue(forKey: orderId)
            return
        }

        try? await self.updateOrderStatus(orderId, status: nextStatus)
    }
}
