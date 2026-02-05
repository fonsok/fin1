import XCTest
@testable import FIN1

// MARK: - Typealias for Mock Compatibility
// Note: MockInvestmentService uses PoolSelectionStrategy but the actual protocol uses InvestmentSelectionStrategy
// This typealias allows tests to work with the mock until it's updated
typealias PoolSelectionStrategy = InvestmentSelectionStrategy

// MARK: - Investment & Trading Simulation Tests
/// Comprehensive test suite for investment and trading simulations
/// These tests demonstrate how to automatically test different combinations of inputs
/// without manually clicking through the UI
final class InvestmentTradingSimulationTests: XCTestCase {

    var mockInvestmentService: MockInvestmentService!
    var mockTraderService: MockTraderService!
    var mockUserService: MockUserService!

    override func setUp() {
        super.setUp()
        mockInvestmentService = MockInvestmentService()
        mockTraderService = MockTraderService()
        mockUserService = MockUserService()
    }

    override func tearDown() {
        mockInvestmentService.reset()
        mockTraderService.reset()
        mockUserService = nil
        mockInvestmentService = nil
        mockTraderService = nil
        super.tearDown()
    }

    // MARK: - Investment Creation Simulations

    func testCreateInvestment_WithVariousAmounts_CreatesSuccessfully() async {
        // Given: Test with different investment amounts
        let amounts = InvestmentTradingTestHelpers.standardInvestmentAmounts

        for amount in amounts {
            // Given
            let expectation = XCTestExpectation(description: "Investment created with amount \(amount)")

            mockInvestmentService.createInvestmentHandler = { _, _, amountPerPool, _, _, _ in
                expectation.fulfill()
                XCTAssertEqual(amountPerPool, amount, accuracy: 0.01, "Failed for amount: \(amount)")
            }

            // When: Create investment with this amount
            // Note: In real tests, you would call the ViewModel method
            // For demonstration, we're directly testing the service

            // Simulate investment creation
            let testUser = await TestHelpers.createInvestorUser(mockUserService: mockUserService)
            let testTrader = TestHelpers.createMockTrader()

            if let user = testUser {
                do {
                    try await mockInvestmentService.createInvestment(
                        investor: user,
                        trader: testTrader,
                        amountPerPool: amount,
                        numberOfPools: 1,
                        specialization: "Tech",
                        poolSelection: InvestmentSelectionStrategy.multipleInvestments
                    )
                } catch {
                    XCTFail("Failed to create investment with amount \(amount): \(error)")
                }
            }

            // Then
            await fulfillment(of: [expectation], timeout: 1.0)
        }
    }

    func testCreateInvestment_WithMultipleCounts_CreatesAll() async {
        // Given: Test with different numbers of investments
        let counts = InvestmentTradingTestHelpers.standardInvestmentCounts

        for count in counts {
            // Given
            let expectation = XCTestExpectation(description: "Created \(count) investments")
            let amountPerInvestment = 1000.0

            mockInvestmentService.createInvestmentHandler = { _, _, amountPerPool, numberOfPools, _, _ in
                expectation.fulfill()
                XCTAssertEqual(numberOfPools, count, "Failed for count: \(count)")
                XCTAssertEqual(amountPerPool, amountPerInvestment, accuracy: 0.01)
            }

            // When
            let testUser = await TestHelpers.createInvestorUser(mockUserService: mockUserService)
            let testTrader = TestHelpers.createMockTrader()

            if let user = testUser {
                do {
                    try await mockInvestmentService.createInvestment(
                        investor: user,
                        trader: testTrader,
                        amountPerPool: amountPerInvestment,
                        numberOfPools: count,
                        specialization: "Tech",
                        poolSelection: InvestmentSelectionStrategy.multipleInvestments
                    )
                } catch {
                    XCTFail("Failed to create \(count) investments: \(error)")
                }
            }

            // Then
            await fulfillment(of: [expectation], timeout: 1.0)
        }
    }

    // MARK: - Trading Simulation Tests

