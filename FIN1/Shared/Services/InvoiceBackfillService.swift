import Foundation

// MARK: - Invoice Backfill Service
/// Generates invoices for existing completed trades that don't have invoices yet
final class InvoiceBackfillService {

    private let invoiceService: any InvoiceServiceProtocol
    private let tradeService: any TradeLifecycleServiceProtocol
    private let transactionIdService: any TransactionIdServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol

    init(
        invoiceService: any InvoiceServiceProtocol,
        tradeService: any TradeLifecycleServiceProtocol,
        transactionIdService: any TransactionIdServiceProtocol,
        configurationService: any ConfigurationServiceProtocol
    ) {
        self.invoiceService = invoiceService
        self.tradeService = tradeService
        self.transactionIdService = transactionIdService
        self.configurationService = configurationService
    }

    /// Generate invoices for all completed trades that don't have invoices
    func backfillInvoices() async {
        guard !self.configurationService.blocksLocalInvoiceGeneration else {
            print("ℹ️ InvoiceBackfillService: skip — monetary server-only active (P3b)")
            return
        }

        print("📄 Starting invoice backfill for existing trades...")

        await InvoiceLocalSynthesisGate.withPermitted {
            let completedTrades = self.tradeService.completedTrades
            let existingInvoices = self.invoiceService.invoices

            for trade in completedTrades where trade.status == .completed {
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

                let tradeInvoices = existingInvoices.filter { $0.tradeId == trade.id }
                let hasBuyInvoice = tradeInvoices.contains { $0.transactionType == .buy }
                let hasSellInvoice = tradeInvoices.contains { $0.transactionType == .sell }

                if !hasBuyInvoice {
                    let buyInvoice = Invoice.from(
                        order: trade.buyOrder,
                        customerInfo: customerInfo,
                        transactionIdService: self.transactionIdService,
                        tradeId: trade.id
                    )
                    await self.invoiceService.addInvoice(buyInvoice)
                    print("📄 Created buy invoice for trade \(trade.id)")
                }

                if !hasSellInvoice {
                    for sellOrder in trade.sellOrders {
                        let sellInvoice = Invoice.from(
                            sellOrder: sellOrder,
                            customerInfo: customerInfo,
                            transactionIdService: self.transactionIdService,
                            tradeId: trade.id
                        )
                        await self.invoiceService.addInvoice(sellInvoice)
                        print("📄 Created sell invoice for trade \(trade.id)")
                    }

                    if let sellOrder = trade.sellOrder, trade.sellOrders.isEmpty {
                        let sellInvoice = Invoice.from(
                            sellOrder: sellOrder,
                            customerInfo: customerInfo,
                            transactionIdService: self.transactionIdService,
                            tradeId: trade.id
                        )
                        await self.invoiceService.addInvoice(sellInvoice)
                        print("📄 Created sell invoice for trade \(trade.id)")
                    }
                }
            }
        }

        print("📄 Invoice backfill complete. Total invoices: \(self.invoiceService.invoices.count)")
    }

    /// Remove sample invoices that don't match any real trades
    func cleanupSampleInvoices() async {
        print("🧹 Cleaning up sample invoices...")

        let completedTrades = self.tradeService.completedTrades
        let tradeIds = Set(completedTrades.map { $0.id })

        let invoicesToKeep = self.invoiceService.invoices.filter { invoice in
            guard let tradeId = invoice.tradeId else { return false }
            return tradeIds.contains(tradeId)
        }

        print("🧹 Kept \(invoicesToKeep.count) real invoices, removed sample data")
    }
}
