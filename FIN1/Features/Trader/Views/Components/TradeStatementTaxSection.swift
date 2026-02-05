import SwiftUI

// MARK: - Trade Statement Tax Section
/// Displays the consolidated tax information
struct TradeStatementTaxSection: View {
    let totalAssessmentBasis: String
    let taxItems: [TaxItem]
    let totalTaxAmount: String
    let netResult: String
    let netResultColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Steuerübersicht (Gesamt)")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            // Tax Table
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                if taxItems.isEmpty {
                    // No taxes due - show simple message
                    HStack {
                        Text("Gesamtsteuerlast")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.fontColor)
                        Spacer()
                        Text("0,00 €")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.accentRed)
                    }
                    .padding(.vertical, ResponsiveDesign.spacing(8))
                    .padding(.horizontal, ResponsiveDesign.spacing(12))
                } else {
                    // Header Row
                    HStack {
                        Text("Steuerart")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)
                        Spacer()
                        Text("Basis (€)")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)
                        Spacer()
                        Text("Satz")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)
                        Spacer()
                        Text("Betrag (€)")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)
                    }
                    .padding(.vertical, ResponsiveDesign.spacing(8))
                    .padding(.horizontal, ResponsiveDesign.spacing(12))
                    .background(AppTheme.inputFieldBackground)

                    // Tax Rows
                    ForEach(taxItems, id: \.name) { tax in
                        TaxRowView(tax: tax)
                    }
                }

                // Total Tax Row (only show if there are tax items)
                if !taxItems.isEmpty {
                    HStack {
                        Text("Gesamtsteuerlast")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.fontColor)
                        Spacer()
                        Text("")
                        Spacer()
                        Text("")
                        Spacer()
                        Text(totalTaxAmount)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.accentRed)
                    }
                    .padding(.vertical, ResponsiveDesign.spacing(8))
                    .padding(.horizontal, ResponsiveDesign.spacing(12))
                }

                // Separator line
                Divider()
                    .background(AppTheme.fontColor.opacity(0.3))

                // Result after taxes row
                HStack {
                    Text("Ergebnis nach Steuern")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)
                    Spacer()
                    Text("")
                    Spacer()
                    Text("")
                    Spacer()
                    Text(netResult)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.bold)
                        .foregroundColor(netResultColor)
                }
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .padding(.horizontal, ResponsiveDesign.spacing(12))
            }
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Tax Row View
struct TaxRowView: View {
    let tax: TaxItem

    var body: some View {
        HStack {
            Text(tax.name)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            Spacer()
            Text(tax.basis)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            Spacer()
            Text(tax.rate)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            Spacer()
            Text(tax.amount)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
        }
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .padding(.horizontal, ResponsiveDesign.spacing(12))
    }
}

// MARK: - Preview
#if DEBUG
struct TradeStatementTaxSection_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTaxes = [
            TaxItem(name: "Abgeltungssteuer", basis: "6.196,62", rate: "25%", amount: "1.549,16 €"),
            TaxItem(name: "Solidaritätszuschlag", basis: "1.549,16", rate: "5,5%", amount: "85,20 €"),
            TaxItem(name: "Kirchensteuer (optional)", basis: "1.549,16", rate: "8%", amount: "123,93 €")
        ]

        TradeStatementTaxSection(
            totalAssessmentBasis: "6.196,62 EUR",
            taxItems: sampleTaxes,
            totalTaxAmount: "1.758,29 €",
            netResult: "4.438,33 EUR",
            netResultColor: AppTheme.accentGreen
        )
        .padding()
    }
}
#endif
