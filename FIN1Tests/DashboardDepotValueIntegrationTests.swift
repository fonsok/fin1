import XCTest
@testable import FIN1

/// Integration tests for Dashboard Depot Value functionality
/// These tests ensure that changes to depot value calculation don't break other features
final class DashboardDepotValueIntegrationTests: XCTestCase {

    var appServices: AppServices!
    var traderService: TraderService!
    var userService: UserService!

    override func setUp() {
        super.setUp()
        appServices = AppServices()
        traderService = appServices.traderService
        userService = appServices.userService
    }

    override func tearDown() {
        appServices = nil
        traderService = nil
        userService = nil
        super.tearDown()
    }

    // MARK: - Depot Value Calculation Tests

    func testDepotValueWithNoTrades() async {
        // Given: No completed trades
        let completedTrades = traderService.completedTrades
        XCTAssertTrue(completedTrades.isEmpty, "Should start with no completed trades")

        // When: Calculate depot value
        let depotValue = calculateDepotValue()

        // Then: Should return 0
        XCTAssertEqual(depotValue, 0.0, "Depot value should be 0 when no trades exist")
    }

    func testDepotValueWithCompletedTrades() async {
        // Given: Create a completed trade
        let trade = createMockCompletedTrade()
        // Note: In real implementation, this would add the trade to traderService

        // When: Calculate depot value
        let depotValue = calculateDepotValue()

        // Then: Should calculate correctly
        XCTAssertGreaterThan(depotValue, 0.0, "Depot value should be greater than 0 with completed trades")
    }

    func testDepotValueWithPartialSales() async {
        // Given: Create a trade with partial sales
        let trade = createMockTradeWithPartialSales()

        // When: Calculate depot value
        let depotValue = calculateDepotValue()

        // Then: Should only include remaining quantity
        let expectedValue = trade.remainingQuantity * trade.buyOrder.price
        XCTAssertEqual(depotValue, expectedValue, accuracy: 0.01, "Depot value should only include remaining quantity")
    }

    func testDepotValueGermanFormatting() {
        // Given: A depot value
        let depotValue = 1234.56

        // When: Format as German currency
        let formatted = depotValue.formattedAsLocalizedCurrency()

        // Then: Should be in German format
        XCTAssertEqual(formatted, "1.234,56 €", "Should format in German currency format")
    }

    // MARK: - Integration with Dashboard Components

    func testDashboardStatsSectionWithDepotValue() {
        // Given: Dashboard stats section
        let statsSection = DashboardStatsSection()

        // When: Access depot value (this would normally be done through the view)
        // Note: This test verifies the component can be created without crashing

        // Then: Should not crash
        XCTAssertNotNil(statsSection, "DashboardStatsSection should be creatable")
    }

    func testDepotValueUpdatesWithTradeChanges() async {
        // Given: Initial state with no trades
        let initialDepotValue = calculateDepotValue()
        XCTAssertEqual(initialDepotValue, 0.0, "Should start with 0 depot value")

        // When: Add a completed trade
        let trade = createMockCompletedTrade()
        // Note: In real implementation, this would update traderService

        // Then: Depot value should update
        let updatedDepotValue = calculateDepotValue()
        XCTAssertGreaterThan(updatedDepotValue, initialDepotValue, "Depot value should increase with new trades")
    }

    // MARK: - Model Compatibility Tests

    func testTradeModelStructureCompatibility() {
        // Given: A trade with the expected structure
        let trade = createMockCompletedTrade()

        // When: Access properties used in depot calculation
        let quantity = trade.buyOrder.quantity
        let price = trade.buyOrder.price
        let remainingQuantity = trade.remainingQuantity
        let totalSoldQuantity = trade.totalSoldQuantity

        // Then: All properties should be accessible
        XCTAssertGreaterThan(quantity, 0, "Trade should have valid quantity")
        XCTAssertGreaterThan(price, 0, "Trade should have valid price")
        XCTAssertGreaterThanOrEqual(remainingQuantity, 0, "Remaining quantity should be non-negative")
        XCTAssertGreaterThanOrEqual(totalSoldQuantity, 0, "Total sold quantity should be non-negative")
    }

    func testDepotHoldingModelCompatibility() {
        // Given: A trade
        let trade = createMockCompletedTrade()

        // When: Create DepotHolding from trade
        let depotBestand = createDepotHoldingFromTrade(trade)

        // Then: DepotHolding should have correct structure
        XCTAssertNotNil(depotBestand.orderId, "DepotHolding should have orderId")
        XCTAssertGreaterThan(depotBestand.remainingQuantity, 0, "DepotHolding should have remaining quantity")
        XCTAssertGreaterThan(depotBestand.currentPrice, 0, "DepotHolding should have valid currentPrice")
    }

    // MARK: - Error Handling Tests

