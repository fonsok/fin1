import Combine
import Foundation

// MARK: - Simplified Order Service (demo / prototype only)
/// Local in-memory order flow for `NewBuyOrderViewModel` prototypes.
///
/// **Production path:** `UnifiedOrderService` + `OrderLifecycleCoordinator` + `OrderStatusSimulationService`.
@available(*, deprecated, message: "Use UnifiedOrderService / OrderLifecycleCoordinator for production trading.")
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

@available(*, deprecated, message: "Use UnifiedOrderService / OrderLifecycleCoordinator for production trading.")
@MainActor
final class NewOrderService: NewOrderServiceProtocol {
    @Published var activeOrders: [NewOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var orderStatusTasks: [String: Task<Void, Never>] = [:]
    private let userService: (any UserServiceProtocol)?

    private var currentTraderId: String {
        self.userService?.currentUser?.id ?? "unknown_trader"
    }

    init(userService: (any UserServiceProtocol)? = nil) {
        self.userService = userService
    }

    func placeBuyOrder(_ request: NewBuyOrderRequest) async throws -> NewOrder {
        self.isLoading = true
        defer { isLoading = false }

        let order = NewOrder(
            traderId: currentTraderId,
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
        self.startOrderStatusProgression(order.id)
        return order
    }

    func placeSellOrder(_ request: NewSellOrderRequest) async throws -> NewOrder {
        self.isLoading = true
        defer { isLoading = false }

        let order = NewOrder(
            traderId: currentTraderId,
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
        self.startOrderStatusProgression(order.id)
        return order
    }

    func cancelOrder(_ orderId: String) async throws {
        if let index = activeOrders.firstIndex(where: { $0.id == orderId }) {
            let order = self.activeOrders[index]
            self.activeOrders[index] = order.withStatus(.cancelled)
            self.stopOrderStatusProgression(orderId)
        }
    }

    func updateOrderStatus(_ orderId: String, status: NewOrderStatus) async throws {
        if let index = activeOrders.firstIndex(where: { $0.id == orderId }) {
            let order = self.activeOrders[index]
            self.activeOrders[index] = order.withStatus(status)
            if status == .completed {
                self.stopOrderStatusProgression(orderId)
            }
        }
    }

    // MARK: - Status progression (same timing SSOT as production: OrderStatusConfig)

    private func stopOrderStatusProgression(_ orderId: String) {
        self.orderStatusTasks[orderId]?.cancel()
        self.orderStatusTasks.removeValue(forKey: orderId)
    }

    private func startOrderStatusProgression(_ orderId: String) {
        self.orderStatusTasks[orderId]?.cancel()
        self.orderStatusTasks[orderId] = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let current = self.activeOrders.first(where: { $0.id == orderId }) else {
                    self.stopOrderStatusProgression(orderId)
                    break
                }
                if current.status == .completed || current.status == .cancelled {
                    self.stopOrderStatusProgression(orderId)
                    break
                }
                let delay = OrderStatusConfig.stepIntervalNanoseconds(fromStatus: current.status.rawValue)
                try? await Task.sleep(nanoseconds: delay)
                await self.advanceOrderStatus(orderId)
            }
        }
    }

    private func advanceOrderStatus(_ orderId: String) async {
        guard let index = activeOrders.firstIndex(where: { $0.id == orderId }) else {
            self.stopOrderStatusProgression(orderId)
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
            self.stopOrderStatusProgression(orderId)
            return
        }

        try? await self.updateOrderStatus(orderId, status: nextStatus)
    }
}
