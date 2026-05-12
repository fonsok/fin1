import SwiftUI

// MARK: - Invoice Display View
/// Main view that orchestrates invoice display using proper MVVM architecture
struct InvoiceDisplayView: View {
    @StateObject private var viewModel: InvoiceDisplayViewModel

    init(invoice: Invoice) {
        self._viewModel = StateObject(wrappedValue: InvoiceDisplayViewModel(invoice: invoice))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                // Document Header (einheitliches Layout für alle Dokumente)
                DocumentHeaderLayoutView(
                    accountHolderName: viewModel.invoice.customerInfo.name,
                    accountHolderAddress: viewModel.invoice.customerInfo.address,
                    accountHolderCity: "\(viewModel.invoice.customerInfo.postalCode) \(viewModel.invoice.customerInfo.city)",
                    documentDate: viewModel.invoice.createdAt
                ) {
                    InvoiceQRCodeView(invoice: viewModel.invoice)
                }

                // Header Section with Invoice Number, Trade Nr., etc.
                InvoiceHeaderSection(invoice: viewModel.invoice)

                // Transaction Type Header (only show if there's a valid transaction type, not for app service charge)
                if let headerData = viewModel.headerData,
                   viewModel.invoice.transactionType != nil,
                   headerData.transactionType != "Unknown" {
                    InvoiceHeaderDisplayView(headerData: headerData)
                }

                // Customer Information
                if let customerData = viewModel.customerData {
                    CustomerInfoDisplayView(customerData: customerData)
                }

                // Invoice Items
                if let displayData = viewModel.displayData {
                    InvoiceItemsDisplayView(items: displayData.items)

                    // Totals Section
                    InvoiceTotalsDisplayView(totals: displayData.totals)
                }

                // Loading State
                if viewModel.isLoading {
                    ProgressView("Loading invoice...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Error State
                if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(ResponsiveDesign.titleFont())
                            .foregroundColor(.red)
                        Text("Error loading invoice")
                            .font(ResponsiveDesign.headlineFont())
                        Text(errorMessage)
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .padding()
            .background(DocumentDesignSystem.documentBackground)
        }
        .background(DocumentDesignSystem.documentBackground)
        .navigationTitle("Rechnung")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refreshDisplayData()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        InvoiceDisplayView(invoice: Invoice.sampleInvoice())
    }
}
