import SwiftUI

// MARK: - Document Navigation Helper
/// Centralized navigation logic for documents to eliminate DRY violations
@MainActor
struct DocumentNavigationHelper {

    // MARK: - Sheet Presentation
    /// Creates a sheet view for document presentation
    /// - Parameters:
    ///   - document: The document to display
    ///   - appServices: App services for dependency injection
    /// - Returns: A view wrapped in NavigationStack for sheet presentation
    @ViewBuilder
    static func sheetView(for document: Document, appServices: AppServices) -> some View {
        NavigationStack {
            self.documentView(for: document, appServices: appServices)
        }
    }

    // MARK: - Navigation Destination
    /// Creates a navigation destination view for document presentation
    /// - Parameters:
    ///   - document: The document to display
    ///   - appServices: App services for dependency injection
    /// - Returns: A view for navigation destination
    @ViewBuilder
    static func navigationDestination(for document: Document, appServices: AppServices) -> some View {
        self.documentView(for: document, appServices: appServices)
    }

    // MARK: - Core Document View Logic
    /// Centralized logic for determining which view to show for a document
    /// - Parameters:
    ///   - document: The document to display
    ///   - appServices: App services for dependency injection
    /// - Returns: The appropriate view for the document type
    @ViewBuilder
    private static func documentView(for document: Document, appServices: AppServices) -> some View {
        switch document.type {
        case .traderCollectionBill:
            CollectionBillDocumentView(document: document, services: appServices)
        case .investorCollectionBill:
            CollectionBillDocumentView(document: document, services: appServices)
        case .traderCreditNote:
            TraderCreditNoteDetailView(
                document: document,
                showCommissionBreakdown: appServices.configurationService.showCommissionBreakdownInCreditNote
            )
        case .monthlyAccountStatement:
            MonthlyAccountStatementView(services: appServices, document: document)
        case .invoice:
            HydratedInvoiceDocumentView(document: document, appServices: appServices)
        default:
            DocumentViewer(document: document)
        }
    }
}

// MARK: - Trade-Based Navigation Helper
/// Centralized navigation logic for trade-based document presentation
@MainActor
struct TradeNavigationHelper {

    // MARK: - Collection Bill Sheet
    /// Creates a sheet view for Collection Bill presentation from trade data
    /// - Parameter trade: The trade to display Collection Bill for
    /// - Returns: A view wrapped in NavigationStack for sheet presentation
    @ViewBuilder
    static func collectionBillSheet(for trade: TradeOverviewItem) -> some View {
        NavigationStack {
            CollectionBillViewWrapper(trade: trade)
        }
    }

    // MARK: - Invoice Sheet
    /// Creates a sheet view for Invoice presentation
    /// - Parameters:
    ///   - invoice: The invoice to display
    ///   - appServices: App services for dependency injection
    /// - Returns: A view wrapped in NavigationStack for sheet presentation
    @ViewBuilder
    static func invoiceSheet(for invoice: Invoice, appServices: AppServices) -> some View {
        NavigationStack {
            InvoiceDetailView(
                invoice: invoice,
                invoiceService: appServices.invoiceService,
                notificationService: appServices.notificationService
            )
        }
    }
}

// MARK: - Invoice document hydration
/// Parse `Document` rows often omit `invoiceData`; match from `InvoiceService` after load so all entry points match the account-statement experience.
@MainActor
private struct HydratedInvoiceDocumentView: View {
    let document: Document
    let appServices: AppServices

    @State private var routingDocument: Document
    @State private var resolvedInvoice: Invoice?
    @State private var hydrationComplete = false

    init(document: Document, appServices: AppServices) {
        self.document = document
        self.appServices = appServices
        _routingDocument = State(initialValue: document)
    }

    var body: some View {
        Group {
            if !self.hydrationComplete {
                ProgressView(String(localized: "Loading invoice…", comment: "Shown while invoice details are fetched"))
            } else if let invoice = resolvedInvoice {
                self.invoiceContent(invoice: invoice, documentRow: self.routingDocument)
            } else {
                DocumentViewer(document: self.routingDocument)
            }
        }
        .task(id: self.document.id) {
            await self.hydrate()
        }
    }

