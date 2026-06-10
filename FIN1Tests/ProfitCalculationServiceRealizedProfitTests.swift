@testable import FIN1
import XCTest

final class ProfitCalculationServiceRealizedProfitTests: XCTestCase {
    func testFullSellInvoiceProfitMatchesLegacyTaxableProfit() {
        let buy = Self.makeInvoice(type: .buy, nonTaxTotal: 1_660)
        let sell = Self.makeInvoice(type: .sell, nonTaxTotal: 2_310)

        let legacy = ProfitCalculationService.calculateTaxableProfit(
            buyInvoice: buy,
            sellInvoices: [sell]
        )
        let realized = ProfitCalculationService.calculateRealizedTaxableProfit(
            buyInvoice: buy,
            sellInvoices: [sell],
            soldQuantity: 1_000,
            buyQuantity: 1_000
        )

        XCTAssertEqual(legacy, 650, accuracy: 0.01)
        XCTAssertEqual(realized, 650, accuracy: 0.01)
    }

    func testPartialSellInvoiceUsesProportionalBuyCost() {
        let buy = Self.makeInvoice(type: .buy, nonTaxTotal: 1_000)
        let sell = Self.makeInvoice(type: .sell, nonTaxTotal: 600)

        let profit = ProfitCalculationService.calculateRealizedTaxableProfit(
            buyInvoice: buy,
            sellInvoices: [sell],
            soldQuantity: 50,
            buyQuantity: 100
        )

        XCTAssertEqual(profit, 100, accuracy: 0.01)
    }

    func testPartialSellOrderProfitUsesProportionalBuyCost() {
        let trade = Self.makeTrade(
            buyQty: 100,
            buyPrice: 10,
            sellQty: 50,
            sellPrice: 12
        )

        let profit = ProfitCalculationService.calculateRealizedGrossProfitFromOrders(for: trade)
        XCTAssertGreaterThan(profit, 0)
        XCTAssertLessThan(profit, ProfitCalculationService.calculateRealizedGrossProfitFromOrders(
            for: Self.makeTrade(buyQty: 100, buyPrice: 10, sellQty: 100, sellPrice: 12)
        ))
    }

    func testDetectsStaleStoredProfitAfterPartialSells() {
        let trade = Self.makeTrade(
            buyQty: 1_000,
            buyPrice: 1.66,
            sellQty: 1_000,
            sellPrice: 2.31,
            storedProfit: -660
        )
        XCTAssertTrue(ProfitCalculationService.isStoredProfitStale(for: trade))
        let resolved = ProfitCalculationService.calculateRealizedGrossProfitFromOrderTotals(for: trade)
        XCTAssertGreaterThan(resolved ?? 0, 0)
    }

    func testTradeWithStoredRealizedProfitSetsCalculatedProfit() {
        let trade = Self.makeTrade(buyQty: 1_000, buyPrice: 1.66, sellQty: 1_000, sellPrice: 2.31)
        let stored = ProfitCalculationService.tradeWithStoredRealizedProfit(trade)
        XCTAssertNotNil(stored.calculatedProfit)
        XCTAssertGreaterThan(stored.calculatedProfit ?? 0, 0)
    }

    // MARK: - Helpers

    private static func makeInvoice(type: TransactionType, nonTaxTotal: Double) -> Invoice {
        let customer = CustomerInfo(
            name: "Trader",
            address: "Street",
            city: "City",
            postalCode: "12345",
            taxNumber: "TAX",
            depotNumber: "DEPOT",
            bank: "Bank",
            customerNumber: "C1"
        )
        return Invoice(
            invoiceNumber: "INV-1",
            type: .securitiesSettlement,
            customerInfo: customer,
            items: [
                InvoiceItem(
                    description: "Securities",
                    quantity: 1,
                    unitPrice: nonTaxTotal,
                    itemType: .securities
                )
            ],
            tradeId: "trade-1",
            tradeNumber: 1,
            transactionType: type
        )
    }

    private static func makeTrade(
        buyQty: Double,
        buyPrice: Double,
        sellQty: Double,
        sellPrice: Double,
        storedProfit: Double? = nil
    ) -> Trade {
        let now = Date()
        let buyOrder = OrderBuy(
            id: "buy-1",
            traderId: "trader-1",
            symbol: "TEST",
            description: "Test",
            quantity: buyQty,
            price: buyPrice,
            totalAmount: buyPrice * buyQty,
            status: .executed,
            createdAt: now,
            executedAt: now,
            confirmedAt: now,
            updatedAt: now,
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
            symbol: "TEST",
            description: "Test",
            quantity: sellQty,
            price: sellPrice,
            totalAmount: sellPrice * sellQty,
            status: .completed,
            createdAt: now,
            executedAt: now,
            confirmedAt: now,
            updatedAt: now,
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: nil,
            category: nil,
            strike: nil,
            orderInstruction: nil,
            limitPrice: nil,
            originalHoldingId: "buy-1"
        )
        let isCompleted = sellQty >= buyQty
        return Trade(
            id: "trade-1",
            tradeNumber: 1,
            traderId: "trader-1",
            symbol: "TEST",
            description: "Test",
            buyOrder: buyOrder,
            sellOrder: nil,
            sellOrders: [sellOrder],
            status: isCompleted ? .completed : .active,
            createdAt: now,
            completedAt: isCompleted ? now : nil,
            updatedAt: now,
            calculatedProfit: storedProfit
        )
    }
}
