import XCTest
@testable import FIN1

final class InvestmentCompletionServiceAccountingTests: XCTestCase {
    func testReturnPercentageUsesGrossProfitFromTrades() {
        // Given
        let investment = Investment(
            id: "inv-1",
            batchId: nil,
            investorId: "investor-1",
            traderId: "trader-1",
            traderName: "Trader One",
            amount: 1_000,
            currentValue: 1_000,
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

        let buyOrder = OrderBuy(
            id: "buy-1",
            traderId: "trader-1",
            symbol: "ABC",
            description: "Test",
            quantity: 1_000,
            price: 2,
            totalAmount: 2_000,
            status: .completed,
            createdAt: Date().addingTimeInterval(-3600),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date().addingTimeInterval(-3500),
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
            description: "Test",
            quantity: 1_000,
            price: 4,
            totalAmount: 4_000,
            status: .confirmed,
            createdAt: Date().addingTimeInterval(-3400),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date().addingTimeInterval(-3300),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: nil,
            category: nil,
            strike: nil,
            orderInstruction: nil,
            limitPrice: nil,
            originalHoldingId: nil
        )

        let trade = Trade(
            id: "trade-1",
            tradeNumber: 1,
            traderId: "trader-1",
            symbol: "ABC",
            description: "Test trade",
            buyOrder: buyOrder,
            sellOrder: nil,
            sellOrders: [sellOrder],
            status: .completed,
            createdAt: Date().addingTimeInterval(-4000),
            completedAt: Date().addingTimeInterval(-1000),
            updatedAt: Date().addingTimeInterval(-900),
            calculatedProfit: 2_000 // gross profit
        )

        let participation = PoolTradeParticipation(
            tradeId: trade.id,
            investmentId: investment.id,
            poolReservationId: "pool-1",
            poolNumber: 1,
            allocatedAmount: 1_000,
            totalTradeValue: 2_000,
            profitShare: 900 // net profit after 10% commission
        )

        let poolService = MockPoolTradeParticipationService()
        poolService.participations = [participation]

        let tradeLifecycleService = MockTradeLifecycleService(completedTrades: [trade])

        let invoiceService = MockInvoiceService()
        invoiceService.invoices = [
            Invoice(
                invoiceNumber: "INV-BUY-1",
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
            ),
            Invoice(
                invoiceNumber: "INV-SELL-1",
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
        ]

        let completionService = InvestmentCompletionService(
            poolTradeParticipationService: poolService,
            telemetryService: nil,
            investorCashBalanceService: nil,
            tradeLifecycleService: tradeLifecycleService,
            invoiceService: invoiceService
        )

        // When
        let updated = completionService.updateInvestmentProfitsFromTrades(in: [investment])

        // Then
        XCTAssertEqual(updated.count, 1)
        guard let updatedInvestment = updated.first else {
            return XCTFail("Missing updated investment")
        }

        // Gross profit share = 2_000 * 50% = 1_000 ⇒ return = 100%
        XCTAssertEqual(updatedInvestment.performance, 100, accuracy: 0.0001)
        XCTAssertEqual(updatedInvestment.currentValue, 1_000 + 900, accuracy: 0.0001)
    }
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
