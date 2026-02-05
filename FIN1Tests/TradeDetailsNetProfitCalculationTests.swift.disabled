import XCTest
@testable import FIN1

// MARK: - Trade Details Net Profit Calculation Tests

final class TradeDetailsNetProfitCalculationTests: XCTestCase {

    func testNetProfitCalculationWithFees() {
        // Given: A trade with the values from the image
        // Buy order executed: -1.802,24 € (includes fees)
        // Sell order executed: +2.881,10 € (includes fees)
        // Expected gross profit: 2.881,10 € - 1.802,24 € = 1.078,86 €
        // Expected net profit after taxes: 1.078,86 € (no taxes on this trade)

        let buyInvoiceAmount = -1802.24
        let sellInvoiceAmount = 2881.10
        let expectedGrossProfit = sellInvoiceAmount + buyInvoiceAmount // 2881.10 + (-1802.24) = 1078.86
        let expectedNetProfit = 1078.86 // No taxes

        // Create mock invoices
        let buyInvoice = createMockInvoice(
            transactionType: .buy,
            totalAmount: buyInvoiceAmount,
            items: [
                createMockInvoiceItem(itemType: .orderFee, amount: 23.45),
                createMockInvoiceItem(itemType: .exchangeFee, amount: 4.69),
                createMockInvoiceItem(itemType: .foreignCosts, amount: 3.00)
            ]
        )

        let sellInvoice = createMockInvoice(
            transactionType: .sell,
            totalAmount: sellInvoiceAmount,
            items: [
                createMockInvoiceItem(itemType: .orderFee, amount: 23.45),
                createMockInvoiceItem(itemType: .exchangeFee, amount: 4.69),
                createMockInvoiceItem(itemType: .foreignCosts, amount: 3.00)
            ]
        )

        // Create trade overview item
        let trade = TradeOverviewItem(
            tradeId: "test-trade-id",
            tradeNumber: 1,
            startDate: Date(),
            endDate: Date(),
            profitLoss: 0.0, // This should be ignored in favor of cash flow calculation
            returnPercentage: 0.0,
            commission: 0.0,
            isActive: false,
            statusText: "Completed",
            statusDetail: "Completed",
            onDetailsTapped: {},
            grossProfit: 0.0,
            totalFees: 0.0
        )

        // Create view model
        let viewModel = TradeDetailsViewModel(trade: trade)

        // Set the invoices
        viewModel.buyInvoice = buyInvoice
        viewModel.sellInvoices = [sellInvoice]

        // When: Calculate net profit
        let actualNetProfit = viewModel.netCreditAmount
        let actualGrossProfit = viewModel.netCashFlow

        // Then: Verify the calculations
        XCTAssertEqual(actualGrossProfit, expectedGrossProfit, accuracy: 0.01,
                      "Gross profit should be calculated from invoice amounts")
        XCTAssertEqual(actualNetProfit, expectedNetProfit, accuracy: 0.01,
                      "Net profit should equal gross profit when no taxes are due")

        // Verify tax calculations are zero
        XCTAssertEqual(viewModel.capitalGainsTax, 0.0, accuracy: 0.01,
                      "Capital gains tax should be zero for this profit amount")
        XCTAssertEqual(viewModel.totalTaxAmount, 0.0, accuracy: 0.01,
                      "Total tax should be zero for this profit amount")
    }

    func testNetProfitCalculationWithTaxes() {
        // Given: A trade with a larger profit that would trigger taxes
        let buyInvoiceAmount = -1000.0
        let sellInvoiceAmount = 2000.0
        let expectedGrossProfit = 1000.0 // 2000 - 1000
        let expectedCapitalGainsTax = 250.0 // 25% of 1000
        let expectedSolidaritySurcharge = 13.75 // 5.5% of 250
        let expectedChurchTax = 20.0 // 8% of 250
        let expectedTotalTax = 283.75 // 250 + 13.75 + 20
        let expectedNetProfit = 716.25 // 1000 - 283.75

        let buyInvoice = createMockInvoice(transactionType: .buy, totalAmount: buyInvoiceAmount, items: [])
        let sellInvoice = createMockInvoice(transactionType: .sell, totalAmount: sellInvoiceAmount, items: [])

        let trade = TradeOverviewItem(
            tradeId: "test-trade-id",
            tradeNumber: 1,
            startDate: Date(),
            endDate: Date(),
            profitLoss: 0.0,
            returnPercentage: 0.0,
            commission: 0.0,
            isActive: false,
            statusText: "Completed",
            statusDetail: "Completed",
            onDetailsTapped: {},
            grossProfit: 0.0,
            totalFees: 0.0
        )

        let viewModel = TradeDetailsViewModel(trade: trade)
        viewModel.buyInvoice = buyInvoice
        viewModel.sellInvoices = [sellInvoice]

        // When: Calculate net profit
        let actualNetProfit = viewModel.netCreditAmount
        let actualGrossProfit = viewModel.netCashFlow

        // Then: Verify the calculations
        XCTAssertEqual(actualGrossProfit, expectedGrossProfit, accuracy: 0.01)
        XCTAssertEqual(viewModel.capitalGainsTax, expectedCapitalGainsTax, accuracy: 0.01)
        XCTAssertEqual(viewModel.solidaritySurcharge, expectedSolidaritySurcharge, accuracy: 0.01)
        XCTAssertEqual(viewModel.churchTax, expectedChurchTax, accuracy: 0.01)
        XCTAssertEqual(viewModel.totalTaxAmount, expectedTotalTax, accuracy: 0.01)
        XCTAssertEqual(actualNetProfit, expectedNetProfit, accuracy: 0.01)
    }

    // MARK: - Helper Methods

    private func createMockInvoice(transactionType: TransactionType, totalAmount: Double, items: [InvoiceItem]) -> Invoice {
        let customerInfo = CustomerInfo(
            name: "Test User",
            address: "Test Address",
            city: "Test City",
            postalCode: "12345",
            taxNumber: "123/456/789",
            depotNumber: "DE12345678901234567890",
            bank: "Test Bank",
            customerNumber: "TEST-001"
        )

        return Invoice(
            invoiceNumber: "TEST-001",
            type: .securitiesSettlement,
            customerInfo: customerInfo,
            items: items,
            tradeId: "test-trade",
            orderId: "test-order",
            transactionType: transactionType
        )
    }

    private func createMockInvoiceItem(itemType: InvoiceItemType, amount: Double) -> InvoiceItem {
        return InvoiceItem(
            description: "Test item",
            quantity: 1,
            unitPrice: amount,
            itemType: itemType
        )
    }
}
