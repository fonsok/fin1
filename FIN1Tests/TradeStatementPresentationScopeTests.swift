@testable import FIN1
import XCTest

final class TradeStatementPresentationScopeTests: XCTestCase {

    func testSellLegOnlyDoesNotSynthesizeBuyFromFullTrade() {
        let builder = TradeStatementDisplayDataBuilder()
        let trade = Self.makeTradeOverview()
        let fullTrade = Self.makeFullTrade(buyQty: 1_200, sellQtys: [400, 400])

        let displayData = builder.buildDisplayData(
            trade: trade,
            fullTrade: fullTrade,
            buyInvoice: nil,
            sellInvoices: [],
            presentationScope: .sellLegOnly(matchingBelegNumber: "TSC-2026-0000140")
        )

        XCTAssertNil(displayData.buyTransaction)
        XCTAssertTrue(displayData.sellTransactions.isEmpty)
    }

    func testFullTradeFallsBackToBuyOrderWhenNoBuyInvoice() {
        let builder = TradeStatementDisplayDataBuilder()
        let trade = Self.makeTradeOverview()
        let fullTrade = Self.makeFullTrade(buyQty: 1_200, sellQtys: [400])

        let displayData = builder.buildDisplayData(
            trade: trade,
            fullTrade: fullTrade,
            buyInvoice: nil,
            sellInvoices: [],
            presentationScope: .fullTrade
        )

        XCTAssertNotNil(displayData.buyTransaction)
        XCTAssertEqual(displayData.buyTransaction?.orderVolume, "1200 St.")
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

    private static func makeFullTrade(buyQty: Double, sellQtys: [Double]) -> Trade {
        let now = Date()
        let buyOrder = OrderBuy(
            id: "buy-1",
            traderId: "trader-1",
            symbol: "GS4GLEF",
            description: "Put - Dow Jones",
            quantity: buyQty,
            price: 2.49,
            totalAmount: 2.49 * buyQty,
            status: .executed,
            createdAt: now,
            executedAt: now,
            confirmedAt: now,
            updatedAt: now,
            optionDirection: "PUT",
            underlyingAsset: "Dow Jones",
            wkn: "GS4GLEF",
            category: "Optionsschein",
            strike: nil,
            orderInstruction: nil,
            limitPrice: nil
        )
        let sellOrders = sellQtys.enumerated().map { index, qty in
            OrderSell(
                id: "sell-\(index + 1)",
                traderId: "trader-1",
                symbol: "GS4GLEF",
                description: "Put - Dow Jones",
                quantity: qty,
                price: 2.50,
                totalAmount: 2.50 * qty,
                status: .completed,
                createdAt: now,
                executedAt: now,
                confirmedAt: now,
                updatedAt: now,
                optionDirection: "PUT",
                underlyingAsset: "Dow Jones",
                wkn: "GS4GLEF",
                category: "Optionsschein",
                strike: nil,
                orderInstruction: nil,
                limitPrice: nil,
                originalHoldingId: "buy-1"
            )
        }
        return Trade(
            id: "trade-1",
            tradeNumber: 1,
            traderId: "trader-1",
            symbol: "GS4GLEF",
            description: "Put - Dow Jones",
            buyOrder: buyOrder,
            sellOrder: nil,
            sellOrders: sellOrders,
            status: .active,
            createdAt: now,
            completedAt: nil,
            updatedAt: now
        )
    }
}
