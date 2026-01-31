import Foundation
import Combine

// MARK: - Pagination Coordinator
/// Coordinates pagination state and data loading for paginated lists
@MainActor
final class PaginationCoordinator<T: Identifiable>: ObservableObject {
    @Published var items: [T] = []
    @Published var state: PaginationState = .idle
    @Published var currentPage: Int = 0
    @Published var hasMoreData: Bool = true

    private let config: PaginationConfig
    private let loadFunction: (Int, Int) async throws -> [T]
    private var cancellables = Set<AnyCancellable>()

    init(config: PaginationConfig = .default, loadFunction: @escaping (Int, Int) async throws -> [T]) {
        self.config = config
        self.loadFunction = loadFunction
    }

    // MARK: - Public Methods

    func loadInitialData() async {
        guard state == .idle else { return }

        state = .loading
        currentPage = 0
        items.removeAll()
        hasMoreData = true

        do {
            let newItems = try await loadFunction(0, config.pageSize)
            items = newItems
            hasMoreData = newItems.count == config.pageSize
            state = .loaded
        } catch {
            state = .error(error)
        }
    }

    func loadMoreData() async {
        guard hasMoreData && state != .loadingMore else { return }

        state = .loadingMore
        currentPage += 1

        do {
            let newItems = try await loadFunction(currentPage, config.pageSize)
            items.append(contentsOf: newItems)
            hasMoreData = newItems.count == config.pageSize

            // Check if we've reached max pages
            if let maxPages = config.maxPages, currentPage >= maxPages {
                hasMoreData = false
            }

            state = .loaded
        } catch {
            state = .error(error)
            currentPage -= 1 // Revert page increment on error
        }
    }

    func refresh() async {
        await loadInitialData()
    }

    func reset() {
        items.removeAll()
        currentPage = 0
        hasMoreData = true
        state = .idle
    }

    // MARK: - Prefetching

    func shouldPrefetch(for index: Int) -> Bool {
        return index >= items.count - config.prefetchThreshold
    }

    func handlePrefetch(for index: Int) {
        if shouldPrefetch(for: index) {
            Task {
                await loadMoreData()
            }
        }
    }
}
