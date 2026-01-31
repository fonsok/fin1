import SwiftUI

// MARK: - Order Selection Card
struct OrderSelectionCard: View {
    let order: OrderBuy
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap, label: {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(ResponsiveDesign.titleFont())
                    .foregroundColor(.accentColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(order.symbol)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.primary)

                    Text(order.description)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)

                    Text("\(order.quantity.formattedAsLocalizedInteger()) shares @ \(order.price.formattedAsLocalizedCurrency())")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        })
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Customer Info Card
struct CustomerInfoCard: View {
    let customerInfo: CustomerInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap, label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.circle")
                        .font(ResponsiveDesign.titleFont())
                        .foregroundColor(.accentColor)

                    Text(customerInfo.name)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }

                Text(customerInfo.fullAddress)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.secondary)

                HStack {
                    Text("Kunde: \(customerInfo.customerNumber)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Depot: \(customerInfo.depotNumber)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        })
        .buttonStyle(PlainButtonStyle())
    }
}
