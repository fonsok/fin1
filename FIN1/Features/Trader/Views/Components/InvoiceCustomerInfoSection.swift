import SwiftUI

// MARK: - Invoice Customer Info Section
/// Displays customer information for the invoice
struct InvoiceCustomerInfoSection: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rechnungsempfänger")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text(invoice.customerInfo.name)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)

                Text(invoice.customerInfo.address)
                    .font(ResponsiveDesign.bodyFont())

                Text("\(invoice.customerInfo.postalCode) \(invoice.customerInfo.city)")
                    .font(ResponsiveDesign.bodyFont())

                Divider()

                HStack {
                    VStack(alignment: .leading) {
                        Text("Steuernummer")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.secondary)
                        Text(invoice.customerInfo.taxNumber)
                            .font(ResponsiveDesign.bodyFont())
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Kundennummer")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.secondary)
                        Text(invoice.customerInfo.customerNumber)
                            .font(ResponsiveDesign.bodyFont())
                    }
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Depotnummer")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.secondary)
                        Text(invoice.customerInfo.depotNumber)
                            .font(ResponsiveDesign.bodyFont())
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Bank")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.secondary)
                        Text(invoice.customerInfo.bank)
                            .font(ResponsiveDesign.bodyFont())
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    InvoiceCustomerInfoSection(invoice: Invoice.sampleInvoice())
        .padding()
}
