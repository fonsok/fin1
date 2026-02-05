import XCTest
@testable import FIN1

// MARK: - Unified Architecture Tests
/// Tests for the new unified order service and state manager
final class UnifiedArchitectureTests: XCTestCase {

    var unifiedOrderService: UnifiedOrderService!
    var tradingStateStore: TradingStateStore!
    var mockTransactionIdService: MockTransactionIdService!
    var mockOrderStatusSimulationService: MockOrderStatusSimulationService!
    var mockTradingNotificationService: MockTradingNotificationService!
    var mockCashBalanceService: MockCashBalanceService!
    var mockTradeNumberService: MockTradeNumberService!

    override func setUp() {
        super.setUp()

        // Create mock services
        mockTransactionIdService = MockTransactionIdService()
        mockOrderStatusSimulationService = MockOrderStatusSimulationService()
        mockTradingNotificationService = MockTradingNotificationService()
        mockCashBalanceService = MockCashBalanceService()
        mockTradeNumberService = MockTradeNumberService()

        // Initialize unified services
        tradingStateStore = TradingStateStore()
        unifiedOrderService = UnifiedOrderService(
            transactionIdService: mockTransactionIdService,
            orderStatusSimulationService: mockOrderStatusSimulationService,
            tradingNotificationService: mockTradingNotificationService,
            cashBalanceService: mockCashBalanceService,
            tradeNumberService: mockTradeNumberService
        )
    }

    override func tearDown() {
        unifiedOrderService = nil
        tradingStateStore = nil
        mockTransactionIdService = nil
        mockOrderStatusSimulationService = nil
        mockTradingNotificationService = nil
        mockCashBalanceService = nil
        mockTradeNumberService = nil
        super.tearDown()
    }

    // MARK: - Unified Order Service Tests

    func testUnifiedOrderServiceInitialization() {
        XCTAssertNotNil(unifiedOrderService)
        XCTAssertEqual(unifiedOrderService.activeOrders.count, 0)
        XCTAssertEqual(unifiedOrderService.completedTrades.count, 0)
        XCTAssertFalse(unifiedOrderService.isLoading)
        XCTAssertNil(unifiedOrderService.errorMessage)
    }

    func testPlaceBuyOrderWithStrikePrice() async throws {
        // Given
        let request = BuyOrderRequest(
            symbol: "TEST123",
            quantity: 100,
            price: 1.50,
            optionDirection: "CALL",
            description: "Test Warrant",
            orderInstruction: "market",
            limitPrice: nil,
            strike: 100.0
        )

        // When
        let order = try await unifiedOrderService.placeBuyOrder(request)

        // Then
        XCTAssertEqual(order.symbol, "TEST123")
        XCTAssertEqual(order.quantity, 100.0)
        XCTAssertEqual(order.price, 1.50)
        XCTAssertEqual(order.strike, 100.0)
        XCTAssertEqual(order.optionDirection, "CALL")
        XCTAssertEqual(unifiedOrderService.activeOrders.count, 1)
    }

    func testPlaceSellOrderWithOriginalHoldingId() async throws {
        // Given
        let request = SellOrderRequest(
            symbol: "TEST123",
            quantity: 50,
            price: 1.75,
            optionDirection: "CALL",
            description: "Test Warrant",
            orderInstruction: "market",
            limitPrice: nil,
            strike: 100.0,
            originalHoldingId: "HOLDING123"
        )

        // When
        let order = try await unifiedOrderService.placeSellOrder(request)

        // Then
        XCTAssertEqual(order.symbol, "TEST123")
        XCTAssertEqual(order.quantity, 50.0)
        XCTAssertEqual(order.price, 1.75)
        XCTAssertEqual(order.strike, 100.0)
        XCTAssertEqual(order.originalHoldingId, "HOLDING123")
        XCTAssertEqual(unifiedOrderService.activeOrders.count, 1)
    }

    // MARK: - Unified State Manager Tests

    func testTradingStateStoreInitialization() {
        XCTAssertNotNil(tradingStateStore)
        XCTAssertEqual(tradingStateStore.holdings.count, 0)
        XCTAssertEqual(tradingStateStore.activeOrders.count, 0)
        XCTAssertEqual(tradingStateStore.completedTrades.count, 0)
        XCTAssertFalse(tradingStateStore.isLoading)
        XCTAssertNil(tradingStateStore.errorMessage)
    }

    func testTradingStateStoreHoldingsUpdate() {
        // Given
        let mockHolding = createMockHolding()

        // When
        tradingStateStore.updateHoldings([mockHolding])

        // Then
        XCTAssertEqual(tradingStateStore.holdings.count, 1)
        XCTAssertEqual(tradingStateStore.holdings.first?.wkn, "TEST123")
    }

    // MARK: - Integration Test: Sell Order Issue Fix

