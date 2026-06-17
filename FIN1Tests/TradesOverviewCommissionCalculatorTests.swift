@testable import FIN1
import XCTest

@MainActor
final class TradesOverviewCommissionCalculatorTests: XCTestCase {
    private let traderId = "trader-1"

    func testGrossCommissionFromCreditNoteInvoice() {
        let invoice = Self.makeCreditNoteInvoice(tradeId: "trade-a", net: 350, vat: 67.87)
        let gross = TradesOverviewCommissionAmounts.grossCommission(from: invoice)
        XCTAssertEqual(gross ?? 0, 417.87, accuracy: 0.01)
    }

    func testIsCommissionPendingOnlyForProfitableTradesWithoutAmount() {
        XCTAssertTrue(
            TradesOverviewCommissionAmounts.isCommissionPending(
                tradeIsCompleted: true,
                hasProfit: true,
                commission: 0
            )
        )
        XCTAssertFalse(
            TradesOverviewCommissionAmounts.isCommissionPending(
                tradeIsCompleted: true,
                hasProfit: true,
                commission: 10
            )
        )
        XCTAssertFalse(
            TradesOverviewCommissionAmounts.isCommissionPending(
                tradeIsCompleted: true,
                hasProfit: false,
                commission: 0
            )
        )
    }

    func testIsCommissionPendingWhileTradeOpenEvenWithPartialSellProfit() {
        XCTAssertTrue(
            TradesOverviewCommissionAmounts.isCommissionPending(
                tradeIsCompleted: false,
                hasProfit: true,
                commission: 0
            )
        )
    }

    func testDocumentCreditNoteWinsOverTimeline() async {
        let documents = MockDocumentService()
        documents.documents = [
            Self.makeCreditNoteDocument(
                userId: self.traderId,
                tradeId: "trade-a",
                net: 100,
                vat: 19
            )
        ]

        let settlement = MockSettlementAPIServiceForCommission()
        settlement.commissionCreditHandler = { _, _, entryType in
            XCTAssertEqual(entryType, "commission_credit")
            return Self.statementResponse(
                entries: [Self.makeBackendEntry(tradeId: "trade-a", amount: 999)]
            )
        }

        let calculator = TradesOverviewCommissionCalculator(
            invoiceService: nil,
            tradeService: nil,
            poolTradeParticipationService: nil,
            commissionCalculationService: nil,
            settlementAPIService: settlement,
            documentService: documents
        )

        await calculator.refreshCommissionCache(traderId: self.traderId)
        let amount = await calculator.calculateCommission(tradeId: "trade-a", hasProfit: true)
        XCTAssertEqual(amount, 119, accuracy: 0.01)
    }

    func testTimelineUsedWhenDocumentMissing() async {
        let settlement = MockSettlementAPIServiceForCommission()
        settlement.commissionCreditHandler = { _, _, entryType in
            XCTAssertEqual(entryType, "commission_credit")
            return Self.statementResponse(
                entries: [Self.makeBackendEntry(tradeId: "trade-b", amount: 250.5)]
            )
        }

        let calculator = TradesOverviewCommissionCalculator(
            invoiceService: nil,
            tradeService: nil,
            poolTradeParticipationService: nil,
            commissionCalculationService: nil,
            settlementAPIService: settlement,
            documentService: nil
        )

        await calculator.refreshCommissionCache(traderId: self.traderId)
        let amount = await calculator.calculateCommission(tradeId: "trade-b", hasProfit: true)
        XCTAssertEqual(amount, 250.5, accuracy: 0.01)
    }

    func testNoProfitReturnsZeroWithoutLookup() async {
        let documents = MockDocumentService()
        documents.documents = [
            Self.makeCreditNoteDocument(userId: self.traderId, tradeId: "trade-a", net: 100, vat: 19)
        ]

        let calculator = TradesOverviewCommissionCalculator(
            invoiceService: nil,
            tradeService: nil,
            poolTradeParticipationService: nil,
            commissionCalculationService: nil,
            settlementAPIService: nil,
            documentService: documents
        )

        await calculator.refreshCommissionCache(traderId: self.traderId)
        let amount = await calculator.calculateCommission(tradeId: "trade-a", hasProfit: false)
        XCTAssertEqual(amount, 0)
    }

    // MARK: - Helpers

