import SwiftUI

// MARK: - Trade Statement Sell Section
/// Displays the sell transaction details for multiple sell orders
struct TradeStatementSellSection: View {
    let sellOrderData: [SellOrderData]
    let securityIdentifier: String
    let underlyingAsset: String?
    let tradingVenue: String
    let profitLoss: String
    let profitLossColor: Color
    let assessmentBasis: String
    let withheldTax: String
    let finalAmountColor: Color

    var body: some View {
        ForEach(Array(self.sellOrderData.enumerated()), id: \.offset) { index, sellOrder in
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                // VERKAUF Header
                HStack {
                    let verkaufLabel = self.sellOrderData.count == 1 ? "VERKAUF" : "VERKAUF - Nr. \(index + 1)/\(self.sellOrderData.count)"
                    Text(verkaufLabel)
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(DocumentDesignSystem.textColor)
                    Spacer()
                }

                // Security Information (WKN - Richtung - Basiswert - Strike - Emittent aus Rechnung)
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(self.securityIdentifier)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.regular)
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)
                }

                // VERKAUF Transaction Details - Reorganized according to specification
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    // First Group: Order Details
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        TradeStatementDetailRow(label: "Ordervolumen:", value: sellOrder.orderVolume)
                        TradeStatementDetailRow(label: "davon ausgef.:", value: sellOrder.orderVolume)
                        TradeStatementDetailRow(label: "Kurs (Bid):", value: sellOrder.price)
                        TradeStatementDetailRow(label: "Kurswert:", value: sellOrder.marketValue)
                    }

                    // Separator line
                    Rectangle()
                        .fill(DocumentDesignSystem.textColor.opacity(0.2))
                        .frame(height: 1)

                    // Second Group: Fees
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        TradeStatementDetailRow(label: "Ordergebühr:", value: sellOrder.commission)
                        TradeStatementDetailRow(label: "Handelsplatzgebühr:", value: sellOrder.ownExpenses)
                        TradeStatementDetailRow(label: "Fremdkostenpauschale:", value: sellOrder.externalExpenses)
                    }

                    // Separator line
                    Rectangle()
                        .fill(DocumentDesignSystem.textColor.opacity(0.2))
                        .frame(height: 1)

                    // Third Group: Sum VERKAUF
                    TradeStatementDetailRow(
                        label: "∑ VERKAUF",
                        value: sellOrder.finalAmount,
                        valueColor: self.finalAmountColor,
                        isBold: true
                    )

                    // Separator line
                    Rectangle()
                        .fill(DocumentDesignSystem.textColor.opacity(0.2))
                        .frame(height: 1)

                    // Fourth Group: Additional Details
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        TradeStatementDetailRow(label: "Devisenkurs:", value: "")
                        TradeStatementDetailRow(label: "Bew-Faktor:", value: "1,0000")
                        TradeStatementDetailRow(label: "Verwahrart:", value: "GS-Verwahrung")
                        TradeStatementDetailRow(label: "Lagerstelle:", value: "Clearstream Nat.")
                        TradeStatementDetailRow(label: "Lagerland:", value: "Deutschland")
                        TradeStatementDetailRow(label: "Valuta:", value: sellOrder.valueDate)
                        TradeStatementDetailRow(label: "Handelsplatz:", value: self.tradingVenue)
                        TradeStatementDetailRow(label: "Schlusstag:", value: sellOrder.closingDate)
                    }
                }
            }
            .documentSection(level: 3)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct TradeStatementSellSection_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSellOrder = SellOrderData(
            transactionNumber: "288/2",
            invoice: Invoice(
                id: "sample-invoice",
                invoiceNumber: "INV-001",
                type: .securitiesSettlement,
                customerInfo: CustomerInfo(
                    name: "Max Mustermann",
                    address: "Musterstraße 1",
                    city: "Musterstadt",
                    postalCode: "12345",
                    taxNumber: "123456789",
                    depotNumber: "104801",
                    bank: "Vontobel",
                    customerNumber: "CUST001"
                ),
                items: []
            )
        )

        TradeStatementSellSection(
            sellOrderData: [sampleSellOrder],
            securityIdentifier: "VONT.FINL PR PUT23 DAX (DE000VU9GG06/VU9GG0)",
            underlyingAsset: "DAX",
            tradingVenue: TradeStatementPlaceholders.tradingVenue,
            profitLoss: "12,53 EUR",
            profitLossColor: AppTheme.accentGreen,
            assessmentBasis: "12,53 EUR",
            withheldTax: "0,00 EUR",
            finalAmountColor: AppTheme.accentGreen
        )
        .padding()
    }
}
#endif
