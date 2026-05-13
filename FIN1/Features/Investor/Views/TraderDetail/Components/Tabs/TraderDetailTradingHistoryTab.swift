import SwiftUI

struct TraderDetailTradingHistoryTab: View {
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Text("Recent Trades")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()

                Button("View All") {
                    // TODO: Navigate to full trading history
                }
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.accentLightBlue)
            }

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ForEach(mockRecentTrades) { trade in
                    TradeHistoryRow(trade: trade)
                }
            }
        }
    }
}

struct TradeHistoryRow: View {
    let trade: MockTrade

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: self.trade.type == .buy ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(self.trade.type == .buy ? AppTheme.accentGreen : AppTheme.accentRed)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(self.trade.symbol) - \(self.trade.type.displayName)")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text("\(self.trade.quantity) shares @ $\(String(format: "%.2f", self.trade.price))")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(
                    self.trade.result > 0 ? "+$\(String(format: "%.2f", self.trade.result))" : "-$\(String(format: "%.2f", abs(self.trade.result)))"
                )
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(self.trade.result > 0 ? AppTheme.accentGreen : AppTheme.accentRed)

                Text(self.trade.date.formatted(date: .abbreviated, time: .omitted))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Mock Data

struct MockTrade: Identifiable {
    let id = UUID()
    let symbol: String
    let type: OrderType
    let quantity: Int
    let price: Double
    let result: Double
    let date: Date
}

let mockRecentTrades = [
    MockTrade(symbol: "AAPL", type: .buy, quantity: 10, price: 175.43, result: 45.20, date: Date().addingTimeInterval(-86_400)),
    MockTrade(symbol: "TSLA", type: .sell, quantity: 5, price: 242.54, result: -12.30, date: Date().addingTimeInterval(-172_800)),
    MockTrade(symbol: "GOOGL", type: .buy, quantity: 8, price: 138.21, result: 23.45, date: Date().addingTimeInterval(-259_200))
]

#Preview {
    TraderDetailTradingHistoryTab()
        .padding()
        .background(AppTheme.screenBackground)
}
