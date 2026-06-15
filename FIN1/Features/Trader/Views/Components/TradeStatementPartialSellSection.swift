import SwiftUI

// MARK: - Trade Statement Partial Sell Section (Teilverkauf-Fortschritt)

struct TradeStatementPartialSellSection: View {
    let partialSell: PartialSellDisplayData

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("TEILVERKAUF")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(DocumentDesignSystem.textColor)
                Spacer()
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                TradeStatementDetailRow(label: "Reihenfolge:", value: self.partialSell.sequenceLabel)
                TradeStatementDetailRow(label: "Ausgeführt am:", value: self.partialSell.executedAt)
                TradeStatementDetailRow(label: "Verkaufsorder:", value: self.partialSell.sellOrderId)
                TradeStatementDetailRow(label: "Dieser Verkauf:", value: self.partialSell.thisSellQuantity)
                TradeStatementDetailRow(label: "Verkauft (kumulativ):", value: self.partialSell.cumulativeSold)
                TradeStatementDetailRow(label: "Verbleibend:", value: self.partialSell.remaining)
                TradeStatementDetailRow(label: "Fortschritt:", value: self.partialSell.progress)
            }
        }
        .documentSection(level: 2)
    }
}
