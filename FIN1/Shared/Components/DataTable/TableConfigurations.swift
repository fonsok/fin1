import SwiftUI

// MARK: - Predefined Table Configurations
extension DataTable {
    static func traderPerformanceTable(
        rows: [TableRowData],
        showTraderColumn: Bool = true,
        isInteractive: Bool = false,
        onInteractiveChange: ((String) -> Void)? = nil
    ) -> DataTable {
        var columns: [TableColumn] = []

        if showTraderColumn {
            columns.append(TableColumn(
                id: "trader",
                title: "Trader",
                alignment: .leading,
                width: .fixed(ResponsiveDesign.columnWidth(for: .trader))
            ))
        }

        columns.append(TableColumn(
            id: "return",
            title: "Return\nlast\nTrade",
            alignment: .center,
            width: .fixed(ResponsiveDesign.columnWidth(for: .`return`))
        ))

        columns.append(TableColumn(
            id: "successRate",
            title: "Overall\nSuccess\nRate",
            alignment: .center,
            width: .fixed(ResponsiveDesign.columnWidth(for: .successRate)),
            infoText: "Overall Success Rate shows what percentage of trades had positive returns (ROI > 0%). It measures how often the trader wins, regardless of the size of wins or losses.\nExample:\nIf a trader has 80% success rate, it means, on average, 8 out of 10 trades had positive returns.\n\nROI = Return On Investment"
        ))

        columns.append(TableColumn(
            id: "avgReturnPerTrade",
            title: "∅Return\nper\nTrade",
            alignment: .center,
            width: .fixed(ResponsiveDesign.columnWidth(for: .avgReturnPerTrade)),
            infoText: "Ø-Return per Trade shows the average ROI percentage across all trades (both wins and losses combined). It measures the average return per trade. This can be negative if losses outweigh wins, or positive if gains are larger.\nExample:\nIf a trader has 36% average return, it means the average ROI across all trades is 36%.\n\nROI = Return On Investment"
        ))

        return DataTable(columns: columns, rows: rows)
    }
}
