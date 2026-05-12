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
                    columnWidths: columnWidths,
                    forMeasurement: false,
                    onShowStatusInfo: onShowStatusInfo
                )
                    .frame(minHeight: 44)
                    .padding(.horizontal, ResponsiveDesign.spacing(12))
                    .padding(.vertical, ResponsiveDesign.spacing(6))

                ForEach(Array(pools.enumerated()), id: \.element.id) { index, pool in
                    OpenInvestmentsTableDataRow(
                        pool: pool,
                        isEven: index % 2 == 0,
                        columnWidths: columnWidths,
                        forMeasurement: false,
                        onDeleteInvestment: onDeleteInvestment
                    )
                }

                OpenInvestmentsTableTotalRow(
                    columnWidths: columnWidths,
                    totalAmount: totalAmount,
                    totalProfit: totalProfit,
                    totalReturn: totalReturn,
                    forMeasurement: false
                )
            }
        }
        .overlay(alignment: .topLeading) {
            ZStack {
                OpenInvestmentsTableHeaderRow(
                    columnWidths: [:],
                    forMeasurement: true,
                    onShowStatusInfo: onShowStatusInfo
                )

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    ForEach(pools) { pool in
                        OpenInvestmentsTableDataRow(
                            pool: pool,
                            isEven: false,
                            columnWidths: [:],
                            forMeasurement: true,
                            onDeleteInvestment: onDeleteInvestment
                        )
                    }

                    OpenInvestmentsTableTotalRow(
                        columnWidths: [:],
                        totalAmount: totalAmount,
                        totalProfit: totalProfit,
                        totalReturn: totalReturn,
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
            columnWidths = widths.mapValues { width in
                max(width + ResponsiveDesign.spacing(4), 40) // Minimum 40pt width
            }
        }
    }
}
