@testable import FIN1
import XCTest

final class DocumentTraderCollectionBillTests: XCTestCase {

    func testExecutionSideFromTscPrefix() {
        let doc = Self.makeTraderBill(number: "TSC-2026-0000140")
        XCTAssertEqual(doc.traderBelegExecutionSide, .sell)
        XCTAssertEqual(doc.traderBelegNavigationTitle, "Verkaufsabrechnung")
    }

    func testExecutionSideFromTbcPrefix() {
        let doc = Self.makeTraderBill(number: "TBC-2026-0000141")
        XCTAssertEqual(doc.traderBelegExecutionSide, .buy)
        XCTAssertEqual(doc.traderBelegNavigationTitle, "Kaufabrechnung")
    }

    func testParsesOrderQuantityFromSnapshot() {
        var doc = Self.makeTraderBill(number: "TSC-2026-0000140")
        doc = Document(
            id: doc.id,
            userId: doc.userId,
            name: doc.name,
            type: doc.type,
            status: doc.status,
            fileURL: doc.fileURL,
            size: doc.size,
            uploadedAt: doc.uploadedAt,
            tradeId: doc.tradeId,
            documentNumber: "TSC-2026-0000140",
            accountingSummaryText: """
            Verkaufsabrechnung
            Ordervolumen: 400 St.
            davon ausgef.: 400 St.
            """
        )
        XCTAssertEqual(doc.traderBelegOrderQuantityFromSnapshot, 400)
    }

    func testExecutionSideFromMetadataOverridesAmbiguousName() {
        let meta = TraderCollectionBillBelegMetadata(
            belegSchemaVersion: 1,
            belegKind: "traderCollectionBill",
            belegLabel: nil,
            traderId: nil,
            traderDisplayName: nil,
            traderUsername: nil,
            executionType: "sell",
            symbol: nil,
            instrumentLine: nil,
            amount: BelegEURMoney(euro: 100),
            quantity: 10,
            price: 10,
            orderId: nil,
            sellOrderId: nil,
            wkn: nil,
            fees: nil,
            totalWithFees: BelegEURMoney(euro: 90),
            valueDate: nil,
            closingDate: nil,
            tradingVenue: nil,
            tradeNumber: 1,
            tradeStatus: nil,
            generatedAt: nil,
            partialSell: nil
        )
        let doc = Document(
            userId: "trader1",
            name: "Kaufabrechnung",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "TBC-2026-0000999",
            traderCollectionBillMetadata: meta
        )
        XCTAssertEqual(doc.traderBelegExecutionSide, .sell)
        XCTAssertEqual(doc.traderBelegOrderQuantityFromSnapshot, 10)
    }

    private static func makeTraderBill(number: String) -> Document {
        Document(
            userId: "trader1",
            name: number,
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "",
            size: 1,
            uploadedAt: Date(),
            documentNumber: number
        )
    }
}
