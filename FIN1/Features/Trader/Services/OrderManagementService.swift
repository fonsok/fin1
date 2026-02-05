import Foundation
import Combine

// MARK: - Order Management Service Implementation
/// Handles order placement, status updates, and management
final class OrderManagementService: OrderManagementServiceProtocol, ServiceLifecycle {
    static let shared = OrderManagementService()

    @Published var activeOrders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let transactionIdService: any TransactionIdServiceProtocol
    private let userService: (any UserServiceProtocol)?
    private var orderAPIService: OrderAPIServiceProtocol?

    var activeOrdersPublisher: AnyPublisher<[Order], Never> {
        $activeOrders
            .handleEvents(receiveOutput: { orders in
                print("🔍 DEBUG: OrderManagementService activeOrdersPublisher emitted \(orders.count) orders")
            })
            .eraseToAnyPublisher()
    }

    private var orderStatusTimers: [String: Timer] = [:]

    init(
        transactionIdService: any TransactionIdServiceProtocol = TransactionIdService(),
        userService: (any UserServiceProtocol)? = nil,
        orderAPIService: OrderAPIServiceProtocol? = nil
    ) {
        self.transactionIdService = transactionIdService
        self.userService = userService
        self.orderAPIService = orderAPIService
        loadMockData()
    }

    /// Configure the API service for backend synchronization
    func configure(orderAPIService: OrderAPIServiceProtocol) {
        self.orderAPIService = orderAPIService
    }

    // MARK: - Current Trader ID
    /// Returns the current trader's ID from the user service
    /// Falls back to "unknown_trader" if no user is logged in
    private var currentTraderId: String {
        userService?.currentUser?.id ?? "unknown_trader"
    }

    // MARK: - ServiceLifecycle
    func start() {
        Task {
            try? await loadActiveOrders()
        }
    }

    func stop() {
        // Clean up all order timers
        orderStatusTimers.values.forEach { $0.invalidate() }
        orderStatusTimers.removeAll()
    }

    func reset() {
        activeOrders.removeAll()
        errorMessage = nil
        stop() // Clean up timers
    }

    // MARK: - Order Data Management

    func loadActiveOrders() async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        // Try to fetch from backend first
        if let apiService = orderAPIService {
            do {
                let orders = try await apiService.fetchActiveOrders(for: currentTraderId)
                await MainActor.run {
                    self.activeOrders = orders
                    self.isLoading = false
                }
                return
            } catch {
                print("⚠️ Failed to fetch orders from backend, using local: \(error.localizedDescription)")
            }
        }

