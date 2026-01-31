import Foundation
@testable import FIN1

// MARK: - Invoice Test Helpers
/// Helper methods for creating test data in InvoiceViewModelTests

extension InvoiceViewModelTests {

    func createSampleTrade() -> Trade {
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
            orderInstruction: "market",
            limitPrice: nil
        )

        return Trade.from(buyOrder: buyOrder, tradeNumber: 1)
    }

    func createSampleCustomerInfo() -> CustomerInfo {
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

    func createPaidInvoice() -> Invoice {
        var invoice = Invoice.sampleInvoice()
        return Invoice(
            invoiceNumber: invoice.invoiceNumber,
            type: invoice.type,
            status: .paid,
            customerInfo: invoice.customerInfo,
            items: invoice.items,
            tradeId: invoice.tradeId,
            orderId: invoice.orderId,
            taxNote: invoice.taxNote,
            legalNote: invoice.legalNote,
            dueDate: invoice.dueDate
        )
    }

    func createOverdueInvoice() -> Invoice {
        guard let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            fatalError("Failed to create past date")
        }
        var invoice = Invoice.sampleInvoice()
        return Invoice(
            invoiceNumber: invoice.invoiceNumber,
            type: invoice.type,
            customerInfo: invoice.customerInfo,
            items: invoice.items,
            tradeId: invoice.tradeId,
            orderId: invoice.orderId,
            taxNote: invoice.taxNote,
            legalNote: invoice.legalNote,
            dueDate: pastDate
        )
    }

    func createCurrentInvoice() -> Invoice {
        guard let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else {
            fatalError("Failed to create future date")
        }
        var invoice = Invoice.sampleInvoice()
        return Invoice(
            invoiceNumber: invoice.invoiceNumber,
            type: invoice.type,
            customerInfo: invoice.customerInfo,
            items: invoice.items,
            tradeId: invoice.tradeId,
            orderId: invoice.orderId,
            taxNote: invoice.taxNote,
            legalNote: invoice.legalNote,
            dueDate: futureDate
        )
    }

    func createInvoiceWithAmount(_ amount: Double) -> Invoice {
        let item = InvoiceItem(
            description: "Test Item",
            quantity: 1,
            unitPrice: amount,
            itemType: .securities
        )

        return Invoice(
            invoiceNumber: "TEST-123",
            type: .securitiesSettlement,
            customerInfo: createSampleCustomerInfo(),
            items: [item]
        )
    }
}