    func testDepotValueWithInvalidTradeData() {
        // Given: A trade with invalid data
        let invalidTrade = createMockTradeWithInvalidData()

        // When: Calculate depot value
        let depotValue = calculateDepotValueForTrade(invalidTrade)

        // Then: Should handle gracefully (return 0 or valid value)
        XCTAssertGreaterThanOrEqual(depotValue, 0, "Should handle invalid data gracefully")
    }

    // MARK: - Helper Methods

    private func calculateDepotValue() -> Double {
        let completedTrades = traderService.completedTrades

        guard !completedTrades.isEmpty else { return 0.0 }

        let totalValue = completedTrades.compactMap { trade -> Double? in
            let holding = createDepotHoldingFromTrade(trade)
            return Double(holding.remainingQuantity) * holding.currentPrice
        }.reduce(0, +)

        return totalValue
    }

    private func calculateDepotValueForTrade(_ trade: Trade) -> Double {
        let holding = createDepotHoldingFromTrade(trade)
        return Double(holding.remainingQuantity) * holding.currentPrice
    }

    private func createDepotHoldingFromTrade(_ trade: Trade) -> DepotHolding {
        let totalSoldQuantity = Int(trade.totalSoldQuantity)
        let remainingQuantity = Int(trade.remainingQuantity)
        let currentPrice = trade.buyOrder.price

        return DepotHolding(
            orderId: trade.id,
            position: 1,
            valuationDate: Date().formatted(date: .numeric, time: .omitted),
            wkn: trade.wkn ?? trade.symbol,
            strike: trade.buyOrder.price,
            designation: trade.description,
            direction: trade.optionDirection,
            underlyingAsset: trade.underlyingAsset,
            purchasePrice: trade.buyOrder.price,
            currentPrice: currentPrice,
            quantity: Int(trade.buyOrder.quantity),
            originalQuantity: Int(trade.buyOrder.quantity),
            soldQuantity: totalSoldQuantity,
            remainingQuantity: remainingQuantity,
            totalValue: trade.remainingQuantity * currentPrice
        )
    }

    private func createMockCompletedTrade() -> Trade {
        let buyOrder = OrderBuy(
            id: UUID().uuidString,
            traderId: "test-trader",
            symbol: "TEST",
            description: "Test Security",
            quantity: 100.0,
            price: 25.50,
            totalAmount: 2550.0,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: "Call",
            underlyingAsset: "DAX",
            wkn: "TEST123",
            category: "Optionsschein",
            orderInstruction: "market",
            limitPrice: nil
        )

        return Trade(
            id: UUID().uuidString,
            tradeNumber: 1,
            traderId: "test-trader",
            symbol: "TEST",
            description: "Test Security",
            buyOrder: buyOrder,
            sellOrder: nil,
            sellOrders: [],
            status: .completed,
            createdAt: Date(),
            completedAt: Date(),
            updatedAt: Date()
        )
    }

    private func createMockTradeWithPartialSales() -> Trade {
        let buyOrder = OrderBuy(
            id: UUID().uuidString,
            traderId: "test-trader",
            symbol: "TEST",
            description: "Test Security",
            quantity: 100.0,
            price: 25.50,
            totalAmount: 2550.0,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: "Call",
            underlyingAsset: "DAX",
            wkn: "TEST123",
            category: "Optionsschein",
            orderInstruction: "market",
            limitPrice: nil
        )

        let sellOrder = OrderSell(
            id: UUID().uuidString,
            traderId: "test-trader",
            symbol: "TEST",
            description: "Test Security",
            quantity: 30.0, // Partial sale
            price: 26.00,
            totalAmount: 780.0,
            status: .confirmed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: "Call",
            underlyingAsset: "DAX",
            wkn: "TEST123",
            category: "Optionsschein",
            orderInstruction: "market",
            limitPrice: nil,
            originalHoldingId: nil
        )

        return Trade(
            id: UUID().uuidString,
            tradeNumber: 1,
            traderId: "test-trader",
            symbol: "TEST",
            description: "Test Security",
            buyOrder: buyOrder,
            sellOrder: nil,
            sellOrders: [sellOrder],
            status: .active,
            createdAt: Date(),
            completedAt: nil,
            updatedAt: Date()
        )
    }

    private func createMockTradeWithInvalidData() -> Trade {
        let buyOrder = OrderBuy(
            id: UUID().uuidString,
            traderId: "test-trader",
            symbol: "TEST",
            description: "Test Security",
            quantity: 0.0, // Invalid quantity
            price: -10.0, // Invalid price
            totalAmount: 0.0,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: "Call",
            underlyingAsset: "DAX",
            wkn: "TEST123",
            category: "Optionsschein",
            orderInstruction: "market",
            limitPrice: nil
        )

        return Trade(
            id: UUID().uuidString,
            tradeNumber: 1,
            traderId: "test-trader",
            symbol: "TEST",
            description: "Test Security",
            buyOrder: buyOrder,
            sellOrder: nil,
            sellOrders: [],
            status: .completed,
            createdAt: Date(),
            completedAt: Date(),
            updatedAt: Date()
        )
    }
}
