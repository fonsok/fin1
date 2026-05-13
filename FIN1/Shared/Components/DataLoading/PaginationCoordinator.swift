import Combine
import Foundation

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
        guard self.state == .idle else { return }

        self.state = .loading
        self.currentPage = 0
        self.items.removeAll()
        self.hasMoreData = true

        do {
            let newItems = try await loadFunction(0, config.pageSize)
            self.items = newItems
            self.hasMoreData = newItems.count == self.config.pageSize
            self.state = .loaded
        } catch {
            self.state = .error(error)
        }
    }

    func loadMoreData() async {
        guard self.hasMoreData && self.state != .loadingMore else { return }

        self.state = .loadingMore
        self.currentPage += 1

        do {
            let newItems = try await loadFunction(currentPage, config.pageSize)
            self.items.append(contentsOf: newItems)
            self.hasMoreData = newItems.count == self.config.pageSize

            // Check if we've reached max pages
            if let maxPages = config.maxPages, currentPage >= maxPages {
                self.hasMoreData = false
            }

            self.state = .loaded
        } catch {
            self.state = .error(error)
            self.currentPage -= 1 // Revert page increment on error
        }
    }

    func refresh() async {
        await self.loadInitialData()
    }

    func reset() {
        self.items.removeAll()
        self.currentPage = 0
        self.hasMoreData = true
        self.state = .idle
    }

    // MARK: - Prefetching

    func shouldPrefetch(for index: Int) -> Bool {
        return index >= self.items.count - self.config.prefetchThreshold
    }

    func handlePrefetch(for index: Int) {
        if self.shouldPrefetch(for: index) {
            Task {
                await self.loadMoreData()
            }
        }
    }
}
