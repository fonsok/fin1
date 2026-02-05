import XCTest
@testable import FIN1

// MARK: - Invoice Model Tests
final class InvoiceModelTests: XCTestCase {

    // MARK: - Invoice Creation Tests

    func testInvoiceCreation() {
        // Given
        let customerInfo = createSampleCustomerInfo()
        let items = createSampleInvoiceItems()

        // When
        let invoice = Invoice(
            invoiceNumber: "INV-20241201-1234",
            type: .securitiesSettlement,
            customerInfo: customerInfo,
            items: items,
            tradeId: "trade-123",
            orderId: "order-456",
            taxNote: "Test tax note",
            legalNote: "Test legal note"
        )

        // Then
        XCTAssertEqual(invoice.invoiceNumber, "INV-20241201-1234")
        XCTAssertEqual(invoice.type, .securitiesSettlement)
        XCTAssertEqual(invoice.customerInfo.name, customerInfo.name)
        XCTAssertEqual(invoice.items.count, 4)
        XCTAssertEqual(invoice.tradeId, "trade-123")
        XCTAssertEqual(invoice.orderId, "order-456")
        XCTAssertEqual(invoice.taxNote, "Test tax note")
        XCTAssertEqual(invoice.legalNote, "Test legal note")
    }

    func testInvoiceFromTrade() {
        // Given
        let trade = createSampleTrade()
        let customerInfo = createSampleCustomerInfo()

        // When
        let invoice = Invoice.from(order: trade.buyOrder, customerInfo: customerInfo, transactionIdService: TransactionIdService())

        // Then
        XCTAssertEqual(invoice.type, .securitiesSettlement)
        XCTAssertEqual(invoice.customerInfo.name, customerInfo.name)
        XCTAssertEqual(invoice.tradeId, trade.id)
        XCTAssertFalse(invoice.items.isEmpty)
        XCTAssertTrue(invoice.totalAmount > 0)
        XCTAssertNotNil(invoice.taxNote)
        XCTAssertNotNil(invoice.legalNote)
    }

    func testSampleInvoice() {
        // When
        let invoice = Invoice.sampleInvoice()

        // Then
        XCTAssertEqual(invoice.type, .securitiesSettlement)
        XCTAssertEqual(invoice.customerInfo.name, "Max Mustermann")
        XCTAssertEqual(invoice.items.count, 4)
        XCTAssertEqual(invoice.totalAmount, 1210.50, accuracy: 0.01)
    }

    // MARK: - Invoice Item Tests

    func testInvoiceItemCreation() {
        // Given
        let description = "Test Item"
        let quantity = 100.0
        let unitPrice = 10.50
        let itemType = InvoiceItemType.securities

        // When
        let item = InvoiceItem(
            description: description,
            quantity: quantity,
            unitPrice: unitPrice,
            itemType: itemType
        )

        // Then
        XCTAssertEqual(item.description, description)
        XCTAssertEqual(item.quantity, quantity)
        XCTAssertEqual(item.unitPrice, unitPrice)
        XCTAssertEqual(item.itemType, itemType)
        XCTAssertEqual(item.totalAmount, quantity * unitPrice)
    }

    func testInvoiceItemTypes() {
        // Test all item types have proper display names
        XCTAssertEqual(InvoiceItemType.securities.displayName, "Wertpapiere")
        XCTAssertEqual(InvoiceItemType.orderFee.displayName, "Ordergebühr")
        XCTAssertEqual(InvoiceItemType.exchangeFee.displayName, "Börsenplatzgebühr")
        XCTAssertEqual(InvoiceItemType.foreignCosts.displayName, "Fremdkostenpauschale")
        XCTAssertEqual(InvoiceItemType.tax.displayName, "Steuer")
        XCTAssertEqual(InvoiceItemType.other.displayName, "Sonstiges")
    }

    // MARK: - Customer Info Tests

    func testCustomerInfoCreation() {
        // Given
        let name = "Max Mustermann"
        let address = "Musterstraße 1"
        let city = "Musterstadt"
        let postalCode = "12345"
        let taxNumber = "12/345/67890"
        let depotNumber = "123456789"
        let bank = "Musterbank AG"
        let customerNumber = "987654321"

        // When
        let customerInfo = CustomerInfo(
            name: name,
            address: address,
            city: city,
            postalCode: postalCode,
            taxNumber: taxNumber,
            depotNumber: depotNumber,
            bank: bank,
            customerNumber: customerNumber
        )

        // Then
        XCTAssertEqual(customerInfo.name, name)
        XCTAssertEqual(customerInfo.address, address)
        XCTAssertEqual(customerInfo.city, city)
        XCTAssertEqual(customerInfo.postalCode, postalCode)
        XCTAssertEqual(customerInfo.taxNumber, taxNumber)
        XCTAssertEqual(customerInfo.depotNumber, depotNumber)
        XCTAssertEqual(customerInfo.bank, bank)
        XCTAssertEqual(customerInfo.customerNumber, customerNumber)
        XCTAssertEqual(customerInfo.fullAddress, "\(address), \(postalCode) \(city)")
    }

