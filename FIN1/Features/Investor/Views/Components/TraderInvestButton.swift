import SwiftUI

// MARK: - Trader Invest Button
/// Investment button for trader details view

struct TraderInvestButton: View {
    let trader: MockTrader
    @Binding var showInvestSheet: Bool

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Investment Button
            Button(action: {
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
                        gradient: Gradient(colors: [AppTheme.accentGreen, AppTheme.accentGreen]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("InvestWithTraderButton")
        }
    }
}
