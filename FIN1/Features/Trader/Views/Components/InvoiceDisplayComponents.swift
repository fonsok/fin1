import SwiftUI

// MARK: - Invoice Display Components
/// Clean, focused UI components that only handle presentation

// MARK: - Invoice Header Component
struct InvoiceHeaderDisplayView: View {
    let headerData: InvoiceHeaderDisplayData

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            HStack {
                Text(headerData.transactionType)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(DocumentDesignSystem.textColor)

                Text("Wertpapier")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)

                Spacer()
            }
        }
        .documentSection(level: 2)
    }
}

// MARK: - Invoice Items List Component
struct InvoiceItemsDisplayView: View {
    let items: [InvoiceItemDisplayData]

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Rechnungspositionen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(DocumentDesignSystem.textColor)

            VStack(spacing: ResponsiveDesign.spacing(0)) {
                // Table Header - only show Stück/Preis columns if there are securities items
                InvoiceItemsTableHeaderView(hasSecuritiesItems: items.contains { $0.itemType == .securities })

                // Table Rows
                ForEach(items) { item in
                    InvoiceItemDisplayRowView(item: item)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                    .fill(DocumentDesignSystem.sectionBackground(level: 2))
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
        }
    }
}

// MARK: - Invoice Item Row Component
struct InvoiceItemDisplayRowView: View {
    let item: InvoiceItemDisplayData

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            // Description column - flexible width, single line with truncation
            Text(item.description)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Only show Stück and Preis columns for securities items
            if item.itemType == .securities {
                Text(item.quantity)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    .frame(minWidth: 50, alignment: .trailing)

                Text(item.unitPrice)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    .frame(minWidth: 60, alignment: .trailing)
            }

            Text(item.total)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .foregroundColor(DocumentDesignSystem.textColor)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(8))
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .background(
            Rectangle()
                .fill(item.itemType == .securities ? DocumentDesignSystem.sectionBackground(level: 3) : Color.clear)
        )
    }
}

// MARK: - Invoice Items Table Header Component
struct InvoiceItemsTableHeaderView: View {
    let hasSecuritiesItems: Bool

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Text("Beschreibung")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Only show Stück and Preis columns if there are securities items
            if hasSecuritiesItems {
                Text("Stück")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    .frame(minWidth: 50, alignment: .trailing)

                Text("Preis")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    .frame(minWidth: 60, alignment: .trailing)
            }

            Text("Gesamt")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(8))
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .background(
            Rectangle()
                .fill(DocumentDesignSystem.sectionBackground(level: 3))
        )
    }
}

// MARK: - Invoice Totals Component
struct InvoiceTotalsDisplayView: View {
    let totals: InvoiceTotalsDisplayData

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Zwischensumme:")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Spacer()
                Text(totals.subtotal)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }

            HStack {
                Text("Steuer:")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Spacer()
                Text(totals.tax)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }

            Divider()
                .background(DocumentDesignSystem.textColor.opacity(0.2))

            HStack {
                Text("Gesamt:")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(DocumentDesignSystem.textColor)
                Spacer()
                Text(totals.total)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(DocumentDesignSystem.textColor)
            }
        }
        .documentSection(level: 2)
    }
}

// MARK: - Customer Info Display Component
struct CustomerInfoDisplayView: View {
    let customerData: CustomerInfoDisplayData

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // "Rechnungsempfänger" Text entfernt - Adresse ist jetzt im Header
            // Adresse entfernt - ist jetzt im DocumentHeaderView unterhalb der Firmen-Adresse

            // Nur noch Steuernummer und Kundennummer
            HStack {
                VStack(alignment: .leading) {
                    Text("Steuernummer")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    Text(customerData.taxNumber)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(DocumentDesignSystem.textColor)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Kundennummer")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    Text(customerData.customerNumber)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(DocumentDesignSystem.textColor)
                }
            }
        }
        .documentSection(level: 1)
    }
}











