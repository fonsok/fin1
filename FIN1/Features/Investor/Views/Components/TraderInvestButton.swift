import SwiftUI

// MARK: - Trader Invest Button
/// Investment button for trader details view

struct TraderInvestButton: View {
    @Environment(\.appServices) private var appServices
    let trader: InvestorTrader
    @Binding var showInvestSheet: Bool

    private var canCreatePlatformInvestments: Bool {
        self.appServices.userService.currentUser?.isEligibleForRegulatedProductAccess ?? false
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Button(action: {
                guard self.canCreatePlatformInvestments else { return }
                self.showInvestSheet = true
            }) {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "plus.circle.fill")
                        .font(ResponsiveDesign.headlineFont())
                    Text("Investiere mit \(self.trader.username)")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                }
                .foregroundColor(AppTheme.fontColor)
                .frame(width: UIScreen.main.bounds.width / 2)
                .padding(.horizontal, ResponsiveDesign.spacing(16))
                .padding(.vertical, ResponsiveDesign.spacing(13))
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            self.canCreatePlatformInvestments ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.3),
                            self.canCreatePlatformInvestments ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.3)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
            .disabled(!self.canCreatePlatformInvestments)
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("InvestWithTraderButton")

            if let currentUser = self.appServices.userService.currentUser, !self.canCreatePlatformInvestments {
                if let reason = currentUser.regulatedProductAccessBlockReason {
                    RegulatedProductAccessNotice(message: reason)
                } else if currentUser.isExcludedFromPlatformTradingDueToRiskClass {
                    DashboardTradingAccessNotice(riskClass: currentUser.riskClass, roleContext: .investor)
                }
            }
        }
    }
}
