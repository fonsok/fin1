import Combine
import Foundation

// MARK: - Unified Order Service Protocol
/// Single service for all order operations - replaces the complex service chain
@MainActor
protocol UnifiedOrderServiceProtocol: ObservableObject {
    // MARK: - Published Properties
    var activeOrders: [Order] { get }
    var completedTrades: [Trade] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Publishers
    var activeOrdersPublisher: AnyPublisher<[Order], Never> { get }
    var completedTradesPublisher: AnyPublisher<[Trade], Never> { get }

    // MARK: - Order Operations
    func placeBuyOrder(_ request: BuyOrderRequest) async throws -> OrderBuy
    func placeSellOrder(_ request: SellOrderRequest) async throws -> OrderSell
    func cancelOrder(_ orderId: String) async throws
    func updateOrderStatus(_ orderId: String, status: String) async throws

    // MARK: - Trade Operations
    func createTrade(from buyOrder: OrderBuy) async throws -> Trade
    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws -> Trade

    // MARK: - Lifecycle Controls
    func start()
    func stop()
    func reset()
}

// MARK: - Unified Order Service Implementation
@MainActor
final class UnifiedOrderService: @preconcurrency ServiceLifecycle, UnifiedOrderServiceProtocol {
    // MARK: - Published Properties
    @Published var activeOrders: [Order] = []
    @Published var completedTrades: [Trade] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Publishers
    var activeOrdersPublisher: AnyPublisher<[Order], Never> {
        self.$activeOrders.eraseToAnyPublisher()
    }

    var completedTradesPublisher: AnyPublisher<[Trade], Never> {
        self.$completedTrades.eraseToAnyPublisher()
    }

    // MARK: - Dependencies
    private let transactionIdService: any TransactionIdServiceProtocol
    private let orderStatusSimulationService: any OrderStatusSimulationServiceProtocol
    private let tradingNotificationService: any TradingNotificationServiceProtocol
    private let cashBalanceService: any CashBalanceServiceProtocol
    private let tradeNumberService: any TradeNumberServiceProtocol
    private let invoiceService: any InvoiceServiceProtocol
    private let userService: (any UserServiceProtocol)?
    private let auditLoggingService: (any AuditLoggingServiceProtocol)?
    private let tradeAPIService: (any TradeAPIServiceProtocol)?

    // MARK: - Current Trader ID
    /// Returns the current trader's ID from the user service
    private var currentTraderId: String {
        self.userService?.currentUser?.id ?? "unknown_trader"
    }

    // MARK: - Private Properties
    private var orderStatusTimers: [String: Timer] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let completionHandler: UnifiedOrderCompletionHandler

    // MARK: - Initialization
    init(
        transactionIdService: any TransactionIdServiceProtocol,
        orderStatusSimulationService: any OrderStatusSimulationServiceProtocol,
        tradingNotificationService: any TradingNotificationServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        tradeNumberService: any TradeNumberServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        userService: (any UserServiceProtocol)? = nil,
        auditLoggingService: (any AuditLoggingServiceProtocol)? = nil,
        tradeAPIService: (any TradeAPIServiceProtocol)? = nil
    ) {
        self.transactionIdService = transactionIdService
        self.orderStatusSimulationService = orderStatusSimulationService
        self.tradingNotificationService = tradingNotificationService
        self.cashBalanceService = cashBalanceService
        self.tradeNumberService = tradeNumberService
        self.invoiceService = invoiceService
        self.userService = userService
        self.auditLoggingService = auditLoggingService
        self.tradeAPIService = tradeAPIService

        // Initialize completion handler with tradeAPIService for backend sync
        self.completionHandler = UnifiedOrderCompletionHandler(
            tradingNotificationService: tradingNotificationService,
            cashBalanceService: cashBalanceService,
            invoiceService: invoiceService,
            tradeNumberService: tradeNumberService,
            tradeAPIService: tradeAPIService
        )
    }

    // MARK: - ServiceLifecycle
    func start() {
        // Start any background services if needed
    }

    func stop() {
        // Stop all order status timers
        self.orderStatusTimers.values.forEach { $0.invalidate() }
        self.orderStatusTimers.removeAll()
    }

    func reset() {
        self.activeOrders = []
        self.completedTrades = []
        self.isLoading = false
        self.errorMessage = nil
        self.stop()
    }

    // MARK: - Order Operations
    func placeBuyOrder(_ request: BuyOrderRequest) async throws -> OrderBuy {
        self.isLoading = true
        self.errorMessage = nil
        defer { isLoading = false }

        print("🔍 UnifiedOrderService.placeBuyOrder: Creating order")
        print("   📊 request.quantity: \(request.quantity)")
        print("   📊 request.price: \(request.price)")

        // Calculate total amount (securities value)
        // totalAmount = quantity × price (securities value, not adjusted by subscription ratio)
        // The subscription ratio affects how many units = 1 share, but totalAmount is the securities value
        let totalAmount = Double(request.quantity) * request.price

        let orderQuantity = Double(request.quantity)
        print("   ✅ order.quantity: \(orderQuantity)")
        print("   ✅ order.totalAmount: \(totalAmount)")

        let order = Order(
            id: transactionIdService.generateOrderId(),
            traderId: self.currentTraderId, // Use actual logged-in trader ID
            symbol: request.symbol,
            description: request.description ?? "Optionsschein",
            type: .buy,
            quantity: orderQuantity,
            price: request.price,
            totalAmount: totalAmount, // ✅ FIXED: Account for subscription ratio
            createdAt: Date(),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date(),
            optionDirection: request.optionDirection,
            underlyingAsset: request.description,
            wkn: request.symbol,
            category: "Optionsschein",
            strike: request.strike,
            orderInstruction: request.orderInstruction,
            limitPrice: request.limitPrice,
            subscriptionRatio: request.subscriptionRatio,
            denomination: request.denomination
        )

        let buyOrder = OrderBuy(from: order)

        // Add to active orders
        self.activeOrders.append(order)

        // Start status progression
        self.startOrderStatusProgression(order.id, isBuyOrder: true)

        // Send notification
        await self.tradingNotificationService.sendOrderStatusNotification(orderId: order.id, status: "submitted")

        return buyOrder
    }