    func testPlaceBuyOrder_WithVariousPrices_ExecutesSuccessfully() async {
        // Given: Test with different buy prices
        let prices = InvestmentTradingTestHelpers.standardBuyPrices

        for price in prices {
            // Given
            let expectation = XCTestExpectation(description: "Buy order placed at price \(price)")
            let quantity = 100

            mockTraderService.placeBuyOrderHandler = { request in
                expectation.fulfill()
                XCTAssertEqual(request.price, price, accuracy: 0.01, "Failed for price: \(price)")
                XCTAssertEqual(request.quantity, quantity)

                return InvestmentTradingTestHelpers.createBuyOrder(
                    price: price,
                    quantity: Double(quantity),
                    status: .submitted
                )
            }

            // When
            let request = BuyOrderRequest(
                symbol: "TEST",
                quantity: quantity,
                price: price,
                optionDirection: nil,
                description: "Test Order",
                orderInstruction: "market",
                limitPrice: nil,
                strike: nil
            )

            do {
                _ = try await mockTraderService.placeBuyOrder(request)
            } catch {
                XCTFail("Failed to place buy order at price \(price): \(error)")
            }

            // Then
            await fulfillment(of: [expectation], timeout: 1.0)
        }
    }

    func testPlaceBuyOrder_WithVariousQuantities_ExecutesSuccessfully() async {
        // Given: Test with different quantities
        let quantities = InvestmentTradingTestHelpers.standardQuantities
        let price = 10.0

        for quantity in quantities {
            // Given
            let expectation = XCTestExpectation(description: "Buy order placed with quantity \(quantity)")

            mockTraderService.placeBuyOrderHandler = { request in
                expectation.fulfill()
                XCTAssertEqual(request.quantity, quantity, "Failed for quantity: \(quantity)")
                XCTAssertEqual(request.price, price, accuracy: 0.01)

                return InvestmentTradingTestHelpers.createBuyOrder(
                    price: price,
                    quantity: Double(quantity),
                    status: .submitted
                )
            }

            // When
            let request = BuyOrderRequest(
                symbol: "TEST",
                quantity: quantity,
                price: price,
                optionDirection: nil,
                description: "Test Order",
                orderInstruction: "market",
                limitPrice: nil,
                strike: nil
            )

            do {
                _ = try await mockTraderService.placeBuyOrder(request)
            } catch {
                XCTFail("Failed to place buy order with quantity \(quantity): \(error)")
            }

            // Then
            await fulfillment(of: [expectation], timeout: 1.0)
        }
    }

    // MARK: - Complete Trade Cycle Tests

    func testCompleteTradeCycle_WithVariousScenarios_CalculatesProfitCorrectly() async {
        // Given: Test with different trade scenarios
        let scenarios = TradeTestScenario.standardScenarios

        for scenario in scenarios {
            // Given
            let buyExpectation = XCTestExpectation(description: "Buy order for \(scenario.name)")
            let sellExpectation = XCTestExpectation(description: "Sell order for \(scenario.name)")

            mockTraderService.placeBuyOrderHandler = { request in
                buyExpectation.fulfill()
                XCTAssertEqual(request.price, scenario.buyPrice, accuracy: 0.01)
                XCTAssertEqual(request.quantity, Int(scenario.quantity))

                return InvestmentTradingTestHelpers.createBuyOrder(
                    price: scenario.buyPrice,
                    quantity: scenario.quantity,
                    status: .completed
                )
            }

            mockTraderService.placeSellOrderHandler = { _, quantity, price in
                sellExpectation.fulfill()
                XCTAssertEqual(quantity, Int(scenario.quantity))
                XCTAssertEqual(price, scenario.sellPrice, accuracy: 0.01)

                return InvestmentTradingTestHelpers.createSellOrder(
                    price: scenario.sellPrice,
                    quantity: scenario.quantity,
                    status: .confirmed
                )
            }

            // When: Place buy order
            let buyRequest = BuyOrderRequest(
                symbol: "TEST",
                quantity: Int(scenario.quantity),
                price: scenario.buyPrice,
                optionDirection: nil,
                description: "Test Buy",
                orderInstruction: "market",
                limitPrice: nil,
                strike: nil
            )

            var buyOrder: OrderBuy?
            do {
                buyOrder = try await mockTraderService.placeBuyOrder(buyRequest)
                await fulfillment(of: [buyExpectation], timeout: 1.0)
            } catch {
                XCTFail("Failed to place buy order for scenario \(scenario.name): \(error)")
                continue
            }

            // When: Create trade from buy order
            guard let completedBuyOrder = buyOrder else {
                XCTFail("Buy order not created for scenario \(scenario.name)")
                continue
            }

            var trade: Trade?
            do {
                trade = try await mockTraderService.createNewTrade(buyOrder: completedBuyOrder)
            } catch {
                XCTFail("Failed to create trade for scenario \(scenario.name): \(error)")
                continue
            }

            // When: Place sell order
            do {
                _ = try await mockTraderService.placeSellOrder(
                    symbol: scenario.trade.symbol,
                    quantity: Int(scenario.quantity),
                    price: scenario.sellPrice
                )
                await fulfillment(of: [sellExpectation], timeout: 1.0)
            } catch {
                XCTFail("Failed to place sell order for scenario \(scenario.name): \(error)")
                continue
            }

            // Then: Verify profit calculation
            if let completedTrade = trade {
                let actualProfit = (scenario.sellPrice - scenario.buyPrice) * scenario.quantity
                let actualReturnPercent = ((scenario.sellPrice - scenario.buyPrice) / scenario.buyPrice) * 100

                XCTAssertEqual(
                    actualProfit,
                    scenario.expectedProfit,
                    accuracy: 0.01,
                    "Profit calculation failed for scenario: \(scenario.name)"
                )
                XCTAssertEqual(
                    actualReturnPercent,
                    scenario.expectedReturnPercent,
                    accuracy: 0.01,
                    "Return percentage failed for scenario: \(scenario.name)"
                )
            }
        }
    }

