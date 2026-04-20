import SwiftUI

// MARK: - Investment Item Wrapper for Sheet
struct InvestmentItem: Identifiable {
    let id: String
    let investment: Investment

    init(investment: Investment) {
        self.id = investment.id
        self.investment = investment
    }
}

// MARK: - Completed Investments Table Component

struct CompletedInvestmentsTable: View {
    let investments: [Investment]
    /// Beleg-/Rechnungsnummern pro Investment-ID (aus ViewModel, MVVM).
    let investmentDocRefs: [String: (docNumber: String?, invoiceNumber: String?)]
    /// Trader-Username pro Investment-ID (aus ViewModel, MVVM).
    let traderUsernames: [String: String]
    /// Trade-Nummer pro Investment-ID (aus ViewModel, MVVM).
    let tradeNumbers: [String: String]
    /// Statement-Summaries pro Investment-ID (aus ViewModel, MVVM).
    let investmentSummaries: [String: InvestorInvestmentStatementSummary]
    /// Server-calculated Return-% pro Investment-ID (Single Source of Truth).
    let tradeLedReturnPercentages: [String: Double]
    let onShowDetails: (Investment) -> Void
    @State private var selectedInvestmentItem: InvestmentItem?
    @State private var columnWidths: [String: CGFloat] = [:]

    // Table Configuration Constants
    private var tableColumnSpacing: CGFloat {
        ResponsiveDesign.spacing(8)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                // Table Header
                headerContent(columnWidths: columnWidths, forMeasurement: false)
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.vertical, ResponsiveDesign.spacing(4))
                    .background(AppTheme.sectionBackground.opacity(0.5))

