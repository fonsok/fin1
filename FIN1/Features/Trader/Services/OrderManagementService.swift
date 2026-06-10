import Combine
import Foundation

// MARK: - Order Management Service Implementation
/// Handles order placement, status updates, and management
final class OrderManagementService: OrderManagementServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = OrderManagementService()

    @Published var activeOrders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let transactionIdService: any TransactionIdServiceProtocol
    private let userService: (any UserServiceProtocol)?
    private var orderAPIService: OrderAPIServiceProtocol?
    /// Parse `tradeId` for sell orders keyed by order id (needed for backend status sync).
    private var sellOrderTradeIds: [String: String] = [:]
    /// `pairExecutionId` for paired-buy trader legs (server finalize + paired cancel).
    private var pairedBuyExecutionIds: [String: String] = [:]

    var activeOrdersPublisher: AnyPublisher<[Order], Never> {
        self.$activeOrders
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
        self.userService?.currentUser?.id ?? "unknown_trader"
    }

    // MARK: - ServiceLifecycle
    func start() {
        Task {
            try? await self.loadActiveOrders()
        }
    }

    func stop() {
        // Clean up all order timers
        self.orderStatusTimers.values.forEach { $0.invalidate() }
        self.orderStatusTimers.removeAll()
    }

    func reset() {
        self.activeOrders.removeAll()
        self.errorMessage = nil
        self.stop() // Clean up timers
    }

    // MARK: - Order Data Management

    func loadActiveOrders() async throws {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        // Try to fetch from backend first
        if let apiService = orderAPIService {
            do {
                let orders = try await apiService.fetchActiveOrders(for: self.currentTraderId)
                await MainActor.run {
                    self.activeOrders = orders
                    self.restorePairedBuyLinks(from: orders)
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
            self.isLoading = false
        }
    }

    func refreshActiveOrders() async throws {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        await MainActor.run {
            loadActiveOrdersSync()
            self.isLoading = false
        }
    }

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
    ) async throws -> OrderBuy {
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
            denomination: denomination,
            isMirrorPoolOrder: isMirrorPoolOrder
        )

        return try await self.placeBuyOrder(params: params)
    }

    func placeBuyOrder(params: BuyOrderParameters) async throws -> OrderBuy {
        DataFlowValidator.logDataFlow(
            step: "OrderManagementService.placeBuyOrder entry",
            optionDirection: params.optionDirection,
            underlyingAsset: params.description
        )

        let orderDetails = try validateAndProcessOrderDetails(params)
        let order = self.createOrder(from: orderDetails, params: params)
        let newOrder = OrderBuy(from: order)

        await addOrderToActiveList(order)

        // Sync to backend (write-through pattern)
        if let apiService = orderAPIService {
            Task { [apiService, newOrder] in
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
            try self.validateOptionsOrder(params)
        }

        let finalOptionType = self.determineOptionType(params, isOptionsOrder: isOptionsOrder)
        let underlyingAsset = self.determineUnderlyingAsset(params, isOptionsOrder: isOptionsOrder)

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
            id: self.transactionIdService.generateOrderId(),
            traderId: self.currentTraderId, // Use actual logged-in trader ID
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
            denomination: params.denomination,
            isMirrorPoolOrder: params.isMirrorPoolOrder
        )
    }

    private func addOrderToActiveList(_ order: Order) async {
        await MainActor.run {
            self.activeOrders.append(order)
            print("🔍 DEBUG: OrderManagementService added order \(order.id) to activeOrders. Total count: \(self.activeOrders.count)")
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
            traderId: self.currentTraderId, // Use actual logged-in trader ID
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
            self.activeOrders.append(order)
        }

        // Sync to backend (write-through pattern)
        if let apiService = orderAPIService {
            Task { [apiService, newOrder] in
                do {
                    let savedOrder = try await apiService.saveSellOrder(newOrder, tradeId: nil)
                    print("✅ Sell order synced to backend: \(savedOrder.id)")
                } catch {
                    print("⚠️ Failed to sync sell order to backend: \(error.localizedDescription)")
                }
            }
        }

        return newOrder
    }

    func updateOrderStatus(_ orderId: String, status: String) async throws {
        let normalized = status.lowercased()

        if normalized == "confirmed" || normalized == "completed" {
            if self.pairedBuyExecutionId(for: orderId) != nil {
                try await self.ensurePairedBuyFinalized(for: orderId)
            }
        }

        if let pairExecutionId = self.pairedBuyExecutionIds[orderId],
           let apiService = self.orderAPIService,
           normalized != "executed",
           normalized != "suspended" {
            // `suspended` is UI-only for STORNO window; server catches up in commitPairedBuyExecution.
            if normalized == "completed" {
                try await apiService.commitPairedBuyExecution(
                    pairExecutionId: pairExecutionId,
                    postDisplayStatus: "completed"
                )
            } else {
                try await apiService.advancePairedOrderStatus(
                    pairExecutionId: pairExecutionId,
                    status: normalized
                )
            }
        }

        await MainActor.run {
            if let index = activeOrders.firstIndex(where: { $0.id == orderId }) {
                let order = self.activeOrders[index]
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
                    executedAt: status == "executed" ? (order.executedAt ?? Date()) : order.executedAt,
                    confirmedAt: status == "confirmed" ? (order.confirmedAt ?? Date()) : order.confirmedAt,
                    updatedAt: Date(),
                    optionDirection: order.optionDirection,
                    underlyingAsset: order.underlyingAsset,
                    wkn: order.wkn,
                    category: order.category,
                    strike: order.strike,
                    orderInstruction: order.orderInstruction,
                    limitPrice: order.limitPrice,
                    isMirrorPoolOrder: order.isMirrorPoolOrder,
                    originalHoldingId: order.originalHoldingId,
                    pairExecutionId: order.pairExecutionId,
                    status: status
                )
                self.activeOrders[index] = updatedOrder
            }
        }
    }

    func restorePairedBuyLinks(from orders: [Order]) {
        for order in orders {
            guard let pairId = order.pairExecutionId?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !pairId.isEmpty else { continue }
            self.pairedBuyExecutionIds[order.id] = pairId
        }
    }

    func ensurePairedBuyFinalized(for orderId: String) async throws {
        guard self.pairedBuyExecutionId(for: orderId) != nil else { return }

        var lastError: Error?
        for attempt in 1...5 {
            do {
                try await self.finalizePairedBuyExecution(for: orderId)
                return
            } catch {
                lastError = error
                print(
                    "⚠️ OrderManagementService: paired buy finalize attempt \(attempt)/5 failed — \(error.localizedDescription)"
                )
                if attempt < 5 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }
        throw lastError ?? AppError.validationError("Paired buy finalize failed")
    }

    func cancelOrder(_ orderId: String) async throws {
        if let apiService = orderAPIService {
            do {
                try await apiService.cancelOrder(orderId)
            } catch {
                // Paired/server-backed orders must cancel on Parse (mirror leg too).
                if self.pairedBuyExecutionIds[orderId] != nil {
                    throw error
                }
                print("⚠️ OrderManagementService: Server cancel skipped — \(error.localizedDescription)")
            }
        }
        await self.removeActiveOrder(orderId)
    }

    func removeActiveOrder(_ orderId: String) async {
        await MainActor.run {
            if let index = activeOrders.firstIndex(where: { $0.id == orderId }) {
                self.activeOrders.remove(at: index)
            }
            self.pairedBuyExecutionIds.removeValue(forKey: orderId)
        }
    }

    // MARK: - Private Methods

    private func loadMockData() {
        // Load mock orders for testing
        self.activeOrders = mockRunningTransactions
        print("🔍 DEBUG: OrderManagementService loaded \(self.activeOrders.count) mock orders")
        self.loadActiveOrdersSync()
    }

    func addOrderToActiveOrders(_ order: Order) async {
        await MainActor.run {
            self.activeOrders.append(order)
            print("🔍 DEBUG: OrderManagementService added order \(order.id) to activeOrders. Total count: \(self.activeOrders.count)")
        }
    }

    func persistSellOrder(_ order: OrderSell, tradeId: String?) async throws -> OrderSell {
        guard let apiService = orderAPIService else {
            print("⚠️ OrderManagementService: No API service — sell order stays local only")
            return order
        }

        let savedOrder = try await apiService.saveSellOrder(order, tradeId: tradeId)
        if let tradeId {
            self.sellOrderTradeIds[savedOrder.id] = tradeId
        }
        print("✅ OrderManagementService: Sell order persisted — Parse id \(savedOrder.id), tradeId \(tradeId ?? "nil")")
        return savedOrder
    }

    func syncActiveOrderToBackend(_ orderId: String) async {
        guard let apiService = orderAPIService else { return }

        let orderSnapshot: Order? = await MainActor.run {
            self.activeOrders.first(where: { $0.id == orderId })
        }
        guard let order = orderSnapshot else { return }

        let tradeId = self.sellOrderTradeIds[orderId]
        do {
            _ = try await apiService.updateOrder(order, tradeId: tradeId)
            print("✅ OrderManagementService: Synced order \(orderId) status '\(order.status)' to backend")
        } catch {
            print("⚠️ OrderManagementService: Failed to sync order \(orderId): \(error.localizedDescription)")
        }
    }

    func registerSellOrderTradeLink(orderId: String, tradeId: String) {
        self.sellOrderTradeIds[orderId] = tradeId
    }

    func registerPairedBuyExecutionLink(orderId: String, pairExecutionId: String) {
        self.pairedBuyExecutionIds[orderId] = pairExecutionId
    }

    func pairedBuyExecutionId(for orderId: String) -> String? {
        self.pairedBuyExecutionIds[orderId]
    }

    @MainActor
    func reportOrderStatusFailure(_ message: String) {
        self.errorMessage = message
    }

    func finalizePairedBuyExecution(for orderId: String) async throws {
        guard let pairExecutionId = pairedBuyExecutionIds[orderId] else { return }
        guard let apiService = orderAPIService else {
            throw AppError.validationError("Backend-Verbindung nicht verfügbar für Paired-Buy-Finalize.")
        }
        try await apiService.commitPairedBuyExecution(
            pairExecutionId: pairExecutionId,
            postDisplayStatus: nil
        )
    }

    private func loadActiveOrdersSync() {
        // In real app, this would load from API
        // For now, keep existing orders to prevent them from disappearing
        // when app becomes active (e.g., returning from browser)
        // activeOrders = [] // Commented out to preserve ongoing orders

        // Force @Published update to notify subscribers
        print("🔍 DEBUG: OrderManagementService loadActiveOrdersSync - publishing \(self.activeOrders.count) orders")
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

        let ordersToSync = self.activeOrders.filter { order in
            if self.pairedBuyExecutionIds[order.id] != nil {
                return false
            }
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
                _ = try await apiService.updateOrder(order, tradeId: nil)
                print("✅ Order \(order.id) synced")
            } catch {
                print("⚠️ Failed to sync order \(order.id): \(error.localizedDescription)")
            }
        }

        print("✅ OrderManagementService: Background sync completed")
    }
}
