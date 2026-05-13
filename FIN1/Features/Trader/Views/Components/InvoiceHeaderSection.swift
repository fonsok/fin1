import SwiftUI

// MARK: - Invoice Header Section
/// Displays the invoice header with number, status, and dates
struct InvoiceHeaderSection: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // Document Title
            Text(self.invoice.type.displayName)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(DocumentDesignSystem.textColor)

            // Kontoinhaber
            Text("Kontoinhaber: \(self.invoice.customerInfo.name)")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(DocumentDesignSystem.textColor)

            // Belegnummer (Document Number) - gemäß GoB
            Text("Beleg Nr.: \(self.invoice.invoiceNumber)")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(DocumentDesignSystem.textColor)

            // Trade Number if available
            if let tradeNumber = invoice.formattedTradeNumber {
                Text("Trade Nr.: \(tradeNumber)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentLightBlue)
            }

            HStack {
                Spacer()

                // Status badge
                InvoiceStatusBadge(status: self.invoice.status)
            }
            .padding(.top, ResponsiveDesign.spacing(4))

            HStack {
                VStack(alignment: .leading) {
                    Text("Erstellt am")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)

                    Text(self.invoice.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(DocumentDesignSystem.textColor)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Fällig am")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)

                    Text(self.invoice.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(DocumentDesignSystem.textColor)
                }
            }
            .padding(.top, ResponsiveDesign.spacing(8))
        }
        .documentSection(level: 1)
    }
}

// MARK: - Preview
#Preview {
    InvoiceHeaderSection(invoice: Invoice.sampleInvoice())
        .responsivePadding()
}
