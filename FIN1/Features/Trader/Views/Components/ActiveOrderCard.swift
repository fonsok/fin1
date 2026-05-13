import SwiftUI

// MARK: - Active Order Card
struct ActiveOrderCard: View {
    let order: MockActiveOrder

    var body: some View {
        Button(action: { /* Details removed */ }, label: {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                // Header
                HStack {
                    Image(systemName: self.order.type == "buy" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(self.order.type == "buy" ? AppTheme.accentGreen : AppTheme.accentRed)

                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                        Text("\(self.order.symbol) - \(self.order.type.capitalized)")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.fontColor)

                        Text("\(self.order.quantity) shares @ $\(String(format: "%.2f", self.order.price))")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    }

                    Spacer()

                    // Status Badge
                    Text(self.order.status.capitalized)
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.screenBackground)
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(self.statusColor)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                }

                // Order Details
                HStack(spacing: ResponsiveDesign.spacing(20)) {
                    TradeDetailItem(
                        title: "Total Amount",
                        value: "$\(String(format: "%.0f", self.order.totalAmount))"
                    )

                    TradeDetailItem(
                        title: "Current P&L",
                        value: self.order.currentPnl > 0 ? "+$\(String(format: "%.0f", self.order.currentPnl))" : "-$\(String(format: "%.0f", abs(self.order.currentPnl)))",
                        isPositive: self.order.currentPnl > 0
                    )

                    TradeDetailItem(
                        title: "Time in Market",
                        value: "\(self.order.durationDays) days"
                    )
                }
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                    .fill(AppTheme.sectionBackground)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        })
        .buttonStyle(PlainButtonStyle())
    }

    private var statusColor: Color {
        switch self.order.status.lowercased() {
        case "active", "pending":
            return AppTheme.accentOrange
        case "executed", "completed":
            return AppTheme.accentGreen
        case "cancelled", "failed":
            return AppTheme.accentRed
        default:
            return .gray
        }
    }
}
