import XCTest
@testable import FIN1

final class InvestorInvestmentStatementViewModelTests: XCTestCase {
    private var mockPoolParticipationService: MockPoolTradeParticipationService!
    private var mockTradeLifecycleService: MockTradeLifecycleService!
    private var mockInvoiceService: MockInvoiceService!

    override func setUp() {
        super.setUp()
        mockPoolParticipationService = MockPoolTradeParticipationService()
        mockInvoiceService = MockInvoiceService()
    }

    // MARK: - Fee Detail Coverage
    func testStatementShowsItemizedFees() {
        // Given
        let investment = sampleInvestment()
        let trade = sampleTrade()

        // Ownership is 50% of the trade
        let participation = PoolTradeParticipation(
            tradeId: trade.id,
            investmentId: investment.id,
            poolReservationId: "pool-1",
            poolNumber: 1,
            allocatedAmount: 1_000,
            totalTradeValue: 2_000,
            profitShare: 900 // net profit share after commission
        )
        mockPoolParticipationService.participations = [participation]
        mockTradeLifecycleService = MockTradeLifecycleService(completedTrades: [trade])

        // Build invoices with explicit fee entries
        let buyInvoice = Invoice(
            invoiceNumber: "INV-BUY",
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: sampleCustomer(),
            items: [
                InvoiceItem(description: "Wertpapiere", quantity: 1, unitPrice: 2_000, itemType: .securities),
                InvoiceItem(description: "Ordergebühr Kauf", quantity: 1, unitPrice: 12, itemType: .orderFee),
                InvoiceItem(description: "Börsenplatz Kauf", quantity: 1, unitPrice: 4, itemType: .exchangeFee)
            ],
            tradeId: trade.id,
            transactionType: .buy
        )

        let sellInvoice = Invoice(
            invoiceNumber: "INV-SELL",
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: sampleCustomer(),
            items: [
                InvoiceItem(description: "Wertpapiere", quantity: 1, unitPrice: 4_000, itemType: .securities),
                InvoiceItem(description: "Ordergebühr Verkauf", quantity: 1, unitPrice: 8, itemType: .orderFee),
                InvoiceItem(description: "Börsenplatz Verkauf", quantity: 1, unitPrice: 2, itemType: .exchangeFee)
            ],
            tradeId: trade.id,
            transactionType: .sell
        )
        mockInvoiceService.invoices = [buyInvoice, sellInvoice]

        // When
        let calculationService = InvestorCollectionBillCalculationService()
        let viewModel = InvestorInvestmentStatementViewModel(
            investment: investment,
            poolTradeParticipationService: mockPoolParticipationService,
            tradeService: mockTradeLifecycleService,
            invoiceService: mockInvoiceService,
            calculationService: calculationService
        )

        // Then
        guard let statement = viewModel.statementItems.first else {
            XCTFail("Expected statement item")
            return
        }

        // Each fee should be scaled by 50% ownership
        XCTAssertEqual(statement.buyFeeDetails.count, 2)
        XCTAssertEqual(statement.sellFeeDetails.count, 2)
        XCTAssertEqual(statement.buyFeeDetails.map { $0.label }, ["Ordergebühr Kauf", "Börsenplatz Kauf"])
        XCTAssertEqual(statement.sellFeeDetails.map { $0.label }, ["Ordergebühr Verkauf", "Börsenplatz Verkauf"])

        XCTAssertEqual(statement.buyFees, 8, accuracy: 0.0001) // (12 + 4) * 0.5
        XCTAssertEqual(statement.sellFees, 5, accuracy: 0.0001) // (8 + 2) * 0.5
    }

    // MARK: - Helpers
    private func sampleInvestment() -> Investment {
        Investment(
            id: "inv-1",
            batchId: nil,
            investorId: "investor-1",
            traderId: "trader-1",
            traderName: "Alice Trader",
            amount: 1_000,
            currentValue: 1_900,
            date: Date(),
            status: .active,
            performance: 0,
            numberOfTrades: 1,
            sequenceNumber: 1,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            specialization: "Tech",
            reservationStatus: .completed
        )
    }

    private func sampleTrade() -> Trade {
        let now = Date()
        let buyOrder = OrderBuy(
            id: "buy-1",
            traderId: "trader-1",
            symbol: "ABC",
            description: "Sample",
            quantity: 1_000,
            price: 2,
            totalAmount: 2_000,
            status: .completed,
            createdAt: now.addingTimeInterval(-3600),
            executedAt: now.addingTimeInterval(-3500),
            confirmedAt: now.addingTimeInterval(-3400),
            updatedAt: now.addingTimeInterval(-3300),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: nil,
            category: nil,
            strike: nil,
            orderInstruction: nil,
            limitPrice: nil
        )

        let sellOrder = OrderSell(
            id: "sell-1",
            traderId: "trader-1",
            symbol: "ABC",
            description: "Sample",
            quantity: 1_000,
            price: 4,
            totalAmount: 4_000,
            status: .confirmed,
            createdAt: now.addingTimeInterval(-3200),
            executedAt: now.addingTimeInterval(-3100),
            confirmedAt: now.addingTimeInterval(-3000),
            updatedAt: now.addingTimeInterval(-2900),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: nil,
            category: nil,
            strike: nil,
            orderInstruction: nil,
            limitPrice: nil,
            originalHoldingId: nil
        )

        return Trade(
            id: "trade-1",
            tradeNumber: 1,
            traderId: "trader-1",
            symbol: "ABC",
            description: "Sample Trade",
            buyOrder: buyOrder,
            sellOrder: nil,
            sellOrders: [sellOrder],
            status: .completed,
            createdAt: now.addingTimeInterval(-4000),
            completedAt: now.addingTimeInterval(-1000),
            updatedAt: now.addingTimeInterval(-900),
            calculatedProfit: 2_000 // Gross profit
        )
    }

    private func sampleCustomer() -> CustomerInfo {
        CustomerInfo(
            name: "Max Mustermann",
            address: "Musterstraße 1",
            city: "Berlin",
            postalCode: "10115",
            taxNumber: "12/345/67890",
            depotNumber: "DEPOT-1",
            bank: "Bank AG",
            customerNumber: "investor-1"
        )
    }
}