    @ViewBuilder
    private func invoiceContent(invoice: Invoice, documentRow: Document) -> some View {
        if invoice.type == .creditNote {
            self.creditNoteDestination(documentRow: documentRow, invoice: invoice)
        } else {
            InvoiceDetailView(
                invoice: invoice,
                invoiceService: self.appServices.invoiceService,
                notificationService: self.appServices.notificationService
            )
        }
    }

    private func creditNoteDestination(documentRow: Document, invoice: Invoice) -> some View {
        var merged = documentRow
        merged.invoiceData = invoice
        return TraderCreditNoteDetailView(
            document: merged,
            showCommissionBreakdown: self.appServices.configurationService.showCommissionBreakdownInCreditNote
        )
    }

    private func hydrate() async {
        self.hydrationComplete = false
        let row = await MainActor.run {
            self.appServices.documentService.getDocument(by: self.document.id) ?? self.document
        }
        self.routingDocument = row

        if let embedded = row.invoiceData {
            self.resolvedInvoice = embedded
            self.logInvoiceHydrationPhase(
                label: "embedded invoiceData (skip fetch)",
                payloadId: self.document.id,
                merged: row,
                invoiceService: self.appServices.invoiceService
            )
            self.hydrationComplete = true
            return
        }

        self.logInvoiceHydrationPhase(
            label: "before loadInvoices(\(row.userId))",
            payloadId: self.document.id,
            merged: row,
            invoiceService: self.appServices.invoiceService
        )

        do {
            try await self.appServices.invoiceService.loadInvoices(for: row.userId)
        } catch {
            print("⚠️ HydratedInvoiceDocumentView loadInvoices failed: \(error.localizedDescription)")
        }

        self.logInvoiceHydrationPhase(
            label: "after loadInvoices(\(row.userId))",
            payloadId: self.document.id,
            merged: row,
            invoiceService: self.appServices.invoiceService
        )

        self.resolvedInvoice = self.appServices.invoiceService.invoice(matching: row)
        if self.resolvedInvoice != nil {
            print(
                "✅ HydratedInvoiceDocumentView matched invoice id=\(self.resolvedInvoice!.id) number=\(self.resolvedInvoice!.invoiceNumber) type=\(self.resolvedInvoice!.type.rawValue)"
            )
        } else {
            print("❌ HydratedInvoiceDocumentView no invoice(matching:) — invoices.count=\(self.appServices.invoiceService.invoices.count)")
        }
        self.hydrationComplete = true
    }

    /// Debug: Notifications vs account-statement hydration (paste from Xcode console).
    private func logInvoiceHydrationPhase(
        label: String,
        payloadId: String,
        merged: Document,
        invoiceService: any InvoiceServiceProtocol
    ) {
        let tradeId = merged.tradeId ?? "nil"
        let accounting = merged.accountingDocumentNumber ?? "nil"
        let tradeHits: [Invoice] = merged.tradeId.map { invoiceService.getInvoicesForTrade($0) } ?? []

        let hitLines = tradeHits.enumerated().map { idx, inv in
            "      [\(idx)] id=\(inv.id) invoiceNumber=\(inv.invoiceNumber) type=\(inv.type.rawValue) tradeId=\(inv.tradeId ?? "nil") customerNumber=\(inv.customerInfo.customerNumber)"
        }.joined(separator: "\n")

        print("""
        🔎 HydratedInvoiceDocumentView — \(label)
          document.id (payload)=\(payloadId)
          merged.id=\(merged.id) merged.name=\(merged.name)
          merged.tradeId=\(tradeId)
          merged.accountingDocumentNumber=\(accounting)
          merged.userId=\(merged.userId)
          getInvoicesForTrade(\(tradeId)): count=\(tradeHits.count)
        \(hitLines.isEmpty ? "      (none)" : hitLines)
        """)
    }
}