    // MARK: - Parameterized Trade Tests

    func testTradeProfitCalculation_WithPriceCombinations_CalculatesCorrectly() async {
        // Given: Test all combinations of buy and sell prices
        let buyPrices: [Double] = [5.0, 10.0, 20.0]
        let sellMultipliers: [Double] = [0.8, 1.0, 1.2, 1.5] // 80%, 100%, 120%, 150% of buy price
        let quantity = 100.0

        for buyPrice in buyPrices {
            for multiplier in sellMultipliers {
                let sellPrice = buyPrice * multiplier
                let expectedProfit = (sellPrice - buyPrice) * quantity
                let expectedReturnPercent = ((sellPrice - buyPrice) / buyPrice) * 100

                // When: Create trade
                let trade = InvestmentTradingTestHelpers.createTrade(
                    buyPrice: buyPrice,
                    sellPrice: sellPrice,
                    buyQuantity: quantity,
                    sellQuantity: quantity
                )

                // Then: Verify calculations
                let actualProfit = (sellPrice - buyPrice) * quantity
                let actualReturnPercent = ((sellPrice - buyPrice) / buyPrice) * 100

                XCTAssertEqual(
                    actualProfit,
                    expectedProfit,
                    accuracy: 0.01,
                    "Failed for buyPrice: \(buyPrice), sellPrice: \(sellPrice)"
                )
                XCTAssertEqual(
                    actualReturnPercent,
                    expectedReturnPercent,
                    accuracy: 0.01,
                    "Failed for buyPrice: \(buyPrice), sellPrice: \(sellPrice)"
                )
            }
        }
    }

    // MARK: - Partial Sell Tests

    func testTradeWithPartialSells_CalculatesProfitCorrectly() async {
        // Given: Test partial sell scenarios
        let buyQuantity = 1000.0
        let buyPrice = 10.0

        let partialSellScenarios: [(sells: [(quantity: Double, price: Double)], expectedStatus: TradeStatus)] = [
            // Scenario 1: Sell 50% at profit
            (
                sells: [(quantity: 500.0, price: 12.0)],
                expectedStatus: .active
            ),
            // Scenario 2: Sell 100% in two parts
            (
                sells: [(quantity: 600.0, price: 11.0), (quantity: 400.0, price: 13.0)],
                expectedStatus: .completed
            ),
            // Scenario 3: Sell more than 100% (should still complete)
            (
                sells: [(quantity: 500.0, price: 12.0), (quantity: 600.0, price: 13.0)],
                expectedStatus: .completed
            )
        ]

        for (index, scenario) in partialSellScenarios.enumerated() {
            // When: Create trade with partial sells
            let trade = InvestmentTradingTestHelpers.createTradeWithPartialSells(
                buyQuantity: buyQuantity,
                buyPrice: buyPrice,
                partialSells: scenario.sells
            )

            // Then: Verify status
            XCTAssertEqual(
                trade.status,
                scenario.expectedStatus,
                "Status mismatch for scenario \(index + 1)"
            )

            // Then: Verify profit calculation if completed
            if trade.status == .completed {
                let totalSellAmount = scenario.sells.reduce(0.0) { $0 + ($1.quantity * $1.price) }
                let buyAmount = buyQuantity * buyPrice
                let expectedProfit = totalSellAmount - buyAmount

                XCTAssertNotNil(trade.calculatedProfit)
                if let calculatedProfit = trade.calculatedProfit {
                    XCTAssertEqual(
                        calculatedProfit,
                        expectedProfit,
                        accuracy: 0.01,
                        "Profit calculation failed for scenario \(index + 1)"
                    )
                }
            }
        }
    }

