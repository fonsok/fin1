import SwiftUI

// MARK: - Invoice Item Row View
/// Displays an individual invoice item row
struct InvoiceItemRowView: View {
    let item: InvoiceItem

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            // Description - flexible width, single line
            Text(item.description)
                .font(ResponsiveDesign.captionFont())
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Only show Stück and Preis columns for securities items
            if item.itemType == .securities {
                Text(item.quantity.formattedAsLocalizedInteger())
                    .font(ResponsiveDesign.captionFont())
                    .frame(minWidth: 50, alignment: .trailing)

                Text(item.unitPrice.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.captionFont())
                    .frame(minWidth: 60, alignment: .trailing)
            }

            Text(item.totalAmount.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .padding(.horizontal, ResponsiveDesign.spacing(8))
    }
}

// MARK: - Preview
#Preview {
    InvoiceItemRowView(item: InvoiceItem(
        id: "1",
        description: "Apple Inc. Call Option",
        quantity: 100,
        unitPrice: 150.0,
        itemType: .securities
    ))
    .responsivePadding()
}











