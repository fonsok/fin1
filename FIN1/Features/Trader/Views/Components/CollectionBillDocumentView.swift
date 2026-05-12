import SwiftUI
import UIKit

// MARK: - Collection Bill Document View
/// Displays a Collection Bill document by extracting either a trade number or an investment ID from the document name.
/// - Trader documents (`CollectionBill_Trade{Number}_...`) show the full Trade Statement.
/// - Investor documents (`CollectionBill_Investment{InvestmentId}_...`) show the Investment Detail sheet.
struct CollectionBillDocumentView: View {
    @StateObject private var viewModel: CollectionBillDocumentViewModel
    @Environment(\.appServices) private var services

    init(document: Document, services: AppServices) {
        self._viewModel = StateObject(wrappedValue: CollectionBillDocumentViewModel(
            document: document,
            services: services
        ))
    }

    /// Merged document from `DocumentService` when the notification payload omits fields (investmentId, etc.).
    private var displayDocument: Document {
        viewModel.canonicalDocument ?? viewModel.document
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading Collection Bill...")
                    .task {
                        await viewModel.loadTargetFromDocument()
                    }
            } else if displayDocument.type == .investorCollectionBill,
                      let investment = viewModel.investment {
                // Show detailed Investment Collection Bill view.
                // Wrapper owns the inner VM via @StateObject so SwiftUI body
                // re-evaluations don't replace the observed instance mid-refresh
                // (otherwise the items table renders empty even though
                // `refreshFromBackend` already populated `statementItems` on the
                // previous instance).
                InvestorInvestmentStatementViewWrapper(
                    investment: investment,
                    documentNumber: (viewModel.canonicalDocument ?? viewModel.document).accountingDocumentNumber,
                    services: services
                )
            } else if displayDocument.type == .investorCollectionBill,
                      let previewImage = viewModel.investorPreviewImage {
                // Fallback to PDF preview if investment not found
                InvestorCollectionBillDocumentView(
                    document: displayDocument,
                    previewImage: previewImage,
                    pdfData: viewModel.investorPDFData
                )
            } else if viewModel.fallbackToDocumentViewer {
                DocumentViewer(document: displayDocument)
            } else if let trade = viewModel.trade {
                CollectionBillViewWrapper(trade: trade, document: displayDocument, fullTrade: viewModel.resolvedFullTrade)
            } else if let investment = viewModel.investment {
                InvestmentDetailView(investment: investment)
            } else {
                errorView
            }
        }
        .navigationTitle("Collection Bill")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var errorView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "exclamationmark.triangle")
                .font(ResponsiveDesign.titleFont())
                .foregroundColor(.orange)

            Text("Collection Bill Not Found")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(.primary)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Document: \(displayDocument.name)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(ResponsiveDesign.spacing(20))
    }
}

// MARK: - Environment-based Wrapper

struct CollectionBillDocumentViewWrapper: View {
    let document: Document
    @Environment(\.appServices) private var services

    var body: some View {
        CollectionBillDocumentView(document: document, services: services)
    }
}
