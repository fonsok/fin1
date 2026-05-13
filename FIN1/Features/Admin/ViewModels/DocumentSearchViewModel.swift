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
        if self.filters.types.contains(type) {
            self.filters.types.removeAll { $0 == type }
        } else {
            self.filters.types.append(type)
        }
        self.scheduleDebouncedSearch()
    }

    func clearAllFilters() {
        self.filters = DocumentSearchFilters()
        self.scheduleDebouncedSearch(immediate: true)
    }

    /// Triggers a fresh page-1 search (debounced for free-text fields).
    func scheduleDebouncedSearch(immediate: Bool = false) {
        self.debounceTask?.cancel()
        if immediate {
            Task { await self.search(reset: true) }
            return
        }
        self.debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.search(reset: true)
        }
    }

    func loadMoreIfNeeded(currentItem: Document) async {
        guard self.hasMore, !self.isLoadingMore else { return }
        guard let last = items.last, last.id == currentItem.id else { return }
        await self.search(reset: false)
    }

    func refresh() async {
        await self.search(reset: true)
    }

    private func search(reset: Bool) async {
        let searchId = UUID()
        self.inFlightSearchId = searchId

        if reset {
            self.isLoading = true
            self.currentPage = DocumentSearchPage(limit: self.currentPage.limit, skip: 0)
        } else {
            self.isLoadingMore = true
            self.currentPage.skip += self.currentPage.limit
        }
        self.errorMessage = nil

        defer {
            if reset { isLoading = false } else { isLoadingMore = false }
        }

        do {
            let result = try await searchService.searchDocuments(self.filters, page: self.currentPage)
            guard self.inFlightSearchId == searchId else { return }
            if reset {
                self.items = result.items
            } else {
                let known = Set(items.map(\.id))
                self.items.append(contentsOf: result.items.filter { !known.contains($0.id) })
            }
            self.hasMore = result.hasMore
        } catch {
            guard self.inFlightSearchId == searchId else { return }
            if !reset {
                self.currentPage.skip = max(0, self.currentPage.skip - self.currentPage.limit)
            }
            self.errorMessage = error.localizedDescription
        }
    }
}
