import SwiftUI

// MARK: - Trade Calculation Table Component

struct TradeCalculationTable: View {
    let breakdown: TradeCalculationService.TransactionBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            // Security Information Table
            SecurityInfoTable(breakdown: breakdown)

            // Transaction Details
            TransactionDetailsTable(breakdown: breakdown)

            // Tax Breakdown
            TaxBreakdownTable(breakdown: breakdown)

            // Final Result
            FinalResultTable(breakdown: breakdown)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Preview
#Preview {
    let sampleBreakdown = TradeCalculationService.TransactionBreakdown(
        wknIsin: "DE000VU9GG06",
        direction: "Put",
        underlying: "DAX",
        strikePrice: 15000.0,
        issuer: "Vontobel",
        buyTransaction: TransactionDetails(
            type: .buy,
            quantity: 100,
            price: 1.50,
            amount: 150.00,
            fees: [
                FeeDetail(name: "Ordergebühr", amount: -7.00),
                FeeDetail(name: "Handelsplatzgebühr", amount: -2.00),
                FeeDetail(name: "Fremdkostenpauschale", amount: 0.00)
            ],
            subtotal: 141.00
        ),
        sellTransactions: [
            TransactionDetails(
                type: .sell,
                quantity: 80,
                price: 3.00,
                amount: 240.00,
                fees: [
                    FeeDetail(name: "Ordergebühr", amount: -5.50),
                    FeeDetail(name: "Handelsplatzgebühr", amount: -1.20),
                    FeeDetail(name: "Fremdkostenpauschale", amount: 0.00)
                ],
                subtotal: 233.30
            ),
            TransactionDetails(
                type: .sell,
                quantity: 20,
                price: 1.00,
                amount: 20.00,
                fees: [
                    FeeDetail(name: "Ordergebühr", amount: -5.50),
                    FeeDetail(name: "Handelsplatzgebühr", amount: -0.30),
                    FeeDetail(name: "Fremdkostenpauschale", amount: 0.00)
                ],
                subtotal: 14.20
            )
        ],
        profitBeforeTaxes: 106.50,
        totalTaxes: 30.22,
        netResult: 76.28
    )

    ScrollView {
        TradeCalculationTable(breakdown: sampleBreakdown)
    }
    .background(AppTheme.systemSecondaryBackground)
}
