import Foundation
import XCTest
@testable import FIN1

// MARK: - Investment & Trading Test Helpers
/// Comprehensive test helpers for creating investment and trading test data
/// Use these helpers to create test scenarios without manual setup
class InvestmentTradingTestHelpers {

    // MARK: - Investment Creation

    /// Creates a test investment with customizable parameters
    /// - Parameters:
    ///   - id: Investment ID (default: UUID)
    ///   - investorId: Investor user ID
    ///   - traderId: Trader user ID
    ///   - traderName: Trader display name
    ///   - amount: Investment amount in EUR
    ///   - currentValue: Current value (if nil, calculates based on performance)
    ///   - performance: Performance percentage (default: 0.0)
    ///   - status: Investment status (default: .active)
    ///   - numberOfTrades: Number of trades associated (default: 0)
    ///   - specialization: Trader specialization (default: "Tech")
    /// - Returns: Configured Investment instance
    static func createInvestment(
        id: String = UUID().uuidString,
        batchId: String? = nil,
        investorId: String = "investor-1",
        investorName: String = "Test Investor",
        traderId: String = "trader-1",
        traderName: String = "Test Trader",
        amount: Double = 1000.0,
        currentValue: Double? = nil,
        performance: Double = 0.0,
        status: InvestmentStatus = .active,
        numberOfTrades: Int = 0,
        sequenceNumber: Int? = 1,
        specialization: String = "Tech",
        reservationStatus: InvestmentReservationStatus? = nil
    ) -> Investment {
        let calculatedValue = currentValue ?? (amount * (1 + performance / 100))
        let actualReservationStatus = reservationStatus ?? (status == .completed ? .completed : .active)

        return Investment(
            id: id,
            batchId: batchId,
            investorId: investorId,
            investorName: investorName,
            traderId: traderId,
            traderName: traderName,
            amount: amount,
            currentValue: calculatedValue,
            date: Date(),
            status: status,
            performance: performance,
            numberOfTrades: numberOfTrades,
            sequenceNumber: sequenceNumber,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: status == .completed ? Date() : nil,
            specialization: specialization,
            reservationStatus: actualReservationStatus
        )
    }

    /// Creates multiple investments for batch testing
    /// - Parameters:
    ///   - count: Number of investments to create
    ///   - baseAmount: Base investment amount
    ///   - traderId: Trader ID (same for all)
    /// - Returns: Array of investments
    static func createInvestments(
        count: Int,
        baseAmount: Double = 1000.0,
        traderId: String = "trader-1"
    ) -> [Investment] {
        return (0..<count).map { index in
            createInvestment(
                id: "inv-\(index)",
                investorId: "investor-\(index % 3)", // Distribute across 3 investors
                traderId: traderId,
                amount: baseAmount * Double(index + 1),
                performance: Double.random(in: -20...50)
            )
        }
    }

    // MARK: - Order Creation

    /// Creates a buy order with customizable parameters
    /// - Parameters:
    ///   - id: Order ID (default: UUID)
    ///   - traderId: Trader user ID
    ///   - symbol: Security symbol/WKN
    ///   - quantity: Order quantity
    ///   - price: Buy price per unit
    ///   - status: Order status (default: .completed)
    ///   - optionDirection: Option direction ("CALL" or "PUT")
    ///   - underlyingAsset: Underlying asset name
    ///   - wkn: WKN number
    /// - Returns: Configured OrderBuy instance
    static func createBuyOrder(
        id: String = UUID().uuidString,
        traderId: String = "trader-1",
        symbol: String = "ABC",
        description: String = "Test Security",
        quantity: Double = 100.0,
        price: Double = 10.0,
        status: OrderBuyStatus = .completed,
        optionDirection: String? = nil,
        underlyingAsset: String? = nil,
        wkn: String? = nil,
        category: String? = nil,
        strike: Double? = nil,
        orderInstruction: String? = "market",
        limitPrice: Double? = nil
    ) -> OrderBuy {
        let now = Date()
        let executedAt = status != .submitted ? now.addingTimeInterval(-300) : nil
        let confirmedAt = status == .completed ? now.addingTimeInterval(-200) : nil

        return OrderBuy(
            id: id,
            traderId: traderId,
            symbol: symbol,
            description: description,
            quantity: quantity,
            price: price,
            totalAmount: quantity * price,
            status: status,
            createdAt: now.addingTimeInterval(-600),
            executedAt: executedAt,
            confirmedAt: confirmedAt,
            updatedAt: now,
            optionDirection: optionDirection,
            underlyingAsset: underlyingAsset,
            wkn: wkn,
            category: category,
            strike: strike,
            orderInstruction: orderInstruction,
            limitPrice: limitPrice
        )
    }

