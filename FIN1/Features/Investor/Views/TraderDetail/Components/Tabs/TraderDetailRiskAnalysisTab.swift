import SwiftUI

struct TraderDetailRiskAnalysisTab: View {
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Text("Risk Metrics")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
            }

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                RiskMetricRow(
                    title: "Sharpe Ratio",
                    value: "1.24",
                    description: "Risk-adjusted return measure"
                )

                RiskMetricRow(
                    title: "Max Drawdown",
                    value: "-8.5%",
                    description: "Largest peak-to-trough decline"
                )

                RiskMetricRow(
                    title: "Volatility",
                    value: "12.3%",
                    description: "Annualized standard deviation"
                )

                RiskMetricRow(
                    title: "Beta",
                    value: "0.87",
                    description: "Market correlation measure"
                )
            }
        }
    }
}

struct RiskMetricRow: View {
    let title: String
    let value: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text(value)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.accentLightBlue)
            }

            Text(description)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

#Preview {
    TraderDetailRiskAnalysisTab()
        .padding()
        .background(AppTheme.screenBackground)
}
