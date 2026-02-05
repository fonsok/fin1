import SwiftUI

// MARK: - Document Navigation Helper
/// Centralized navigation logic for documents to eliminate DRY violations
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
            documentView(for: document, appServices: appServices)
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
        documentView(for: document, appServices: appServices)
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
            if let invoice = document.invoiceData {
                // Check if this is a credit note invoice
                if invoice.type == .creditNote {
                    TraderCreditNoteDetailView(
                        document: document,
                        showCommissionBreakdown: appServices.configurationService.showCommissionBreakdownInCreditNote
                    )
                } else {
                    InvoiceDetailView(
                        invoice: invoice,
                        invoiceService: appServices.invoiceService,
                        notificationService: appServices.notificationService
                    )
                }
            } else {
                DocumentViewer(document: document)
            }
        default:
            DocumentViewer(document: document)
        }
    }
}

// MARK: - Trade-Based Navigation Helper
/// Centralized navigation logic for trade-based document presentation
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
