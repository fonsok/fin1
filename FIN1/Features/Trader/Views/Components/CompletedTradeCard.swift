import SwiftUI

// MARK: - Completed Trade Card
struct CompletedTradeCard: View {
    let trade: MockCompletedTrade
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Header
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentGreen)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("\(self.trade.symbol) - Trade")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Completed \(self.trade.completedDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)
                }

                Spacer()

                // Final P&L
                VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(4)) {
                    Text(
                        self.trade.finalPnl > 0 ? "+$\(String(format: "%.0f", self.trade.finalPnl))" : "-$\(String(format: "%.0f", abs(self.trade.finalPnl)))"
                    )
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(self.trade.finalPnl > 0 ? AppTheme.accentGreen : AppTheme.accentRed)

                    Text("Final P&L")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.tertiaryText)
                }
            }

            // Summary
            HStack(spacing: ResponsiveDesign.spacing(20)) {
                TradeDetailItem(
                    title: "Entry Price",
                    value: "$\(String(format: "%.2f", self.trade.entryPrice))"
                )

                TradeDetailItem(
                    title: "Exit Price",
                    value: "$\(String(format: "%.2f", self.trade.exitPrice))"
                )

                TradeDetailItem(
                    title: "Quantity",
                    value: "\(self.trade.quantity)"
                )
            }

            // Performance Metrics
            HStack(spacing: ResponsiveDesign.spacing(20)) {
                TradeDetailItem(
                    title: "Return %",
                    value: self.trade.roi.formattedAsROIPercentage(),
                    isPositive: self.trade.roi > 0
                )

                TradeDetailItem(
                    title: "Duration",
                    value: "5 days" // Mock duration
                )

                TradeDetailItem(
                    title: "Volume",
                    value: "$\(String(format: "%.0f", self.trade.buyOrder.totalAmount))"
                )
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .fill(AppTheme.sectionBackground)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}
