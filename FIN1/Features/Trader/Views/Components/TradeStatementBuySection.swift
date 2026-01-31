import SwiftUI

// MARK: - Trade Statement Buy Section
/// Displays the buy transaction details
struct TradeStatementBuySection: View {
    let securityIdentifier: String
    let underlyingAsset: String?
    let orderVolume: String
    let executedVolume: String
    let price: String
    let exchangeRate: String
    let conversionFactor: String
    let custodyType: String
    let depository: String
    let depositoryCountry: String
    let profitLoss: String
    let profitLossColor: Color
    let valueDate: String
    let tradingVenue: String
    let closingDate: String
    let marketValue: String
    let commission: String
    let ownExpenses: String
    let externalExpenses: String
    let assessmentBasis: String
    let withheldTax: String
    let finalAmount: String
    let finalAmountColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // KAUF Header
            HStack {
                Text("KAUF")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(DocumentDesignSystem.textColor)
                Spacer()
            }

            // Security Information - Dynamic format
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text("WKN/ISIN: VU9GG0/DE000VU9GG06")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.regular)
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)

                let assetTypeSuffix = DepotUtils.getAssetTypeSuffix(for: underlyingAsset)
                let underlyingName = underlyingAsset ?? "DAX"
                Text("PUT - \(underlyingName) \(assetTypeSuffix)15.000 - 15.12.2023 - Vontobel")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.regular)
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
            }

            // KAUF Transaction Details - Reorganized according to specification
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                // First Group: Order Details
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    TradeStatementDetailRow(label: "Ordervolumen:", value: orderVolume)
                    TradeStatementDetailRow(label: "davon ausgef.:", value: executedVolume)
                    TradeStatementDetailRow(label: "Kurs (Ask):", value: price)
                    TradeStatementDetailRow(label: "Kurswert:", value: marketValue)
                }

                // Separator line
                Rectangle()
                    .fill(DocumentDesignSystem.textColor.opacity(0.2))
                    .frame(height: 1)

                // Second Group: Fees
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    TradeStatementDetailRow(label: "Ordergebühr:", value: commission)
                    TradeStatementDetailRow(label: "Handelsplatzgebühr:", value: ownExpenses)
                    TradeStatementDetailRow(label: "Fremdkostenpauschale:", value: externalExpenses)
                    TradeStatementDetailRow(label: "Commission:", value: commission)
                }

                // Separator line
                Rectangle()
                    .fill(DocumentDesignSystem.textColor.opacity(0.2))
                    .frame(height: 1)

                // Third Group: Sum KAUF
                TradeStatementDetailRow(
                    label: "∑ KAUF",
                    value: finalAmount,
                    valueColor: finalAmountColor,
                    isBold: true
                )

                // Separator line
                Rectangle()
                    .fill(DocumentDesignSystem.textColor.opacity(0.2))
                    .frame(height: 1)

                // Fourth Group: Additional Details
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    TradeStatementDetailRow(label: "Devisenkurs:", value: exchangeRate)
                    TradeStatementDetailRow(label: "Bew-Faktor:", value: conversionFactor)
                    TradeStatementDetailRow(label: "Verwahrart:", value: custodyType)
                    TradeStatementDetailRow(label: "Lagerstelle:", value: depository)
                    TradeStatementDetailRow(label: "Lagerland:", value: depositoryCountry)
                    TradeStatementDetailRow(label: "Valuta:", value: valueDate)
                    TradeStatementDetailRow(label: "Handelsplatz:", value: tradingVenue)
                    TradeStatementDetailRow(label: "Schlusstag:", value: closingDate)
                }
            }
        }
        .documentSection(level: 3)
    }
}

// MARK: - Detail Row Component
struct TradeStatementDetailRow: View {
    let label: String
    let value: String
    let valueColor: Color
    let isBold: Bool

    init(label: String, value: String, valueColor: Color = .primary, isBold: Bool = false) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.isBold = isBold
    }

    var body: some View {
        HStack {
            Text(label)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
            Spacer()
            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(isBold ? .regular : .light)
                .foregroundColor(valueColor == .primary ? DocumentDesignSystem.textColor : valueColor)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct TradeStatementBuySection_Previews: PreviewProvider {
    static var previews: some View {
        TradeStatementBuySection(
            securityIdentifier: "VONT.FINL PR PUT23 DAX (DE000VU9GG06/VU9GG0)",
            underlyingAsset: "DAX",
            orderVolume: "100,00 St.",
            executedVolume: "100,00 St.",
            price: "0,4100 EUR",
            exchangeRate: "",
            conversionFactor: "1,0000",
            custodyType: "GS-Verwahrung",
            depository: "Clearstream Nat.",
            depositoryCountry: "Deutschland",
            profitLoss: "-41,00 EUR",
            profitLossColor: AppTheme.accentRed,
            valueDate: "17.10.23",
            tradingVenue: "Vontobel",
            closingDate: "17.10.2023, 14:30 Uhr",
            marketValue: "41,00 EUR",
            commission: "5,90 EUR",
            ownExpenses: "",
            externalExpenses: "",
            assessmentBasis: "-41,00 EUR",
            withheldTax: "0,00 EUR",
            finalAmount: "-46,90 EUR",
            finalAmountColor: AppTheme.accentRed
        )
        .padding()
    }
}
#endif
