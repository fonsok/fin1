import Foundation

extension InvoiceService {

    /// Generate invoices for all existing completed trades (backfill)
    func generateInvoicesForCompletedTrades(_ trades: [Trade]) async {
        print("📄 Generating invoices for \(trades.count) completed trades...")

        for trade in trades where trade.status == .completed {
            let customerInfo = CustomerInfo(
                name: "Dr. Hans-Peter Müller",
                address: "Hauptstraße 42",
                city: "Frankfurt am Main",
                postalCode: "60311",
                taxNumber: "43/123/45678",
                depotNumber: "DE12345678901234567890",
                bank: "Deutsche Bank AG",
                customerNumber: trade.traderId
            )

            let existingInvoices = invoices.filter { $0.tradeId == trade.id }
            let hasBuyInvoice = existingInvoices.contains { $0.transactionType == .buy }

            if !hasBuyInvoice {
                let buyInvoice = Invoice.from(
                    order: trade.buyOrder,
                    customerInfo: customerInfo,
                    transactionIdService: transactionIdService,
                    tradeId: trade.id,
                    tradeNumber: trade.tradeNumber
                )
                await addInvoice(buyInvoice)
            }

            for sellOrder in trade.sellOrders {
                let invoiceExists = existingInvoices.contains { $0.orderId == sellOrder.id }
                if !invoiceExists {
                    let sellInvoice = Invoice.from(
                        sellOrder: sellOrder,
                        customerInfo: customerInfo,
                        transactionIdService: transactionIdService,
                        tradeId: trade.id,
                        tradeNumber: trade.tradeNumber
                    )
                    await addInvoice(sellInvoice)
                }
            }

            if let sellOrder = trade.sellOrder, trade.sellOrders.isEmpty {
                let invoiceExists = existingInvoices.contains { $0.orderId == sellOrder.id }
                if !invoiceExists {
                    let sellInvoice = Invoice.from(
                        sellOrder: sellOrder,
                        customerInfo: customerInfo,
                        transactionIdService: transactionIdService,
                        tradeId: trade.id,
                        tradeNumber: trade.tradeNumber
                    )
                    await addInvoice(sellInvoice)
                }
            }
        }

        print("📄 Invoice generation complete. Total invoices: \(invoices.count)")
    }
}
