import SwiftUI

// MARK: - Trade Statement Calculation Section

/// Displays the calculation breakdown for "Ergebnis vor Steuern"
struct TradeStatementCalculationSection: View {
    let calculationBreakdown: CalculationBreakdownData

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // Section Title
            Text("Berechnung Ergebnis vor Steuern")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            // Calculation Breakdown
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                // Sell amounts
                ForEach(Array(calculationBreakdown.sellAmounts.enumerated()), id: \.offset) { index, sellAmount in
                    HStack {
                        if index == 0 {
                            Text("∑ Verkauf")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                        } else {
                            Text("∑ Verkauf \(index + 1)")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                        }
                        Spacer()
                        Text("+ \(sellAmount)")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)
                    }
                }

                // Separator line
                Divider()
                    .background(AppTheme.fontColor.opacity(0.3))

                // Buy amount
                HStack {
                    Text("∑ Kauf")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                    Spacer()
                    Text("- \(calculationBreakdown.buyAmount)")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)
                }

                // Separator line
                Divider()
                    .background(AppTheme.fontColor.opacity(0.3))

                // Result before taxes
                HStack {
                    Text("= Ergebnis vor Steuern")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)
                    Spacer()
                    Text(calculationBreakdown.resultBeforeTaxes)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.bold)
                        .foregroundColor(calculationBreakdown.resultBeforeTaxesColor == "fin1AccentGreen" ? AppTheme.accentGreen : AppTheme.accentRed)
                }

                // Final separator line
                Rectangle()
                    .fill(AppTheme.fontColor.opacity(0.5))
                    .frame(height: 2)
            }
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    TradeStatementCalculationSection(
        calculationBreakdown: CalculationBreakdownData(
            sellAmounts: ["1.200,00 €", "800,00 €", "600,00 €"],
            totalSellAmount: "2.600,00 €",
            buyAmount: "2.000,00 €",
            resultBeforeTaxes: "600,00 €",
            resultBeforeTaxesColor: "fin1AccentGreen"
        )
    )
    .background(AppTheme.screenBackground)
}
