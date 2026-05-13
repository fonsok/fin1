import SwiftUI

// MARK: - Invoice Demo View
/// Demo view to showcase invoice functionality
struct InvoiceDemoView: View {
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: InvoiceViewModel
    @State private var showingCreateInvoice = false
    @State private var selectedInvoice: Invoice?

    init() {
        // This will be injected via environment in real usage
        self._viewModel = StateObject(
            wrappedValue: InvoiceViewModel(invoiceService: InvoiceService(), notificationService: NotificationService())
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                // Header
                self.headerSection

                // Sample Invoice Card
                self.sampleInvoiceCard

                // Action Buttons
                self.actionButtonsSection

                Spacer()
            }
            .padding()
            .navigationTitle("Rechnungs-Demo")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: self.$showingCreateInvoice) {
                CreateInvoiceView(invoiceService: self.services.invoiceService, notificationService: self.services.notificationService)
            }
            .sheet(item: self.$selectedInvoice) { invoice in
                NavigationStack {
                    InvoiceDetailView(
                        invoice: invoice,
                        invoiceService: self.services.invoiceService,
                        notificationService: self.services.notificationService
                    )
                }
            }
        }
        .onAppear {
            // Load actual user invoices
            let currentUserId = self.services.userService.currentUser?.id ?? "current_user_id"
            self.viewModel.loadInvoices(for: currentUserId)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "doc.text.badge.plus")
                .font(ResponsiveDesign.scaledSystemFont(size: 50))
                .foregroundColor(.accentColor)

            Text("Wertpapierabrechnung")
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)

            Text("Professionelle PDF-Rechnungen für Wertpapiertransaktionen")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Sample Invoice Card

    private var sampleInvoiceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Musterrechnung")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)

                Spacer()

                InvoiceStatusBadge(status: .generated)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Rechnungsnummer:")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("INV-20241201-1234")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Kunde:")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Max Mustermann")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Wertpapiere:")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("1.000 Optionsscheine PUT")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Gesamtbetrag:")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("1.210,50 €")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Steuerlicher Hinweis:")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)

                Text(
                    "Beim Kauf werden keine Steuern abgezogen. Die Besteuerung erfolgt erst beim Verkauf bzw. Gewinnrealisierung gemäß Abgeltungsteuer (dzt. 25% + Soli)."
                )
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(16))
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .onTapGesture {
            // Show sample invoice detail
            self.selectedInvoice = Invoice.sampleInvoice()
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Button("Musterrechnung anzeigen") {
                self.selectedInvoice = Invoice.sampleInvoice()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            Button("Neue Rechnung erstellen") {
                self.showingCreateInvoice = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Button("PDF generieren") {
                self.generateSamplePDF()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Private Methods

    private func generateSamplePDF() {
        let sampleInvoice = Invoice.sampleInvoice()
        self.viewModel.generatePDF(for: sampleInvoice)
    }
}

// MARK: - Preview

struct InvoiceDemoView_Previews: PreviewProvider {
    static var previews: some View {
        InvoiceDemoView()
    }
}