    func testSellOrderDoesNotReappearInHoldings() async throws {
        // This test verifies that the original sell order issue is fixed

        // Given: Create a buy order first
        let buyRequest = BuyOrderRequest(
            symbol: "TEST123",
            quantity: 100,
            price: 1.50,
            optionDirection: "CALL",
            description: "Test Warrant",
            orderInstruction: "market",
            limitPrice: nil,
            strike: 100.0
        )

        let buyOrder = try await unifiedOrderService.placeBuyOrder(buyRequest)

        // Simulate buy order completion
        try await unifiedOrderService.updateOrderStatus(buyOrder.id, status: "completed")

        // Verify trade was created
        XCTAssertEqual(unifiedOrderService.completedTrades.count, 1)

        // When: Create a sell order with proper originalHoldingId
        let sellRequest = SellOrderRequest(
            symbol: "TEST123",
            quantity: 100,
            price: 1.75,
            optionDirection: "CALL",
            description: "Test Warrant",
            orderInstruction: "market",
            limitPrice: nil,
            strike: 100.0,
            originalHoldingId: buyOrder.id // This should link to the buy order
        )

        let sellOrder = try await unifiedOrderService.placeSellOrder(sellRequest)

        // Simulate sell order completion
        try await unifiedOrderService.updateOrderStatus(sellOrder.id, status: "completed")

        // Then: Verify the trade was updated correctly and holdings reflect the sale
        XCTAssertEqual(unifiedOrderService.completedTrades.count, 1)

        guard let updatedTrade = unifiedOrderService.completedTrades.first else {
            XCTFail("Expected completed trade not found")
            return
        }
        XCTAssertNotNil(updatedTrade.sellOrder)
        XCTAssertEqual(updatedTrade.sellOrder?.id, sellOrder.id)

        // The key test: Holdings should not show the security anymore (fully sold)
        // This verifies the original issue is fixed
        let holdings = tradingStateStore.holdings
        let remainingHoldings = holdings.filter { $0.wkn == "TEST123" && $0.remainingQuantity > 0 }
        XCTAssertEqual(remainingHoldings.count, 0, "Security should not reappear in holdings after full sale")
    }

    // MARK: - Helper Methods

    private func createMockHolding() -> DepotHolding {
        return DepotHolding(
            id: UUID(),
            orderId: "ORDER123",
            wkn: "TEST123",
            designation: "Test Warrant",
            quantity: 100,
            remainingQuantity: 100,
            currentPrice: 1.50,
            totalValue: 150.0,
            direction: "CALL",
            underlyingAsset: "Test Asset",
            strike: 100.0,
            position: 1
        )
    }
}

// MARK: - Mock Services

class MockTransactionIdService: TransactionIdServiceProtocol {
    private var counter = 0

    func start() async {}
    func stop() async {}
    func reset() async { counter = 0 }

    func generateOrderId() -> String {
        counter += 1
        return "ORDER_\(counter)"
    }

    func generateTradeId() -> String {
        counter += 1
        return "TRADE_\(counter)"
    }

    func generateInvoiceNumber() -> String {
        counter += 1
        return "INV_\(counter)"
    }

    func generateInvestorDocumentNumber() -> String {
        counter += 1
        return "INVST_\(counter)"
    }

    func generatePaymentId() -> String {
        counter += 1
        return "PAY_\(counter)"
    }

    func generateCustomerId() -> String {
        counter += 1
        return "CUST_\(counter)"
    }

    func validateId(_ id: String) -> Bool { !id.isEmpty }
}

class MockOrderStatusSimulationService: OrderStatusSimulationServiceProtocol {
    var isLoading: Bool { false }
    var errorMessage: String? { nil }

    func startOrderStatusProgression(_ orderId: String, onStatusUpdate: @escaping (String, Order) -> Void) {
        // Mock implementation - just call completion immediately
        let mockOrder = Order(
            id: orderId,
            traderId: "test_trader",
            symbol: "TEST",
            description: "Test",
            type: .buy,
            quantity: 100,
            price: 1.0,
            totalAmount: 100.0,
            createdAt: Date(),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date()
        )
        onStatusUpdate("completed", mockOrder)
    }

    func stopOrderStatusProgression(_ orderId: String) {}
    func stopAllOrderStatusProgressions() {}

    func advanceOrderStatus(_ orderId: String, onStatusUpdate: @escaping (String, Order) -> Void) async {
        // Immediately update to completed
        startOrderStatusProgression(orderId, onStatusUpdate: onStatusUpdate)
    }

    func moveOrderToHoldings(_ orderId: String, activeOrders: [Order], onOrderMoved: @escaping (Order) -> Void) async {}
}

class MockTradingNotificationService: TradingNotificationServiceProtocol {
    var isLoading: Bool { false }
    var errorMessage: String? { nil }

    func sendOrderStatusNotification(orderId: String, status: String) async {}
    func showBuyConfirmation(for trade: Trade) async {}
    func showSellConfirmation(for trade: Trade) async {}
    func generateInvoiceAndNotification(for order: Order, tradeId: String?, tradeNumber: Int?) async {}
    func generateCollectionBillDocument(for trade: Trade) async {}
    func sendTradeCompletionNotification(tradeId: String) async {}
}

class MockCashBalanceService: CashBalanceServiceProtocol {
    var currentBalance: Double = 0.0
    var formattedBalance: String { "€\(currentBalance)" }

    func start() async {}
    func stop() async {}
    func reset() async { currentBalance = 0.0 }

    func processBuyOrderExecution(amount: Double) async { currentBalance -= amount }
    func processSellOrderExecution(amount: Double) async { currentBalance += amount }
    func processGutschrift(amount: Double) async { currentBalance += amount }
    func resetToInitialBalance() async { currentBalance = 0.0 }
    func estimatedBalanceAfterPurchase(amount: Double) -> Double { currentBalance - amount }
    func hasSufficientFunds(for amount: Double, minimumReserve: Double?) -> Bool {
        let minReserve = minimumReserve ?? 20.0
        return (currentBalance - amount) >= minReserve
    }
}

class MockTradeNumberService: TradeNumberServiceProtocol {
    private var counter = 0

    func start() async {}
    func stop() async {}
    func reset() async { counter = 0 }

    func generateNextTradeNumber() -> Int { counter + 1; defer { counter += 1 } }
    func getCurrentTradeNumber() -> Int { counter }
    func formatTradeNumber(_ number: Int) -> String { String(format: "%03d", number) }
    func isValidTradeNumber(_ number: Int) -> Bool { number > 0 && number <= 999 }
}
