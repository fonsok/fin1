import SwiftUI

// MARK: - Invoice Totals Section
/// Displays the invoice totals including subtotal, tax, and total amount
struct InvoiceTotalsSection: View {
    let invoice: Invoice

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Zwischensumme")
                    .font(ResponsiveDesign.bodyFont())

                Spacer()

                Text(invoice.formattedSubtotal)
                    .font(ResponsiveDesign.bodyFont())
            }

            if invoice.totalTax > 0 {
                HStack {
                    Text("Steuer")
                        .font(ResponsiveDesign.bodyFont())

                    Spacer()

                    Text(invoice.formattedTaxAmount)
                        .font(ResponsiveDesign.bodyFont())
                }
            }

            Divider()

            HStack {
                Text("Gesamtbetrag")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)

                Spacer()

                Text(invoice.formattedTotalAmount)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .padding(.vertical, ResponsiveDesign.spacing(1)) // Even smaller vertical padding
    }
}

// MARK: - Preview
#Preview {
    InvoiceTotalsSection(invoice: Invoice.sampleInvoice())
        .responsivePadding()
}
