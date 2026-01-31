import SwiftUI

/// New Investment button component for investor dashboard
/// Navigates to the Discover tab (Find Trader) when tapped
struct NewInvestmentButton: View {
    @EnvironmentObject var tabRouter: TabRouter

    var body: some View {
        Button(action: {
            // Navigate to Discover tab (tab 1) which contains Find Trader
            tabRouter.selectedTab = 1
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
            .background(AppTheme.buttonColor)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .accessibilityIdentifier("NewInvestmentButton")
        .accessibilityLabel("New Investment")
        .accessibilityHint("Tap to find traders for new investment")
    }
}

#Preview {
    NewInvestmentButton()
        .environmentObject(TabRouter())
        .padding()
        .background(AppTheme.screenBackground)
}

