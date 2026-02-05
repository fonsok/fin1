import XCTest
@testable import FIN1

/// Tests to verify that trader ROI and investor return calculations match
/// This ensures consistency between trader and investor views
final class ROICalculationConsistencyTests: XCTestCase {

    // MARK: - Test Helpers

    private func createBuyInvoice(securitiesValue: Double, fees: Double) -> Invoice {
        let securitiesItem = InvoiceItem(
            description: "Test Security",
            quantity: 1000.0,
            unitPrice: securitiesValue / 1000.0,
            itemType: .securities
        )

        let feeItems = [
            InvoiceItem(
                description: "Ordergebühr",
                quantity: 1.0,
                unitPrice: fees / 3.0,
                itemType: .orderFee
            ),
            InvoiceItem(
                description: "Handelsplatzgebühr",
                quantity: 1.0,
                unitPrice: fees / 3.0,
                itemType: .exchangeFee
            ),
            InvoiceItem(
                description: "Fremdkostenpauschale",
                quantity: 1.0,
                unitPrice: fees / 3.0,
                itemType: .foreignCosts
            )
        ]

        let customerInfo = CustomerInfo(
            name: "Test Trader",
            address: "Test Address",
            city: "Test City",
            postalCode: "12345",
            taxNumber: "123/456/789",
            depotNumber: "123456",
            bank: "Test Bank",
            customerNumber: "789"
        )

        return Invoice(
            invoiceNumber: "INV-001",
            type: .securitiesSettlement,
            customerInfo: customerInfo,
            items: [securitiesItem] + feeItems,
            tradeId: "trade-001",
            tradeNumber: 1,
            orderId: "order-buy-001",
            transactionType: .buy
        )
    }

    private func createSellInvoice(securitiesValue: Double, fees: Double) -> Invoice {
        let securitiesItem = InvoiceItem(
            description: "Test Security",
            quantity: 1000.0,
            unitPrice: securitiesValue / 1000.0,
            itemType: .securities
        )

        // Sell fees are negative (they reduce proceeds)
        let feeItems = [
            InvoiceItem(
                description: "Ordergebühr",
                quantity: 1.0,
                unitPrice: -fees / 3.0,
                itemType: .orderFee
            ),
            InvoiceItem(
                description: "Handelsplatzgebühr",
                quantity: 1.0,
                unitPrice: -fees / 3.0,
                itemType: .exchangeFee
            ),
            InvoiceItem(
                description: "Fremdkostenpauschale",
                quantity: 1.0,
                unitPrice: -fees / 3.0,
                itemType: .foreignCosts
            )
        ]

        let customerInfo = CustomerInfo(
            name: "Test Trader",
            address: "Test Address",
            city: "Test City",
            postalCode: "12345",
            taxNumber: "123/456/789",
            depotNumber: "123456",
            bank: "Test Bank",
            customerNumber: "789"
        )

        return Invoice(
            invoiceNumber: "INV-002",
            type: .securitiesSettlement,
            customerInfo: customerInfo,
            items: [securitiesItem] + feeItems,
            tradeId: "trade-001",
            tradeNumber: 1,
            orderId: "order-sell-001",
            transactionType: .sell
        )
    }

    private func createCompletedTrade(
        buyInvoice: Invoice,
        sellInvoices: [Invoice],
        buyPrice: Double = 2.0,
        quantity: Double = 1000.0
    ) -> Trade {
        let buyOrder = OrderBuy(
            id: "order-buy-001",
            traderId: "trader-001",
            symbol: "TEST",
            description: "Test Security",
            quantity: quantity,
            price: buyPrice,
            totalAmount: buyPrice * quantity,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date()
        )

        let sellOrder = OrderSell(
            id: "order-sell-001",
            traderId: "trader-001",
            symbol: "TEST",
            description: "Test Security",
            quantity: quantity,
            price: 4.5,
            totalAmount: 4.5 * quantity,
            status: .confirmed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
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

        // Calculate profit from invoices (same method trader uses)
        let calculatedProfit = ProfitCalculationService.calculateTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        return Trade(
            id: "trade-001",
            tradeNumber: 1,
            traderId: "trader-001",
            symbol: "TEST",
            description: "Test Security",
            buyOrder: buyOrder,
            sellOrder: sellOrder,
            sellOrders: [sellOrder],
            status: .completed,
            createdAt: Date(),
            completedAt: Date(),
            updatedAt: Date(),
            calculatedProfit: calculatedProfit
        )
    }

    // MARK: - Tests

    func testTraderAndInvestorROIMatch() {
        // Given: A completed trade with invoices
        let buyInvoice = createBuyInvoice(securitiesValue: 2000.0, fees: 83.0)
        let sellInvoice = createSellInvoice(securitiesValue: 4500.0, fees: 83.0)
        let trade = createCompletedTrade(
            buyInvoice: buyInvoice,
            sellInvoices: [sellInvoice],
            buyPrice: 2.0,
            quantity: 1000.0
        )

        // When: Calculate trader ROI
        let traderROI = trade.roi ?? 0.0

        // And: Calculate investor return (50% ownership)
        let ownershipPercentage = 0.5
        let investorProfit = ProfitCalculationService.calculateInvestorTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: [sellInvoice],
            ownershipPercentage: ownershipPercentage
        )
        let traderDenominator = trade.buyOrder.price * Double(trade.totalSoldQuantity)
        let investorDenominator = traderDenominator * ownershipPercentage
        let investorReturn = (investorProfit / investorDenominator) * 100

        // Then: Both should match (within rounding tolerance)
        XCTAssertEqual(
            traderROI,
            investorReturn,
            accuracy: 0.01,
            "Trader ROI (\(traderROI)%) and Investor Return (\(investorReturn)%) should match"
        )
    }

