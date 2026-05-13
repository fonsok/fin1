import SwiftUI

struct CompletedInvestmentsTableHeaderRow: View {
    let columnWidths: [String: CGFloat]
    let forMeasurement: Bool

    var body: some View {
        HStack(spacing: CompletedInvestmentsTableLayout.columnSpacing) {
            Group {
                Text("Investment Nr.")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(CompletedInvestmentsHeaderCellModifier(
                columnKey: "investmentNr",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .leading
            ))

            Group {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Trader")
                    Text("Username")
                }
                .font(ResponsiveDesign.captionFont())
            }
            .modifier(CompletedInvestmentsHeaderCellModifier(
                columnKey: "traderUsername",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .leading
            ))

            Group {
                Text("Trade Nr.")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(CompletedInvestmentsHeaderCellModifier(
                columnKey: "tradeNr",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .leading
            ))

            Group {
                Text("InvestAmount (€)")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(CompletedInvestmentsHeaderCellModifier(
                columnKey: "amount",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .trailing
            ))

            Group {
                Text("Gross Profit (€)")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(CompletedInvestmentsHeaderCellModifier(
                columnKey: "profit",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .trailing
            ))

            Group {
                Text("Return (%)")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(CompletedInvestmentsHeaderCellModifier(
                columnKey: "return",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .trailing
            ))

            Group {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Beleg /")
                    Text("Rechnung")
                }
                .font(ResponsiveDesign.captionFont())
            }
            .modifier(CompletedInvestmentsHeaderCellModifier(
                columnKey: "docRef",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .leading
            ))

            Group {
                Text("Details")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(CompletedInvestmentsHeaderCellModifier(
                columnKey: "details",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .center
            ))
        }
    }
}
