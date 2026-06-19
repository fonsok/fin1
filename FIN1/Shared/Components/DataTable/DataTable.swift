import SwiftUI

// MARK: - VVaaa-Style Table Colors
enum DataTableColors {
    static let headerBackground = Color(red: 0.05, green: 0.10, blue: 0.20)
    static let rowBackground = Color(red: 0.08, green: 0.13, blue: 0.23)
    static let rowBackgroundAlt = Color(red: 0.06, green: 0.11, blue: 0.21)
    static let separatorLine = Color.white.opacity(0.1)
    static let headerText = Color.white.opacity(0.8)
    static let traderNameColor = Color(red: 0.4, green: 0.7, blue: 1.0)
    static let positiveValue = AppTheme.accentGreen
    static let negativeValue = AppTheme.accentRed
    static let normalText = Color.white
}

enum DataTableLayout {
    /// Rounded card with inset border (discovery, trader details).
    case card
    /// Full-width list rows — keeps table band colors, no outer card wrapper (dashboard).
    case flatList
}

// MARK: - Data Table View
struct DataTable: View {
    let columns: [TableColumn]
    let rows: [TableRowData]
    let headerColor: Color
    let headerFontWeight: Font.Weight
    let layout: DataTableLayout

    init(
        columns: [TableColumn],
        rows: [TableRowData],
        headerColor: Color = DataTableColors.headerText,
        headerFontWeight: Font.Weight = .semibold,
        layout: DataTableLayout = .card
    ) {
        self.columns = columns
        self.rows = rows
        self.headerColor = headerColor
        self.headerFontWeight = headerFontWeight
        self.layout = layout
    }

    var body: some View {
        switch self.layout {
        case .card:
            self.cardTableBody
        case .flatList:
            self.flatListTableBody
        }
    }

    private var cardTableBody: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            self.tableHeader

            ForEach(Array(self.rows.enumerated()), id: \.element.id) { index, row in
                self.tableRow(row: row, index: index)
            }
        }
        .background(DataTableColors.rowBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var flatListTableBody: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            self.flatListHeaderRow

            ForEach(Array(self.rows.enumerated()), id: \.element.id) { index, row in
                self.flatListDataRow(row: row, index: index)
            }
        }
    }

    private var flatListHeaderRow: some View {
        self.tableHeaderContent
            .frame(minWidth: self.minimumTableWidth, alignment: .leading)
            .stripedListSection(
                stripeIndex: 0,
                solidBackground: DataTableColors.headerBackground,
                verticalPadding: ResponsiveDesign.spacing(10)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.white.opacity(0.2)),
                alignment: .bottom
            )
    }

    private func flatListDataRow(row: TableRowData, index: Int) -> some View {
        self.tableRowContent(row: row)
            .frame(minWidth: self.minimumTableWidth, alignment: .leading)
            .stripedListSection(
                stripeIndex: 0,
                solidBackground: index.isMultiple(of: 2)
                    ? DataTableColors.rowBackground
                    : DataTableColors.rowBackgroundAlt,
                verticalPadding: ResponsiveDesign.spacing(10)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DataTableColors.separatorLine),
                alignment: .bottom
            )
    }

    private var minimumTableWidth: CGFloat {
        let columnWidth = self.columns.reduce(into: CGFloat(0)) { total, column in
            if case .fixed(let width) = column.width {
                total += width
            }
        }
        return columnWidth + ResponsiveDesign.columnWidth(for: .watchlist)
    }

    private var tableHeader: some View {
        self.tableHeaderContent
            .frame(height: 50)
            .padding(.horizontal, 8)
            .background(DataTableColors.headerBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.white.opacity(0.2)),
                alignment: .bottom
            )
    }

    private var tableHeaderContent: some View {
        HStack(spacing: ResponsiveDesign.spacing(0)) {
            ForEach(self.columns, id: \.id) { column in
                TableHeaderCell(column: column, headerColor: self.headerColor, headerFontWeight: self.headerFontWeight)
                    .frame(maxWidth: .infinity)
            }

            Color.clear
                .frame(width: ResponsiveDesign.columnWidth(for: .watchlist))
        }
        .frame(height: 50)
    }

    private func tableRow(row: TableRowData, index: Int) -> some View {
        self.tableRowContent(row: row)
            .frame(height: 50)
            .padding(.horizontal, 8)
            .background(
                index.isMultiple(of: 2)
                    ? DataTableColors.rowBackground
                    : DataTableColors.rowBackgroundAlt
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DataTableColors.separatorLine),
                alignment: .bottom
            )
    }

    private func tableRowContent(row: TableRowData) -> some View {
        HStack(spacing: ResponsiveDesign.spacing(0)) {
            ForEach(self.columns, id: \.id) { column in
                VVaaaStyleDataCell(column: column, row: row)
                    .frame(maxWidth: .infinity)
            }

            WatchlistButton(
                isInWatchlist: row.isInWatchlist ?? false,
                onToggle: row.onWatchlistToggle,
                isBusy: row.isWatchlistBusy ?? false
            )
            .frame(width: ResponsiveDesign.columnWidth(for: .watchlist))
        }
        .frame(height: 50)
    }
}

// MARK: - VVaaa-Style Data Cell
struct VVaaaStyleDataCell: View {
    let column: TableColumn
    let row: TableRowData

    var body: some View {
        if self.column.id == "trader" {
            // Trader name - clickable, blue color
            Button(action: {
                self.row.onTap?()
            }) {
                Text(self.row.cells[self.column.id] ?? "")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(DataTableColors.traderNameColor)
                    .frame(maxWidth: .infinity, alignment: self.column.alignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        } else if self.column.id == "return" || self.column.id == "returnLastTrade" {
            // Return values - green for positive, red for negative
            Text(self.row.cells[self.column.id] ?? "")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor((self.row.isPositive ?? true) ? DataTableColors.positiveValue : DataTableColors.negativeValue)
                .frame(maxWidth: .infinity, alignment: self.column.alignment)
                .minimumScaleFactor(0.8)
        } else {
            // Normal values - white text
            Text(self.row.cells[self.column.id] ?? "")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(DataTableColors.normalText)
                .frame(maxWidth: .infinity, alignment: self.column.alignment)
                .minimumScaleFactor(0.8)
        }
    }
}

#Preview {
    let sampleRows = [
        TableRowData(
            id: "1",
            cells: [
                "trader": "Johnson",
                "return": "153%",
                "avgReturn": "128%",
                "successRate": "78.0%",
                "avgTrades": "12.5"
            ],
            isPositive: true,
            onTap: { print("Trader tapped") },
            onWatchlistToggle: { isWatched in print("Watchlist: \(isWatched)") },
            isInWatchlist: false
        )
    ]

    return DataTable.traderPerformanceTable(rows: sampleRows)
        .padding()
        .background(AppTheme.screenBackground)
}
