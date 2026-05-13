import SwiftUI

// MARK: - Data Cell
struct DataCell: View {
    let column: TableColumn
    let row: TableRowData

    var body: some View {
        if self.column.id == "trader" {
            // Special handling for trader name (clickable)
            Button(action: {
                self.row.onTap?()
            }) {
                Text(self.row.cells[self.column.id] ?? "")
                    .font(self.tableDataFont)
                    .fontWeight(.regular)
                    .foregroundColor(AppTheme.accentLightBlue)
                    .frame(maxWidth: .infinity, alignment: self.column.alignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            Text(self.row.cells[self.column.id] ?? "")
                .font(self.tableDataFont)
                .fontWeight((self.column.id == "return" || self.column.id == "returnLastTrade") ? .medium : .regular)
                .foregroundColor(self.cellColor)
                .frame(maxWidth: .infinity, alignment: self.column.alignment)
                .minimumScaleFactor(0.8)
                .lineLimit(nil)
        }
    }

    private var cellColor: Color {
        if self.column.id == "return" || self.column.id == "returnLastTrade" {
            return (self.row.isPositive ?? true) ? AppTheme.accentGreen : AppTheme.accentRed
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
        DataCell(column: self.column, row: self.row)
            .frame(width: self.columnWidth, alignment: self.column.alignment)
    }

    private var columnWidth: CGFloat? {
        switch self.column.width {
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
            self.row.onTap?()
        }) {
            HStack(spacing: ResponsiveDesign.spacing(0)) {
                ForEach(self.columns, id: \.id) { column in
                    TableRowCell(
                        column: column,
                        row: self.row
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
