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
    let traderDataService: (any TraderDataServiceProtocol)?
    /// Local statement summaries (preview/tests). Empty when `monetaryServerOnly`.
    let investmentSummaries: [String: InvestorInvestmentStatementSummary]
    /// Server-canonical totals + ROI2. SSOT for € columns when `monetaryServerOnly`.
    var canonicalSummaries: [String: ServerInvestmentCanonicalSummary] = [:]
    /// When true, ROI and profit come only from `canonicalSummaries`.
    var monetaryServerOnly: Bool = false
    let onShowDetails: (Investment) -> Void

    private func returnPercentage(for investment: Investment) -> Double? {
        if let canonical = canonicalSummaries[investment.id], canonical.hasReturnPercentage {
            return canonical.returnPercentage
        }
        guard !self.monetaryServerOnly,
              let summary = investmentSummaries[investment.id],
              summary.statementTotalBuyCost > 0 else { return nil }
        let net = summary.statementGrossProfit - summary.statementCommission
        return (net / summary.statementTotalBuyCost) * 100.0
    }
    @State private var selectedInvestmentItem: InvestmentItem?
    @State private var columnWidths: [String: CGFloat] = [:]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                CompletedInvestmentsTableHeaderRow(
                    columnWidths: self.columnWidths,
                    forMeasurement: false
                )
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                .padding(.vertical, ResponsiveDesign.spacing(4))
                .background(AppTheme.sectionBackground.opacity(0.5))

                ForEach(Array(self.investments.enumerated()), id: \.element.id) { index, investment in
                    let rowModel = CompletedInvestmentsTableRowModel(
                        investment: investment,
                        summary: investmentSummaries[investment.id],
                        canonical: self.canonicalSummaries[investment.id],
                        returnPercentage: self.returnPercentage(for: investment),
                        traderDataService: self.traderDataService,
                        docNumber: self.investmentDocRefs[investment.id]?.docNumber,
                        invoiceNumber: self.investmentDocRefs[investment.id]?.invoiceNumber
                    )
                    CompletedInvestmentsTableDataRow(
                        model: rowModel,
                        isEven: index % 2 == 0,
                        columnWidths: self.columnWidths,
                        onShowCommissionExplanation: {
                            self.selectedInvestmentItem = InvestmentItem(investment: investment)
                        },
                        onShowDetails: {
                            self.onShowDetails(investment)
                        },
                        forMeasurement: false
                    )
                }
            }
        }
        .overlay(alignment: .topLeading) {
            ZStack {
                CompletedInvestmentsTableHeaderRow(
                    columnWidths: [:],
                    forMeasurement: true
                )

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    ForEach(self.investments) { investment in
                        let rowModel = CompletedInvestmentsTableRowModel(
                            investment: investment,
                            summary: investmentSummaries[investment.id],
                            canonical: self.canonicalSummaries[investment.id],
                            returnPercentage: self.returnPercentage(for: investment),
                            traderDataService: self.traderDataService,
                            docNumber: self.investmentDocRefs[investment.id]?.docNumber,
                            invoiceNumber: self.investmentDocRefs[investment.id]?.invoiceNumber
                        )
                        CompletedInvestmentsTableDataRow(
                            model: rowModel,
                            isEven: false,
                            columnWidths: [:],
                            onShowCommissionExplanation: {},
                            onShowDetails: {},
                            forMeasurement: true
                        )
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
            self.columnWidths = widths.mapValues { width in
                max(width + ResponsiveDesign.spacing(4), 40) // Minimum 40pt width
            }
        }
        .sheet(item: self.$selectedInvestmentItem) { item in
            CommissionCalculationExplanationSheet(investment: item.investment)
        }
    }
}
