import Foundation

// MARK: - Watchlist Filter
enum WatchlistFilter: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
    case recent = "Recent"
    
    var displayName: String { rawValue }
}
