import SwiftUI

// MARK: - Invoice Action Buttons Section
/// Displays action buttons for PDF generation and preview
struct InvoiceActionButtonsSection: View {
    @ObservedObject var viewModel: InvoiceViewModel
    let invoice: Invoice

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            if self.viewModel.isGeneratingPDF {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ProgressView(value: self.viewModel.pdfGenerationProgress)
                        .progressViewStyle(LinearProgressViewStyle())

                    Text("PDF wird generiert...")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    Button("PDF Vorschau") {
                        self.viewModel.generatePDFPreview(for: self.invoice)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("PDF Generieren") {
                        self.viewModel.generatePDF(for: self.invoice)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    InvoiceActionButtonsSection(
        viewModel: InvoiceViewModel(invoiceService: InvoiceService(), notificationService: NotificationService()),
        invoice: Invoice.sampleInvoice()
    )
    .responsivePadding()
}
