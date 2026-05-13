import SwiftUI

// MARK: - Generic Measured Table

/// Styling constants for measured tables
public struct MeasuredTableConstants {
    public static let columnSpacing: CGFloat = 16
    public static let rowHorizontalPadding: CGFloat = 16
    public static let headerVerticalPadding: CGFloat = 4
    public static let rowVerticalPadding: CGFloat = 12
    public static let rowCornerRadius: CGFloat = 8
    public static let headerCornerRadius: CGFloat = 8
    // Fixed width for trailing action column (icons)
    public static let actionColumnWidth: CGFloat = 30
}

/// A generic, reusable measured table that avoids truncation by auto-sizing columns
public struct MeasuredTable<RowData>: View {
    public typealias ColumnKey = String

    private let rows: [RowData]
    private let header: ([ColumnKey: CGFloat]) -> AnyView
    private let measureHeader: () -> AnyView
    private let row: (RowData, Int, [ColumnKey: CGFloat]) -> AnyView
    private let measureRow: (RowData) -> AnyView

    @State private var measuredWidths: [ColumnKey: CGFloat] = [:]

    public init(
        rows: [RowData],
        header: @escaping ([ColumnKey: CGFloat]) -> AnyView,
        measureHeader: @escaping () -> AnyView,
        row: @escaping (RowData, Int, [ColumnKey: CGFloat]) -> AnyView,
        measureRow: @escaping (RowData) -> AnyView
    ) {
        self.rows = rows
        self.header = header
        self.measureHeader = measureHeader
        self.row = row
        self.measureRow = measureRow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.header(self.measuredWidths)
            ForEach(Array(self.rows.enumerated()), id: \.offset) { index, data in
                self.row(data, index, self.measuredWidths)
            }
        }
        .overlay(alignment: .topLeading) {
            ZStack {
                self.measureHeader()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(self.rows.enumerated()), id: \.offset) { _, data in
                        self.measureRow(data)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: true)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onPreferenceChange(ColumnWidthPreferenceKey.self) { widths in
            self.measuredWidths = widths
        }
    }

    /// Exposes measured widths for outer callers if needed later
    public var widths: [ColumnKey: CGFloat] { self.measuredWidths }
}
