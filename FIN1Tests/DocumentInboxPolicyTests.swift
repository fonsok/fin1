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
            tradeNumber: 1,
            documentNumber: "CN-2026-0042"
        )
        XCTAssertEqual(DocumentInboxPolicy.inboxTitle(for: doc), "CN-2026-0042 · Trade #001")
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

    func testBelongsToUserOrServerInboxRowAcceptsParseSettlementWhenLegacyUserId() {
        let keys: Set<String> = [UserFactory.stableUserId(for: "investor5@test.com")]
        let doc = Document(
            id: "Fr3od3E9Wd",
            userId: "yqpmpTiBK9",
            name: "CB-2026-0000001",
            type: .investorCollectionBill,
            status: .verified,
            fileURL: "collectionbill://CB-2026-0000001.pdf",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "CB-2026-0000001"
        )
        XCTAssertTrue(DocumentInboxPolicy.belongsToUserOrServerInboxRow(doc, keys: keys))
    }

    func testInvestorInboxExcludesTraderSettlementTypes() {
        let keys: Set<String> = [UserFactory.stableUserId(for: "investor5@test.com")]
        let traderBill = Document(
            id: "AbCdEfGhIj",
            userId: "qFaNaREwn7",
            name: "CB-TRADER",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "https://files/cb.pdf",
            size: 1,
            uploadedAt: Date()
        )
        XCTAssertFalse(DocumentInboxPolicy.belongsToUserOrServerInboxRow(traderBill, keys: keys, role: .investor))
    }

    func testInboxDocumentsCountsUnreadParseObjectIdRowsForLegacyUserKey() {
        let user = Self.makeInvestorUser(
            id: UserFactory.stableUserId(for: "investor5@test.com"),
            email: "investor5@test.com"
        )
        let unreadBill = Document(
            id: "Fr3od3E9Wd",
            userId: "yqpmpTiBK9",
            name: "CB-2026-0000001",
            type: .investorCollectionBill,
            status: .verified,
            fileURL: "collectionbill://CB-2026-0000001.pdf",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "CB-2026-0000001"
        )
        let inbox = DocumentInboxPolicy.inboxDocuments(from: [unreadBill], for: user)
        XCTAssertEqual(inbox.count, 1)
        XCTAssertNil(inbox.first?.readAt)
    }

    func testTraderInboxExcludesPoolMirrorEigenbelegByPrefix() {
        let user = Self.makeTraderUser(id: "trader1", email: "trader2@test.com")
        let internalDoc = Document(
            id: "PmBc123456",
            userId: "trader1",
            name: "Pool-Mirror Eigenbeleg",
            type: .other,
            status: .verified,
            fileURL: "beleg://pool-mirror.pdf",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "PMBC-2026-0000001"
        )
        let externalDoc = Document(
            id: "Tbc1234567",
            userId: "trader1",
            name: "TBC-2026-0000002",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "https://files/tbc.pdf",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "TBC-2026-0000002"
        )
        let inbox = DocumentInboxPolicy.inboxDocuments(from: [internalDoc, externalDoc], for: user)
        XCTAssertEqual(inbox.count, 1)
        XCTAssertEqual(inbox.first?.type, .traderCollectionBill)
    }

    func testTraderInboxExcludesInvestorCollectionBill() {
        let user = Self.makeTraderUser(id: "trader1", email: "trader2@test.com")
        let investorBill = Document(
            id: "InvCb12345",
            userId: "trader1",
            name: "CB-INV",
            type: .investorCollectionBill,
            status: .verified,
            fileURL: "x",
            size: 1,
            uploadedAt: Date(),
            documentNumber: "CB-2026-0001"
        )
        let inbox = DocumentInboxPolicy.inboxDocuments(from: [investorBill], for: user)
        XCTAssertTrue(inbox.isEmpty)
    }

    func testTraderInboxIncludesMultipleSellCollectionBillsPerTrade() {
        let user = Self.makeTraderUser(id: "qFaNaREwn7", email: "trader2@test.com")
        let tradeId = "mlETWoRJPf"
        let buy = Document(
            id: "A86AF2RHog",
            userId: "qFaNaREwn7",
            name: "TBC-2026-0000141",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "",
            size: 1,
            uploadedAt: Date(),
            tradeId: tradeId,
            documentNumber: "TBC-2026-0000141"
        )
        let sell1 = Document(
            id: "cDiIQmXM4W",
            userId: "qFaNaREwn7",
            name: "TSC-2026-0000138",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "",
            size: 1,
            uploadedAt: Date(),
            tradeId: tradeId,
            documentNumber: "TSC-2026-0000138"
        )
        let sell2 = Document(
            id: "fkVWPIwNux",
            userId: "qFaNaREwn7",
            name: "TSC-2026-0000139",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "",
            size: 1,
            uploadedAt: Date(),
            tradeId: tradeId,
            documentNumber: "TSC-2026-0000139"
        )
        let inbox = DocumentInboxPolicy.inboxDocuments(from: [buy, sell1, sell2], for: user)
        XCTAssertEqual(inbox.count, 3)
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

    private static func makeTraderUser(id: String, email: String) -> User {
        var user = Self.makeInvestorUser(id: id, email: email)
        user.role = .trader
        return user
    }

    private static func makeInvestorUser(id: String, email: String) -> User {
        User(
            id: id,
            customerNumber: "CUST001",
            accountType: .individual,
            email: email,
            username: email.components(separatedBy: "@").first ?? "user",
            phoneNumber: "+1234567890",
            password: "test",
            salutation: .mr,
            academicTitle: "",
            firstName: "Test",
            lastName: "User",
            streetAndNumber: "123 Test St",
            postalCode: "12345",
            city: "Test City",
            state: "TS",
            country: "Test Country",
            dateOfBirth: Date(),
            placeOfBirth: "Test City",
            countryOfBirth: "Test Country",
            role: .investor,
            csrRole: nil,
            employmentStatus: .employed,
            income: 50_000,
            incomeRange: .middle,
            riskTolerance: 5,
            address: "123 Test St",
            nationality: "DE",
            additionalNationalities: "",
            taxNumber: "",
            additionalTaxResidences: "",
            isNotUSCitizen: true,
            isEmailVerified: true,
            isKYCCompleted: true,
            acceptedTerms: true,
            acceptedPrivacyPolicy: true,
            acceptedMarketingConsent: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
