import SwiftUI

// MARK: - Tax Breakdown Table
struct TaxBreakdownTable: View {
    let breakdown: TradeCalculationService.TransactionBreakdown

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            if breakdown.profitBeforeTaxes <= 0 {
                // If profit before taxes is ≤ 0, show only the total tax burden (which will be 0)
                HStack {
                    Text("Gesamtsteuerlast")
                        .tradeCalculationBoldStyle()
                    Spacer()
                    Text("")
                    Spacer()
                    Text("")
                    Spacer()
                    Text("0,00 €")
                        .tradeCalculationBoldStyle()
                }
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .padding(.horizontal, ResponsiveDesign.spacing(12))
            } else {
                // If profit before taxes is > 0, show the full tax breakdown
                // Header
                Text("Steuerliche Abzüge und Endergebnis")
                    .tradeCalculationSectionHeaderStyle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, ResponsiveDesign.spacing(8))

                Divider()

                // Tax Header
                HStack {
                    Text("Steuerart")
                        .tradeCalculationHeaderStyle()
                    Spacer()
                    Text("Basis (€)")
                        .tradeCalculationHeaderStyle()
                    Spacer()
                    Text("Satz")
                        .tradeCalculationHeaderStyle()
                    Spacer()
                    Text("Betrag (€)")
                        .tradeCalculationHeaderStyle()
                }
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .background(AppTheme.inputFieldBackground)

                Divider()

                // Calculate taxes once and reuse
                let capitalGainsTax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: breakdown.profitBeforeTaxes)
                let solidaritySurcharge = InvoiceTaxCalculator.calculateSolidaritySurcharge(for: capitalGainsTax)
                let churchTax = InvoiceTaxCalculator.calculateChurchTax(for: capitalGainsTax)

                // Capital Gains Tax
                TaxRow(
                    name: "Abgeltungs-\nsteuer",
                    base: breakdown.profitBeforeTaxes,
                    rate: "25%",
                    amount: capitalGainsTax
                )

                // Solidarity Surcharge
                TaxRow(
                    name: "Solidaritäts\nzuschlag",
                    base: capitalGainsTax,
                    rate: "5,5%",
                    amount: solidaritySurcharge
                )

                // Church Tax
                TaxRow(
                    name: "Kirchensteuer\n(optional)",
                    base: capitalGainsTax,
                    rate: "8%",
                    amount: churchTax
                )

                Divider()

                // Total Taxes
                HStack {
                    Text("Gesamtsteuerlast")
                        .tradeCalculationBoldStyle()
                    Spacer()
                    Text("")
                    Spacer()
                    Text("")
                    Spacer()
                    Text(breakdown.totalTaxes.formatted(.currency(code: "EUR")))
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.accentRed)
                }
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .padding(.horizontal, ResponsiveDesign.spacing(12))
            }
        }
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}
