import SwiftUI

struct OpenInvestmentsTableDataRow: View {
    let pool: InvestmentRow
    let isEven: Bool
    let columnWidths: [String: CGFloat]
    let forMeasurement: Bool
    let onDeleteInvestment: (InvestmentRow) -> Void

    var body: some View {
        HStack(spacing: OpenInvestmentsTableLayout.columnSpacing) {
            Text(self.pool.uniqueDisplayLabel)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.forMeasurement ? nil : AppTheme.fontColor)
                .modifier(self.cellFrame("pool", .leading))

            self.statusCell
                .modifier(self.cellFrame("status", self.pool.isDeletable ? .center : .leading))
                .contentShape(Rectangle())

            Text(self.pool.amount.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.forMeasurement ? nil : AppTheme.fontColor)
                .modifier(self.cellFrame("amount", .trailing))

            self.profitCell
                .modifier(self.cellFrame("profit", .trailing))

            self.returnCell
                .modifier(self.cellFrame("return", .trailing))

            InvestmentDocRefView(verrechnungNumber: self.pool.docNumber, rechnungNumber: self.pool.invoiceNumber)
                .modifier(self.cellFrame("docRef", .leading))
        }
        .frame(minHeight: 44)
        .padding(.horizontal, OpenInvestmentsTableLayout.cellHorizontalPadding)
        .padding(.vertical, OpenInvestmentsTableLayout.cellVerticalPadding)
        .background(
            self.forMeasurement ? Color.clear : (
                self.isEven ? AppTheme.screenBackground.opacity(0.3) : AppTheme.screenBackground.opacity(0.1)
            )
        )
    }

    @ViewBuilder
    private var statusCell: some View {
        HStack(spacing: ResponsiveDesign.spacing(2)) {
            if self.pool.isDeletable {
                if !self.pool.statusDisplayText.isEmpty {
                    Text(self.pool.statusDisplayText)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(self.forMeasurement ? nil : AppTheme.fontColor)
                }

                if self.forMeasurement {
                    Image(systemName: "trash")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                } else {
                    Button(action: { self.onDeleteInvestment(self.pool) }) {
                        Image(systemName: "trash")
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                Text(self.pool.statusDisplayText)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(self.forMeasurement ? nil : self.pool.status.displayColor)
            }
        }
    }

    @ViewBuilder
    private var profitCell: some View {
        if let profit = pool.profit {
            Text(profit.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.forMeasurement ? nil : (profit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed))
        } else {
            let placeholder = self.pool.status == .completed ? 0.0.formattedAsLocalizedCurrency() : ""
            Text(placeholder).font(ResponsiveDesign.bodyFont())
        }
    }

    @ViewBuilder
    private var returnCell: some View {
        if let returnPercentage = pool.returnPercentage {
            Text("\(String(format: "%.0f", returnPercentage))%")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.forMeasurement ? nil : (returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed))
        } else {
            let placeholder = self.pool.status == .completed ? "0%" : ""
            Text(placeholder).font(ResponsiveDesign.bodyFont())
        }
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
