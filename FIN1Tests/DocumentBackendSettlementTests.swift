@testable import FIN1
import XCTest

final class DocumentBackendSettlementTests: XCTestCase {

    func testBackendSettlementDocumentMapsTraderBelegSSOT() throws {
        let json = """
        {
          "objectId": "Pv4kvW5AQb",
          "userId": "trader-1",
          "type": "traderCollectionBill",
          "name": "Verkaufsabrechnung_Trade3_HS4PMLC.pdf",
          "tradeId": "trade-3",
          "accountingDocumentNumber": "TSC-2026-0000168",
          "accountingSummaryText": "Verkaufsabrechnung\\nBelegnummer: TSC-2026-0000168\\nOrdervolumen: 500 St.\\nΣ VERKAUF: 1.918,05 €",
          "metadata": {
            "executionType": "sell",
            "quantity": 500,
            "amount": 1930.7,
            "amountCents": 193070,
            "totalWithFees": 1918.05,
            "totalWithFeesCents": 191805
          }
        }
        """
        let backend = try JSONDecoder().decode(BackendSettlementDocument.self, from: Data(json.utf8))
        let document = Document(backendSettlementDocument: backend)

        XCTAssertEqual(document.id, "Pv4kvW5AQb")
        XCTAssertEqual(document.accountingDocumentNumber, "TSC-2026-0000168")
        XCTAssertTrue(Document.isUsableTraderBelegSnapshotText(document.accountingSummaryText))
        XCTAssertEqual(document.traderCollectionBillMetadata?.executionType, "sell")
        XCTAssertEqual(document.traderCollectionBillMetadata?.quantity, 500)
        XCTAssertFalse(document.needsTraderBelegSnapshotRefresh)
    }

    func testMergePreservingTraderBelegSSOTKeepsSnapshotWhenIncomingSparse() {
        let rich = Document(
            id: "doc-2",
            userId: "trader-1",
            name: "TSC-2026-0000168",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "parse://doc-2",
            size: 512,
            uploadedAt: Date(),
            tradeId: "trade-3",
            documentNumber: "TSC-2026-0000168",
            accountingSummaryText: """
            Verkaufsabrechnung
            Belegnummer: TSC-2026-0000168
            Ordervolumen: 500 St.
            Σ VERKAUF: 1.918,05 €
            """,
            traderCollectionBillMetadata: nil
        )
        let sparse = Document(
            id: "doc-2",
            userId: "trader-1",
            name: "TSC-2026-0000168",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "",
            size: 0,
            uploadedAt: Date(),
            tradeId: "trade-3",
            documentNumber: "TSC-2026-0000168"
        )

        let merged = Document.mergedPreservingTraderBelegSSOT(existing: rich, incoming: sparse)
        XCTAssertTrue(Document.isUsableTraderBelegSnapshotText(merged.accountingSummaryText))
        XCTAssertFalse(merged.needsTraderBelegSnapshotRefresh)
    }

    func testReferencedDocumentDoesNotFallbackToFirstSellBillWhenExplicitNumberMissing() {
        let firstSell = Document(
            id: "sell-1-doc",
            userId: "trader-1",
            name: "TSC-2026-0000167",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "",
            size: 0,
            uploadedAt: Date(),
            tradeId: "trade-3",
            documentNumber: "TSC-2026-0000167"
        )
        let service = MockDocumentService()
        service.documents = [firstSell]
        let entry = AccountStatementEntry(
            title: "VERKAUF",
            occurredAt: Date(),
            amount: 1_918.05,
            direction: .credit,
            category: .tradeSettlement,
            referenceDocumentId: "Pv4kvW5AQb",
            referenceDocumentNumber: "TSC-2026-0000168",
            metadata: [
                "tradeId": "trade-3",
                "transactionType": "sell",
            ],
            balanceAfter: 9_120.05
        )

        XCTAssertNil(entry.referencedDocument(documentService: service))
    }

    func testMatchesBelegReferenceRejectsWrongCachedLeg() {
        let wrongLeg = Document(
            id: "sell-1-doc",
            userId: "trader-1",
            name: "TSC-2026-0000167",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "",
            size: 0,
            uploadedAt: Date(),
            tradeId: "trade-3",
            documentNumber: "TSC-2026-0000167"
        )
        let entry = AccountStatementEntry(
            title: "VERKAUF",
            occurredAt: Date(),
            amount: 1_918.05,
            direction: .credit,
            category: .tradeSettlement,
            referenceDocumentId: "Pv4kvW5AQb",
            referenceDocumentNumber: "TSC-2026-0000168",
            metadata: [:],
            balanceAfter: 9_120.05
        )

        XCTAssertFalse(wrongLeg.matchesBelegReference(for: entry))
    }
}
