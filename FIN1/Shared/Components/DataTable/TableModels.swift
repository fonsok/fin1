import SwiftUI

// MARK: - Table Column Definition
struct TableColumn {
    let id: String
    let title: String
    let alignment: Alignment
    let width: ColumnWidth
    let isInteractive: Bool
    let interactiveOptions: [String]?
    let onInteractiveChange: ((String) -> Void)?
    let infoText: String? // Optional info text to show when info icon is tapped

    enum ColumnWidth {
        case flexible
        case fixed(CGFloat)
    }

    init(
        id: String,
        title: String,
        alignment: Alignment = .leading,
        width: ColumnWidth = .flexible,
        isInteractive: Bool = false,
        interactiveOptions: [String]? = nil,
        onInteractiveChange: ((String) -> Void)? = nil,
        infoText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.alignment = alignment
        self.width = width
        self.isInteractive = isInteractive
        self.interactiveOptions = interactiveOptions
        self.onInteractiveChange = onInteractiveChange
        self.infoText = infoText
    }
}

// MARK: - Table Row Data
struct TableRowData {
    let id: String
    let cells: [String: String]
    let isPositive: Bool?
    let onTap: (() -> Void)?
    let onWatchlistToggle: ((Bool) -> Void)?
    let isInWatchlist: Bool?
    let isWatchlistBusy: Bool?

    init(
        id: String,
        cells: [String: String],
        isPositive: Bool? = nil,
        onTap: (() -> Void)? = nil,
        onWatchlistToggle: ((Bool) -> Void)? = nil,
        isInWatchlist: Bool? = nil,
        isWatchlistBusy: Bool? = nil
    ) {
        self.id = id
        self.cells = cells
        self.isPositive = isPositive
        self.onTap = onTap
        self.onWatchlistToggle = onWatchlistToggle
        self.isInWatchlist = isInWatchlist
        self.isWatchlistBusy = isWatchlistBusy
    }
}
