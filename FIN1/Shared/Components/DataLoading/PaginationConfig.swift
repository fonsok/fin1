import Foundation

// MARK: - Pagination Configuration
struct PaginationConfig {
    let pageSize: Int
    let maxPages: Int?
    let prefetchThreshold: Int

    static let `default` = PaginationConfig(
        pageSize: 20,
        maxPages: nil,
        prefetchThreshold: 5
    )

    static let small = PaginationConfig(
        pageSize: 10,
        maxPages: 10,
        prefetchThreshold: 3
    )

    static let large = PaginationConfig(
        pageSize: 50,
        maxPages: nil,
        prefetchThreshold: 10
    )
}
