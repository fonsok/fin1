import SwiftUI

// MARK: - Investment Header View
/// Displays trader information in the investment sheet header
struct InvestmentHeaderView: View {
    let trader: MockTrader
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack {
            Text("Investment plan:")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)

            Text(self.trader.username)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Spacer()
        }
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }
}

// MARK: - Preview
#Preview {
    InvestmentHeaderView(trader: mockTraders[0])
        .responsivePadding()
        .background(AppTheme.screenBackground)
}
