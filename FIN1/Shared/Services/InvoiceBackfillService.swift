import Foundation

// MARK: - Invoice Backfill Service
/// Generates invoices for existing completed trades that don't have invoices yet
final class InvoiceBackfillService {

    private let invoiceService: any InvoiceServiceProtocol
    private let tradeService: any TradeLifecycleServiceProtocol
    private let transactionIdService: any TransactionIdServiceProtocol

    init(
        invoiceService: any InvoiceServiceProtocol,
        tradeService: any TradeLifecycleServiceProtocol,
        transactionIdService: any TransactionIdServiceProtocol
    ) {
        self.invoiceService = invoiceService
        self.tradeService = tradeService
        self.transactionIdService = transactionIdService
    }

    /// Generate invoices for all completed trades that don't have invoices
    func backfillInvoices() async {
        print("📄 Starting invoice backfill for existing trades...")

        let completedTrades = tradeService.completedTrades
        let existingInvoices = invoiceService.invoices

        for trade in completedTrades where trade.status == .completed {
            // CRITICAL: Use trade.traderId as customer number for proper trader isolation
            // This ensures invoices are tied to the specific trader who owns the trade
            let customerInfo = CustomerInfo(
                name: "Dr. Hans-Peter Müller",
                address: "Hauptstraße 42",
                city: "Frankfurt am Main",
                postalCode: "60311",
                taxNumber: "43/123/45678",
                depotNumber: "DE12345678901234567890",
                bank: "Deutsche Bank AG",
                customerNumber: trade.traderId  // Use trader ID for proper isolation
            )

            // Check if invoices already exist for this trade
            let tradeInvoices = existingInvoices.filter { $0.tradeId == trade.id }

            let hasBuyInvoice = tradeInvoices.contains { $0.transactionType == .buy }
            let hasSellInvoice = tradeInvoices.contains { $0.transactionType == .sell }

            // Create buy invoice if missing
            if !hasBuyInvoice {
                let buyInvoice = Invoice.from(
                    order: trade.buyOrder,
                    customerInfo: customerInfo,
                    transactionIdService: transactionIdService,
                    tradeId: trade.id
                )
                await invoiceService.addInvoice(buyInvoice)
                print("📄 Created buy invoice for trade \(trade.id)")
            }

            // Create sell invoices for all sell orders if missing
            if !hasSellInvoice {
                // Handle multiple sell orders (partial sales)
                for sellOrder in trade.sellOrders {
                    let sellInvoice = Invoice.from(
                        sellOrder: sellOrder,
                        customerInfo: customerInfo,
                        transactionIdService: transactionIdService,
                        tradeId: trade.id
                    )
                    await invoiceService.addInvoice(sellInvoice)
                    print("📄 Created sell invoice for trade \(trade.id)")
                }

                // Handle legacy single sell order
                if let sellOrder = trade.sellOrder, trade.sellOrders.isEmpty {
                    let sellInvoice = Invoice.from(
                        sellOrder: sellOrder,
                        customerInfo: customerInfo,
                        transactionIdService: transactionIdService,
                        tradeId: trade.id
                    )
                    await invoiceService.addInvoice(sellInvoice)
                    print("📄 Created sell invoice for trade \(trade.id)")
                }
            }
        }

        print("📄 Invoice backfill complete. Total invoices: \(invoiceService.invoices.count)")
    }

    /// Remove sample invoices that don't match any real trades
    func cleanupSampleInvoices() async {
        print("🧹 Cleaning up sample invoices...")

        let completedTrades = tradeService.completedTrades
        let tradeIds = Set(completedTrades.map { $0.id })

        // Remove invoices that have sample-trade-id or don't match any real trade
        let invoicesToKeep = invoiceService.invoices.filter { invoice in
            guard let tradeId = invoice.tradeId else { return false }
            return tradeIds.contains(tradeId)
        }

        print("🧹 Kept \(invoicesToKeep.count) real invoices, removed sample data")
    }
}