    func placeSellOrder(_ request: SellOrderRequest) async throws -> OrderSell {
        self.isLoading = true
        self.errorMessage = nil
        defer { isLoading = false }

        print("🔍 UnifiedOrderService.placeBuyOrder: Creating order")
        print("   📊 request.quantity: \(request.quantity)")
        print("   📊 request.price: \(request.price)")

        let orderQuantity = Double(request.quantity)
        let orderTotalAmount = orderQuantity * request.price
        print("   ✅ order.quantity: \(orderQuantity)")
        print("   ✅ order.totalAmount: \(orderTotalAmount)")

        let order = Order(
            id: transactionIdService.generateOrderId(),
            traderId: self.currentTraderId, // Use actual logged-in trader ID
            symbol: request.symbol,
            description: request.description ?? "Optionsschein",
            type: .sell,
            quantity: Double(request.quantity),
            price: request.price,
            totalAmount: Double(request.quantity) * request.price,
            createdAt: Date(),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date(),
            optionDirection: request.optionDirection,
            underlyingAsset: request.description,
            wkn: request.symbol,
            category: "Optionsschein",
            strike: request.strike,
            orderInstruction: request.orderInstruction,
            limitPrice: request.limitPrice,
            originalHoldingId: request.originalHoldingId
        )

        let sellOrder = OrderSell(from: order)

        // Add to active orders
        self.activeOrders.append(order)

        // Start status progression
        self.startOrderStatusProgression(order.id, isBuyOrder: false)

        // ✅ MiFID II Compliance: Log sell order placement
        if let auditService = auditLoggingService,
           let userId = userService?.currentUser?.id {
            let complianceEvent = ComplianceEvent(
                eventType: .orderPlaced,
                agentId: userId,
                customerId: userId,
                description: "Sell order placed: \(request.description ?? request.symbol) - \(request.quantity) @ €\(request.price.formatted(.number.precision(.fractionLength(2)))))",
                severity: .medium,
                requiresReview: false,
                notes: "Order ID: \(order.id), Symbol: \(request.symbol), Mode: \(request.orderInstruction ?? "market")"
            )
            Task {
                await auditService.logComplianceEvent(complianceEvent)
            }
        }

        // Send notification
        await self.tradingNotificationService.sendOrderStatusNotification(orderId: order.id, status: "submitted")

        return sellOrder
    }

    func cancelOrder(_ orderId: String) async throws {
        // Stop status progression
        self.orderStatusTimers[orderId]?.invalidate()
        self.orderStatusTimers.removeValue(forKey: orderId)

        // Remove from active orders
        self.activeOrders.removeAll { $0.id == orderId }

        // Send notification
        await self.tradingNotificationService.sendOrderStatusNotification(orderId: orderId, status: "cancelled")
    }

    func updateOrderStatus(_ orderId: String, status: String) async throws {
        guard let index = activeOrders.firstIndex(where: { $0.id == orderId }) else {
            throw AppError.orderNotFound(orderId)
        }

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
            originalHoldingId: order.originalHoldingId,
            status: status
        )

        self.activeOrders[index] = updatedOrder

        // Handle order completion
        if status == "completed" {
            await self.completionHandler.handleOrderCompletion(order: updatedOrder, completedTrades: self.completedTrades)

            // Remove from active orders after completion
            self.activeOrders.removeAll { $0.id == order.id }
        }
    }

    // MARK: - Trade Operations
    func createTrade(from buyOrder: OrderBuy) async throws -> Trade {
        let trade = try await completionHandler.createTrade(from: buyOrder)
        self.completedTrades.append(trade)
        return trade
    }

    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws -> Trade {
        let updatedTrade = try await completionHandler.addSellOrderToTrade(tradeId, sellOrder: sellOrder, in: self.completedTrades)

        guard let tradeIndex = completedTrades.firstIndex(where: { $0.id == tradeId }) else {
            throw AppError.tradeNotFound(tradeId)
        }
        self.completedTrades[tradeIndex] = updatedTrade

        return updatedTrade
    }

    // MARK: - Private Methods
    private func startOrderStatusProgression(_ orderId: String, isBuyOrder: Bool) {
        self.orderStatusSimulationService.startOrderStatusProgression(orderId) { [weak self] status, _ in
            Task { @MainActor in
                try? await self?.updateOrderStatus(orderId, status: status)
            }
        }
    }
}

// MARK: - Sell Order Request
struct SellOrderRequest {
    let symbol: String
    let quantity: Int
    let price: Double
    let optionDirection: String?
    let description: String?
    let orderInstruction: String?
    let limitPrice: Double?
    let strike: Double?
    let originalHoldingId: String?
}