    /// Creates a sell order with customizable parameters
    /// - Parameters:
    ///   - id: Order ID (default: UUID)
    ///   - traderId: Trader user ID
    ///   - symbol: Security symbol/WKN
    ///   - quantity: Order quantity
    ///   - price: Sell price per unit
    ///   - status: Order status (default: .confirmed)
    ///   - originalHoldingId: ID of the holding being sold
    /// - Returns: Configured OrderSell instance
    static func createSellOrder(
        id: String = UUID().uuidString,
        traderId: String = "trader-1",
        symbol: String = "ABC",
        description: String = "Test Security",
        quantity: Double = 100.0,
        price: Double = 12.0,
        status: OrderSellStatus = .confirmed,
        optionDirection: String? = nil,
        underlyingAsset: String? = nil,
        wkn: String? = nil,
        category: String? = nil,
        strike: Double? = nil,
        orderInstruction: String? = "market",
        limitPrice: Double? = nil,
        originalHoldingId: String? = nil
    ) -> OrderSell {
        let now = Date()
        let executedAt = status != .submitted ? now.addingTimeInterval(-100) : nil
        let confirmedAt = status == .confirmed ? now : nil

        return OrderSell(
            id: id,
            traderId: traderId,
            symbol: symbol,
            description: description,
            quantity: quantity,
            price: price,
            totalAmount: quantity * price,
            status: status,
            createdAt: now.addingTimeInterval(-200),
            executedAt: executedAt,
            confirmedAt: confirmedAt,
            updatedAt: now,
            optionDirection: optionDirection,
            underlyingAsset: underlyingAsset,
            wkn: wkn,
            category: category,
            strike: strike,
            orderInstruction: orderInstruction,
            limitPrice: limitPrice,
            originalHoldingId: originalHoldingId
        )
    }

    // MARK: - Trade Creation

    /// Creates a complete trade (buy + sell) with customizable parameters
    /// - Parameters:
    ///   - id: Trade ID (default: UUID)
    ///   - tradeNumber: Sequential trade number
    ///   - traderId: Trader user ID
    ///   - symbol: Security symbol
    ///   - buyQuantity: Buy order quantity
    ///   - buyPrice: Buy price per unit
    ///   - sellQuantity: Sell order quantity (if nil, uses buyQuantity)
    ///   - sellPrice: Sell price per unit
    ///   - status: Trade status (default: .completed)
    ///   - partialSells: Array of partial sell orders (for partial sell scenarios)
    /// - Returns: Configured Trade instance
    static func createTrade(
        id: String = UUID().uuidString,
        tradeNumber: Int = 1,
        traderId: String = "trader-1",
        symbol: String = "ABC",
        description: String = "Test Trade",
        buyQuantity: Double = 100.0,
        buyPrice: Double = 10.0,
        sellQuantity: Double? = nil,
        sellPrice: Double = 12.0,
        status: TradeStatus = .completed,
        partialSells: [OrderSell] = []
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
            status: status == .completed ? .confirmed : .submitted
        )

        let allSellOrders = partialSells.isEmpty ? [sellOrder] : partialSells

        let calculatedProfit: Double? = {
            if status == .completed {
                let totalSellAmount = allSellOrders.reduce(0.0) { $0 + $1.totalAmount }
                return totalSellAmount - buyOrder.totalAmount
            }
            return nil
        }()

