import XCTest
@testable import FIN1

// MARK: - Partial Selling Tests
/// Tests for the partial selling functionality
final class PartialSellingTests: XCTestCase {

    // MARK: - DepotHolding Tests

    func testDepotHoldingPartialSaleCreation() {
        // Given: A completed buy order
        let buyOrder = OrderBuy(
            id: "buy-123",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 100,
            price: 150.0,
            totalAmount: 15000.0,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil
        )

        // When: Creating a DepotHolding from the buy order
        let holding = DepotHolding.from(completedOrder: buyOrder, position: 1)

        // Then: The holding should have correct initial values
        XCTAssertEqual(holding.originalQuantity, 100)
        XCTAssertEqual(holding.soldQuantity, 0)
        XCTAssertEqual(holding.remainingQuantity, 100)
        XCTAssertFalse(holding.isPartiallySold)
        XCTAssertFalse(holding.isFullySold)
        XCTAssertEqual(holding.sellProgressPercentage, 0.0)
    }

    func testDepotHoldingPartialSaleUpdate() {
        // Given: A holding with 100 original quantity
        let buyOrder = OrderBuy(
            id: "buy-123",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 100,
            price: 150.0,
            totalAmount: 15000.0,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil
        )

        let holding = DepotHolding.from(completedOrder: buyOrder, position: 1)

        // When: Applying a partial sale of 30 units
        let updatedHolding = holding.withPartialSale(soldQuantity: 30)

        // Then: The holding should reflect the partial sale
        XCTAssertEqual(updatedHolding.originalQuantity, 100)
        XCTAssertEqual(updatedHolding.soldQuantity, 30)
        XCTAssertEqual(updatedHolding.remainingQuantity, 70)
        XCTAssertTrue(updatedHolding.isPartiallySold)
        XCTAssertFalse(updatedHolding.isFullySold)
        XCTAssertEqual(updatedHolding.sellProgressPercentage, 30.0)
    }

    func testDepotHoldingMultiplePartialSales() {
        // Given: A holding with 100 original quantity
        let buyOrder = OrderBuy(
            id: "buy-123",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 100,
            price: 150.0,
            totalAmount: 15000.0,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil
        )

        let holding = DepotHolding.from(completedOrder: buyOrder, position: 1)

        // When: Applying multiple partial sales (30 + 20 + 25)
        let afterFirstSale = holding.withPartialSale(soldQuantity: 30)
        let afterSecondSale = afterFirstSale.withPartialSale(soldQuantity: 20)
        let afterThirdSale = afterSecondSale.withPartialSale(soldQuantity: 25)

        // Then: The holding should reflect all partial sales
        XCTAssertEqual(afterThirdSale.originalQuantity, 100)
        XCTAssertEqual(afterThirdSale.soldQuantity, 75)
        XCTAssertEqual(afterThirdSale.remainingQuantity, 25)
        XCTAssertTrue(afterThirdSale.isPartiallySold)
        XCTAssertFalse(afterThirdSale.isFullySold)
        XCTAssertEqual(afterThirdSale.sellProgressPercentage, 75.0)
    }

    func testDepotHoldingFullSale() {
        // Given: A holding with 100 original quantity
        let buyOrder = OrderBuy(
            id: "buy-123",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 100,
            price: 150.0,
            totalAmount: 15000.0,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil
        )

        let holding = DepotHolding.from(completedOrder: buyOrder, position: 1)

        // When: Selling all remaining quantity
        let fullySoldHolding = holding.withPartialSale(soldQuantity: 100)

        // Then: The holding should be fully sold
        XCTAssertEqual(fullySoldHolding.originalQuantity, 100)
        XCTAssertEqual(fullySoldHolding.soldQuantity, 100)
        XCTAssertEqual(fullySoldHolding.remainingQuantity, 0)
        XCTAssertFalse(fullySoldHolding.isPartiallySold)
        XCTAssertTrue(fullySoldHolding.isFullySold)
        XCTAssertEqual(fullySoldHolding.sellProgressPercentage, 100.0)
    }

    // MARK: - Trade Tests

