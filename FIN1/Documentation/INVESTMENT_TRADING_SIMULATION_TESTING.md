# Investment & Trading Simulation Testing Guide

## Overview

This guide explains how to create comprehensive tests for investment simulations and trader securities purchase/sale simulations. With proper test design, you can cover any combination of inputs and conditions automatically, eliminating the need to manually click through menus every time.

## Table of Contents

1. [Testing Strategy](#testing-strategy)
2. [Test Data Factories](#test-data-factories)
3. [Investment Simulation Tests](#investment-simulation-tests)
4. [Trading Simulation Tests](#trading-simulation-tests)
5. [Parameterized Tests](#parameterized-tests)
6. [Test Suites & Macros](#test-suites--macros)
7. [Best Practices](#best-practices)

---

## Testing Strategy

### Three-Layer Approach

1. **Unit Tests**: Test individual components (ViewModels, Services) with mocked dependencies
2. **Integration Tests**: Test complete flows (investment creation → trade execution → profit calculation)
3. **Simulation Tests**: Test multiple scenarios with different combinations of inputs

### Key Principles

- ✅ **Use closure-based mocks** (per `.cursor/rules/testing.md`)
- ✅ **Use `XCTestExpectation`** for async operations (never `Task.sleep`)
- ✅ **Create test data factories** for reusable test scenarios
- ✅ **Use parameterized tests** to cover multiple combinations
- ✅ **Keep tests focused** - one aspect per test

---

## Test Data Factories

### Investment Test Data Factory

```swift
// FIN1Tests/InvestmentTradingTestHelpers.swift

extension InvestmentTradingTestHelpers {
    /// Creates a test investment with customizable parameters
    static func createInvestment(
        id: String = UUID().uuidString,
        investorId: String = "investor-1",
        traderId: String = "trader-1",
        traderName: String = "Test Trader",
        amount: Double = 1000.0,
        currentValue: Double? = nil, // If nil, calculates based on performance
        performance: Double = 0.0,
        status: InvestmentStatus = .active,
        numberOfTrades: Int = 0,
        specialization: String = "Tech"
    ) -> Investment {
        let calculatedValue = currentValue ?? (amount * (1 + performance / 100))

        return Investment(
            id: id,
            batchId: nil,
            investorId: investorId,
            investorName: "Test Investor",
            traderId: traderId,
            traderName: traderName,
            amount: amount,
            currentValue: calculatedValue,
            date: Date(),
            status: status,
            performance: performance,
            numberOfTrades: numberOfTrades,
            sequenceNumber: 1,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: status == .completed ? Date() : nil,
            specialization: specialization,
            reservationStatus: status == .completed ? .completed : .active
        )
    }
}
```

### Trade Test Data Factory

```swift
extension InvestmentTradingTestHelpers {
    /// Creates a buy order with customizable parameters
    static func createBuyOrder(
        id: String = UUID().uuidString,
        traderId: String = "trader-1",
        symbol: String = "ABC",
        quantity: Double = 100.0,
        price: Double = 10.0,
        status: OrderBuyStatus = .completed,
        optionDirection: String? = nil,
        underlyingAsset: String? = nil
    ) -> OrderBuy {
        return OrderBuy(
            id: id,
            traderId: traderId,
            symbol: symbol,
            description: "Test Security",
            quantity: quantity,
            price: price,
            totalAmount: quantity * price,
            status: status,
            createdAt: Date(),
            executedAt: status != .submitted ? Date() : nil,
            confirmedAt: status == .completed ? Date() : nil,
            updatedAt: Date(),
            optionDirection: optionDirection,
            underlyingAsset: underlyingAsset,
            wkn: nil,
            category: nil,
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil
        )
    }

    /// Creates a sell order with customizable parameters
    static func createSellOrder(
        id: String = UUID().uuidString,
        traderId: String = "trader-1",
        symbol: String = "ABC",
        quantity: Double = 100.0,
        price: Double = 12.0,
        status: OrderSellStatus = .confirmed,
        originalHoldingId: String? = nil
    ) -> OrderSell {
        return OrderSell(
            id: id,
            traderId: traderId,
            symbol: symbol,
            description: "Test Security",
            quantity: quantity,
            price: price,
            totalAmount: quantity * price,
            status: status,
            createdAt: Date(),
            executedAt: status != .submitted ? Date() : nil,
            confirmedAt: status == .confirmed ? Date() : nil,
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: nil,
            category: nil,
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil,
            originalHoldingId: originalHoldingId
        )
    }

    /// Creates a complete trade (buy + sell) with customizable parameters
    static func createTrade(
        id: String = UUID().uuidString,
        tradeNumber: Int = 1,
        traderId: String = "trader-1",
        symbol: String = "ABC",
        buyQuantity: Double = 100.0,
        buyPrice: Double = 10.0,
        sellQuantity: Double? = nil, // If nil, uses buyQuantity
        sellPrice: Double = 12.0,
        status: TradeStatus = .completed
    ) -> Trade {
        let actualSellQuantity = sellQuantity ?? buyQuantity

        let buyOrder = createBuyOrder(
            traderId: traderId,
            symbol: symbol,
            quantity: buyQuantity,
            price: buyPrice,
            status: .completed
        )

        let sellOrder = createSellOrder(
            traderId: traderId,
            symbol: symbol,
            quantity: actualSellQuantity,
            price: sellPrice,
            status: .confirmed
        )

        return Trade(
            id: id,
            tradeNumber: tradeNumber,
            traderId: traderId,
            symbol: symbol,
            description: "Test Trade",
            buyOrder: buyOrder,
            sellOrder: sellOrder,
            sellOrders: [sellOrder],
            status: status,
            createdAt: Date(),
            completedAt: status == .completed ? Date() : nil,
            updatedAt: Date(),
            calculatedProfit: status == .completed ? (actualSellQuantity * sellPrice) - (buyQuantity * buyPrice) : nil
        )
    }
}
```

---

## Investment Simulation Tests

### Example: Testing Investment Creation with Different Amounts

```swift
// FIN1Tests/InvestmentSimulationTests.swift

final class InvestmentSimulationTests: XCTestCase {
    var mockInvestmentService: MockInvestmentService!
    var mockUserService: MockUserService!
    var viewModel: InvestmentSheetViewModel!

    override func setUp() {
        super.setUp()
        mockInvestmentService = MockInvestmentService()
        mockUserService = MockUserService()
        // ... setup viewModel
    }

    override func tearDown() {
        mockInvestmentService.reset()
        mockInvestmentService = nil
        mockUserService = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Investment Amount Variations

    func testCreateInvestment_WithMinimumAmount_CreatesSuccessfully() async {
        // Given
        let expectation = XCTestExpectation(description: "Investment created")
        let minimumAmount = 100.0

        mockInvestmentService.createInvestmentHandler = { _, _, amountPerPot, _, _, _ in
            expectation.fulfill()
            // Verify minimum amount
            XCTAssertGreaterThanOrEqual(amountPerPot, minimumAmount)
        }

        // When
        viewModel.investmentAmount = String(Int(minimumAmount))
        await viewModel.createInvestment()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testCreateInvestment_WithMaximumAmount_CreatesSuccessfully() async {
        // Given
        let expectation = XCTestExpectation(description: "Investment created")
        let maximumAmount = 100000.0

        mockInvestmentService.createInvestmentHandler = { _, _, amountPerPot, _, _, _ in
            expectation.fulfill()
            XCTAssertLessThanOrEqual(amountPerPot, maximumAmount)
        }

        // When
        viewModel.investmentAmount = String(Int(maximumAmount))
        await viewModel.createInvestment()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Multiple Investments Variations

    func testCreateInvestment_WithSingleInvestment_CreatesOne() async {
        // Given
        let expectation = XCTestExpectation(description: "Single investment created")

        mockInvestmentService.createInvestmentHandler = { _, _, amountPerPot, numberOfPots, _, _ in
            expectation.fulfill()
            XCTAssertEqual(numberOfPots, 1)
        }

        // When
        viewModel.selectedInvestmentSelection = .singleInvestment
        viewModel.numberOfInvestments = 1
        await viewModel.createInvestment()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testCreateInvestment_WithMultipleInvestments_CreatesAll() async {
        // Given
        let expectation = XCTestExpectation(description: "Multiple investments created")
        let numberOfInvestments = 5

        mockInvestmentService.createInvestmentHandler = { _, _, amountPerPot, numberOfPots, _, _ in
            expectation.fulfill()
            XCTAssertEqual(numberOfPots, numberOfInvestments)
        }

        // When
        viewModel.selectedInvestmentSelection = .multipleInvestments
        viewModel.numberOfInvestments = numberOfInvestments
        await viewModel.createInvestment()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
```

---

## Trading Simulation Tests

### Example: Testing Trade Execution with Different Prices and Quantities

```swift
// FIN1Tests/TradingSimulationTests.swift

final class TradingSimulationTests: XCTestCase {
    var mockTraderService: MockTraderService!
    var buyOrderViewModel: BuyOrderViewModel!

    override func setUp() {
        super.setUp()
        mockTraderService = MockTraderService()
        // ... setup viewModel
    }

    override func tearDown() {
        mockTraderService.reset()
        mockTraderService = nil
        buyOrderViewModel = nil
        super.tearDown()
    }

    // MARK: - Buy Order Price Variations

    func testPlaceBuyOrder_WithLowPrice_ExecutesSuccessfully() async {
        // Given
        let expectation = XCTestExpectation(description: "Buy order placed")
        let lowPrice = 0.50

        mockTraderService.placeBuyOrderHandler = { request in
            expectation.fulfill()
            XCTAssertEqual(request.price, lowPrice, accuracy: 0.01)
            return InvestmentTradingTestHelpers.createBuyOrder(
                price: lowPrice,
                status: .submitted
            )
        }

        // When
        buyOrderViewModel.price = String(lowPrice)
        await buyOrderViewModel.placeOrder()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testPlaceBuyOrder_WithHighPrice_ExecutesSuccessfully() async {
        // Given
        let expectation = XCTestExpectation(description: "Buy order placed")
        let highPrice = 1000.0

        mockTraderService.placeBuyOrderHandler = { request in
            expectation.fulfill()
            XCTAssertEqual(request.price, highPrice, accuracy: 0.01)
            return InvestmentTradingTestHelpers.createBuyOrder(
                price: highPrice,
                status: .submitted
            )
        }

        // When
        buyOrderViewModel.price = String(highPrice)
        await buyOrderViewModel.placeOrder()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Quantity Variations

    func testPlaceBuyOrder_WithMinimumQuantity_ExecutesSuccessfully() async {
        // Given
        let expectation = XCTestExpectation(description: "Buy order placed")
        let minQuantity = 1

        mockTraderService.placeBuyOrderHandler = { request in
            expectation.fulfill()
            XCTAssertGreaterThanOrEqual(request.quantity, minQuantity)
            return InvestmentTradingTestHelpers.createBuyOrder(
                quantity: Double(minQuantity),
                status: .submitted
            )
        }

        // When
        buyOrderViewModel.quantity = String(minQuantity)
        await buyOrderViewModel.placeOrder()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testPlaceBuyOrder_WithLargeQuantity_ExecutesSuccessfully() async {
        // Given
        let expectation = XCTestExpectation(description: "Buy order placed")
        let largeQuantity = 10000

        mockTraderService.placeBuyOrderHandler = { request in
            expectation.fulfill()
            XCTAssertEqual(request.quantity, largeQuantity)
            return InvestmentTradingTestHelpers.createBuyOrder(
                quantity: Double(largeQuantity),
                status: .submitted
            )
        }

        // When
        buyOrderViewModel.quantity = String(largeQuantity)
        await buyOrderViewModel.placeOrder()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Complete Trade Cycle

    func testCompleteTradeCycle_BuyThenSell_CalculatesProfit() async {
        // Given
        let buyExpectation = XCTestExpectation(description: "Buy order placed")
        let sellExpectation = XCTestExpectation(description: "Sell order placed")

        let buyPrice = 10.0
        let sellPrice = 12.0
        let quantity = 100.0
        let expectedProfit = (sellPrice - buyPrice) * quantity

        var buyOrder: OrderBuy?

        mockTraderService.placeBuyOrderHandler = { request in
            buyExpectation.fulfill()
            buyOrder = InvestmentTradingTestHelpers.createBuyOrder(
                price: buyPrice,
                quantity: quantity,
                status: .completed
            )
            return buyOrder!
        }

        mockTraderService.placeSellOrderHandler = { _, sellQty, sellPrice in
            sellExpectation.fulfill()
            XCTAssertEqual(sellQty, Int(quantity))
            XCTAssertEqual(sellPrice, sellPrice, accuracy: 0.01)
            return InvestmentTradingTestHelpers.createSellOrder(
                price: sellPrice,
                quantity: quantity,
                status: .confirmed
            )
        }

        // When - Place buy order
        buyOrderViewModel.price = String(buyPrice)
        buyOrderViewModel.quantity = String(Int(quantity))
        await buyOrderViewModel.placeOrder()
        await fulfillment(of: [buyExpectation], timeout: 1.0)

        // When - Place sell order (simulated)
        guard let completedBuyOrder = buyOrder else {
            XCTFail("Buy order not created")
            return
        }

        let trade = try? await mockTraderService.createNewTrade(buyOrder: completedBuyOrder)
        XCTAssertNotNil(trade)

        // Then - Verify profit calculation
        if let trade = trade {
            let actualProfit = (sellPrice - buyPrice) * quantity
            XCTAssertEqual(actualProfit, expectedProfit, accuracy: 0.01)
        }
    }
}
```

---

## Parameterized Tests

### Using XCTest Parameterized Tests (Swift 5.9+)

```swift
// MARK: - Parameterized Investment Tests

func testCreateInvestment_WithVariousAmounts_CreatesSuccessfully(
    amount: Double,
    expectedStatus: InvestmentStatus
) async {
    // Given
    let expectation = XCTestExpectation(description: "Investment created with amount \(amount)")

    mockInvestmentService.createInvestmentHandler = { _, _, amountPerPot, _, _, _ in
        expectation.fulfill()
        XCTAssertEqual(amountPerPot, amount, accuracy: 0.01)
    }

    // When
    viewModel.investmentAmount = String(Int(amount))
    await viewModel.createInvestment()

    // Then
    await fulfillment(of: [expectation], timeout: 1.0)
}

// Test invocation with multiple parameters
func testCreateInvestment_WithVariousAmounts_CreatesSuccessfully() async {
    let testCases: [(amount: Double, status: InvestmentStatus)] = [
        (100.0, .active),
        (1000.0, .active),
        (5000.0, .active),
        (10000.0, .active),
        (50000.0, .active)
    ]

    for testCase in testCases {
        await testCreateInvestment_WithVariousAmounts_CreatesSuccessfully(
            amount: testCase.amount,
            expectedStatus: testCase.status
        )
    }
}
```

### Using Test Data Arrays

```swift
// MARK: - Test Data Arrays

struct TradeTestScenario {
    let name: String
    let buyPrice: Double
    let sellPrice: Double
    let quantity: Double
    let expectedProfit: Double
    let expectedReturnPercent: Double
}

extension TradingSimulationTests {
    static let tradeScenarios: [TradeTestScenario] = [
        TradeTestScenario(
            name: "Small profit",
            buyPrice: 10.0,
            sellPrice: 11.0,
            quantity: 100.0,
            expectedProfit: 100.0,
            expectedReturnPercent: 10.0
        ),
        TradeTestScenario(
            name: "Large profit",
            buyPrice: 10.0,
            sellPrice: 15.0,
            quantity: 100.0,
            expectedProfit: 500.0,
            expectedReturnPercent: 50.0
        ),
        TradeTestScenario(
            name: "Loss",
            buyPrice: 10.0,
            sellPrice: 8.0,
            quantity: 100.0,
            expectedProfit: -200.0,
            expectedReturnPercent: -20.0
        ),
        TradeTestScenario(
            name: "High quantity",
            buyPrice: 5.0,
            sellPrice: 6.0,
            quantity: 10000.0,
            expectedProfit: 10000.0,
            expectedReturnPercent: 20.0
        )
    ]

    func testTradeScenarios_CalculateProfitCorrectly() async {
        for scenario in Self.tradeScenarios {
            // Given
            let trade = InvestmentTradingTestHelpers.createTrade(
                buyPrice: scenario.buyPrice,
                sellPrice: scenario.sellPrice,
                buyQuantity: scenario.quantity,
                sellQuantity: scenario.quantity
            )

            // When
            let actualProfit = (scenario.sellPrice - scenario.buyPrice) * scenario.quantity
            let actualReturnPercent = ((scenario.sellPrice - scenario.buyPrice) / scenario.buyPrice) * 100

            // Then
            XCTAssertEqual(
                actualProfit,
                scenario.expectedProfit,
                accuracy: 0.01,
                "Failed for scenario: \(scenario.name)"
            )
            XCTAssertEqual(
                actualReturnPercent,
                scenario.expectedReturnPercent,
                accuracy: 0.01,
                "Failed for scenario: \(scenario.name)"
            )
        }
    }
}
```

---

## Test Suites & Macros

### Creating Test Suites

```swift
// FIN1Tests/InvestmentTradingTestSuite.swift

/// Comprehensive test suite covering all investment and trading scenarios
final class InvestmentTradingTestSuite: XCTestCase {

    // MARK: - Investment Test Suite

    func testInvestmentSuite() async {
        // Run all investment-related tests
        await testInvestmentCreation()
        await testInvestmentStatusTransitions()
        await testInvestmentProfitCalculation()
    }

    private func testInvestmentCreation() async {
        // Test various investment creation scenarios
        let amounts: [Double] = [100, 500, 1000, 5000, 10000]
        let numberOfInvestments: [Int] = [1, 3, 5, 10]

        for amount in amounts {
            for count in numberOfInvestments {
                // Test each combination
                await testCreateInvestment(amount: amount, count: count)
            }
        }
    }

    private func testCreateInvestment(amount: Double, count: Int) async {
        // Implementation
    }

    // MARK: - Trading Test Suite

    func testTradingSuite() async {
        // Run all trading-related tests
        await testBuyOrderVariations()
        await testSellOrderVariations()
        await testCompleteTradeCycles()
    }

    private func testBuyOrderVariations() async {
        let prices: [Double] = [0.50, 1.0, 5.0, 10.0, 50.0, 100.0]
        let quantities: [Int] = [1, 10, 100, 1000, 10000]

        for price in prices {
            for quantity in quantities {
                await testPlaceBuyOrder(price: price, quantity: quantity)
            }
        }
    }

    private func testPlaceBuyOrder(price: Double, quantity: Int) async {
        // Implementation
    }
}
```

### Using XCTest Macros (Swift 5.9+)

```swift
// MARK: - Using XCTest Macros for Parameterized Tests

@available(iOS 16.0, *)
final class ParameterizedTradingTests: XCTestCase {

    // Define test cases as a static property
    static let buyOrderTestCases: [(price: Double, quantity: Int)] = [
        (0.50, 1),
        (1.0, 10),
        (5.0, 100),
        (10.0, 1000),
        (50.0, 10000),
        (100.0, 1)
    ]

    // Use XCTest macro for parameterized tests
    func testPlaceBuyOrder_WithVariousParameters(
        price: Double,
        quantity: Int
    ) async throws {
        // Test implementation
        let expectation = XCTestExpectation(description: "Buy order placed")

        // ... test logic

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // Invoke with all test cases
    func testPlaceBuyOrder_WithVariousParameters_AllCases() async {
        for testCase in Self.buyOrderTestCases {
            try? await testPlaceBuyOrder_WithVariousParameters(
                price: testCase.price,
                quantity: testCase.quantity
            )
        }
    }
}
```

---

## Best Practices

### 1. Test Data Organization

```swift
// Organize test data in a dedicated file
// FIN1Tests/InvestmentTradingTestData.swift

struct InvestmentTestData {
    static let standardAmounts: [Double] = [100, 500, 1000, 5000, 10000]
    static let standardCounts: [Int] = [1, 3, 5, 10]
    static let standardPerformances: [Double] = [-50, -25, 0, 25, 50, 100]
}

struct TradingTestData {
    static let standardPrices: [Double] = [0.50, 1.0, 5.0, 10.0, 50.0, 100.0]
    static let standardQuantities: [Int] = [1, 10, 100, 1000, 10000]
    static let profitMargins: [Double] = [-50, -25, 0, 10, 25, 50, 100]
}
```

### 2. Test Helper Methods

```swift
extension InvestmentTradingTestHelpers {
    /// Executes a complete investment → trade → profit flow
    static func executeInvestmentTradeFlow(
        investmentAmount: Double,
        buyPrice: Double,
        sellPrice: Double,
        quantity: Double,
        mockInvestmentService: MockInvestmentService,
        mockTraderService: MockTraderService
    ) async throws -> (investment: Investment, trade: Trade, profit: Double) {
        // 1. Create investment
        let investment = createInvestment(amount: investmentAmount)

        // 2. Create buy order
        let buyOrder = createBuyOrder(price: buyPrice, quantity: quantity)

        // 3. Create sell order
        let sellOrder = createSellOrder(price: sellPrice, quantity: quantity)

        // 4. Create trade
        let trade = createTrade(
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            buyQuantity: quantity,
            sellQuantity: quantity
        )

        // 5. Calculate profit
        let profit = (sellPrice - buyPrice) * quantity

        return (investment, trade, profit)
    }
}
```

### 3. Test Coverage Matrix

Create a matrix to ensure all combinations are tested:

```swift
struct TestCoverageMatrix {
    struct InvestmentMatrix {
        let amounts: [Double]
        let counts: [Int]
        let statuses: [InvestmentStatus]
    }

    struct TradingMatrix {
        let buyPrices: [Double]
        let sellPrices: [Double]
        let quantities: [Int]
    }

    static func generateAllCombinations() -> [(InvestmentMatrix, TradingMatrix)] {
        // Generate all test combinations
        // This ensures comprehensive coverage
    }
}
```

### 4. Performance Testing

```swift
func testInvestmentCreation_Performance_WithLargeDataSet() async {
    measure {
        // Create 1000 investments
        for i in 0..<1000 {
            let investment = InvestmentTradingTestHelpers.createInvestment(
                id: "inv-\(i)",
                amount: Double.random(in: 100...10000)
            )
            // Process investment
        }
    }
}
```

---

## Running Tests

### Command Line

```bash
# Run all investment/trading tests
xcodebuild test -scheme FIN1 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FIN1Tests/InvestmentTradingSimulationTests

# Run specific test suite
xcodebuild test -scheme FIN1 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FIN1Tests/InvestmentTradingSimulationTests/testInvestmentSuite

# Run with test plan
xcodebuild test -scheme FIN1 -testPlan FIN1 -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Xcode

1. Open `FIN1.xcodeproj`
2. Select test target `FIN1Tests`
3. Use Test Navigator (⌘6) to run individual tests or suites
4. Use Product → Test (⌘U) to run all tests

---

## Summary

By following this guide, you can:

1. ✅ **Create comprehensive test coverage** for all investment and trading scenarios
2. ✅ **Automate testing** of different combinations without manual UI interaction
3. ✅ **Use parameterized tests** to cover multiple scenarios efficiently
4. ✅ **Organize tests** into logical suites for better maintainability
5. ✅ **Ensure consistency** by following established patterns

The key is to:
- Use **test data factories** for creating test objects
- Use **parameterized tests** to cover multiple scenarios
- Use **test suites** to organize related tests
- Follow **MVVM and testing best practices** from `.cursor/rules/testing.md`

















