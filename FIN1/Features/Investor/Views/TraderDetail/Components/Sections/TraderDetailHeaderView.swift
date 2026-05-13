import SwiftUI

struct TraderDetailHeaderView: View {
    let trader: MockTrader

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            // Profile Header
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Circle()
                    .fill(AppTheme.accentLightBlue.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(ResponsiveDesign.titleFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                    )

                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Text(self.trader.name)
                        .font(ResponsiveDesign.titleFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    Text(self.trader.specialization)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))

                    HStack(spacing: ResponsiveDesign.spacing(16)) {
                        if self.trader.isVerified {
                            Label("Verified", systemImage: "checkmark.seal.fill")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.accentGreen)
                        }

                        Label("\(self.trader.experienceYears) years", systemImage: "clock.fill")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    }
                }
            }

            // Quick Stats
            HStack(spacing: ResponsiveDesign.spacing(20)) {
                QuickStatItem(title: "Total Trades", value: "\(self.trader.totalTrades)")
                QuickStatItem(title: "Win Rate", value: "\(String(format: "%.1f", self.trader.winRate))%")
                QuickStatItem(title: "Avg Return", value: "\(String(format: "%.1f", self.trader.averageReturn))%")
            }
        }
        .padding(ResponsiveDesign.spacing(20))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }
}

struct QuickStatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Text(self.value)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    TraderDetailHeaderView(trader: mockTraders[0])
        .padding()
        .background(AppTheme.screenBackground)
}
