import SwiftUI

struct TraderDetailPerformanceView: View {
    let trader: MockTrader

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Text("Performance Overview")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
            }

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                PerformanceRow(
                    title: "Year-to-Date",
                    value: self.trader.performance > 0 ? "+\(String(format: "%.1f", self.trader.performance))%" : "\(String(format: "%.1f", self.trader.performance))%",
                    isPositive: self.trader.performance > 0
                )

                PerformanceRow(
                    title: "Last 12 Months",
                    value: "+18.7%",
                    isPositive: true
                )

                PerformanceRow(
                    title: "Last 3 Years",
                    value: "+45.2%",
                    isPositive: true
                )
            }
        }
    }
}

struct PerformanceRow: View {
    let title: String
    let value: String
    let isPositive: Bool

    var body: some View {
        HStack {
            Text(self.title)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            Text(self.value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(self.isPositive ? AppTheme.accentGreen : AppTheme.accentRed)
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

#Preview {
    TraderDetailPerformanceView(trader: mockTraders[0])
        .padding()
        .background(AppTheme.screenBackground)
}
