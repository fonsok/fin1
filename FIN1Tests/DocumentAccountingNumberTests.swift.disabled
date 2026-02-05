import XCTest
@testable import FIN1

// MARK: - Document Accounting Number Tests
/// Tests for document number functionality to ensure GoB compliance

final class DocumentAccountingNumberTests: XCTestCase {

    // MARK: - accountingDocumentNumber Tests

    func testAccountingDocumentNumber_WithDocumentNumber_ReturnsDocumentNumber() {
        // Given
        let documentNumber = "FIN1-INV-20250123-00001"
        let document = Document(
            userId: "user1",
            name: "Test Invoice",
            type: .invoice,
            status: .verified,
            fileURL: "test://invoice.pdf",
            size: 1024,
            uploadedAt: Date(),
            documentNumber: documentNumber
        )

        // When
        let result = document.accountingDocumentNumber

        // Then
        XCTAssertEqual(result, documentNumber)
    }

    func testAccountingDocumentNumber_WithInvoiceData_ReturnsInvoiceNumber() {
        // Given
        let invoiceNumber = "FIN1-INV-20250123-00002"
        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: CustomerInfo.sample(),
            items: []
        )
        let document = Document(
            userId: "user1",
            name: "Test Invoice",
            type: .invoice,
            status: .verified,
            fileURL: "test://invoice.pdf",
            size: 1024,
            uploadedAt: Date(),
            invoiceData: invoice
        )

        // When
        let result = document.accountingDocumentNumber

        // Then
        XCTAssertEqual(result, invoiceNumber)
    }

    func testAccountingDocumentNumber_DocumentNumberTakesPrecedenceOverInvoiceData() {
        // Given
        let documentNumber = "FIN1-INV-20250123-00001"
        let invoiceNumber = "FIN1-INV-20250123-00002"
        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: CustomerInfo.sample(),
            items: []
        )
        let document = Document(
            userId: "user1",
            name: "Test Invoice",
            type: .invoice,
            status: .verified,
            fileURL: "test://invoice.pdf",
            size: 1024,
            uploadedAt: Date(),
            invoiceData: invoice,
            documentNumber: documentNumber
        )

        // When
        let result = document.accountingDocumentNumber

        // Then
        XCTAssertEqual(result, documentNumber, "documentNumber should take precedence over invoiceData.invoiceNumber")
    }

    func testAccountingDocumentNumber_WithoutDocumentNumberOrInvoiceData_ReturnsNil() {
        // Given
        let document = Document(
            userId: "user1",
            name: "Test Document",
            type: .other,
            status: .verified,
            fileURL: "test://document.pdf",
            size: 1024,
            uploadedAt: Date()
        )

        // When
        let result = document.accountingDocumentNumber

        // Then
        XCTAssertNil(result)
    }

    // MARK: - hasAccountingDocumentNumber Tests

    func testHasAccountingDocumentNumber_WithDocumentNumber_ReturnsTrue() {
        // Given
        let document = Document(
            userId: "user1",
            name: "Test Document",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "test://document.pdf",
            size: 1024,
            uploadedAt: Date(),
            documentNumber: "FIN1-INV-20250123-00001"
        )

        // When
        let result = document.hasAccountingDocumentNumber

        // Then
        XCTAssertTrue(result)
    }

    func testHasAccountingDocumentNumber_WithInvoiceData_ReturnsTrue() {
        // Given
        let invoice = Invoice(
            invoiceNumber: "FIN1-INV-20250123-00001",
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: CustomerInfo.sample(),
            items: []
        )
        let document = Document(
            userId: "user1",
            name: "Test Invoice",
            type: .invoice,
            status: .verified,
            fileURL: "test://invoice.pdf",
            size: 1024,
            uploadedAt: Date(),
            invoiceData: invoice
        )

        // When
        let result = document.hasAccountingDocumentNumber

        // Then
        XCTAssertTrue(result)
    }

    func testHasAccountingDocumentNumber_WithoutDocumentNumberOrInvoiceData_ReturnsFalse() {
        // Given
        let document = Document(
            userId: "user1",
            name: "Test Document",
            type: .other,
            status: .verified,
            fileURL: "test://document.pdf",
            size: 1024,
            uploadedAt: Date()
        )

        // When
        let result = document.hasAccountingDocumentNumber

        // Then
        XCTAssertFalse(result)
    }

    // MARK: - Document Creation with Document Numbers Tests

    func testDocumentCreation_InvoiceDocument_SetsDocumentNumberFromInvoice() {
        // Given
        let invoiceNumber = "FIN1-INV-20250123-00001"
        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: CustomerInfo.sample(),
            items: []
        )

        // When
        let document = Document(
            userId: "user1",
            name: "Test Invoice",
            type: .invoice,
            status: .verified,
            fileURL: "test://invoice.pdf",
            size: 1024,
            uploadedAt: Date(),
            invoiceData: invoice
        )

        // Then
        XCTAssertEqual(document.documentNumber, invoiceNumber)
        XCTAssertEqual(document.accountingDocumentNumber, invoiceNumber)
    }

    func testDocumentCreation_CollectionBill_SetsDocumentNumber() {
        // Given
        let documentNumber = "FIN1-INV-20250123-00001"

        // When
        let document = Document(
            userId: "user1",
            name: "Collection Bill",
            type: .traderCollectionBill,
            status: .verified,
            fileURL: "test://collectionbill.pdf",
            size: 1024,
            uploadedAt: Date(),
            documentNumber: documentNumber
        )

        // Then
        XCTAssertEqual(document.documentNumber, documentNumber)
        XCTAssertEqual(document.accountingDocumentNumber, documentNumber)
    }

    func testDocumentCreation_CreditNote_SetsDocumentNumberFromInvoice() {
        // Given
        let invoiceNumber = "FIN1-INV-20250123-00001"
        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            type: .creditNote,
            status: .generated,
            customerInfo: CustomerInfo.sample(),
            items: []
        )

        // When
        let document = Document(
            userId: "user1",
            name: "Credit Note",
            type: .traderCreditNote,
            status: .verified,
            fileURL: "test://creditnote.pdf",
            size: 1024,
            uploadedAt: Date(),
            invoiceData: invoice
        )

        // Then
        XCTAssertEqual(document.documentNumber, invoiceNumber)
        XCTAssertEqual(document.accountingDocumentNumber, invoiceNumber)
    }
}

// MARK: - CustomerInfo Extension for Tests

private extension CustomerInfo {
    static func sample() -> CustomerInfo {
        return CustomerInfo(
            name: "Test Customer",
            address: "Test Street 1",
            city: "Test City",
            postalCode: "12345",
            taxNumber: "123/456/789",
            depotNumber: "DE12345678901234567890",
            bank: "Test Bank",
            customerNumber: "CUST001"
        )
    }
}
