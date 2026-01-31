import SwiftUI
import UIKit

// MARK: - Collection Bill Document View
/// Displays a Collection Bill document by extracting either a trade number or an investment ID from the document name.
/// - Trader documents (`CollectionBill_Trade{Number}_...`) show the full Trade Statement.
/// - Investor documents (`CollectionBill_Investment{InvestmentId}_...`) show the Investment Detail sheet.
struct CollectionBillDocumentView: View {
    @StateObject private var viewModel: CollectionBillDocumentViewModel

    init(document: Document, services: AppServices) {
        self._viewModel = StateObject(wrappedValue: CollectionBillDocumentViewModel(
            document: document,
            services: services
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading Collection Bill...")
                    .task {
                        await viewModel.loadTargetFromDocument()
                    }
            } else if viewModel.document.type == .investorCollectionBill,
                      viewModel.investment != nil,
                      let statementViewModel = viewModel.createInvestorStatementViewModel() {
                // Show detailed Investment Collection Bill view
                InvestorInvestmentStatementView(viewModel: statementViewModel)
            } else if viewModel.document.type == .investorCollectionBill,
                      let previewImage = viewModel.investorPreviewImage {
                // Fallback to PDF preview if investment not found
                InvestorCollectionBillDocumentView(
                    document: viewModel.document,
                    previewImage: previewImage,
                    pdfData: viewModel.investorPDFData
                )
            } else if viewModel.fallbackToDocumentViewer {
                DocumentViewer(document: viewModel.document)
            } else if let trade = viewModel.trade {
                CollectionBillViewWrapper(trade: trade, document: viewModel.document)
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

            Text("Document: \(viewModel.document.name)")
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
