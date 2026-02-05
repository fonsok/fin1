import XCTest
@testable import FIN1

// MARK: - Invoice Service Tests
final class InvoiceServiceTests: XCTestCase {

    var invoiceService: InvoiceService!

    override func setUp() {
        super.setUp()
        invoiceService = InvoiceService()
    }

    override func tearDown() {
        invoiceService = nil
        super.tearDown()
    }

    // MARK: - Invoice Creation Tests

    func testCreateInvoiceFromTrade() async throws {
        // Given
        let trade = createSampleTrade()
        let customerInfo = createSampleCustomerInfo()

        // When
        let invoice = try await invoiceService.createInvoice(from: trade.buyOrder, customerInfo: customerInfo)

        // Then
        XCTAssertEqual(invoice.type, .securitiesSettlement)
        XCTAssertEqual(invoice.customerInfo.name, customerInfo.name)
        XCTAssertEqual(invoice.tradeId, trade.id)
        XCTAssertFalse(invoice.items.isEmpty)
        XCTAssertTrue(invoice.totalAmount > 0)
    }

    func testInvoiceValidation() {
        // Given
        let validInvoice = Invoice.sampleInvoice()
        let invalidInvoice = createInvalidInvoice()

        // When & Then
        XCTAssertTrue(invoiceService.validateInvoice(validInvoice))
        XCTAssertFalse(invoiceService.validateInvoice(invalidInvoice))
    }

    func testCustomerInfoValidation() {
        // Given
        let validCustomerInfo = createSampleCustomerInfo()
        let invalidCustomerInfo = createInvalidCustomerInfo()

        // When & Then
        XCTAssertTrue(invoiceService.validateCustomerInfo(validCustomerInfo))
        XCTAssertFalse(invoiceService.validateCustomerInfo(invalidCustomerInfo))
    }

    // MARK: - PDF Generation Tests

    func testGeneratePDF() async throws {
        // Given
        let invoice = Invoice.sampleInvoice()

        // When
        let pdfData = try await invoiceService.generatePDF(for: invoice)

        // Then
        XCTAssertFalse(pdfData.isEmpty)
        XCTAssertGreaterThan(pdfData.count, 1000) // PDF should be substantial
    }

    func testGeneratePDFPreview() async throws {
        // Given
        let invoice = Invoice.sampleInvoice()

        // When
        let preview = try await invoiceService.generatePDFPreview(for: invoice)

        // Then
        XCTAssertNotNil(preview)
        XCTAssertGreaterThan(preview.size.width, 0)
        XCTAssertGreaterThan(preview.size.height, 0)
    }

    // MARK: - Invoice Queries Tests

    func testGetInvoicesForTrade() {
        // Given
        let tradeId = "test-trade-123"
        let invoice = createInvoiceWithTradeId(tradeId)
        invoiceService.invoices = [invoice]

        // When
        let result = invoiceService.getInvoicesForTrade(tradeId)

        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.tradeId, tradeId)
    }

    func testGetInvoicesByType() {
        // Given
        let invoice1 = createInvoiceWithType(.securitiesSettlement)
        let invoice2 = createInvoiceWithType(.tradingFee)
        invoiceService.invoices = [invoice1, invoice2]

        // When
        let securitiesInvoices = invoiceService.getInvoicesByType(.securitiesSettlement, for: "test-user")
        let tradingFeeInvoices = invoiceService.getInvoicesByType(.tradingFee, for: "test-user")

        // Then
        XCTAssertEqual(securitiesInvoices.count, 1)
        XCTAssertEqual(tradingFeeInvoices.count, 1)
        XCTAssertEqual(securitiesInvoices.first?.type, .securitiesSettlement)
        XCTAssertEqual(tradingFeeInvoices.first?.type, .tradingFee)
    }

    // MARK: - Invoice Status Update Tests

    func testUpdateInvoiceStatus() async throws {
        // Given
        let invoice = Invoice.sampleInvoice()
        invoiceService.invoices = [invoice]

        // When
        try await invoiceService.updateInvoiceStatus(invoice, status: .sent)

        // Then
        let updatedInvoice = invoiceService.getInvoice(by: invoice.id)
        XCTAssertEqual(updatedInvoice?.status, .sent)
    }

    func testDeleteInvoice() async throws {
        // Given
        let invoice = Invoice.sampleInvoice()
        invoiceService.invoices = [invoice]

        // When
        try await invoiceService.deleteInvoice(invoice)

        // Then
        XCTAssertTrue(invoiceService.invoices.isEmpty)
    }

    // MARK: - Helper Methods

    private func createSampleTrade() -> Trade {
        let buyOrder = OrderBuy(
            id: "test-order-123",
            traderId: "test-trader",
            symbol: "DAX PUT",
            description: "DAX Optionsschein PUT",
            quantity: 1000,
            price: 1.20,
            totalAmount: 1200.00,
            status: .completed,
            createdAt: Date(),
            executedAt: Date(),
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: "PUT",
            underlyingAsset: "DAX",
            wkn: "VT1234",
            category: "Optionsschein",
            strike: 100.0,
            orderInstruction: "market",
            limitPrice: nil
        )

        return Trade.from(buyOrder: buyOrder, tradeNumber: 1)
    }

    private func createSampleCustomerInfo() -> CustomerInfo {
        return CustomerInfo(
            name: "Max Mustermann",
            address: "Musterstraße 1",
            city: "Musterstadt",
            postalCode: "12345",
            taxNumber: "12/345/67890",
            depotNumber: "123456789",
            bank: "Musterbank AG",
            customerNumber: "987654321"
        )
    }

    private func createInvalidCustomerInfo() -> CustomerInfo {
        return CustomerInfo(
            name: "",
            address: "",
            city: "",
            postalCode: "invalid",
            taxNumber: "",
            depotNumber: "",
            bank: "",
            customerNumber: ""
        )
    }

    private func createInvalidInvoice() -> Invoice {
        return Invoice(
            invoiceNumber: "",
            type: .securitiesSettlement,
            customerInfo: createInvalidCustomerInfo(),
            items: [],
            tradeId: nil,
            orderId: nil,
            taxNote: nil,
            legalNote: nil
        )
    }

    private func createInvoiceWithTradeId(_ tradeId: String) -> Invoice {
        var invoice = Invoice.sampleInvoice()
        return Invoice(
            invoiceNumber: invoice.invoiceNumber,
            type: invoice.type,
            customerInfo: invoice.customerInfo,
            items: invoice.items,
            tradeId: tradeId,
            orderId: invoice.orderId,
            taxNote: invoice.taxNote,
            legalNote: invoice.legalNote,
            dueDate: invoice.dueDate
        )
    }

    private func createInvoiceWithType(_ type: InvoiceType) -> Invoice {
        var invoice = Invoice.sampleInvoice()
        return Invoice(
            invoiceNumber: invoice.invoiceNumber,
            type: type,
            customerInfo: invoice.customerInfo,
            items: invoice.items,
            tradeId: invoice.tradeId,
            orderId: invoice.orderId,
            taxNote: invoice.taxNote,
            legalNote: invoice.legalNote,
            dueDate: invoice.dueDate
        )
    }
}
