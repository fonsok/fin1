@testable import FIN1
import XCTest

final class DocumentTraderCreditNoteTests: XCTestCase {

    func testResolvesTradeNumberFromParseField() {
        let doc = Self.makeCreditNote(tradeNumber: 14, name: "CreditNote_Trade14_20260615_ABC.pdf")
        XCTAssertEqual(doc.resolvedTraderCreditNoteTradeNumber, 14)
        XCTAssertEqual(doc.traderCreditNoteTradeReferenceLabel, "Trade #014")
    }

    func testParsesTradeNumberFromFilenameWhenParseFieldMissing() {
        let doc = Self.makeCreditNote(
            tradeNumber: nil,
            name: "CreditNote_Trade3_20260521_ABC.pdf",
            documentNumber: "CN-2026-0042"
        )
        XCTAssertEqual(doc.resolvedTraderCreditNoteTradeNumber, 3)
    }

    func testInboxTitleIncludesTradeReference() {
        let doc = Self.makeCreditNote(
            tradeNumber: 1,
            name: "CreditNote_Trade1_20260521_ABC.pdf",
            documentNumber: "CN-2026-0042"
        )
        XCTAssertEqual(DocumentInboxPolicy.inboxTitle(for: doc), "CN-2026-0042 · Trade #001")
        XCTAssertEqual(DocumentInboxPolicy.inboxSubtitle(for: doc), "Gutschrift Provision · Trade #001")
    }

    func testNavigationTitleUsesTradeReference() {
        let doc = Self.makeCreditNote(tradeNumber: 42, name: "CN", documentNumber: "CN-2026-0099")
        XCTAssertEqual(doc.traderCreditNoteNavigationTitle, "Gutschrift (Trade #042)")
    }

    func testResolvesCommissionAmountFromMetadataWhenInvoiceMissing() {
        let metadata = TraderCollectionBillBelegMetadata(
            belegSchemaVersion: nil,
            belegKind: nil,
            belegLabel: nil,
            traderId: "trader1",
            traderDisplayName: nil,
            traderUsername: nil,
            executionType: nil,
            symbol: nil,
            instrumentLine: nil,
            amount: nil,
            quantity: nil,
            price: nil,
            orderId: nil,
            sellOrderId: nil,
            wkn: nil,
            fees: nil,
            totalWithFees: nil,
            valueDate: nil,
            closingDate: nil,
            tradingVenue: nil,
            tradeNumber: 1,
            tradeStatus: nil,
            generatedAt: nil,
            partialSell: nil,
            commissionAmount: 71.89,
            commissionRate: 0.05,
            grossProfit: 1_437.78,
            netProfit: 1_365.89
        )
        let doc = Document(
            userId: "trader1",
            name: "CN-2026-0000001",
            type: .traderCreditNote,
            status: .verified,
            fileURL: "",
            size: 1,
            uploadedAt: Date(),
            tradeId: "trade-abc",
            tradeNumber: 1,
            documentNumber: "CN-2026-0000001",
            traderCollectionBillMetadata: metadata
        )
        XCTAssertEqual(doc.resolvedTraderCreditNoteCommissionAmount ?? 0, 71.89, accuracy: 0.01)
    }

    private static func makeCreditNote(
        tradeNumber: Int?,
        name: String,
        documentNumber: String? = nil
    ) -> Document {
        Document(
            userId: "trader1",
            name: name,
            type: .traderCreditNote,
            status: .verified,
            fileURL: "",
            size: 1,
            uploadedAt: Date(),
            tradeId: "trade-abc",
            tradeNumber: tradeNumber,
            documentNumber: documentNumber
        )
    }
}
