import SwiftUI

// MARK: - Security Information Table
struct SecurityInfoTable: View {
    let breakdown: TradeCalculationService.TransactionBreakdown

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            // Header
            HStack {
                Text("WKN/ISIN")
                    .tradeCalculationHeaderStyle()
                Spacer()
                Text("Richtung")
                    .tradeCalculationHeaderStyle()
                Spacer()
                Text("Basiswert")
                    .tradeCalculationHeaderStyle()
                Spacer()
                Text("Strike")
                    .tradeCalculationHeaderStyle()
            }
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .background(AppTheme.inputFieldBackground)

            Divider()

            // Data Row
            HStack {
                Text(breakdown.wknIsin)
                    .tradeCalculationValueStyle()
                Spacer()
                Text(breakdown.direction)
                    .tradeCalculationValueStyle()
                Spacer()
                Text(breakdown.underlying)
                    .tradeCalculationValueStyle()
                Spacer()
                Text(breakdown.strikePrice?.formatted(.number.precision(.fractionLength(2))) ?? "N/A")
                    .tradeCalculationValueStyle()
            }
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .padding(.horizontal, ResponsiveDesign.spacing(12))
        }
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}
