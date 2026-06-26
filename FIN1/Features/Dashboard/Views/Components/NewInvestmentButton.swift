import SwiftUI

/// New Investment button component for investor dashboard
/// Navigates to the Discover tab (Find Trader) when tapped
struct NewInvestmentButton: View {
    @Environment(\.appServices) private var appServices
    @EnvironmentObject var tabRouter: TabRouter
    @State private var syncedUser: User?

    private var isTradingAllowed: Bool {
        guard let syncedUser else { return false }
        return syncedUser.isEligibleForRegulatedProductAccess
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Button(action: {
                guard self.isTradingAllowed else { return }
                self.tabRouter.selectedTab = 1
            }) {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    Image(systemName: "plus.circle.fill")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text("New Investment")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)
                }
                .frame(maxWidth: .infinity)
                .frame(height: ResponsiveDesign.spacing(56))
                .background(self.isTradingAllowed ? AppTheme.buttonColor : AppTheme.fontColor.opacity(0.3))
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .disabled(!self.isTradingAllowed)
            .accessibilityIdentifier("NewInvestmentButton")
            .accessibilityLabel("New Investment")
            .accessibilityHint(
                self.isTradingAllowed
                    ? "Tap to find traders for new investment"
                    : "New investments are not available for your account status"
            )

            if let syncedUser, !self.isTradingAllowed {
                if let reason = syncedUser.regulatedProductAccessBlockReason {
                    RegulatedProductAccessNotice(message: reason)
                } else if syncedUser.isExcludedFromPlatformTradingDueToRiskClass {
                    DashboardTradingAccessNotice(riskClass: syncedUser.riskClass, roleContext: .investor)
                }
            }
        }
        .dashboardTradingUserSync(self.$syncedUser)
    }
}

#Preview {
    NewInvestmentButton()
        .environmentObject(TabRouter())
        .padding()
        .background(AppTheme.screenBackground)
}
