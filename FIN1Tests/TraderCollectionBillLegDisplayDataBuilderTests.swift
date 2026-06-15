@testable import FIN1
import XCTest

final class TraderCollectionBillLegDisplayDataBuilderTests: XCTestCase {

    func testSellLegShowsVerkaufWithMetadataQuantity() {
        let trade = Self.makeTradeOverview()
        let metadata = TraderCollectionBillBelegMetadata(
            belegSchemaVersion: 1,
            belegKind: "traderCollectionBill",
            belegLabel: "Verkaufsabrechnung",
            traderId: "trader-1",
            traderDisplayName: "Trader One",
            traderUsername: nil,
            executionType: "sell",
            symbol: "GS4GLEF",
            instrumentLine: "Put - Dow Jones (GS4GLEF)",
            amount: 996.0,
            quantity: 400,
            price: 2.49,
            orderId: "sell-1",
            sellOrderId: "sell-1",
            wkn: "GS4GLEF",
            fees: .init(orderFee: 5, exchangeFee: 1, foreignCosts: 1.5, totalFees: 7.5),
            totalWithFees: 988.5,
            valueDate: "15.06.26",
            closingDate: "15.06.2026, 10:00 Uhr",
            tradingVenue: "XETRA",
            tradeNumber: 1,
            tradeStatus: "active",
            generatedAt: nil,
            partialSell: .init(
                isPartialSell: true,
                soldQuantity: 400,
                remainingQuantity: 800,
                buyQuantity: 1_200,
                sellOrderId: "kUI8NNLSzj",
                eventIndex: 1,
                totalSellEvents: 2,
                executedAt: "2026-06-15T12:45:00.000Z",
                orderQuantity: 400,
                cumulativeSoldQuantity: 400,
                sellVolumeProgress: 0.3333333333
            )
        )

        let display = TraderCollectionBillLegDisplayDataBuilder.build(
            trade: trade,
            metadata: metadata,
            belegNumber: "TSC-2026-0000140"
        )

        XCTAssertNil(display.buyTransaction)
        XCTAssertEqual(display.sellTransactions.count, 1)
        XCTAssertEqual(display.sellTransactions.first?.orderVolume, "400 St.")
        XCTAssertTrue(display.sellTransactions.first?.price.contains("2,49") == true)
        XCTAssertEqual(display.securityIdentifier, "Put - Dow Jones (GS4GLEF)")
        XCTAssertTrue(display.sellInvoices.isEmpty)
        XCTAssertNotNil(display.partialSellDisplay)
        XCTAssertEqual(display.partialSellDisplay?.sequenceLabel, "Teilverkauf 1 von 2")
        XCTAssertEqual(display.partialSellDisplay?.thisSellQuantity, "400 St.")
        XCTAssertEqual(display.partialSellDisplay?.remaining, "800 St.")
    }

    func testSecondPartialSellLegShowsFullProgressWhenComplete() {
        let trade = Self.makeTradeOverview()
        let metadata = TraderCollectionBillBelegMetadata(
            belegSchemaVersion: 1,
            belegKind: "traderCollectionBill",
            belegLabel: "Verkaufsabrechnung",
            traderId: "trader-1",
            traderDisplayName: "Julia Richter",
            traderUsername: nil,
            executionType: "sell",
            symbol: "GS4GLEF",
            instrumentLine: "Put - Dow Jones (GS4GLEF)",
            amount: 2_400.0,
            quantity: 800,
            price: 3.0,
            orderId: "sell-2",
            sellOrderId: "sell-2",
            wkn: "GS4GLEF",
            fees: .init(orderFee: 12, exchangeFee: 0.5, foreignCosts: 2.5, totalFees: 15),
            totalWithFees: 2_385.0,
            valueDate: "15.06.26",
            closingDate: "15.06.2026, 14:47 Uhr",
            tradingVenue: "XETRA",
            tradeNumber: 1,
            tradeStatus: "completed",
            generatedAt: nil,
            partialSell: .init(
                isPartialSell: true,
                soldQuantity: 800,
                remainingQuantity: 0,
                buyQuantity: 1_200,
                sellOrderId: "sell-2",
                eventIndex: 2,
                totalSellEvents: 2,
                executedAt: "2026-06-15T12:47:00.000Z",
                orderQuantity: 800,
                cumulativeSoldQuantity: 1_200,
                sellVolumeProgress: 1.0
            )
        )

        let display = TraderCollectionBillLegDisplayDataBuilder.build(
            trade: trade,
            metadata: metadata,
            belegNumber: "TSC-2026-0000141"
        )

        XCTAssertEqual(display.partialSellDisplay?.sequenceLabel, "Teilverkauf 2 von 2")
        XCTAssertEqual(display.partialSellDisplay?.thisSellQuantity, "800 St.")
        XCTAssertEqual(display.partialSellDisplay?.cumulativeSold, "1200 von 1200 St.")
        XCTAssertEqual(display.partialSellDisplay?.remaining, "0 St.")
        XCTAssertEqual(display.partialSellDisplay?.progress, "100.0 %")
    }

