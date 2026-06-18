import Foundation

/// Client-side paging helpers (mirrors admin `PaginationBar` slice math).
enum ClientSideListPagination {
    static let defaultPageSize = PaginationConfig.small.pageSize

    static func totalPages(total: Int, pageSize: Int) -> Int {
        max(1, Int(ceil(Double(total) / Double(max(pageSize, 1)))))
    }

    static func slice<T>(_ items: [T], page: Int, pageSize: Int) -> [T] {
        guard !items.isEmpty else { return [] }
        let safePage = max(0, min(page, self.totalPages(total: items.count, pageSize: pageSize) - 1))
        let start = safePage * pageSize
        guard start < items.count else { return [] }
        return Array(items[start..<min(start + pageSize, items.count)])
    }

    static func displayRange(page: Int, pageSize: Int, total: Int) -> (from: Int, to: Int) {
        guard total > 0 else { return (0, 0) }
        let safePage = max(0, min(page, self.totalPages(total: total, pageSize: pageSize) - 1))
        let from = safePage * pageSize + 1
        let to = min((safePage + 1) * pageSize, total)
        return (from, to)
    }

    static func shouldPaginate(total: Int, threshold: Int = 2) -> Bool {
        total > threshold
    }
}

enum ListSortOrder: String, CaseIterable, Sendable {
    case newestFirst
    case oldestFirst

    var displayName: String {
        switch self {
        case .newestFirst: return "Neueste zuerst"
        case .oldestFirst: return "Älteste zuerst"
        }
    }
}

enum CompletedInvestmentOutcomeFilter: String, CaseIterable, Sendable {
    case all
    case completedOnly
    case cancelledOnly

    var displayName: String {
        switch self {
        case .all: return "Alle"
        case .completedOnly: return "Abgeschlossen"
        case .cancelledOnly: return "Storniert"
        }
    }
}
