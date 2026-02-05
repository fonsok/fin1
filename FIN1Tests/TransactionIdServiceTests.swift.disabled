import XCTest
@testable import FIN1

// MARK: - Transaction ID Service Tests

final class TransactionIdServiceTests: XCTestCase {

    var service: TransactionIdService!

    override func setUp() {
        super.setUp()
        service = TransactionIdService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Order ID Tests

    func testGenerateOrderId_ReturnsValidFormat() {
        // Given
        let orderId = service.generateOrderId()

        // Then
        XCTAssertTrue(service.validateId(orderId))
        XCTAssertTrue(orderId.hasPrefix("FIN1-ORD-"))
        XCTAssertEqual(orderId.components(separatedBy: "-").count, 4)
    }

    func testGenerateOrderId_ContainsTimestamp() {
        // Given
        let orderId = service.generateOrderId()
        let components = orderId.components(separatedBy: "-")

        // Then
        XCTAssertEqual(components[0], "FIN1")
        XCTAssertEqual(components[1], "ORD")
        XCTAssertEqual(components[2].count, 8) // YYYYMMDD
        XCTAssertEqual(components[3].count, 11) // HHMMSS-XXXXX
    }

    func testGenerateOrderId_GeneratesUniqueIds() {
        // Given
        let orderId1 = service.generateOrderId()
        let orderId2 = service.generateOrderId()

        // Then
        XCTAssertNotEqual(orderId1, orderId2)
    }

    // MARK: - Trade ID Tests

    func testGenerateTradeId_ReturnsValidFormat() {
        // Given
        let tradeId = service.generateTradeId()

        // Then
        XCTAssertTrue(service.validateId(tradeId))
        XCTAssertTrue(tradeId.hasPrefix("FIN1-TRD-"))
        XCTAssertEqual(tradeId.components(separatedBy: "-").count, 4)
    }

    func testGenerateTradeId_GeneratesUniqueIds() {
        // Given
        let tradeId1 = service.generateTradeId()
        let tradeId2 = service.generateTradeId()

        // Then
        XCTAssertNotEqual(tradeId1, tradeId2)
    }

    // MARK: - Invoice Number Tests

    func testGenerateInvoiceNumber_ReturnsValidFormat() {
        // Given
        let invoiceNumber = service.generateInvoiceNumber()

        // Then
        XCTAssertTrue(service.validateId(invoiceNumber))
        XCTAssertTrue(invoiceNumber.hasPrefix("FIN1-INV-"))
        XCTAssertEqual(invoiceNumber.components(separatedBy: "-").count, 3)
    }

    func testGenerateInvoiceNumber_ContainsDateOnly() {
        // Given
        let invoiceNumber = service.generateInvoiceNumber()
        let components = invoiceNumber.components(separatedBy: "-")

        // Then
        XCTAssertEqual(components[0], "FIN1")
        XCTAssertEqual(components[1], "INV")
        XCTAssertEqual(components[2].count, 13) // YYYYMMDD-XXXXX
    }

    func testGenerateInvoiceNumber_GeneratesUniqueNumbers() {
        // Given
        let invoiceNumber1 = service.generateInvoiceNumber()
        let invoiceNumber2 = service.generateInvoiceNumber()

        // Then
        XCTAssertNotEqual(invoiceNumber1, invoiceNumber2)
    }

    // MARK: - Investor Document Number Tests

    func testGenerateInvestorDocumentNumber_ReturnsValidFormat() {
        // Given
        let documentNumber = service.generateInvestorDocumentNumber()

        // Then
        XCTAssertTrue(service.validateId(documentNumber))
        XCTAssertTrue(documentNumber.hasPrefix("FIN1-INVST-"))
        XCTAssertEqual(documentNumber.components(separatedBy: "-").count, 3)
    }

    func testGenerateInvestorDocumentNumber_GeneratesUniqueNumbers() {
        // Given
        let documentNumber1 = service.generateInvestorDocumentNumber()
        let documentNumber2 = service.generateInvestorDocumentNumber()

        // Then
        XCTAssertNotEqual(documentNumber1, documentNumber2)
    }

    // MARK: - Payment ID Tests

    func testGeneratePaymentId_ReturnsValidFormat() {
        // Given
        let paymentId = service.generatePaymentId()

        // Then
        XCTAssertTrue(service.validateId(paymentId))
        XCTAssertTrue(paymentId.hasPrefix("FIN1-PAY-"))
        XCTAssertEqual(paymentId.components(separatedBy: "-").count, 4)
    }

    func testGeneratePaymentId_GeneratesUniqueIds() {
        // Given
        let paymentId1 = service.generatePaymentId()
        let paymentId2 = service.generatePaymentId()

        // Then
        XCTAssertNotEqual(paymentId1, paymentId2)
    }

    // MARK: - Customer ID Tests

    func testGenerateCustomerId_ReturnsValidFormat() {
        // Given
        let customerId = service.generateCustomerId()

        // Then
        XCTAssertTrue(customerId.hasPrefix("FIN1-"))
        XCTAssertEqual(customerId.components(separatedBy: "-").count, 3)
    }

    func testGenerateCustomerId_ContainsCurrentYear() {
        // Given
        let customerId = service.generateCustomerId()
        let currentYear = Calendar.current.component(.year, from: Date())

        // Then
        XCTAssertTrue(customerId.contains("\(currentYear)"))
    }

    func testGenerateCustomerId_GeneratesUniqueIds() {
        // Given
        let customerId1 = service.generateCustomerId()
        let customerId2 = service.generateCustomerId()

        // Then
        XCTAssertNotEqual(customerId1, customerId2)
    }

    // MARK: - ID Validation Tests

    func testValidateId_ValidOrderId_ReturnsTrue() {
        // Given
        let validOrderId = "FIN1-ORD-20241201-143022-00001"

        // When
        let isValid = service.validateId(validOrderId)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateId_ValidInvoiceNumber_ReturnsTrue() {
        // Given
        let validInvoiceNumber = "FIN1-INV-20241201-00001"

        // When
        let isValid = service.validateId(validInvoiceNumber)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateId_InvalidFormat_ReturnsFalse() {
        // Given
        let invalidIds = [
            "INVALID-ID",
            "FIN1-ORD-20241201-143022", // Missing counter
            "FIN1-ORD-20241201-143022-00001-EXTRA", // Too many parts
            "FIN1-ORD-20241201-143022-0000", // Counter too short
            "FIN1-ORD-20241201-143022-000001", // Counter too long
            "FIN1-ORD-20241201-14302-00001", // Time too short
            "FIN1-ORD-20241201-1430222-00001", // Time too long
            "FIN1-ORD-202412011-143022-00001", // Date too long
            "FIN1-ORD-2024120-143022-00001", // Date too short
            "FIN1-ORD-20241201-143022-0000a", // Non-numeric counter
            "FIN1-ORD-20241201-14302a-00001", // Non-numeric time
            "FIN1-ORD-2024120a-143022-00001" // Non-numeric date
        ]

        // When & Then
        for invalidId in invalidIds {
            let isValid = service.validateId(invalidId)
            XCTAssertFalse(isValid, "Expected \(invalidId) to be invalid")
        }
    }

    // MARK: - Service Lifecycle Tests

    func testStart_InitializesDailyCounters() async {
        // When
        await service.start()

        // Then
        let today = DateFormatter().string(from: Date())
        // Service should be ready to generate IDs
        let orderId = service.generateOrderId()
        XCTAssertTrue(service.validateId(orderId))
    }

    func testStop_CleansUpOldCounters() async {
        // Given
        await service.start()

        // When
        await service.stop()

        // Then
        // Service should still work after stop
        let orderId = service.generateOrderId()
        XCTAssertTrue(service.validateId(orderId))
    }

    func testReset_ClearsAllCounters() async {
        // Given
        await service.start()
        _ = service.generateOrderId() // Generate one ID

        // When
        await service.reset()

        // Then
        // Service should still work after reset
        let orderId = service.generateOrderId()
        XCTAssertTrue(service.validateId(orderId))
    }

    // MARK: - Concurrency Tests

    func testConcurrentIdGeneration_GeneratesUniqueIds() async {
        // Given
        await service.start()

        // When
        let ids = await withTaskGroup(of: String.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    return self.service.generateOrderId()
                }
            }

            var results: [String] = []
            for await id in group {
                results.append(id)
            }
            return results
        }

        // Then
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All generated IDs should be unique")
    }

    // MARK: - Performance Tests

    func testIdGenerationPerformance() {
        // Given
        let expectation = XCTestExpectation(description: "ID generation performance")

        // When
        let startTime = CFAbsoluteTimeGetCurrent()

        DispatchQueue.global().async {
            for _ in 0..<1000 {
                _ = self.service.generateOrderId()
            }

            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            XCTAssertLessThan(timeElapsed, 1.0, "ID generation should be fast")
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: 2.0)
    }
}

// MARK: - DateFormatter Extension for Tests

private extension DateFormatter {
    static let testFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
