@testable import FIN1
import XCTest

final class InvoiceLocalSynthesisGateTests: XCTestCase {

    func testPermitFlagDefaultsFalse() {
        XCTAssertFalse(InvoiceLocalSynthesisGate.isPermitted)
    }

    func testInvoiceFromSucceedsInsidePermit() {
        let order = Self.makeOrderBuy()
        let customer = Self.makeCustomerInfo()

        let invoice = InvoiceLocalSynthesisGate.withPermitted {
            Invoice.from(
                order: order,
                customerInfo: customer,
                transactionIdService: TransactionIdService()
            )
        }

        XCTAssertEqual(invoice.transactionType, .buy)
        XCTAssertEqual(invoice.items.first?.quantity, 100)
        XCTAssertFalse(InvoiceLocalSynthesisGate.isPermitted)
    }

    private static func makeOrderBuy() -> OrderBuy {
        let now = Date()
        return OrderBuy(
            id: "buy-1",
            traderId: "trader-1",
            symbol: "TEST",
            description: "Test",
            quantity: 100,
            price: 1.0,
            totalAmount: 100,
            status: .executed,
            createdAt: now,
            executedAt: now,
            confirmedAt: now,
            updatedAt: now,
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "TEST",
            category: nil,
            strike: nil,
            orderInstruction: nil,
            limitPrice: nil
        )
    }

    private static func makeCustomerInfo() -> CustomerInfo {
        CustomerInfo(
            name: "Test",
            address: "Street",
            city: "City",
            postalCode: "12345",
            taxNumber: "1",
            depotNumber: "1",
            bank: "Bank",
            customerNumber: "trader-1"
        )
    }
}
