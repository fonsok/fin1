import SwiftUI

// MARK: - Transaction Details Table
struct TransactionDetailsTable: View {
    let breakdown: TradeCalculationService.TransactionBreakdown

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            // Header
            HStack {
                Text("Transaktion")
                    .tradeCalculationHeaderStyle()
                Spacer()
                Text("Stückzahl")
                    .tradeCalculationHeaderStyle()
                Spacer()
                Text("Kurs (€)")
                    .tradeCalculationHeaderStyle()
                Spacer()
                Text("Betrag (€)")
                    .tradeCalculationHeaderStyle()
            }
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .background(AppTheme.inputFieldBackground)

            Divider()

            // Buy Transaction
            if let buyTransaction = breakdown.buyTransaction {
                TransactionRow(transaction: buyTransaction)

                // Buy Fees
                ForEach(buyTransaction.fees, id: \.name) { fee in
                    FeeRow(fee: fee)
                }

                // Buy Subtotal
                SubtotalRow(amount: buyTransaction.subtotal, label: "∑ Kauf")

                Divider()
            }

            // Sell Transactions
            ForEach(Array(breakdown.sellTransactions.enumerated()), id: \.offset) { index, sellTransaction in
                let verkaufLabel = breakdown.sellTransactions.count == 1 ? "Verkauf" : "Verkauf \(index + 1)"
                TransactionRow(transaction: sellTransaction, label: verkaufLabel)

                // Sell Fees
                ForEach(sellTransaction.fees, id: \.name) { fee in
                    FeeRow(fee: fee)
                }

                // Sell Subtotal
                let sellLabel = breakdown.sellTransactions.count == 1 ? "∑ Verkauf" : "∑ Verkauf \(index + 1)"
                SubtotalRow(amount: sellTransaction.subtotal, label: sellLabel)

                if index < breakdown.sellTransactions.count - 1 {
                    Divider()
                }
            }

            Divider()

            // Profit Before Taxes
            HStack {
                Text("Ergebnis vor Steuern")
                    .tradeCalculationMediumStyle()
                Spacer()
                Text(breakdown.profitBeforeTaxes.formatted(.currency(code: "EUR")))
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(breakdown.profitBeforeTaxes >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
            }
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .padding(.horizontal, ResponsiveDesign.spacing(12))
        }
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}