                // Table Rows
                ForEach(Array(investments.enumerated()), id: \.element.id) { index, investment in
                    completedInvestmentRow(
                        investment: investment,
                        isEven: index % 2 == 0,
                        columnWidths: columnWidths,
                        onShowCommissionExplanation: {
                            selectedInvestmentItem = InvestmentItem(investment: investment)
                        }
                    )
                }
            }
        }
        .overlay(alignment: .topLeading) {
            // Hidden measurement views
            ZStack {
                // Measure header cells
                headerContent(columnWidths: [:], forMeasurement: true)

                // Measure data rows
                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    ForEach(investments) { investment in
                        measurementRow(investment: investment)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: true)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onPreferenceChange(ColumnWidthPreferenceKey.self) { widths in
            // Add small padding to each column width for breathing room
            columnWidths = widths.mapValues { width in
                max(width + ResponsiveDesign.spacing(4), 40) // Minimum 40pt width
            }
        }
        .sheet(item: $selectedInvestmentItem) { item in
            CommissionCalculationExplanationSheet(investment: item.investment)
        }
    }

    // MARK: - Header Content Builder (DRY)

    @ViewBuilder
    private func headerContent(columnWidths: [String: CGFloat], forMeasurement: Bool) -> some View {
        HStack(spacing: tableColumnSpacing) {
            Group {
                Text("Investment Nr.")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "investmentNr",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .leading
            ))

            Group {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Trader")
                    Text("Username")
                }
                .font(ResponsiveDesign.captionFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "traderUsername",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .leading
            ))

            Group {
                Text("Trade Nr.")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "tradeNr",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .leading
            ))

            Group {
                Text("InvestAmount (€)")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "amount",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .trailing
            ))

            Group {
                Text("Profit (€)")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "profit",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .trailing
            ))

            Group {
                Text("Return (%)")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "return",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .trailing
            ))

            Group {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Beleg /")
                    Text("Rechnung")
                }
                .font(ResponsiveDesign.captionFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "docRef",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .leading
            ))

            Group {
                Text("Details")
                    .font(ResponsiveDesign.captionFont())
            }
            .modifier(HeaderCellModifier(
                columnKey: "details",
                columnWidths: columnWidths,
                forMeasurement: forMeasurement,
                alignment: .center
            ))
        }
    }

    // MARK: - Header Cell Modifier

    private struct HeaderCellModifier: ViewModifier {
        let columnKey: String
        let columnWidths: [String: CGFloat]
        let forMeasurement: Bool
        let alignment: Alignment

        func body(content: Content) -> some View {
            if forMeasurement {
                content
                    .measureWidth(column: columnKey)
            } else {
                content
                    .foregroundColor(AppTheme.fontColor)
                    .frame(width: columnWidths[columnKey] ?? defaultWidth, alignment: alignment)
            }
        }

        private var defaultWidth: CGFloat {
            switch columnKey {
            case "investmentNr": return 80
            case "traderUsername": return 60
            case "tradeNr": return 50
            case "amount": return 80
            case "profit": return 80
            case "return": return 60
            case "docRef": return 100
            case "details": return 40
            default: return 60
            }
        }
    }

    // MARK: - Measurement Row (Hidden)

    @ViewBuilder
    private func measurementRow(investment: Investment) -> some View {
        let summary = investmentSummaries[investment.id]
        let grossProfit = summary?.statementGrossProfit
        let returnPercentage = tradeLedReturnPercentages[investment.id]
        let isCancelled = investment.status == .cancelled
        let traderUsername = traderUsernames[investment.id] ?? "---"
        let tradeNumberText = tradeNumbers[investment.id] ?? "---"

        HStack(spacing: tableColumnSpacing) {
            Text(investment.id.extractInvestmentNumber())
                .font(ResponsiveDesign.bodyFont())
                .measureWidth(column: "investmentNr")

            Text(traderUsername)
                .font(ResponsiveDesign.bodyFont())
                .measureWidth(column: "traderUsername")

            Text(tradeNumberText)
                .font(ResponsiveDesign.bodyFont())
                .measureWidth(column: "tradeNr")

            Text(investment.amount.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .measureWidth(column: "amount")

            Group {
                if isCancelled {
                    Text("cancelled")
                } else if let grossProfit = grossProfit {
                    Text(grossProfit.formattedAsLocalizedCurrency())
                } else {
                    Text("Awaiting invoices")
                }
            }
            .font(ResponsiveDesign.bodyFont())
            .measureWidth(column: "profit")

            Group {
                if isCancelled {
                    Text("---")
                } else if summary != nil, let returnPercentage {
                    Text(String(format: "%.2f%", returnPercentage))
                } else {
                    Text("pending")
                }
            }
            .font(ResponsiveDesign.bodyFont())
            .measureWidth(column: "return")

            InvestmentDocRefView(
                verrechnungNumber: investmentDocRefs[investment.id]?.docNumber,
                rechnungNumber: investmentDocRefs[investment.id]?.invoiceNumber
            )
            .measureWidth(column: "docRef")

            Image(systemName: "doc.text")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                .measureWidth(column: "details")
        }
    }

    // MARK: - Table Row

    private func completedInvestmentRow(
        investment: Investment,
        isEven: Bool,
        columnWidths: [String: CGFloat],
        onShowCommissionExplanation: @escaping () -> Void
    ) -> some View {
        let summary = investmentSummaries[investment.id]
        let grossProfit = summary?.statementGrossProfit
        let returnPercentage = tradeLedReturnPercentages[investment.id]
        let isCancelled = investment.status == .cancelled
        let traderUsername = traderUsernames[investment.id] ?? "---"
        let tradeNumberText = tradeNumbers[investment.id] ?? "---"

        return HStack(spacing: tableColumnSpacing) {
            Text(investment.id.extractInvestmentNumber())
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(width: columnWidths["investmentNr"] ?? 80, alignment: .leading)

            Text(traderUsername)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(width: columnWidths["traderUsername"] ?? 60, alignment: .leading)

            Text(tradeNumberText)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(width: columnWidths["tradeNr"] ?? 50, alignment: .leading)

            Text(investment.amount.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(width: columnWidths["amount"] ?? 80, alignment: .trailing)

            // Profit = currentValue - amount (actual monetary profit)
            Group {
                if isCancelled {
                    Text("cancelled")
                } else if let grossProfit = grossProfit {
                    Text(grossProfit.formattedAsLocalizedCurrency())
                } else {
                    Text("Awaiting invoices")
                        .italic()
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
            }
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor({
                    if isCancelled { return AppTheme.fontColor }
                    guard let grossProfit = grossProfit else { return AppTheme.fontColor }
                    return grossProfit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
                }())
                .frame(width: columnWidths["profit"] ?? 80, alignment: .trailing)

            // Return = performance percentage with info icon
            HStack(spacing: ResponsiveDesign.spacing(2)) {
                Group {
                    if isCancelled {
                        Text("---")
                    } else if summary != nil, let returnPercentage {
                        Text(String(format: "%.2f%", returnPercentage))
                    } else {
                        Text("pending")
                            .italic()
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    }
                }
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor({
                    if isCancelled { return AppTheme.fontColor }
                    guard let _ = summary, let returnPercentage else { return AppTheme.fontColor }
                    return returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
                }())

                if !isCancelled, let profit = grossProfit, profit > 0 {
                    Button(action: onShowCommissionExplanation, label: {
                        Image(systemName: "info.circle")
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.7))
                            .foregroundColor(AppTheme.accentLightBlue.opacity(0.7))
                    })
                }
            }
            .frame(width: columnWidths["return"] ?? 60, alignment: .trailing)

            // Beleg / Rechnung (Account Statement + Service Charge Invoice)
            InvestmentDocRefView(
                verrechnungNumber: investmentDocRefs[investment.id]?.docNumber,
                rechnungNumber: investmentDocRefs[investment.id]?.invoiceNumber
            )
            .frame(width: columnWidths["docRef"] ?? 100, alignment: .leading)

            // Details Button
            Button(action: {
                onShowDetails(investment)
            }) {
                Image(systemName: "doc.text")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
            .frame(width: columnWidths["details"] ?? 40, alignment: .center)
        }
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
        .padding(.vertical, ResponsiveDesign.spacing(4))
        .background(isEven ? AppTheme.screenBackground : AppTheme.sectionBackground.opacity(0.3))
    }

}
