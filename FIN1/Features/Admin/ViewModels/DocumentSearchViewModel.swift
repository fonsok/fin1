import Foundation
import SwiftUI

@MainActor
final class DocumentSearchViewModel: ObservableObject {
    @Published var filters = DocumentSearchFilters()

    @Published private(set) var items: [Document] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = false
    @Published private(set) var errorMessage: String?

    private let searchService: any DocumentSearchAPIServiceProtocol
    private var currentPage = DocumentSearchPage()
    private var inFlightSearchId: UUID = UUID()
    private var debounceTask: Task<Void, Never>?

    init(searchService: any DocumentSearchAPIServiceProtocol) {
        self.searchService = searchService
    }

    /// Available document type filter options. Excludes internal/onboarding-only types.
    static var selectableTypes: [DocumentType] {
        [
            .invoice,
            .traderCollectionBill,
            .investorCollectionBill,
            .traderCreditNote,
            .investmentReservationEigenbeleg,
            .monthlyAccountStatement,
            .financial,
            .tax,
            .other,
        ]
    }

    func toggleType(_ type: DocumentType) {
        if filters.types.contains(type) {
            filters.types.removeAll { $0 == type }
        } else {
            filters.types.append(type)
        }
        scheduleDebouncedSearch()
    }

    func clearAllFilters() {
        filters = DocumentSearchFilters()
        scheduleDebouncedSearch(immediate: true)
    }

    /// Triggers a fresh page-1 search (debounced for free-text fields).
    func scheduleDebouncedSearch(immediate: Bool = false) {
        debounceTask?.cancel()
        if immediate {
            Task { await self.search(reset: true) }
            return
        }
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.search(reset: true)
        }
    }

    func loadMoreIfNeeded(currentItem: Document) async {
        guard hasMore, !isLoadingMore else { return }
        guard let last = items.last, last.id == currentItem.id else { return }
        await search(reset: false)
    }

    func refresh() async {
        await search(reset: true)
    }

    private func search(reset: Bool) async {
        let searchId = UUID()
        inFlightSearchId = searchId

        if reset {
            isLoading = true
            currentPage = DocumentSearchPage(limit: currentPage.limit, skip: 0)
        } else {
            isLoadingMore = true
            currentPage.skip += currentPage.limit
        }
        errorMessage = nil

        defer {
            if reset { isLoading = false } else { isLoadingMore = false }
        }

        do {
            let result = try await searchService.searchDocuments(filters, page: currentPage)
            guard inFlightSearchId == searchId else { return }
            if reset {
                items = result.items
            } else {
                let known = Set(items.map(\.id))
                items.append(contentsOf: result.items.filter { !known.contains($0.id) })
            }
            hasMore = result.hasMore
        } catch {
            guard inFlightSearchId == searchId else { return }
            if !reset {
                currentPage.skip = max(0, currentPage.skip - currentPage.limit)
            }
            errorMessage = error.localizedDescription
        }
    }
}