    private static func makeCreditNoteInvoice(tradeId: String, net: Double, vat: Double) -> Invoice {
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
            invoiceNumber: "CN-TEST",
            type: .creditNote,
            customerInfo: customer,
            items: [
                InvoiceItem(description: "Provision", quantity: 1, unitPrice: net, itemType: .commission),
                InvoiceItem(description: "MwSt", quantity: 1, unitPrice: vat, itemType: .vat)
            ],
            tradeId: tradeId
        )
    }

    private static func makeCreditNoteDocument(
        userId: String,
        tradeId: String,
        net: Double,
        vat: Double
    ) -> Document {
        Document(
            userId: userId,
            name: "CreditNote.pdf",
            type: .traderCreditNote,
            status: .verified,
            fileURL: "file://credit",
            size: 100,
            uploadedAt: Date(),
            invoiceData: self.makeCreditNoteInvoice(tradeId: tradeId, net: net, vat: vat),
            tradeId: tradeId
        )
    }

    private static func makeBackendEntry(tradeId: String, amount: Double) -> BackendAccountEntry {
        let json = """
        {
          "objectId": "\(UUID().uuidString)",
          "userId": "trader-1",
          "entryType": "commission_credit",
          "amount": \(amount),
          "balanceBefore": 0,
          "balanceAfter": 0,
          "tradeId": "\(tradeId)",
          "source": "customer_display"
        }
        """
        do {
            return try JSONDecoder().decode(BackendAccountEntry.self, from: Data(json.utf8))
        } catch {
            XCTFail("fixture decode failed: \(error)")
            fatalError("fixture decode failed")
        }
    }

    private static func statementResponse(entries: [BackendAccountEntry]) -> BackendAccountStatementResponse {
        let entryPayload = entries.map { entry -> String in
            """
            {
              "objectId": "\(entry.objectId)",
              "userId": "\(entry.userId)",
              "entryType": "\(entry.entryType)",
              "amount": \(entry.amount),
              "balanceBefore": 0,
              "balanceAfter": 0,
              "tradeId": "\(entry.tradeId ?? "")",
              "source": "customer_display"
            }
            """
        }.joined(separator: ",")

        let full = """
        {
          "entries": [\(entryPayload)],
          "total": \(entries.count),
          "hasMore": false,
          "sortOrder": "asc",
          "timelineTruncated": false
        }
        """
        do {
            return try JSONDecoder().decode(BackendAccountStatementResponse.self, from: Data(full.utf8))
        } catch {
            XCTFail("fixture decode failed: \(error)")
            fatalError("fixture decode failed")
        }
    }
}

// MARK: - Mock settlement API (commission tests only)

private final class MockSettlementAPIServiceForCommission: SettlementAPIServiceProtocol, @unchecked Sendable {
    var commissionCreditHandler: ((Int, Int, String?) async throws -> BackendAccountStatementResponse)?

    func isTradeSettledByBackend(tradeId: String) async -> Bool { false }

    func fetchTradeSettlement(tradeId: String) async throws -> TradeSettlementResponse {
        throw AppError.serviceError(.serviceUnavailable)
    }

    func fetchAccountStatement(limit: Int, skip: Int, entryType: String?) async throws -> BackendAccountStatementResponse {
        if let commissionCreditHandler {
            return try await commissionCreditHandler(limit, skip, entryType)
        }
        return try JSONDecoder().decode(
            BackendAccountStatementResponse.self,
            from: Data(
                """
                {"entries":[],"total":0,"hasMore":false,"sortOrder":"asc","timelineTruncated":false}
                """.utf8
            )
        )
    }

    func fetchUserCashBalance() async throws -> BackendUserCashBalanceResponse {
        BackendUserCashBalanceResponse(userId: "test", currentBalance: 0, source: "UserCashBalance")
    }

    func fetchTradeInvoices(tradeId: String) async throws -> BackendInvoiceListResponse {
        throw AppError.serviceError(.serviceUnavailable)
    }

    func fetchUserInvoices(limit: Int, skip: Int, invoiceType: String?) async throws -> BackendInvoiceListResponse {
        throw AppError.serviceError(.serviceUnavailable)
    }

    func fetchInvestorCollectionBills(
        limit: Int,
        skip: Int,
        investmentId: String?,
        tradeId: String?
    ) async throws -> BackendCollectionBillResponse {
        throw AppError.serviceError(.serviceUnavailable)
    }
}