        // Fallback to local mock data
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        await MainActor.run {
            loadActiveOrdersSync()
            isLoading = false
        }
    }

    func refreshActiveOrders() async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        await MainActor.run {
            loadActiveOrdersSync()
            isLoading = false
        }
    }

    // MARK: - Order Management

    func placeBuyOrder(symbol: String, quantity: Int, price: Double, optionDirection: String?, description: String?, orderInstruction: String?, limitPrice: Double?, strike: Double?, subscriptionRatio: Double?, denomination: Int?) async throws -> OrderBuy {
        let params = BuyOrderParameters(
            symbol: symbol,
            quantity: quantity,
            price: price,
            optionDirection: optionDirection,
            description: description,
            orderInstruction: orderInstruction,
            limitPrice: limitPrice,
            strike: strike,
            subscriptionRatio: subscriptionRatio,
            denomination: denomination
        )

        return try await placeBuyOrder(params: params)
    }

    func placeBuyOrder(params: BuyOrderParameters) async throws -> OrderBuy {
        DataFlowValidator.logDataFlow(
            step: "OrderManagementService.placeBuyOrder entry",
            optionDirection: params.optionDirection,
            underlyingAsset: params.description
        )

        let orderDetails = try validateAndProcessOrderDetails(params)
        let order = createOrder(from: orderDetails, params: params)
        var newOrder = OrderBuy(from: order)

        await addOrderToActiveList(order)

        // Sync to backend (write-through pattern)
        if let apiService = orderAPIService {
            Task.detached { [apiService, newOrder] in
                do {
                    let savedOrder = try await apiService.saveBuyOrder(newOrder)
                    print("✅ Order synced to backend: \(savedOrder.id)")
                } catch {
                    print("⚠️ Failed to sync order to backend: \(error.localizedDescription)")
                }
            }
        }

        return newOrder
    }

    // MARK: - Private Helper Methods

    private func validateAndProcessOrderDetails(_ params: BuyOrderParameters) throws -> OrderDetails {
        let isOptionsOrder = params.optionDirection != nil

        if isOptionsOrder {
            try validateOptionsOrder(params)
        }

        let finalOptionType = determineOptionType(params, isOptionsOrder: isOptionsOrder)
        let underlyingAsset = determineUnderlyingAsset(params, isOptionsOrder: isOptionsOrder)

        print("🔍 DEBUG: finalOptionType = \(finalOptionType ?? "nil")")
        print("🔍 DEBUG: underlyingAsset = \(underlyingAsset ?? "nil")")

        return OrderDetails(
            isOptionsOrder: isOptionsOrder,
            optionType: finalOptionType,
            underlyingAsset: underlyingAsset
        )
    }

    private func validateOptionsOrder(_ params: BuyOrderParameters) throws {
        if params.optionDirection == nil {
            print("❌ ERROR: isOptionsOrder=true but optionDirection=nil")
            throw AppError.validationError("Invalid options order: missing option type")
        }

        if params.description == nil {
            print("❌ ERROR: isOptionsOrder=true but description=nil")
            throw AppError.validationError("Invalid options order: missing underlying asset")
        }
    }

    private func determineOptionType(_ params: BuyOrderParameters, isOptionsOrder: Bool) -> String? {
        guard isOptionsOrder else { return nil }

        if let passedOptionType = params.optionDirection {
            return passedOptionType.uppercased()
        } else {
            return "CALL"
        }
    }

    private func determineUnderlyingAsset(_ params: BuyOrderParameters, isOptionsOrder: Bool) -> String? {
        guard isOptionsOrder else { return nil }

        if params.description == nil {
            print("⚠️ WARNING: underlyingAsset is nil for options order - this should not happen")
        }

        return params.description
    }

    private func createOrder(from details: OrderDetails, params: BuyOrderParameters) -> Order {
        return Order(
            id: transactionIdService.generateOrderId(),
            traderId: currentTraderId, // Use actual logged-in trader ID
            symbol: params.symbol,
            description: details.isOptionsOrder ? "Optionsschein - \(details.underlyingAsset ?? "Unknown")" : "Aktie",
            type: .buy,
            quantity: Double(params.quantity),
            price: params.price,
            totalAmount: Double(params.quantity) * params.price,
            createdAt: Date(),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date(),
            optionDirection: details.optionType,
            underlyingAsset: details.underlyingAsset,
            wkn: params.symbol, // Use the symbol as WKN
            category: nil, // TODO: Set category from search result
            strike: params.strike,
            orderInstruction: params.orderInstruction,
            limitPrice: params.limitPrice,
            subscriptionRatio: params.subscriptionRatio,
            denomination: params.denomination
        )
    }

    private func addOrderToActiveList(_ order: Order) async {
        await MainActor.run {
            activeOrders.append(order)
            print("🔍 DEBUG: OrderManagementService added order \(order.id) to activeOrders. Total count: \(activeOrders.count)")
        }
    }
}

// MARK: - Supporting Types

struct OrderDetails {
    let isOptionsOrder: Bool
    let optionType: String?
    let underlyingAsset: String?
}

