import SwiftUI

struct OpenInvestmentsTableDataRow: View {
    let pool: InvestmentRow
    let isEven: Bool
    let columnWidths: [String: CGFloat]
    let forMeasurement: Bool
    let onDeleteInvestment: (InvestmentRow) -> Void

    var body: some View {
        HStack(spacing: OpenInvestmentsTableLayout.columnSpacing) {
            Text(pool.uniqueDisplayLabel)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(forMeasurement ? nil : AppTheme.fontColor)
                .modifier(cellFrame("pool", .leading))

            statusCell
                .modifier(cellFrame("status", pool.isDeletable ? .center : .leading))
                .contentShape(Rectangle())

            Text(pool.amount.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(forMeasurement ? nil : AppTheme.fontColor)
                .modifier(cellFrame("amount", .trailing))

            profitCell
                .modifier(cellFrame("profit", .trailing))

            returnCell
                .modifier(cellFrame("return", .trailing))

            InvestmentDocRefView(verrechnungNumber: pool.docNumber, rechnungNumber: pool.invoiceNumber)
                .modifier(cellFrame("docRef", .leading))
        }
        .frame(minHeight: 44)
        .padding(.horizontal, OpenInvestmentsTableLayout.cellHorizontalPadding)
        .padding(.vertical, OpenInvestmentsTableLayout.cellVerticalPadding)
        .background(forMeasurement ? Color.clear : (isEven ? AppTheme.screenBackground.opacity(0.3) : AppTheme.screenBackground.opacity(0.1)))
    }

    @ViewBuilder
    private var statusCell: some View {
        HStack(spacing: ResponsiveDesign.spacing(2)) {
            if pool.isDeletable {
                if !pool.statusDisplayText.isEmpty {
                    Text(pool.statusDisplayText)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(forMeasurement ? nil : AppTheme.fontColor)
                }

                if forMeasurement {
                    Image(systemName: "trash")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                } else {
                    Button(action: { onDeleteInvestment(pool) }) {
                        Image(systemName: "trash")
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                Text(pool.statusDisplayText)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(forMeasurement ? nil : pool.status.displayColor)
            }
        }
    }

    @ViewBuilder
    private var profitCell: some View {
        if let profit = pool.profit {
            Text(profit.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(forMeasurement ? nil : (profit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed))
        } else {
            let placeholder = pool.status == .completed ? 0.0.formattedAsLocalizedCurrency() : ""
            Text(placeholder).font(ResponsiveDesign.bodyFont())
        }
    }

    @ViewBuilder
    private var returnCell: some View {
        if let returnPercentage = pool.returnPercentage {
            Text("\(String(format: "%.0f", returnPercentage))%")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(forMeasurement ? nil : (returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed))
        } else {
            let placeholder = pool.status == .completed ? "0%" : ""
            Text(placeholder).font(ResponsiveDesign.bodyFont())
        }
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
