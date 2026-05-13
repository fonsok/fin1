import Combine
import SwiftUI

/// ViewModel for Help Center view
/// Manages FAQ data, search, and category filtering
@MainActor
final class HelpCenterViewModel: ObservableObject {
    private let faqContentBridge: UncheckedFAQContentServiceBridge?
    private let userRole: String?

    // MARK: - Published Properties

    @Published var selectedCategory: FAQCategoryContent?
    @Published var searchQuery: String = ""
    @Published var expandedFAQIds: Set<String> = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadFailed: Bool = false
    @Published private(set) var faqs: [FAQContentItem] = []
    @Published private(set) var categories: [FAQCategoryContent] = []

    init(faqContentService: (any FAQContentServiceProtocol)? = nil, userRole: String? = nil) {
        self.faqContentBridge = faqContentService.map { UncheckedFAQContentServiceBridge(service: $0) }
        self.userRole = userRole

        Task { @MainActor [weak self] in
            await self?.loadServerFAQsIfAvailable()
        }
    }

    func reload() async {
        await self.loadServerFAQsIfAvailable(forceRefresh: true)
    }

    // MARK: - Computed Properties

    var hasNoFAQs: Bool {
        !self.isLoading && self.categories.isEmpty && self.faqs.isEmpty
    }

    var filteredFAQs: [FAQContentItem] {
        if !self.searchQuery.isEmpty {
            let q = self.searchQuery.lowercased()
            return self.faqs.filter { faq in
                faq.question.lowercased().contains(q) || faq.answer.lowercased().contains(q)
            }
        }

        if let category = selectedCategory {
            return self.faqs(for: category)
        }

        return self.faqs
    }

    var hasSearchResults: Bool {
        !self.searchQuery.isEmpty && !self.filteredFAQs.isEmpty
    }

    var hasNoSearchResults: Bool {
        !self.searchQuery.isEmpty && self.filteredFAQs.isEmpty
    }

    // MARK: - Methods

    func toggleFAQ(_ faq: FAQContentItem) {
        if self.expandedFAQIds.contains(faq.id) {
            self.expandedFAQIds.remove(faq.id)
        } else {
            self.expandedFAQIds.insert(faq.id)
        }
    }

    func isExpanded(_ faq: FAQContentItem) -> Bool {
        self.expandedFAQIds.contains(faq.id)
    }

    func selectCategory(_ category: FAQCategoryContent?) {
        self.selectedCategory = category
        // Clear search when selecting a category
        if category != nil {
            self.searchQuery = ""
        }
    }

    func clearFilters() {
        self.selectedCategory = nil
        self.searchQuery = ""
    }

    private func loadServerFAQsIfAvailable(forceRefresh: Bool = false) async {
        guard let faqContentBridge else { return }
        self.isLoading = true
        self.loadFailed = false
        do {
            if forceRefresh {
                await faqContentBridge.clearCache(location: "help_center", userRole: self.userRole)
            }
            let categories = try await faqContentBridge.fetchFAQCategories(location: "help_center", userRole: self.userRole)
            let faqs = try await faqContentBridge.fetchFAQsForHelpCenter(userRole: self.userRole)
            // Always apply a successful response (even if empty) so retry/refresh replaces stale data.
            self.categories = categories
            self.faqs = faqs
        } catch {
            self.loadFailed = true
            self.categories = []
            self.faqs = []
        }
        self.isLoading = false
    }

    func faqs(for category: FAQCategoryContent) -> [FAQContentItem] {
        self.faqs.filter { $0.categoryId == category.id }
    }
}










