@testable import FIN1
import XCTest

final class DocumentInboxPolicyTests: XCTestCase {

    func testExcludesWalletReceiptFinancial() {
        let doc = Document(
            userId: "u1",
            name: "wallet",
            type: .financial,
            status: .verified,
            fileURL: "x",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "IAR-2026-0001"
        )
        XCTAssertFalse(DocumentInboxPolicy.isDisplayableInNotificationsInbox(doc))
    }

    func testInboxTitlePrefersAccountingDocumentNumber() {
        let doc = Document(
            userId: "u1",
            name: "CreditNote_Trade1_20260521_ABC.pdf",
            type: .traderCreditNote,
            status: .verified,
            fileURL: "",
            size: 0,
            uploadedAt: Date(),
            documentNumber: "CN-2026-0042"
        )
        XCTAssertEqual(DocumentInboxPolicy.inboxTitle(for: doc), "CN-2026-0042")
    }

    func testDetectsLocalPlaceholderCreditNote() {
        let doc = Document(
            userId: "u1",
            name: "Gutschrift",
            type: .traderCreditNote,
            status: .verified,
            fileURL: "creditnote://local.pdf",
            size: 1,
            uploadedAt: Date()
        )
        XCTAssertTrue(DocumentInboxPolicy.isLocalPlaceholderDocument(doc))
    }

    func testShouldNotSyncServerManagedPlaceholderToParse() {
        let collectionBill = Document(
            userId: "u1",
            name: "InvestorCollectionBill_Batch.pdf",
            type: .investorCollectionBill,
            status: .verified,
            fileURL: "investment://ABCDEFG-INVST-20260605-00001.pdf",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "ABCDEFG-INVST-20260605-00001"
        )
        XCTAssertFalse(DocumentInboxPolicy.shouldSyncDocumentToParse(collectionBill))

        let invoice = Document(
            userId: "u1",
            name: "Invoice.pdf",
            type: .invoice,
            status: .verified,
            fileURL: "invoice://ABCDEFG-INV-20260605-00001.pdf",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "ABCDEFG-INV-20260605-00001"
        )
        XCTAssertFalse(DocumentInboxPolicy.shouldSyncDocumentToParse(invoice))
    }

    func testShouldSyncNonPlaceholderServerManagedDocument() {
        let doc = Document(
            userId: "u1",
            name: "CB-2026-0001",
            type: .investorCollectionBill,
            status: .verified,
            fileURL: "https://files.example/cb.pdf",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "CB-2026-0001"
        )
        XCTAssertTrue(DocumentInboxPolicy.shouldSyncDocumentToParse(doc))
    }

    func testBelongsToUserMatchesLegacyStableUserId() {
        let email = "investor1@test.com"
        let keys: Set<String> = ["flCPAlXSM6", UserFactory.stableUserId(for: email)]
        let doc = Document(
            userId: "user:\(email)",
            name: "CB",
            type: .investorCollectionBill,
            status: .verified,
            fileURL: "https://x",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "CB-2026-0001"
        )
        XCTAssertTrue(DocumentInboxPolicy.belongsToUser(doc, keys: keys))
    }

    func testDedupeRemovesLocalPlaceholderWhenServerBillExists() {
        let tradeId = "trade-abc"
        let placeholder = Document(
            id: "local-cn",
            userId: "trader1",
            name: "CreditNote_Trade1.pdf",
            type: .traderCreditNote,
            status: .verified,
            fileURL: "creditnote://x.pdf",
            size: 0,
            uploadedAt: Date(),
            tradeId: tradeId
        )
        let server = Document(
            id: "AbCdEfGhIj",
            userId: "trader1",
            name: "CN-2026-0042",
            type: .traderCreditNote,
            status: .verified,
            fileURL: "https://files/cn.pdf",
            size: 45_000,
            uploadedAt: Date(),
            tradeId: tradeId,
            documentNumber: "CN-2026-0042"
        )
        let deduped = DocumentInboxPolicy.dedupeInboxDocuments([placeholder, server])
        XCTAssertEqual(deduped.count, 1)
        XCTAssertEqual(deduped.first?.id, server.id)
    }

    func testIncludesInvestorCollectionBill() {
        let doc = Document(
            userId: "u1",
            name: "Collection Bill",
            type: .investorCollectionBill,
            status: .verified,
            fileURL: "x",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "CB-2026-0001"
        )
        XCTAssertTrue(DocumentInboxPolicy.isDisplayableInNotificationsInbox(doc))
    }
}