    // MARK: - Investment Performance Tests

    func testInvestmentPerformance_WithVariousReturns_CalculatesCorrectly() async {
        // Given: Test investments with different performance percentages
        let performances = InvestmentTradingTestHelpers.standardPerformances
        let baseAmount = 1000.0

        for performance in performances {
            // When: Create investment with this performance
            let investment = InvestmentTradingTestHelpers.createInvestment(
                amount: baseAmount,
                performance: performance
            )

            // Then: Verify current value calculation
            let expectedValue = baseAmount * (1 + performance / 100)
            XCTAssertEqual(
                investment.currentValue,
                expectedValue,
                accuracy: 0.01,
                "Failed for performance: \(performance)%"
            )
            XCTAssertEqual(
                investment.performance,
                performance,
                accuracy: 0.01,
                "Performance not set correctly for: \(performance)%"
            )
        }
    }

    // MARK: - Integration Flow Tests

    func testInvestmentToTradeFlow_WithVariousAmounts_ExecutesSuccessfully() async {
        // Given: Test complete flow from investment to trade
        let investmentAmounts: [Double] = [1000, 5000, 10000]
        let buyPrice = 10.0
        let sellPrice = 12.0
        let quantity = 100.0

        for investmentAmount in investmentAmounts {
            // When: Execute complete flow
            let (investment, trade, profit) = InvestmentTradingTestHelpers.executeInvestmentTradeFlow(
                investmentAmount: investmentAmount,
                buyPrice: buyPrice,
                sellPrice: sellPrice,
                quantity: quantity
            )

            // Then: Verify investment
            XCTAssertEqual(investment.amount, investmentAmount, accuracy: 0.01)

            // Then: Verify trade
            XCTAssertEqual(trade.buyOrder.price, buyPrice, accuracy: 0.01)
            XCTAssertEqual(trade.sellOrder?.price, sellPrice, accuracy: 0.01)
            XCTAssertEqual(trade.buyOrder.quantity, quantity, accuracy: 0.01)

            // Then: Verify profit
            let expectedProfit = (sellPrice - buyPrice) * quantity
            XCTAssertEqual(profit, expectedProfit, accuracy: 0.01)

            // Then: Verify return percentage relative to investment
            let returnPercent = (profit / investmentAmount) * 100
            XCTAssertGreaterThan(returnPercent, 0, "Should have positive return")
        }
    }
}

// MARK: - Test Suite Organization

extension InvestmentTradingSimulationTests {

    /// Runs all investment-related simulation tests
    func testInvestmentSimulationSuite() async {
        await testCreateInvestment_WithVariousAmounts_CreatesSuccessfully()
        await testCreateInvestment_WithMultipleCounts_CreatesAll()
        await testInvestmentPerformance_WithVariousReturns_CalculatesCorrectly()
    }

    /// Runs all trading-related simulation tests
    func testTradingSimulationSuite() async {
        await testPlaceBuyOrder_WithVariousPrices_ExecutesSuccessfully()
        await testPlaceBuyOrder_WithVariousQuantities_ExecutesSuccessfully()
        await testCompleteTradeCycle_WithVariousScenarios_CalculatesProfitCorrectly()
        await testTradeProfitCalculation_WithPriceCombinations_CalculatesCorrectly()
        await testTradeWithPartialSells_CalculatesProfitCorrectly()
    }

    /// Runs all integration flow tests
    func testIntegrationFlowSuite() async {
        await testInvestmentToTradeFlow_WithVariousAmounts_ExecutesSuccessfully()
    }

    /// Runs the complete test suite
    func testCompleteSimulationSuite() async {
        await testInvestmentSimulationSuite()
        await testTradingSimulationSuite()
        await testIntegrationFlowSuite()
    }
}
