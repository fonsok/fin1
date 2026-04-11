import Foundation
import Combine

// MARK: - Order Status Simulation Service Implementation
/// Handles order status progression simulation and timer management
@MainActor
final class OrderStatusSimulationService: OrderStatusSimulationServiceProtocol, ServiceLifecycle {
    static let shared = OrderStatusSimulationService()

    @Published var isLoading = false
    @Published var errorMessage: String?

    private var orderStatusTasks: [String: Task<Void, Never>] = [:]
    private let orderManagementService: any OrderManagementServiceProtocol

    init(orderManagementService: any OrderManagementServiceProtocol = OrderManagementService.shared) {
        self.orderManagementService = orderManagementService
    }

    // MARK: - ServiceLifecycle
    func start() {
        // Simulation service doesn't need to load data on start
        // It manages timers for orders
    }

    func stop() {
        stopAllOrderStatusProgressions()
    }

    func reset() {
        stopAllOrderStatusProgressions()
        errorMessage = nil
    }

    // MARK: - Order Status Simulation

    func stopOrderStatusProgression(_ orderId: String) {
        orderStatusTasks[orderId]?.cancel()
        orderStatusTasks.removeValue(forKey: orderId)
    }

    func stopAllOrderStatusProgressions() {
        orderStatusTasks.values.forEach { $0.cancel() }
        orderStatusTasks.removeAll()
    }

    // MARK: - Order Status Management

    func startOrderStatusProgression(_ orderId: String, onStatusUpdate: @escaping (String, Order) -> Void) {
        orderStatusTasks[orderId]?.cancel()

        orderStatusTasks[orderId] = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: OrderStatusConfig.progressionIntervalNanoseconds)
                await self.advanceOrderStatus(orderId, onStatusUpdate: onStatusUpdate)
                if let order = self.orderManagementService.activeOrders.first(where: { $0.id == orderId }),
                   order.status == "completed" {
                    break
                }
            }
            await self.cleanupTask(for: orderId)
        }
    }

    func advanceOrderStatus(_ orderId: String, onStatusUpdate: @escaping (String, Order) -> Void) async {
        // Get the current order from OrderManagementService
        #if DEBUG
        print("🔍 DEBUG: advanceOrderStatus - looking for order \(orderId) in activeOrders (count: \(orderManagementService.activeOrders.count))")
        for order in orderManagementService.activeOrders {
            print("🔍 DEBUG: activeOrders - order \(order.id) type: \(order.type) status: '\(order.status)'")
        }
        #endif

        guard let index = orderManagementService.activeOrders.firstIndex(where: { $0.id == orderId }) else {
            // Order not found, stop task
            stopOrderStatusProgression(orderId)
            #if DEBUG
            print("🔍 DEBUG: advanceOrderStatus - order \(orderId) not found in activeOrders, stopping task")
            #endif
            return
        }

        let order = orderManagementService.activeOrders[index]
        let currentStatus = order.status
        let nextStatus: String

        #if DEBUG
        print("🔍 DEBUG: advanceOrderStatus - order \(orderId) current status: '\(currentStatus)' (type: \(order.type))")
        #endif

        // Same progression for both buy and sell orders: submitted → suspended → executed → confirmed → completed
        switch currentStatus {
        case "submitted", "1":
            nextStatus = "suspended"
        case "suspended", "2":
            nextStatus = "executed"
        case "executed", "3":
            nextStatus = "confirmed"
        case "confirmed", "4":
            nextStatus = "completed"
        case "completed", "5":
            // Order is completed (final status), stop task
            stopOrderStatusProgression(orderId)
            #if DEBUG
            print("🔍 DEBUG: advanceOrderStatus - order \(orderId) completed, stopping task")
            #endif
            return
        default:
            // Unknown status, stop task
            stopOrderStatusProgression(orderId)
            #if DEBUG
            print("🔍 DEBUG: advanceOrderStatus - order \(orderId) unknown status \(currentStatus), stopping task")
            #endif
            return
        }

        // Update order status through OrderManagementService
        try? await orderManagementService.updateOrderStatus(orderId, status: nextStatus)

        // Get the updated order and notify the calling service
        if let updatedOrder = orderManagementService.activeOrders.first(where: { $0.id == orderId }) {
            onStatusUpdate(nextStatus, updatedOrder)
            #if DEBUG
            print("🔍 DEBUG: advanceOrderStatus - order \(orderId) status changed from \(currentStatus) to \(nextStatus)")
            #endif
        }
    }

    func moveOrderToHoldings(_ orderId: String, activeOrders: [Order], onOrderMoved: @escaping (Order) -> Void) async {
        guard let index = activeOrders.firstIndex(where: { $0.id == orderId }) else {
            #if DEBUG
            print("🔍 DEBUG: moveOrderToHoldings - order \(orderId) not found in activeOrders")
            #endif
            return
        }

        let order = activeOrders[index]
        #if DEBUG
        print("🔍 DEBUG: moveOrderToHoldings - moving order \(orderId) to holdings. Current activeOrders count: \(activeOrders.count)")
        #endif

        // Notify the calling service about the order that needs to be moved
        onOrderMoved(order)
    }

    private func cleanupTask(for orderId: String) {
        orderStatusTasks[orderId] = nil
    }
}