extension OrderManagementService {
    func placeSellOrder(symbol: String, quantity: Int, price: Double) async throws -> OrderSell {
        let newOrder = OrderSell(
            id: transactionIdService.generateOrderId(),
            traderId: currentTraderId, // Use actual logged-in trader ID
            symbol: symbol,
            description: "Typ - Basiswert", // Placeholder
            quantity: Double(quantity),
            price: price,
            totalAmount: Double(quantity) * price,
            status: .submitted,
            createdAt: Date(),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: nil,
            category: nil,
            strike: nil,
            orderInstruction: nil,
            limitPrice: nil,
            originalHoldingId: nil
        )

        await MainActor.run {
            let order = Order(
                id: newOrder.id,
                traderId: newOrder.traderId,
                symbol: newOrder.symbol,
                description: newOrder.description,
                type: .sell,
                quantity: newOrder.quantity,
                price: newOrder.price,
                totalAmount: newOrder.totalAmount,
                createdAt: newOrder.createdAt,
                executedAt: newOrder.executedAt,
                confirmedAt: newOrder.confirmedAt,
                updatedAt: newOrder.updatedAt,
                optionDirection: newOrder.optionDirection,
                underlyingAsset: newOrder.underlyingAsset,
                wkn: newOrder.wkn,
                category: newOrder.category,
                strike: newOrder.strike,
                orderInstruction: newOrder.orderInstruction,
                limitPrice: newOrder.limitPrice,
                originalHoldingId: newOrder.originalHoldingId
            )
            activeOrders.append(order)
        }

        // Sync to backend (write-through pattern)
        if let apiService = orderAPIService {
            Task.detached { [apiService, newOrder] in
                do {
                    let savedOrder = try await apiService.saveSellOrder(newOrder)
                    print("✅ Sell order synced to backend: \(savedOrder.id)")
                } catch {
                    print("⚠️ Failed to sync sell order to backend: \(error.localizedDescription)")
                }
            }
        }

        return newOrder
    }

    func updateOrderStatus(_ orderId: String, status: String) async throws {
        await MainActor.run {
            if let index = activeOrders.firstIndex(where: { $0.id == orderId }) {
                let order = activeOrders[index]
                let updatedOrder = Order(
                    id: order.id,
                    traderId: order.traderId,
                    symbol: order.symbol,
                    description: order.description,
                    type: order.type,
                    quantity: order.quantity,
                    price: order.price,
                    totalAmount: order.totalAmount,
                    createdAt: order.createdAt,
                    executedAt: order.executedAt,
                    confirmedAt: order.confirmedAt,
                    updatedAt: Date(),
                    optionDirection: order.optionDirection,
                    underlyingAsset: order.underlyingAsset,
                    wkn: order.wkn,
                    category: order.category,
                    strike: order.strike,
                    orderInstruction: order.orderInstruction,
                    limitPrice: order.limitPrice,
                    status: status
                )
                activeOrders[index] = updatedOrder
            }
        }
    }

    func cancelOrder(_ orderId: String) async throws {
        await MainActor.run {
            if let index = activeOrders.firstIndex(where: { $0.id == orderId }) {
                activeOrders.remove(at: index)
            }
        }
    }

    // MARK: - Private Methods

    private func loadMockData() {
        // Load mock orders for testing
        activeOrders = mockRunningTransactions
        print("🔍 DEBUG: OrderManagementService loaded \(activeOrders.count) mock orders")
        loadActiveOrdersSync()
    }

    func addOrderToActiveOrders(_ order: Order) async {
        await MainActor.run {
            activeOrders.append(order)
            print("🔍 DEBUG: OrderManagementService added order \(order.id) to activeOrders. Total count: \(activeOrders.count)")
        }
    }

    private func loadActiveOrdersSync() {
        // In real app, this would load from API
        // For now, keep existing orders to prevent them from disappearing
        // when app becomes active (e.g., returning from browser)
        // activeOrders = [] // Commented out to preserve ongoing orders

        // Force @Published update to notify subscribers
        print("🔍 DEBUG: OrderManagementService loadActiveOrdersSync - publishing \(activeOrders.count) orders")
        objectWillChange.send()
    }

    // MARK: - Backend Synchronization

    /// Syncs any pending orders to the backend
    /// Called automatically when app enters background
    func syncToBackend() async {
        guard let apiService = orderAPIService else {
            print("⚠️ OrderManagementService: No API service configured, skipping sync")
            return
        }

        let ordersToSync = activeOrders.filter { order in
            // Sync orders that are not yet completed or cancelled
            let status = order.status.lowercased()
            return status != "completed" && status != "cancelled"
        }

        guard !ordersToSync.isEmpty else {
            print("📤 OrderManagementService: No pending orders to sync")
            return
        }

        print("📤 OrderManagementService: Syncing \(ordersToSync.count) orders to backend...")

        for order in ordersToSync {
            do {
                _ = try await apiService.updateOrder(order)
                print("✅ Order \(order.id) synced")
            } catch {
                print("⚠️ Failed to sync order \(order.id): \(error.localizedDescription)")
            }
        }

        print("✅ OrderManagementService: Background sync completed")
    }
}
