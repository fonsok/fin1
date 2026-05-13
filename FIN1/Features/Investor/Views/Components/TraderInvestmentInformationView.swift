import SwiftUI

// MARK: - Trader Investment Information View
/// Displays investment information for traders

struct TraderInvestmentInformationView: View {
    let trader: MockTrader

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Investment Information")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            // For now, show empty state since MockTrader doesn't have investment pools
            self.emptyInvestmentsView
        }
        .responsivePadding()
        .background(AppTheme.systemSecondaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }

    private var emptyInvestmentsView: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "building.2")
                .font(ResponsiveDesign.titleFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.3))

            Text("No investments available")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .responsivePadding()
    }
}
