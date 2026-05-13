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
    /// Source-of-truth für Gross Profit, Commission, Total Buy Cost. Dieselben Werte
    /// sind auf der Investor Collection Bill abgedruckt.
    let investmentSummaries: [String: InvestorInvestmentStatementSummary]
    /// Server-canonical ROI2 pro Investment-ID (optional). Wenn vorhanden,
    /// wird dieser Wert bevorzugt gegenüber der lokalen Ableitung aus
    /// `investmentSummaries`. Fallback-Design: nie "pending" anzeigen, solange
    /// die lokale Ableitung verfügbar ist. Task 5a.
    var canonicalSummaries: [String: ServerInvestmentCanonicalSummary] = [:]
    let onShowDetails: (Investment) -> Void

    /// ROI2 = (Gross Profit − Commission) / Total Buy Cost × 100.
    /// Reihenfolge: (1) Server-canonical aus `canonicalSummaries` (SSOT für ROI2);
    /// (2) lokale Ableitung aus `investmentSummaries`, die dasselbe Aggregator-Resultat
    /// nutzt wie die Collection-Bill-PDF.
    private func returnPercentage(for investment: Investment) -> Double? {
        if let canonical = canonicalSummaries[investment.id], canonical.hasReturnPercentage {
            return canonical.returnPercentage
        }
        guard let summary = investmentSummaries[investment.id],
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
                        returnPercentage: self.returnPercentage(for: investment),
                        traderUsername: self.traderUsernames[investment.id] ?? "---",
                        tradeNumberText: self.tradeNumbers[investment.id] ?? "---",
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
                            returnPercentage: self.returnPercentage(for: investment),
                            traderUsername: self.traderUsernames[investment.id] ?? "---",
                            tradeNumberText: self.tradeNumbers[investment.id] ?? "---",
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