    // MARK: - Invoice Type Tests

    func testInvoiceTypes() {
        // Test all invoice types have proper display names and icons
        XCTAssertEqual(InvoiceType.securitiesSettlement.displayName, "Wertpapierabrechnung")
        XCTAssertEqual(InvoiceType.tradingFee.displayName, "Handelsgebühren")
        XCTAssertEqual(InvoiceType.accountStatement.displayName, "Kontoauszug")

        XCTAssertEqual(InvoiceType.securitiesSettlement.icon, "doc.text")
        XCTAssertEqual(InvoiceType.tradingFee.icon, "banknote")
        XCTAssertEqual(InvoiceType.accountStatement.icon, "list.bullet.rectangle")
    }

    // MARK: - Invoice Status Tests

    func testInvoiceStatuses() {
        // Test all invoice statuses have proper display names and colors
        XCTAssertEqual(InvoiceStatus.draft.displayName, "Entwurf")
        XCTAssertEqual(InvoiceStatus.generated.displayName, "Generiert")
        XCTAssertEqual(InvoiceStatus.sent.displayName, "Versendet")
        XCTAssertEqual(InvoiceStatus.paid.displayName, "Bezahlt")
        XCTAssertEqual(InvoiceStatus.cancelled.displayName, "Storniert")
    }

    // MARK: - Computed Properties Tests

    func testInvoiceComputedProperties() {
        // Given
        let invoice = Invoice.sampleInvoice()

        // When & Then
        XCTAssertTrue(invoice.formattedInvoiceNumber.hasPrefix("FIN1-INV-"))
        XCTAssertTrue(invoice.formattedTotalAmount.contains("€"))
        XCTAssertTrue(invoice.formattedSubtotal.contains("€"))
        XCTAssertTrue(invoice.formattedTaxAmount.contains("€"))
        XCTAssertFalse(invoice.isPaid) // Sample invoice is not paid by default
    }

    func testInvoiceOverdueStatus() {
        // Given
        guard let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()),
              let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else {
            XCTFail("Failed to create test dates")
            return
        }

        let overdueInvoice = Invoice(
            invoiceNumber: "INV-123",
            type: .securitiesSettlement,
            customerInfo: createSampleCustomerInfo(),
            items: [],
            dueDate: pastDate
        )

        let currentInvoice = Invoice(
            invoiceNumber: "INV-456",
            type: .securitiesSettlement,
            customerInfo: createSampleCustomerInfo(),
            items: [],
            dueDate: futureDate
        )

        // When & Then
        XCTAssertTrue(overdueInvoice.isOverdue)
        XCTAssertFalse(currentInvoice.isOverdue)
    }

    func testInvoiceDaysUntilDue() {
        // Given
        guard let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date()) else {
            XCTFail("Failed to create future date")
            return
        }
        let invoice = Invoice(
            invoiceNumber: "INV-123",
            type: .securitiesSettlement,
            customerInfo: createSampleCustomerInfo(),
            items: [],
            dueDate: futureDate
        )

        // When
        let daysUntilDue = invoice.daysUntilDue

        // Then
        XCTAssertNotNil(daysUntilDue)
        XCTAssertEqual(daysUntilDue, 5)
    }

    // MARK: - Helper Methods

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

    private func createSampleInvoiceItems() -> [InvoiceItem] {
        return [
            InvoiceItem(
                description: "Optionsschein PUT (VT1234)",
                quantity: 1000,
                unitPrice: 1.20,
                itemType: .securities
            ),
            InvoiceItem(
                description: "Ordergebühr",
                quantity: 1,
                unitPrice: 7.00,
                itemType: .orderFee
            ),
            InvoiceItem(
                description: "Börsenplatzgebühr",
                quantity: 1,
                unitPrice: 2.00,
                itemType: .exchangeFee
            ),
            InvoiceItem(
                description: "Fremdkostenpauschale",
                quantity: 1,
                unitPrice: 1.50,
                itemType: .foreignCosts
            )
        ]
    }

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
}
