import SwiftUI

struct OpenInvestmentsTableHeaderRow: View {
    let columnWidths: [String: CGFloat]
    let forMeasurement: Bool
    let onShowStatusInfo: () -> Void

    var body: some View {
        HStack(spacing: OpenInvestmentsTableLayout.columnSpacing) {
            Group {
                Text("Investment")
                    .font(ResponsiveDesign.bodyFont())
            }
            .modifier(OpenInvestmentsHeaderCellModifier(
                columnKey: "pool",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .leading
            ))

            Group {
                HStack(spacing: ResponsiveDesign.spacing(2)) {
                    Text("Status")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(self.forMeasurement ? .clear : AppTheme.fontColor)

                    if self.forMeasurement {
                        Image(systemName: "info.circle")
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                    } else {
                        Button(action: self.onShowStatusInfo) {
                            Image(systemName: "info.circle")
                                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        }
                    }
                }
            }
            .modifier(OpenInvestmentsHeaderCellModifier(
                columnKey: "status",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .leading
            ))

            Group {
                Text("Amount (€)")
                    .font(ResponsiveDesign.bodyFont())
            }
            .modifier(OpenInvestmentsHeaderCellModifier(
                columnKey: "amount",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .trailing
            ))

            Group {
                Text("Profit (€)")
                    .font(ResponsiveDesign.bodyFont())
            }
            .modifier(OpenInvestmentsHeaderCellModifier(
                columnKey: "profit",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .trailing
            ))

            Group {
                Text("Return (%)")
                    .font(ResponsiveDesign.bodyFont())
            }
            .modifier(OpenInvestmentsHeaderCellModifier(
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
                .font(ResponsiveDesign.bodyFont())
            }
            .modifier(OpenInvestmentsHeaderCellModifier(
                columnKey: "docRef",
                columnWidths: self.columnWidths,
                forMeasurement: self.forMeasurement,
                alignment: .leading
            ))
        }
    }
}