    func testTraderAndInvestorROIMatchWithDifferentOwnershipPercentages() {
        // Given: A completed trade with invoices
        let buyInvoice = createBuyInvoice(securitiesValue: 2000.0, fees: 83.0)
        let sellInvoice = createSellInvoice(securitiesValue: 4500.0, fees: 83.0)
        let trade = createCompletedTrade(
            buyInvoice: buyInvoice,
            sellInvoices: [sellInvoice],
            buyPrice: 2.0,
            quantity: 1000.0
        )

        // When: Calculate trader ROI
        let traderROI = trade.roi ?? 0.0

        // Test multiple ownership percentages
        let ownershipPercentages: [Double] = [0.1, 0.25, 0.5, 0.75, 0.9, 1.0]

        for ownershipPercentage in ownershipPercentages {
            // Calculate investor return
            let investorProfit = ProfitCalculationService.calculateInvestorTaxableProfit(
                buyInvoice: buyInvoice,
                sellInvoices: [sellInvoice],
                ownershipPercentage: ownershipPercentage
            )
            let traderDenominator = trade.buyOrder.price * Double(trade.totalSoldQuantity)
            let investorDenominator = traderDenominator * ownershipPercentage
            let investorReturn = (investorProfit / investorDenominator) * 100

            // Then: Both should match regardless of ownership percentage
            XCTAssertEqual(
                traderROI,
                investorReturn,
                accuracy: 0.01,
                "Trader ROI (\(traderROI)%) and Investor Return (\(investorReturn)%) should match for \(ownershipPercentage * 100)% ownership"
            )
        }
    }

    func testInvestorTaxableProfitIsProportional() {
        // Given: A trade with known profit
        let buyInvoice = createBuyInvoice(securitiesValue: 2000.0, fees: 83.0)
        let sellInvoice = createSellInvoice(securitiesValue: 4500.0, fees: 83.0)

        // When: Calculate full trade profit
        let fullProfit = ProfitCalculationService.calculateTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: [sellInvoice]
        )

        // And: Calculate investor profit for 50% ownership
        let ownershipPercentage = 0.5
        let investorProfit = ProfitCalculationService.calculateInvestorTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: [sellInvoice],
            ownershipPercentage: ownershipPercentage
        )

        // Then: Investor profit should be exactly 50% of full profit
        let expectedInvestorProfit = fullProfit * ownershipPercentage
        XCTAssertEqual(
            investorProfit,
            expectedInvestorProfit,
            accuracy: 0.01,
            "Investor profit should be proportional to ownership percentage"
        )
    }

    func testROICalculationWithMultipleSellInvoices() {
        // Given: A trade with multiple partial sell orders
        let buyInvoice = createBuyInvoice(securitiesValue: 2000.0, fees: 83.0)
        let sellInvoice1 = createSellInvoice(securitiesValue: 1500.0, fees: 62.0)
        let sellInvoice2 = createSellInvoice(securitiesValue: 1000.0, fees: 41.0)
        let trade = createCompletedTrade(
            buyInvoice: buyInvoice,
            sellInvoices: [sellInvoice1, sellInvoice2],
            buyPrice: 2.0,
            quantity: 1000.0
        )

        // When: Calculate trader ROI
        let traderROI = trade.roi ?? 0.0

        // And: Calculate investor return (30% ownership)
        let ownershipPercentage = 0.3
        let investorProfit = ProfitCalculationService.calculateInvestorTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: [sellInvoice1, sellInvoice2],
            ownershipPercentage: ownershipPercentage
        )
        let traderDenominator = trade.buyOrder.price * Double(trade.totalSoldQuantity)
        let investorDenominator = traderDenominator * ownershipPercentage
        let investorReturn = (investorProfit / investorDenominator) * 100

        // Then: Both should match
        XCTAssertEqual(
            traderROI,
            investorReturn,
            accuracy: 0.01,
            "Trader ROI and Investor Return should match even with multiple sell invoices"
        )
    }
}