    func testBuyLegShowsKaufOnly() {
        let trade = Self.makeTradeOverview()
        let metadata = TraderCollectionBillBelegMetadata(
            belegSchemaVersion: 1,
            belegKind: "traderCollectionBill",
            belegLabel: "Kaufabrechnung",
            traderId: "trader-1",
            traderDisplayName: nil,
            traderUsername: nil,
            executionType: "buy",
            symbol: "GS4GLEF",
            instrumentLine: nil,
            amount: 2_988.0,
            quantity: 1_200,
            price: 2.49,
            orderId: "buy-1",
            sellOrderId: nil,
            wkn: "GS4GLEF",
            fees: .init(orderFee: 5, exchangeFee: 1, foreignCosts: 1.5, totalFees: 7.5),
            totalWithFees: 2_995.5,
            valueDate: "10.06.26",
            closingDate: "10.06.2026, 09:00 Uhr",
            tradingVenue: "XETRA",
            tradeNumber: 1,
            tradeStatus: "active",
            generatedAt: nil,
            partialSell: nil
        )

        let display = TraderCollectionBillLegDisplayDataBuilder.build(
            trade: trade,
            metadata: metadata,
            belegNumber: "TBC-2026-0000141"
        )

        XCTAssertNotNil(display.buyTransaction)
        XCTAssertEqual(display.buyTransaction?.orderVolume, "1200 St.")
        XCTAssertTrue(display.sellTransactions.isEmpty)
    }

    func testSellOrderDataFromTransactionWithoutInvoice() {
        let tx = SellTransactionData(
            transactionNumber: "TSC-1",
            orderVolume: "400 St.",
            executedVolume: "400 St.",
            price: "2,49 EUR",
            exchangeRate: "",
            conversionFactor: "1,0000",
            custodyType: "GS-Verwahrung",
            depository: "Clearstream Nat.",
            depositoryCountry: "Deutschland",
            profitLoss: "0,00 EUR",
            profitLossColor: "fin1FontColor",
            valueDate: "15.06.26",
            tradingVenue: "XETRA",
            closingDate: "15.06.2026",
            marketValue: "996,00 EUR",
            commission: "-5,00 EUR",
            ownExpenses: "-1,00 EUR",
            externalExpenses: "-1,50 EUR",
            assessmentBasis: "0,00 EUR",
            withheldTax: "0,00 EUR",
            finalAmount: "988,50 EUR",
            finalAmountColor: "fin1AccentGreen"
        )
        let row = SellOrderData.from(transaction: tx)
        XCTAssertEqual(row.orderVolume, "400 St.")
        XCTAssertEqual(row.price, "2,49 EUR")
        XCTAssertEqual(row.finalAmount, "988,50 EUR")
    }

    private static func makeTradeOverview() -> TradeOverviewItem {
        TradeOverviewItem(
            tradeId: "trade-1",
            tradeNumber: 1,
            startDate: Date(),
            endDate: Date(),
            profitLoss: 0,
            returnPercentage: 0,
            commission: 0,
            isCommissionPending: false,
            isActive: false,
            statusText: "completed",
            statusDetail: "",
            onDetailsTapped: {},
            grossProfit: 0,
            totalFees: 0
        )
    }
}
