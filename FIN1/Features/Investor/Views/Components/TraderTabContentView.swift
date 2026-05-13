import SwiftUI

// MARK: - Trader Tab Content View
/// Content for different tabs in trader details

struct TraderTabContentView: View {
    let trader: MockTrader
    @Binding var selectedTab: Int

    var body: some View {
        Group {
            switch self.selectedTab {
            case 0:
                self.performanceTab
            case 1:
                self.reviewsTab
            case 2:
                self.riskAnalysisTab
            case 3:
                self.tradingHistoryTab
            default:
                self.performanceTab
            }
        }
        .animation(.easeInOut, value: self.selectedTab)
    }

    private var performanceTab: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Performance Chart Placeholder
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .fill(AppTheme.systemSecondaryBackground)
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(ResponsiveDesign.titleFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                        Text("Performance Chart")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)
                        Text("Coming Soon")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    }
                )

            // Performance Stats
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                StatCard(
                    title: "Monthly Return",
                    value: "\(String(format: "%.1f", self.trader.performance))%",
                    icon: "arrow.up.right",
                    color: self.trader.performance > 0 ? AppTheme.accentGreen : AppTheme.accentRed
                )

                StatCard(
                    title: "Sharpe Ratio",
                    value: "1.2",
                    icon: "chart.bar.xaxis",
                    color: AppTheme.accentLightBlue
                )

                StatCard(
                    title: "Max Drawdown",
                    value: "-5.2%",
                    icon: "arrow.down.right",
                    color: AppTheme.accentRed
                )
            }
        }
        .responsivePadding()
        .background(AppTheme.systemSecondaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }

    private var reviewsTab: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("Investor Reviews")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text("No reviews available yet")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .responsivePadding()
        .background(AppTheme.systemSecondaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }

    private var riskAnalysisTab: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("Risk Analysis")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text("Risk analysis coming soon")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .responsivePadding()
        .background(AppTheme.systemSecondaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }

    private var tradingHistoryTab: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("Trading History")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text("Trading history coming soon")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .responsivePadding()
        .background(AppTheme.systemSecondaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }
}
