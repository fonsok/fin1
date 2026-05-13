import SwiftUI

struct CompletedInvestmentsTableDataRow: View {
    let model: CompletedInvestmentsTableRowModel
    let isEven: Bool
    let columnWidths: [String: CGFloat]
    let onShowCommissionExplanation: () -> Void
    let onShowDetails: () -> Void
    let forMeasurement: Bool

    var body: some View {
        HStack(spacing: CompletedInvestmentsTableLayout.columnSpacing) {
            Text(self.model.investmentNumber)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.forMeasurement ? nil : AppTheme.fontColor)
                .modifier(self.cellFrame("investmentNr", .leading))

            Text(self.model.traderUsername)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.forMeasurement ? nil : AppTheme.fontColor)
                .modifier(self.cellFrame("traderUsername", .leading))

            Text(self.model.tradeNumberText)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.forMeasurement ? nil : AppTheme.fontColor)
                .modifier(self.cellFrame("tradeNr", .leading))

            Text(self.model.amount.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.forMeasurement ? nil : AppTheme.fontColor)
                .modifier(self.cellFrame("amount", .trailing))

            self.profitView
                .modifier(self.cellFrame("profit", .trailing))

            self.returnView
                .modifier(self.cellFrame("return", .trailing))

            InvestmentDocRefView(verrechnungNumber: self.model.docNumber, rechnungNumber: self.model.invoiceNumber)
                .modifier(self.cellFrame("docRef", .leading))

            self.detailsView
                .modifier(self.cellFrame("details", .center))
        }
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
        .padding(.vertical, ResponsiveDesign.spacing(4))
        .background(self.forMeasurement ? Color.clear : (self.isEven ? AppTheme.screenBackground : AppTheme.sectionBackground.opacity(0.3)))
    }

    @ViewBuilder
    private var profitView: some View {
        Group {
            if self.model.isCancelled {
                Text("cancelled")
            } else if let grossProfit = model.grossProfit {
                Text(grossProfit.formattedAsLocalizedCurrency())
            } else {
                Text(self.forMeasurement ? "Awaiting invoices" : "Awaiting invoices")
                    .italic(!self.forMeasurement)
            }
        }
        .font(ResponsiveDesign.bodyFont())
        .foregroundColor({
            if self.forMeasurement { return nil }
            if self.model.isCancelled { return AppTheme.fontColor }
            guard let grossProfit = model.grossProfit else { return AppTheme.fontColor.opacity(0.7) }
            return grossProfit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
        }())
    }

    @ViewBuilder
    private var returnView: some View {
        HStack(spacing: ResponsiveDesign.spacing(2)) {
            Group {
                if self.model.isCancelled {
                    Text("---")
                } else if let returnPercentage = model.returnPercentage {
                    Text(String(format: "%.2f%%", returnPercentage))
                } else {
                    Text(self.forMeasurement ? "pending" : "pending")
                        .italic(!self.forMeasurement)
                }
            }
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor({
                if self.forMeasurement { return nil }
                if self.model.isCancelled { return AppTheme.fontColor }
                guard let returnPercentage = model.returnPercentage else { return AppTheme.fontColor.opacity(0.7) }
                return returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
            }())

            if !self.forMeasurement, !self.model.isCancelled, let profit = model.grossProfit, profit > 0 {
                Button(action: self.onShowCommissionExplanation) {
                    Image(systemName: "info.circle")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.7))
                        .foregroundColor(AppTheme.accentLightBlue.opacity(0.7))
                }
            } else if self.forMeasurement, !self.model.isCancelled, let profit = model.grossProfit, profit > 0 {
                Image(systemName: "info.circle")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.7))
            }
        }
    }

    @ViewBuilder
    private var detailsView: some View {
        if self.forMeasurement {
            Image(systemName: "doc.text")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
        } else {
            Button(action: self.onShowDetails) {
                Image(systemName: "doc.text")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
        }
    }

    private func cellFrame(_ key: String, _ alignment: Alignment) -> some ViewModifier {
        CompletedInvestmentsHeaderCellModifier(
            columnKey: key,
            columnWidths: self.columnWidths,
            forMeasurement: self.forMeasurement,
            alignment: alignment
        )
    }
}

private extension View {
    @ViewBuilder
    func italic(_ enabled: Bool) -> some View {
        if enabled {
            self.italic()
        } else {
            self
        }
    }
}
