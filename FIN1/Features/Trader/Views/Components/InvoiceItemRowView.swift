import SwiftUI

// MARK: - Invoice Item Row View
/// Displays an individual invoice item row
struct InvoiceItemRowView: View {
    let item: InvoiceItem

    var body: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
            // Description - allow multiple lines for service charge and securities items
            let allowMultiLine = (item.itemType == .serviceCharge || self.item.itemType == .securities)
            Text(self.item.description)
                .font(ResponsiveDesign.captionFont())
                .lineLimit(allowMultiLine ? nil : 1)
                .truncationMode(allowMultiLine ? .tail : .middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            // Only show Stück and Preis columns for securities items
            if self.item.itemType == .securities {
                Text(self.item.quantity.formattedAsLocalizedInteger())
                    .font(ResponsiveDesign.captionFont())
                    .frame(minWidth: 50, alignment: .trailing)

                Text(self.item.unitPrice.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.captionFont())
                    .frame(minWidth: 60, alignment: .trailing)
            }

            Text(self.item.totalAmount.formattedAsLocalizedCurrency())
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











