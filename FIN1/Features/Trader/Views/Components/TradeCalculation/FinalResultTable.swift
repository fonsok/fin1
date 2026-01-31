import SwiftUI

// MARK: - Final Result Table
struct FinalResultTable: View {
    let breakdown: TradeCalculationService.TransactionBreakdown

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            HStack {
                Text("Ergebnis nach Steuern und Gebühren")
                    .tradeCalculationBoldStyle()
                Spacer()
                Text(breakdown.netResult.formatted(.currency(code: "EUR")))
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.bold)
                    .foregroundColor(breakdown.netResult >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
            }
            .padding(.vertical, ResponsiveDesign.spacing(12))
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .background(AppTheme.accentLightBlue.opacity(0.2))
        }
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}
