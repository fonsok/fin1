import Foundation

// MARK: - Pagination State
enum PaginationState: Equatable {
    case idle
    case loading
    case loaded
    case loadingMore
    case noMoreData
    case error(Error)

    static func == (lhs: PaginationState, rhs: PaginationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded), (.loadingMore, .loadingMore), (.noMoreData, .noMoreData):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}
