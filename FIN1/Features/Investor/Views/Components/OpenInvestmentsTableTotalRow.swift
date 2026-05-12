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
                .foregroundColor(forMeasurement ? nil : AppTheme.fontColor)
                .modifier(cellFrame("pot", .leading))

            Text("")
                .modifier(cellFrame("status", .leading))

            Text(totalAmount.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(forMeasurement ? nil : AppTheme.fontColor)
                .modifier(cellFrame("amount", .trailing))

            Group {
                if let profit = totalProfit {
                    Text(profit.formattedAsLocalizedCurrency())
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                } else {
                    Text("not yet\(forMeasurement ? "\n" : " ")available")
                        .font(ResponsiveDesign.bodyFont())
                }
            }
            .foregroundColor(forMeasurement ? nil : AppTheme.fontColor.opacity(totalProfit == nil ? 0.7 : 1))
            .modifier(cellFrame("profit", .trailing))

            Group {
                if let returnPercentage = totalReturn {
                    Text("\(String(format: "%.0f", returnPercentage))%")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                } else {
                    Text("not yet\(forMeasurement ? "\n" : " ")available")
                        .font(ResponsiveDesign.bodyFont())
                }
            }
            .foregroundColor(
                forMeasurement
                    ? nil
                    : (totalReturn.map { $0 >= 0 ? AppTheme.accentGreen : AppTheme.accentRed } ?? AppTheme.fontColor.opacity(0.7))
            )
            .modifier(cellFrame("return", .trailing))

            Text("")
                .modifier(cellFrame("docRef", .leading))
        }
        .frame(minHeight: 44)
        .padding(.horizontal, OpenInvestmentsTableLayout.cellHorizontalPadding)
        .padding(.vertical, OpenInvestmentsTableLayout.cellVerticalPadding)
        .background(forMeasurement ? Color.clear : AppTheme.screenBackground.opacity(0.2))
    }

    private func cellFrame(_ key: String, _ alignment: Alignment) -> some ViewModifier {
        OpenInvestmentsHeaderCellModifier(
            columnKey: key,
            columnWidths: columnWidths,
            forMeasurement: forMeasurement,
            alignment: alignment
        )
    }
}