        return Trade(
            id: id,
            tradeNumber: tradeNumber,
            traderId: traderId,
            symbol: symbol,
            description: description,
            buyOrder: buyOrder,
            sellOrder: sellOrder,
            sellOrders: allSellOrders,
            status: status,
            createdAt: Date(),
            completedAt: status == .completed ? Date() : nil,
            updatedAt: Date(),
            calculatedProfit: calculatedProfit
        )
    }

    /// Creates a trade with partial sells
    /// - Parameters:
    ///   - buyQuantity: Total buy quantity
    ///   - buyPrice: Buy price
    ///   - partialSells: Array of (quantity, price) tuples for partial sells
    /// - Returns: Trade with multiple sell orders
    static func createTradeWithPartialSells(
        buyQuantity: Double = 1000.0,
        buyPrice: Double = 10.0,
        partialSells: [(quantity: Double, price: Double)]
    ) -> Trade {
        let buyOrder = createBuyOrder(
            quantity: buyQuantity,
            price: buyPrice,
            status: .completed
        )

        let sellOrders = partialSells.enumerated().map { index, sell in
            createSellOrder(
                id: "sell-\(index)",
                quantity: sell.quantity,
                price: sell.price,
                status: .confirmed
            )
        }

        let totalSellQuantity = partialSells.reduce(0.0) { $0 + $1.quantity }
        let status: TradeStatus = totalSellQuantity >= buyQuantity ? .completed : .active

        let calculatedProfit: Double? = {
            if status == .completed {
                let totalSellAmount = sellOrders.reduce(0.0) { $0 + $1.totalAmount }
                return totalSellAmount - buyOrder.totalAmount
            }
            return nil
        }()

        return Trade(
            id: UUID().uuidString,
            tradeNumber: 1,
            traderId: "trader-1",
            symbol: "ABC",
            description: "Partial Sell Trade",
            buyOrder: buyOrder,
            sellOrder: sellOrders.first,
            sellOrders: sellOrders,
            status: status,
            createdAt: Date(),
            completedAt: status == .completed ? Date() : nil,
            updatedAt: Date(),
            calculatedProfit: calculatedProfit
        )
    }

    // MARK: - Test Scenarios

    /// Creates a profitable trade scenario
    static func createProfitableTrade(
        buyPrice: Double = 10.0,
        sellPrice: Double = 15.0,
        quantity: Double = 100.0
    ) -> Trade {
        return createTrade(
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            buyQuantity: quantity,
            sellQuantity: quantity,
            status: .completed
        )
    }

    /// Creates a losing trade scenario
    static func createLosingTrade(
        buyPrice: Double = 10.0,
        sellPrice: Double = 8.0,
        quantity: Double = 100.0
    ) -> Trade {
        return createTrade(
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            buyQuantity: quantity,
            sellQuantity: quantity,
            status: .completed
        )
    }

    /// Creates a break-even trade scenario
    static func createBreakEvenTrade(
        price: Double = 10.0,
        quantity: Double = 100.0
    ) -> Trade {
        return createTrade(
            buyPrice: price,
            sellPrice: price,
            buyQuantity: quantity,
            sellQuantity: quantity,
            status: .completed
        )
    }

    // MARK: - Complete Flow Helpers

    /// Executes a complete investment → trade → profit flow
    /// - Parameters:
    ///   - investmentAmount: Investment capital amount
    ///   - buyPrice: Buy price per unit
    ///   - sellPrice: Sell price per unit
    ///   - quantity: Trade quantity
    /// - Returns: Tuple containing investment, trade, and calculated profit
    static func executeInvestmentTradeFlow(
        investmentAmount: Double,
        buyPrice: Double,
        sellPrice: Double,
        quantity: Double
    ) -> (investment: Investment, trade: Trade, profit: Double) {
        let investment = createInvestment(amount: investmentAmount)
        let trade = createTrade(
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            buyQuantity: quantity,
            sellQuantity: quantity
        )
        let profit = (sellPrice - buyPrice) * quantity

        return (investment, trade, profit)
    }

    // MARK: - Test Data Arrays

    /// Standard investment amounts for testing
    static let standardInvestmentAmounts: [Double] = [100, 500, 1000, 5000, 10000, 50000]

    /// Standard investment counts for testing
    static let standardInvestmentCounts: [Int] = [1, 3, 5, 10]

    /// Standard buy prices for testing
    static let standardBuyPrices: [Double] = [0.50, 1.0, 5.0, 10.0, 50.0, 100.0]

    /// Standard sell prices for testing (relative to buy prices)
    static let standardSellPriceMultipliers: [Double] = [0.5, 0.8, 1.0, 1.2, 1.5, 2.0]

    /// Standard quantities for testing
    static let standardQuantities: [Int] = [1, 10, 100, 1000, 10000]

    /// Performance percentages for testing
    static let standardPerformances: [Double] = [-50, -25, 0, 10, 25, 50, 100]
}

// MARK: - Test Scenario Structures

/// Represents a complete trade test scenario
struct TradeTestScenario {
    let name: String
    let buyPrice: Double
    let sellPrice: Double
    let quantity: Double
    let expectedProfit: Double
    let expectedReturnPercent: Double

    var trade: Trade {
        InvestmentTradingTestHelpers.createTrade(
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            buyQuantity: quantity,
            sellQuantity: quantity
        )
    }
}

extension TradeTestScenario {
    /// Standard trade scenarios for testing
    static let standardScenarios: [TradeTestScenario] = [
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
        ),
        TradeTestScenario(
            name: "Break even",
            buyPrice: 10.0,
            sellPrice: 10.0,
            quantity: 100.0,
            expectedProfit: 0.0,
            expectedReturnPercent: 0.0
        )
    ]
}











