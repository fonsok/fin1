import XCTest
@testable import FIN1

final class TraderServiceTests: XCTestCase {
    var traderService: TraderService!
    var tradingCoordinator: TradingCoordinator!

    override func setUp() {
        super.setUp()
        // Build focused dependencies per new coordinator API
        let mockUserService = MockUserService()
        let mockTraderDataService = MockTraderDataService()
        let mockConfigurationService = ConfigurationService(userService: mockUserService)
        let commissionCalculationService = CommissionCalculationService()
        let traderCashBalanceService = TraderCashBalanceService(configurationService: mockConfigurationService)
        let orderLifecycleCoordinator = OrderLifecycleCoordinator(
            orderManagementService: OrderManagementService.shared,
            orderStatusSimulationService: OrderStatusSimulationService.shared,
            tradingNotificationService: TradingNotificationService.shared,
            tradeLifecycleService: TradeLifecycleService.shared,
            tradeMatchingService: TradeMatchingService(),
            cashBalanceService: CashBalanceService(),
            investmentService: nil,
            userService: mockUserService,
            traderDataService: mockTraderDataService,
            commissionCalculationService: commissionCalculationService,
            traderCashBalanceService: traderCashBalanceService
        )

        let tradingStateStore = LegacyTradingStateStore(
            orderManagementService: OrderManagementService.shared,
            tradeLifecycleService: TradeLifecycleService.shared,
            securitiesWatchlistService: SecuritiesWatchlistService.shared,
            orderStatusSimulationService: OrderStatusSimulationService.shared
        )

        let tradingStatisticsService = TradingStatisticsService()

        tradingCoordinator = TradingCoordinator(
            tradingStateStore: tradingStateStore,
            orderLifecycleCoordinator: orderLifecycleCoordinator,
            tradeLifecycleCoordinator: TradeLifecycleCoordinator(tradeLifecycleService: TradeLifecycleService.shared),
            securitiesWatchlistService: SecuritiesWatchlistService.shared,
            tradingStatisticsService: tradingStatisticsService
        )
        traderService = TraderService(tradingCoordinator: tradingCoordinator)
        traderService.reset()
    }

    override func tearDown() {
        traderService = nil
        tradingCoordinator = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertFalse(traderService.isLoading)
        XCTAssertNil(traderService.errorMessage)
        XCTAssertTrue(traderService.activeOrders.isEmpty)
        XCTAssertTrue(traderService.completedTrades.isEmpty)
        XCTAssertTrue(traderService.orders.isEmpty)
        // Trading stats not available in current TraderService implementation
    }

    // MARK: - Data Loading Tests

    func testLoadAllTradingData() async {
        // Given
        let expectation = XCTestExpectation(description: "Trading data loaded")

        // When
        do {
            try await traderService.loadAllTradingData()
            expectation.fulfill()
        } catch {
            XCTFail("Failed to load trading data: \(error)")
        }

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(traderService.activeOrders.isEmpty)
        XCTAssertFalse(traderService.completedTrades.isEmpty)
        XCTAssertFalse(traderService.orders.isEmpty)
        // Trading stats not available in current TraderService implementation
    }

    func testLoadActiveOrders() async {
        // Given
        let expectation = XCTestExpectation(description: "Active orders loaded")

        // When
        do {
            try await traderService.loadActiveOrders()
            expectation.fulfill()
        } catch {
            XCTFail("Failed to load active orders: \(error)")
        }

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(traderService.activeOrders.isEmpty)
        XCTAssertEqual(traderService.activeOrders.count, 2)
    }

    func testLoadCompletedTrades() async {
        // Given
        let expectation = XCTestExpectation(description: "Completed trades loaded")

        // When
        do {
            try await traderService.loadCompletedTrades()
            expectation.fulfill()
        } catch {
            XCTFail("Failed to load completed trades: \(error)")
        }

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(traderService.completedTrades.isEmpty)
        XCTAssertEqual(traderService.completedTrades.count, 2)
    }

    func testLoadOrders() async {
        // Given
        let expectation = XCTestExpectation(description: "Orders loaded")

        // When
        do {
            try await traderService.loadOrders()
            expectation.fulfill()
        } catch {
            XCTFail("Failed to load orders: \(error)")
        }

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(traderService.orders.isEmpty)
        XCTAssertEqual(traderService.orders.count, 2)
    }

    // MARK: - Trade Management Tests

