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
            Text(model.investmentNumber)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(forMeasurement ? nil : AppTheme.fontColor)
                .modifier(cellFrame("investmentNr", .leading))

            Text(model.traderUsername)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(forMeasurement ? nil : AppTheme.fontColor)
                .modifier(cellFrame("traderUsername", .leading))

            Text(model.tradeNumberText)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(forMeasurement ? nil : AppTheme.fontColor)
                .modifier(cellFrame("tradeNr", .leading))

            Text(model.amount.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(forMeasurement ? nil : AppTheme.fontColor)
                .modifier(cellFrame("amount", .trailing))

            profitView
                .modifier(cellFrame("profit", .trailing))

            returnView
                .modifier(cellFrame("return", .trailing))

            InvestmentDocRefView(verrechnungNumber: model.docNumber, rechnungNumber: model.invoiceNumber)
                .modifier(cellFrame("docRef", .leading))

            detailsView
                .modifier(cellFrame("details", .center))
        }
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
        .padding(.vertical, ResponsiveDesign.spacing(4))
        .background(forMeasurement ? Color.clear : (isEven ? AppTheme.screenBackground : AppTheme.sectionBackground.opacity(0.3)))
    }

    @ViewBuilder
    private var profitView: some View {
        Group {
            if model.isCancelled {
                Text("cancelled")
            } else if let grossProfit = model.grossProfit {
                Text(grossProfit.formattedAsLocalizedCurrency())
            } else {
                Text(forMeasurement ? "Awaiting invoices" : "Awaiting invoices")
                    .italic(!forMeasurement)
            }
        }
        .font(ResponsiveDesign.bodyFont())
        .foregroundColor({
            if forMeasurement { return nil }
            if model.isCancelled { return AppTheme.fontColor }
            guard let grossProfit = model.grossProfit else { return AppTheme.fontColor.opacity(0.7) }
            return grossProfit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
        }())
    }

    @ViewBuilder
    private var returnView: some View {
        HStack(spacing: ResponsiveDesign.spacing(2)) {
            Group {
                if model.isCancelled {
                    Text("---")
                } else if let returnPercentage = model.returnPercentage {
                    Text(String(format: "%.2f%%", returnPercentage))
                } else {
                    Text(forMeasurement ? "pending" : "pending")
                        .italic(!forMeasurement)
                }
            }
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor({
                if forMeasurement { return nil }
                if model.isCancelled { return AppTheme.fontColor }
                guard let returnPercentage = model.returnPercentage else { return AppTheme.fontColor.opacity(0.7) }
                return returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
            }())

            if !forMeasurement, !model.isCancelled, let profit = model.grossProfit, profit > 0 {
                Button(action: onShowCommissionExplanation) {
                    Image(systemName: "info.circle")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.7))
                        .foregroundColor(AppTheme.accentLightBlue.opacity(0.7))
                }
            } else if forMeasurement, !model.isCancelled, let profit = model.grossProfit, profit > 0 {
                Image(systemName: "info.circle")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.7))
            }
        }
    }

    @ViewBuilder
    private var detailsView: some View {
        if forMeasurement {
            Image(systemName: "doc.text")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
        } else {
            Button(action: onShowDetails) {
                Image(systemName: "doc.text")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
        }
    }

    private func cellFrame(_ key: String, _ alignment: Alignment) -> some ViewModifier {
        CompletedInvestmentsHeaderCellModifier(
            columnKey: key,
            columnWidths: columnWidths,
            forMeasurement: forMeasurement,
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