    func testTradePartialSales() {
        // Given: A trade with a buy order
        let buyOrder = OrderBuy(
            id: "buy-123",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 100,
            price: 150.0,
            totalAmount: 15000.0,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil
        )

        let trade = Trade.from(buyOrder: buyOrder, tradeNumber: 1)

        // When: Adding partial sell orders
        let sellOrder1 = OrderSell(
            id: "sell-1",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 30,
            price: 160.0,
            totalAmount: 4800.0,
            status: .confirmed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil,
            originalHoldingId: "holding-123"
        )

        let sellOrder2 = OrderSell(
            id: "sell-2",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 20,
            price: 165.0,
            totalAmount: 3300.0,
            status: .confirmed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil,
            originalHoldingId: "holding-123"
        )

        let tradeWithFirstSale = trade.withPartialSellOrder(sellOrder1)
        let tradeWithSecondSale = tradeWithFirstSale.withPartialSellOrder(sellOrder2)

        // Then: The trade should track partial sales correctly
        XCTAssertEqual(tradeWithSecondSale.totalSoldQuantity, 50)
        XCTAssertEqual(tradeWithSecondSale.remainingQuantity, 50)
        XCTAssertTrue(tradeWithSecondSale.isPartiallySold)
        XCTAssertFalse(tradeWithSecondSale.isFullySold)
        XCTAssertEqual(tradeWithSecondSale.sellOrders.count, 2)
    }

    func testTradePnLCalculationWithPartialSales() {
        // Given: A trade with buy order and partial sell orders
        let buyOrder = OrderBuy(
            id: "buy-123",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 100,
            price: 150.0,
            totalAmount: 15000.0,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil
        )

        let trade = Trade.from(buyOrder: buyOrder, tradeNumber: 1)

        let sellOrder1 = OrderSell(
            id: "sell-1",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 50,
            price: 160.0,
            totalAmount: 8000.0,
            status: .confirmed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil,
            originalHoldingId: "holding-123"
        )

        let tradeWithSale = trade.withPartialSellOrder(sellOrder1)

        // When: Calculating PnL
        let pnl = tradeWithSale.currentPnL

        // Then: PnL should be calculated correctly
        // Buy cost: 50 * 150 = 7500
        // Sell proceeds: 50 * 160 = 8000
        // PnL: 8000 - 7500 = 500
        XCTAssertEqual(pnl, 500.0)
    }

    // MARK: - Integration Tests

    func testPartialSellingWorkflow() {
        // Given: A completed buy order creating a holding
        let buyOrder = OrderBuy(
            id: "buy-123",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 100,
            price: 150.0,
            totalAmount: 15000.0,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil
        )

        let trade = Trade.from(buyOrder: buyOrder, tradeNumber: 1)
        let holding = DepotHolding.from(completedOrder: buyOrder, position: 1)

        // When: User makes first partial sale of 30 units
        let firstSale = holding.withPartialSale(soldQuantity: 30)
        let tradeWithFirstSale = trade.withPartialSellOrder(OrderSell(
            id: "sell-1",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 30,
            price: 160.0,
            totalAmount: 4800.0,
            status: .confirmed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil,
            originalHoldingId: "holding-123"
        ))

        // Then: Both holding and trade should reflect the partial sale
        XCTAssertEqual(firstSale.remainingQuantity, 70)
        XCTAssertEqual(tradeWithFirstSale.remainingQuantity, 70)
        XCTAssertTrue(firstSale.isPartiallySold)
        XCTAssertTrue(tradeWithFirstSale.isPartiallySold)

        // When: User makes second partial sale of 20 units
        let secondSale = firstSale.withPartialSale(soldQuantity: 20)
        let tradeWithSecondSale = tradeWithFirstSale.withPartialSellOrder(OrderSell(
            id: "sell-2",
            traderId: "trader-1",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 20,
            price: 165.0,
            totalAmount: 3300.0,
            status: .confirmed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL123",
            category: "Stock",
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil,
            originalHoldingId: "holding-123"
        ))

        // Then: Both should reflect cumulative sales
        XCTAssertEqual(secondSale.remainingQuantity, 50)
        XCTAssertEqual(tradeWithSecondSale.remainingQuantity, 50)
        XCTAssertEqual(secondSale.soldQuantity, 50)
        XCTAssertEqual(tradeWithSecondSale.totalSoldQuantity, 50)
        XCTAssertEqual(secondSale.sellProgressPercentage, 50.0)
    }
}