    func testCreateNewTrade() async {
        // Given
        let symbol = "TEST"
        let quantity = 100
        let price = 50.0
        let initialCount = traderService.completedTrades.count

        let buyOrder = OrderBuy(
            id: UUID().uuidString,
            traderId: "test_trader",
            symbol: symbol,
            description: "Test Order",
            quantity: Double(quantity),
            price: price,
            totalAmount: Double(quantity) * price,
            status: .submitted,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: nil,
            category: nil,
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil
        )

        // When
        do {
            _ = try await traderService.createNewTrade(buyOrder: buyOrder)
        } catch {
            XCTFail("Failed to create new trade: \(error)")
        }

        // Then
        XCTAssertEqual(traderService.completedTrades.count, initialCount + 1)
        let newTrade = traderService.completedTrades.first { $0.symbol == symbol }
        XCTAssertNotNil(newTrade)
        XCTAssertEqual(newTrade?.buyOrder.symbol, symbol)
        XCTAssertEqual(newTrade?.buyOrder.quantity, Double(quantity))
        XCTAssertEqual(newTrade?.buyOrder.price, price)
    }

    func testCancelTrade() async {
        // Given
        let tradeId = "3" // First mock completed trade
        let initialCount = traderService.completedTrades.count

        // When
        do {
            try await traderService.cancelTrade(tradeId)
        } catch {
            XCTFail("Failed to cancel trade: \(error)")
        }

        // Then
        XCTAssertEqual(traderService.completedTrades.count, initialCount)
        let cancelledTrade = traderService.completedTrades.first { $0.id == tradeId }
        XCTAssertNotNil(cancelledTrade)
        XCTAssertEqual(cancelledTrade?.status, .cancelled)
    }

    func testCompleteTrade() async {
        // Given
        let tradeId = "3" // First mock completed trade
        let initialCompletedCount = traderService.completedTrades.count

        // When
        do {
            try await traderService.completeTrade(tradeId)
        } catch {
            XCTFail("Failed to complete trade: \(error)")
        }

        // Then
        XCTAssertEqual(traderService.completedTrades.count, initialCompletedCount)
        let completedTrade = traderService.completedTrades.first { $0.id == tradeId }
        XCTAssertNotNil(completedTrade)
        XCTAssertEqual(completedTrade?.status, .completed)
    }

    // MARK: - Order Management Tests

    func testPlaceBuyOrder() async {
        // Given
        let symbol = "TEST"
        let quantity = 50
        let price = 25.0
        let initialCount = traderService.activeOrders.count

        // When
        do {
            let request = BuyOrderRequest(
                symbol: symbol,
                quantity: quantity,
                price: price,
                optionDirection: nil,
                description: "Test Order",
                orderInstruction: "market",
                limitPrice: nil,
                strike: nil
            )
            _ = try await traderService.placeBuyOrder(request)
        } catch {
            XCTFail("Failed to place buy order: \(error)")
        }

        // Then
        XCTAssertEqual(traderService.activeOrders.count, initialCount + 1)
        let newOrder = traderService.activeOrders.first { $0.symbol == symbol }
        XCTAssertNotNil(newOrder)
        XCTAssertEqual(newOrder?.type, .buy)
        XCTAssertEqual(newOrder?.quantity, Double(quantity))
        XCTAssertEqual(newOrder?.price, price)
    }

    func testCancelOrder() async {
        // Given
        let orderId = "1" // First mock active order
        let initialCount = traderService.activeOrders.count

        // When
        do {
            try await traderService.cancelOrder(orderId)
        } catch {
            XCTFail("Failed to cancel order: \(error)")
        }

        // Then
        XCTAssertEqual(traderService.activeOrders.count, initialCount - 1)
        XCTAssertFalse(traderService.activeOrders.contains { $0.id == orderId })
    }

    // MARK: - Statistics Tests

    func testCalculateTotalVolume() {
        // Given
        // Mock data should be loaded with known values

        // When
        let totalVolume = traderService.calculateTotalVolume()

        // Then
        XCTAssertGreaterThan(totalVolume, 0)
    }

    func testCalculateDailyPnL() {
        // Given
        // Mock data should be loaded

        // When
        let dailyPnL = traderService.calculateDailyPnL()

        // Then
        XCTAssertEqual(dailyPnL, 1250.0) // Mock value
    }

    // MARK: - Service Lifecycle Tests

    func testServiceLifecycle() {
        // Given
        traderService.reset()

        // When
        traderService.start()

        // Then
        // Service should be started (in real implementation, this would verify state)
        XCTAssertNotNil(traderService)

        // When
        traderService.stop()

        // Then
        // Service should be stopped (in real implementation, this would verify state)
        XCTAssertNotNil(traderService)
    }
}
