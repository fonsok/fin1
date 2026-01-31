import SwiftUI

// MARK: - Data Cell
struct DataCell: View {
    let column: TableColumn
    let row: TableRowData

    var body: some View {
        if column.id == "trader" {
            // Special handling for trader name (clickable)
            Button(action: {
                row.onTap?()
            }) {
                Text(row.cells[column.id] ?? "")
                    .font(tableDataFont)
                    .fontWeight(.regular)
                    .foregroundColor(AppTheme.accentLightBlue)
                    .frame(maxWidth: .infinity, alignment: column.alignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            Text(row.cells[column.id] ?? "")
                .font(tableDataFont)
                .fontWeight((column.id == "return" || column.id == "returnLastTrade") ? .medium : .regular)
                .foregroundColor(cellColor)
                .frame(maxWidth: .infinity, alignment: column.alignment)
                .minimumScaleFactor(0.8)
                .lineLimit(nil)
        }
    }

    private var cellColor: Color {
        if column.id == "return" || column.id == "returnLastTrade" {
            return (row.isPositive ?? true) ? AppTheme.accentGreen : AppTheme.accentRed
        }
        return AppTheme.fontColor.opacity(0.8)
    }

    // Slightly enlarged font for table data cells
    private var tableDataFont: Font {
        if ResponsiveDesign.isCompactDevice() {
            return .subheadline
        } else if ResponsiveDesign.isLargeDevice() {
            return .headline
        }
        return .body
    }
}

// MARK: - Table Row Cell
struct TableRowCell: View {
    let column: TableColumn
    let row: TableRowData

    var body: some View {
        DataCell(column: column, row: row)
            .frame(width: columnWidth, alignment: column.alignment)
    }

    private var columnWidth: CGFloat? {
        switch column.width {
        case .flexible:
            return nil
        case .fixed(let width):
            return width
        }
    }
}

// MARK: - Table Row View
struct TableRowView: View {
    let row: TableRowData
    let columns: [TableColumn]

    var body: some View {
        Button(action: {
            row.onTap?()
        }) {
            HStack(spacing: ResponsiveDesign.spacing(0)) {
                ForEach(columns, id: \.id) { column in
                    TableRowCell(
                        column: column,
                        row: row
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
