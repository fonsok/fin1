import SwiftUI

// MARK: - Invoice Detail View
/// Displays detailed information about a specific invoice
struct InvoiceDetailView: View {
    @StateObject private var viewModel: InvoiceViewModel
    let invoice: Invoice
    @State private var showingPDFPreview = false
    @State private var showingStatusUpdate = false
    @State private var showingShareSheet = false
    @State private var selectedStatus: InvoiceStatus
    @State private var shareablePDFURL: URL?
    @Environment(\.dismiss) private var dismiss

    init(invoice: Invoice, invoiceService: any InvoiceServiceProtocol, notificationService: any NotificationServiceProtocol) {
        self.invoice = invoice
        self._viewModel = StateObject(wrappedValue: InvoiceViewModel(invoiceService: invoiceService, notificationService: notificationService))
        self._selectedStatus = State(initialValue: invoice.status)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                // Use the new clean MVVM architecture
                InvoiceDisplayView(invoice: invoice)

                // Keep existing sections that aren't part of the display refactor
                InvoiceNotesSection(invoice: invoice)

                // Action Buttons
                InvoiceActionButtonsSection(viewModel: viewModel, invoice: invoice)
            }
            .padding()
            .background(DocumentDesignSystem.documentBackground)
        }
        .background(DocumentDesignSystem.documentBackground)
        .navigationTitle("Rechnung Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(DocumentDesignSystem.documentBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize(), weight: .medium))
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // PDF Actions
                    Button(action: {
                        viewModel.generatePDFPreview(for: invoice)
                    }, label: {
                        Label("PDF Vorschau", systemImage: "eye")
                    })

                    Button(action: {
                        viewModel.generatePDF(for: invoice)
                    }, label: {
                        Label("PDF Generieren", systemImage: "doc.badge.plus")
                    })

                    Button(action: {
                        Task {
                            shareablePDFURL = await viewModel.createShareablePDFURL(for: invoice)
                            showingShareSheet = true
                        }
                    }, label: {
                        Label("PDF Teilen", systemImage: "square.and.arrow.up")
                    })

                    Button(action: {
                        viewModel.downloadPDFViaBrowser(for: invoice)
                    }, label: {
                        Label("PDF Download", systemImage: "arrow.down.circle")
                    })

                    Divider()

                    // Status Actions
                    Button(action: {
                        showingStatusUpdate = true
                    }, label: {
                        Label("Status ändern", systemImage: "pencil")
                    })

                    // Additional Actions
                    Button(action: {
                        // Mark as read functionality
                        print("Mark invoice as read")
                    }, label: {
                        Label("Als gelesen markieren", systemImage: "checkmark.circle")
                    })

                    Button(action: {
                        // Print functionality
                        print("Print invoice")
                    }) {
                        Label("Drucken", systemImage: "printer")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize(), weight: .medium))
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
        .sheet(isPresented: $showingPDFPreview) {
            if let previewImage = viewModel.pdfPreviewImage {
                PDFPreviewView(image: previewImage)
            }
        }
        .sheet(isPresented: $showingStatusUpdate) {
            StatusUpdateView(
                currentStatus: invoice.status,
                onStatusSelected: { newStatus in
                    viewModel.updateInvoiceStatus(invoice, status: newStatus)
                    showingStatusUpdate = false
                }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let pdfURL = shareablePDFURL {
                ShareSheetView(pdfURL: pdfURL, invoiceNumber: invoice.formattedInvoiceNumber)
            }
        }
        .alert("Fehler", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten.")
        }
    }

}
// MARK: - Preview

struct InvoiceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            InvoiceDetailView(
                invoice: Invoice.sampleInvoice(),
                invoiceService: InvoiceService(),
                notificationService: NotificationService()
            )
        }
    }
}
