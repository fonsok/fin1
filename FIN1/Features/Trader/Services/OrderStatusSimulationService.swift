import Foundation
@preconcurrency import Dispatch
import Combine

// MARK: - Order Status Simulation Service Implementation
/// Handles order status progression simulation and timer management
/// Note: Safe to use with DispatchQueue.async closures due to [weak self] capture pattern
/// @unchecked Sendable: Safe because we use [weak self] in all async closures
final class OrderStatusSimulationService: OrderStatusSimulationServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = OrderStatusSimulationService()

    @Published var isLoading = false
    @Published var errorMessage: String?

    private var orderStatusTasks: [String: Task<Void, Never>] = [:]
    private let orderManagementService: any OrderManagementServiceProtocol
    private let taskQueue = DispatchQueue(label: "com.fin.app.orderStatusTasks", attributes: .concurrent)

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
        let orderIdCopy = orderId
        let taskQueue = self.taskQueue
        // Safe: [weak self] prevents retain cycles; @preconcurrency import Dispatch suppresses Sendable warnings
        taskQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.orderStatusTasks[orderIdCopy]?.cancel()
            self.orderStatusTasks.removeValue(forKey: orderIdCopy)
        }
    }

    func stopAllOrderStatusProgressions() {
        let taskQueue = self.taskQueue
        taskQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.orderStatusTasks.values.forEach { $0.cancel() }
            self.orderStatusTasks.removeAll()
        }
    }

    // MARK: - Order Status Management

    func startOrderStatusProgression(_ orderId: String, onStatusUpdate: @escaping (String, Order) -> Void) {
        let orderIdCopy = orderId
        let orderManagementService = self.orderManagementService
        let taskQueue = self.taskQueue
        taskQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // Cancel any existing task for this order
            self.orderStatusTasks[orderIdCopy]?.cancel()

            // Start task loop for status progression using centralized configuration
            self.orderStatusTasks[orderIdCopy] = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: OrderStatusConfig.progressionIntervalNanoseconds)
                    await self.advanceOrderStatus(orderIdCopy, onStatusUpdate: onStatusUpdate)
                    if let order = orderManagementService.activeOrders.first(where: { $0.id == orderIdCopy }), order.status == "completed" {
                        break
                    }
                }
                // Clean up task reference
                let orderId = orderIdCopy
                let taskQueue = self.taskQueue
                await MainActor.run {
                    // Safe: [weak self] prevents retain cycles; @preconcurrency import Dispatch suppresses Sendable warnings
                    taskQueue.async(flags: .barrier) { [weak self] in
                        self?.orderStatusTasks[orderId] = nil
                    }
                }
            }
        }
    }

    func advanceOrderStatus(_ orderId: String, onStatusUpdate: @escaping (String, Order) -> Void) async {
        // Get the current order from OrderManagementService
        print("🔍 DEBUG: advanceOrderStatus - looking for order \(orderId) in activeOrders (count: \(orderManagementService.activeOrders.count))")
        for order in orderManagementService.activeOrders {
            print("🔍 DEBUG: activeOrders - order \(order.id) type: \(order.type) status: '\(order.status)'")
        }

        guard let index = orderManagementService.activeOrders.firstIndex(where: { $0.id == orderId }) else {
            // Order not found, stop task
            let orderIdCopy = orderId
            let taskQueue = self.taskQueue
            taskQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self.orderStatusTasks[orderIdCopy]?.cancel()
                self.orderStatusTasks.removeValue(forKey: orderIdCopy)
            }
            print("🔍 DEBUG: advanceOrderStatus - order \(orderId) not found in activeOrders, stopping task")
            return
        }

        let order = orderManagementService.activeOrders[index]
        let currentStatus = order.status
        let nextStatus: String

        print("🔍 DEBUG: advanceOrderStatus - order \(orderId) current status: '\(currentStatus)' (type: \(order.type))")

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
            let orderIdCopy = orderId
            let taskQueue = self.taskQueue
            taskQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self.orderStatusTasks[orderIdCopy]?.cancel()
                self.orderStatusTasks.removeValue(forKey: orderIdCopy)
            }
            print("🔍 DEBUG: advanceOrderStatus - order \(orderId) completed, stopping task")
            return
        default:
            // Unknown status, stop task
            let orderIdCopy = orderId
            let taskQueue = self.taskQueue
            taskQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self.orderStatusTasks[orderIdCopy]?.cancel()
                self.orderStatusTasks.removeValue(forKey: orderIdCopy)
            }
            print("🔍 DEBUG: advanceOrderStatus - order \(orderId) unknown status \(currentStatus), stopping task")
            return
        }

        // Update order status through OrderManagementService
        try? await orderManagementService.updateOrderStatus(orderId, status: nextStatus)

        // Get the updated order and notify the calling service
        if let updatedOrder = orderManagementService.activeOrders.first(where: { $0.id == orderId }) {
            onStatusUpdate(nextStatus, updatedOrder)
            print("🔍 DEBUG: advanceOrderStatus - order \(orderId) status changed from \(currentStatus) to \(nextStatus)")
        }
    }

    func moveOrderToHoldings(_ orderId: String, activeOrders: [Order], onOrderMoved: @escaping (Order) -> Void) async {
        guard let index = activeOrders.firstIndex(where: { $0.id == orderId }) else {
            print("🔍 DEBUG: moveOrderToHoldings - order \(orderId) not found in activeOrders")
            return
        }

        let order = activeOrders[index]
        print("🔍 DEBUG: moveOrderToHoldings - moving order \(orderId) to holdings. Current activeOrders count: \(activeOrders.count)")

        // Notify the calling service about the order that needs to be moved
        onOrderMoved(order)
    }
}
