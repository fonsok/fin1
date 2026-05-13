import SwiftUI

// MARK: - Reserved/Active Investments Table Component

struct OpenInvestmentsTable: View {
    let pools: [InvestmentRow]
    @Binding var columnWidths: [String: CGFloat]
    let totalAmount: Double
    let totalProfit: Double?
    let totalReturn: Double?
    let onDeleteInvestment: (InvestmentRow) -> Void
    let onShowStatusInfo: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                OpenInvestmentsTableHeaderRow(
                    columnWidths: self.columnWidths,
                    forMeasurement: false,
                    onShowStatusInfo: self.onShowStatusInfo
                )
                .frame(minHeight: 44)
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .padding(.vertical, ResponsiveDesign.spacing(6))

                ForEach(Array(self.pools.enumerated()), id: \.element.id) { index, pool in
                    OpenInvestmentsTableDataRow(
                        pool: pool,
                        isEven: index % 2 == 0,
                        columnWidths: self.columnWidths,
                        forMeasurement: false,
                        onDeleteInvestment: self.onDeleteInvestment
                    )
                }

                OpenInvestmentsTableTotalRow(
                    columnWidths: self.columnWidths,
                    totalAmount: self.totalAmount,
                    totalProfit: self.totalProfit,
                    totalReturn: self.totalReturn,
                    forMeasurement: false
                )
            }
        }
        .overlay(alignment: .topLeading) {
            ZStack {
                OpenInvestmentsTableHeaderRow(
                    columnWidths: [:],
                    forMeasurement: true,
                    onShowStatusInfo: self.onShowStatusInfo
                )

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    ForEach(self.pools) { pool in
                        OpenInvestmentsTableDataRow(
                            pool: pool,
                            isEven: false,
                            columnWidths: [:],
                            forMeasurement: true,
                            onDeleteInvestment: self.onDeleteInvestment
                        )
                    }

                    OpenInvestmentsTableTotalRow(
                        columnWidths: [:],
                        totalAmount: self.totalAmount,
                        totalProfit: self.totalProfit,
                        totalReturn: self.totalReturn,
                        forMeasurement: true
                    )
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
    }
}
