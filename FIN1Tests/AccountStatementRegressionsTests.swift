import XCTest
@testable import FIN1

// MARK: - Account Statement Regression Tests

final class AccountStatementRegressionsTests: XCTestCase {

    // MARK: - Display helper coverage

    func testProfitDistributionDisplaysInvestmentDetails() {
        let entry = AccountStatementEntry(
            title: "Profit Distribution",
            subtitle: nil,
            occurredAt: Date(),
            amount: 150.0,
            direction: .credit,
            category: .profitDistribution,
            reference: nil,
            metadata: ["investmentId": "INV-123"],
            balanceAfter: 10_000
        )

        XCTAssertEqual(
            entry.descriptionTitle,
            "Profit distribution from Investment INV-123"
        )
        XCTAssertEqual(
            entry.descriptionSubtitle,
            "Cash inflow from realized profits on Investment INV-123."
        )
    }

    func testRemainingBalanceDisplaysInvestmentDetails() {
        let entry = AccountStatementEntry(
            title: "Remaining balance distribution",
            subtitle: nil,
            occurredAt: Date(),
            amount: 250.0,
            direction: .credit,
            category: .remainingBalance,
            reference: nil,
            metadata: ["investmentId": "INV-XYZ"],
            balanceAfter: 9_500
        )

        XCTAssertEqual(
            entry.descriptionTitle,
            "Remaining balance distribution from Investment INV-XYZ"
        )
        XCTAssertEqual(
            entry.descriptionSubtitle,
            "Cash returned from Investment INV-XYZ after cancellation or deletion."
        )
    }

    // MARK: - Investor ledger regression coverage

    func testInvestorCashBalanceRecordsInvestmentMetadata() async {
        let service = InvestorCashBalanceService(configurationService: MockConfigurationService())
        await service.processRemainingBalanceDistribution(
            investorId: "investor-1",
            amount: 125.0,
            investmentId: "INV-888"
        )

        let entries = service.getTransactions(for: "investor-1")
        let remainingDistribution = entries.first { $0.category == .remainingBalance }

        XCTAssertEqual(remainingDistribution?.metadata["investmentId"], "INV-888")
        XCTAssertEqual(
            remainingDistribution?.descriptionTitle,
            "Remaining balance distribution from Investment INV-888"
        )
    }

    // MARK: - Trader statement regression coverage

    func testTraderAccountStatementBuilderEnrichesMetadata() async {
        let mockInvoiceService = MockInvoiceService()
        let customer = CustomerInfo(
            name: "Trader AG",
            address: "Street 1",
            city: "Berlin",
            postalCode: "10115",
            taxNumber: "TAX123",
            depotNumber: "DEPOT1",
            bank: "Bank",
            customerNumber: "CUST1"
        )
        let securitiesItem = InvoiceItem(
            description: "MS4YXS1 - PUT - Euro Stoxx 50 - 11.270 Pkt. - Morgan Stanley",
            quantity: 1_200,
            unitPrice: 1.72,
            itemType: .securities
        )
        let invoice = Invoice(
            invoiceNumber: "INV-001",
            type: .securities,
            status: .paid,
            customerInfo: customer,
            items: [securitiesItem],
            tradeId: "trade-1",
            tradeNumber: 7,
            transactionType: .sell
        )
        mockInvoiceService.stubbedInvoices = [invoice]

        let traderUser = await TestHelpers.createTraderUser(mockUserService: MockUserService())
        let snapshot = TraderAccountStatementBuilder.buildSnapshot(
            for: traderUser,
            invoiceService: mockInvoiceService,
            configurationService: MockConfigurationService()
        )

        XCTAssertEqual(snapshot.entries.count, 1)
        let entry = snapshot.entries[0]
        XCTAssertEqual(entry.metadata["wknOrIsin"], "MS4YXS1")
        XCTAssertEqual(entry.metadata["securitiesDirection"], "PUT")
        XCTAssertEqual(entry.metadata["underlyingAsset"], "Euro Stoxx 50")
        XCTAssertEqual(
            entry.descriptionTitle,
            "PUT MS4YXS1 · Euro Stoxx 50"
        )
        XCTAssertTrue(entry.descriptionSubtitle?.contains("MS4YXS1") ?? false)
    }
}

// MARK: - Test Doubles

private final class MockConfigurationService: ConfigurationServiceProtocol {
    var minimumCashReserve: Double = 12.0
    var initialAccountBalance: Double = 50_000.0
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy = .immediateDistribution
    var poolBalanceDistributionThreshold: Double = 5.0
    var isAdminMode: Bool = false

    func updateMinimumCashReserve(_ value: Double) async throws { minimumCashReserve = value }
    func updateMinimumCashReserve(_ value: Double, for userId: String) async throws { minimumCashReserve = value }
    func getMinimumCashReserve(for userId: String) -> Double { minimumCashReserve }
    func updateInitialAccountBalance(_ value: Double) async throws { initialAccountBalance = value }
    func updatePoolBalanceDistributionStrategy(_ strategy: PoolBalanceDistributionStrategy) async throws {
        poolBalanceDistributionStrategy = strategy
    }
    func updatePoolBalanceDistributionThreshold(_ threshold: Double) async throws {
        poolBalanceDistributionThreshold = threshold
    }
    func resetToDefaults() async throws {}
    func validateMinimumCashReserve(_ value: Double) -> Bool { value >= 0 }
    func validateInitialAccountBalance(_ value: Double) -> Bool { value >= 0 }
    func validatePoolBalanceDistributionThreshold(_ value: Double) -> Bool { value >= 0 }
}

private final class MockInvoiceService: InvoiceServiceProtocol {
    @Published var invoices: [Invoice] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    var stubbedInvoices: [Invoice] = []

    func start() {}
    func stop() {}
    func reset() {}

    func loadInvoices(for userId: String) async throws {}
    func createInvoice(from order: OrderBuy, customerInfo: CustomerInfo) async throws -> Invoice { fatalError() }
    func createInvoice(from sellOrder: OrderSell, customerInfo: CustomerInfo) async throws -> Invoice { fatalError() }
    func addInvoice(_ invoice: Invoice) async {}
    func updateInvoiceStatus(_ invoice: Invoice, status: InvoiceStatus) async throws {}
    func deleteInvoice(_ invoice: Invoice) async throws {}
    func generateInvoicesForCompletedTrades(_ trades: [Trade]) async {}
    func generatePDF(for invoice: Invoice) async throws -> Data { Data() }
    func generatePDFPreview(for invoice: Invoice) async throws -> UIImage { UIImage() }
    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL { URL(fileURLWithPath: "/tmp/\(fileName)") }

    func getInvoices(for userId: String) -> [Invoice] { stubbedInvoices }
    func getInvoicesByType(_ type: InvoiceType, for userId: String) -> [Invoice] { stubbedInvoices }
    func getInvoice(by id: String) -> Invoice? { stubbedInvoices.first { $0.id == id } }
    func getInvoicesForTrade(_ tradeId: String) -> [Invoice] { stubbedInvoices.filter { $0.tradeId == tradeId } }
    func validateInvoice(_ invoice: Invoice) -> Bool { true }
    func validateCustomerInfo(_ customerInfo: CustomerInfo) -> Bool { true }
}
