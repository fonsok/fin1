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
        self._viewModel = StateObject(
            wrappedValue: InvoiceViewModel(invoiceService: invoiceService, notificationService: notificationService)
        )
        self._selectedStatus = State(initialValue: invoice.status)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                // Use the new clean MVVM architecture
                InvoiceDisplayView(invoice: self.invoice)

                // Keep existing sections that aren't part of the display refactor
                InvoiceNotesSection(invoice: self.invoice)

                // Action Buttons
                InvoiceActionButtonsSection(viewModel: self.viewModel, invoice: self.invoice)
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
                    self.dismiss()
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
                        self.viewModel.generatePDFPreview(for: self.invoice)
                    }, label: {
                        Label("PDF Vorschau", systemImage: "eye")
                    })

                    Button(action: {
                        self.viewModel.generatePDF(for: self.invoice)
                    }, label: {
                        Label("PDF Generieren", systemImage: "doc.badge.plus")
                    })

                    Button(action: {
                        Task {
                            self.shareablePDFURL = await self.viewModel.createShareablePDFURL(for: self.invoice)
                            self.showingShareSheet = true
                        }
                    }, label: {
                        Label("PDF Teilen", systemImage: "square.and.arrow.up")
                    })

                    Button(action: {
                        self.viewModel.downloadPDFViaBrowser(for: self.invoice)
                    }, label: {
                        Label("PDF Download", systemImage: "arrow.down.circle")
                    })

                    Divider()

                    // Status Actions
                    Button(action: {
                        self.showingStatusUpdate = true
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
        .sheet(isPresented: self.$showingPDFPreview) {
            if let previewImage = viewModel.pdfPreviewImage {
                PDFPreviewView(image: previewImage)
            }
        }
        .sheet(isPresented: self.$showingStatusUpdate) {
            StatusUpdateView(
                currentStatus: self.invoice.status,
                onStatusSelected: { newStatus in
                    self.viewModel.updateInvoiceStatus(self.invoice, status: newStatus)
                    self.showingStatusUpdate = false
                }
            )
        }
        .sheet(isPresented: self.$showingShareSheet) {
            if let pdfURL = shareablePDFURL {
                ShareSheetView(pdfURL: pdfURL, invoiceNumber: self.invoice.formattedInvoiceNumber)
            }
        }
        .alert("Fehler", isPresented: self.$viewModel.showError) {
            Button("OK") {
                self.viewModel.clearError()
            }
        } message: {
            Text(self.viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten.")
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
