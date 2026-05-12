import SwiftUI

// MARK: - VVaaa-Style Table Colors
private struct TableColors {
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

// MARK: - Data Table View
struct DataTable: View {
    let columns: [TableColumn]
    let rows: [TableRowData]
    let headerColor: Color
    let headerFontWeight: Font.Weight

    init(
        columns: [TableColumn],
        rows: [TableRowData],
        headerColor: Color = TableColors.headerText,
        headerFontWeight: Font.Weight = .semibold
    ) {
        self.columns = columns
        self.rows = rows
        self.headerColor = headerColor
        self.headerFontWeight = headerFontWeight
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            // Table Header
            tableHeader

            // Table Rows
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                tableRow(row: row, index: index)
            }
        }
        .background(TableColors.rowBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var tableHeader: some View {
        HStack(spacing: ResponsiveDesign.spacing(0)) {
            ForEach(columns, id: \.id) { column in
                TableHeaderCell(column: column, headerColor: headerColor, headerFontWeight: headerFontWeight)
                    .frame(maxWidth: .infinity)
            }

            // Watchlist Column Header (integrated within table)
            Color.clear
                .frame(width: ResponsiveDesign.columnWidth(for: .watchlist))
        }
        .frame(height: 50)
        .padding(.horizontal, 8)
        .background(TableColors.headerBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.2)),
            alignment: .bottom
        )
    }

    private func tableRow(row: TableRowData, index: Int) -> some View {
        HStack(spacing: ResponsiveDesign.spacing(0)) {
            ForEach(columns, id: \.id) { column in
                VVaaaStyleDataCell(column: column, row: row)
                    .frame(maxWidth: .infinity)
            }

            // Watchlist Button (integrated within table)
            WatchlistButton(
                isInWatchlist: row.isInWatchlist ?? false,
                onToggle: row.onWatchlistToggle,
                isBusy: row.isWatchlistBusy ?? false
            )
            .frame(width: ResponsiveDesign.columnWidth(for: .watchlist))
        }
        .frame(height: 50)
        .padding(.horizontal, 8)
        .background(index % 2 == 0 ? TableColors.rowBackground : TableColors.rowBackgroundAlt)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(TableColors.separatorLine),
            alignment: .bottom
        )
    }
}

// MARK: - VVaaa-Style Data Cell
struct VVaaaStyleDataCell: View {
    let column: TableColumn
    let row: TableRowData

    var body: some View {
        if column.id == "trader" {
            // Trader name - clickable, blue color
            Button(action: {
                row.onTap?()
            }) {
                Text(row.cells[column.id] ?? "")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(TableColors.traderNameColor)
                    .frame(maxWidth: .infinity, alignment: column.alignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        } else if column.id == "return" || column.id == "returnLastTrade" {
            // Return values - green for positive, red for negative
            Text(row.cells[column.id] ?? "")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor((row.isPositive ?? true) ? TableColors.positiveValue : TableColors.negativeValue)
                .frame(maxWidth: .infinity, alignment: column.alignment)
                .minimumScaleFactor(0.8)
        } else {
            // Normal values - white text
            Text(row.cells[column.id] ?? "")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(TableColors.normalText)
                .frame(maxWidth: .infinity, alignment: column.alignment)
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
