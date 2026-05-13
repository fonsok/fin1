import SwiftUI

struct OpenInvestmentsTableTotalRow: View {
    let columnWidths: [String: CGFloat]
    let totalAmount: Double
    let totalProfit: Double?
    let totalReturn: Double?
    let forMeasurement: Bool

    var body: some View {
        HStack(spacing: OpenInvestmentsTableLayout.columnSpacing) {
            Text("Total")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(self.forMeasurement ? nil : AppTheme.fontColor)
                .modifier(self.cellFrame("pool", .leading))

            Text("")
                .modifier(self.cellFrame("status", .leading))

            Text(self.totalAmount.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(self.forMeasurement ? nil : AppTheme.fontColor)
                .modifier(self.cellFrame("amount", .trailing))

            Group {
                if let profit = totalProfit {
                    Text(profit.formattedAsLocalizedCurrency())
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                } else {
                    Text("not yet\(self.forMeasurement ? "\n" : " ")available")
                        .font(ResponsiveDesign.bodyFont())
                }
            }
            .foregroundColor(self.forMeasurement ? nil : AppTheme.fontColor.opacity(self.totalProfit == nil ? 0.7 : 1))
            .modifier(self.cellFrame("profit", .trailing))

            Group {
                if let returnPercentage = totalReturn {
                    Text("\(String(format: "%.0f", returnPercentage))%")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                } else {
                    Text("not yet\(self.forMeasurement ? "\n" : " ")available")
                        .font(ResponsiveDesign.bodyFont())
                }
            }
            .foregroundColor(
                self.forMeasurement
                    ? nil
                    : (self.totalReturn.map { $0 >= 0 ? AppTheme.accentGreen : AppTheme.accentRed } ?? AppTheme.fontColor.opacity(0.7))
            )
            .modifier(self.cellFrame("return", .trailing))

            Text("")
                .modifier(self.cellFrame("docRef", .leading))
        }
        .frame(minHeight: 44)
        .padding(.horizontal, OpenInvestmentsTableLayout.cellHorizontalPadding)
        .padding(.vertical, OpenInvestmentsTableLayout.cellVerticalPadding)
        .background(self.forMeasurement ? Color.clear : AppTheme.screenBackground.opacity(0.2))
    }

    private func cellFrame(_ key: String, _ alignment: Alignment) -> some ViewModifier {
        OpenInvestmentsHeaderCellModifier(
            columnKey: key,
            columnWidths: self.columnWidths,
            forMeasurement: self.forMeasurement,
            alignment: alignment
        )
    }
}
