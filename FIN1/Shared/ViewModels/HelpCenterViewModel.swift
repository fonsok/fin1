import SwiftUI
import Combine

/// ViewModel for Help Center view
/// Manages FAQ data, search, and category filtering
@MainActor
final class HelpCenterViewModel: ObservableObject {
    private let faqContentService: (any FAQContentServiceProtocol)?

    // MARK: - Published Properties

    @Published var selectedCategory: FAQCategoryContent?
    @Published var searchQuery: String = ""
    @Published var expandedFAQIds: Set<String> = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadFailed: Bool = false
    @Published private(set) var faqs: [FAQContentItem] = []
    @Published private(set) var categories: [FAQCategoryContent] = []

    init(faqContentService: (any FAQContentServiceProtocol)? = nil) {
        self.faqContentService = faqContentService

        Task { [weak self] in
            await self?.loadServerFAQsIfAvailable()
        }
    }

    func reload() async {
        await loadServerFAQsIfAvailable()
    }

    // MARK: - Computed Properties

    var hasNoFAQs: Bool {
        !isLoading && categories.isEmpty && faqs.isEmpty
    }

    var filteredFAQs: [FAQContentItem] {
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            return faqs.filter { faq in
                faq.question.lowercased().contains(q) || faq.answer.lowercased().contains(q)
            }
        }

        if let category = selectedCategory {
            return faqs(for: category)
        }

        return faqs
    }

    var hasSearchResults: Bool {
        !searchQuery.isEmpty && !filteredFAQs.isEmpty
    }

    var hasNoSearchResults: Bool {
        !searchQuery.isEmpty && filteredFAQs.isEmpty
    }

    // MARK: - Methods

    func toggleFAQ(_ faq: FAQContentItem) {
        if expandedFAQIds.contains(faq.id) {
            expandedFAQIds.remove(faq.id)
        } else {
            expandedFAQIds.insert(faq.id)
        }
    }

    func isExpanded(_ faq: FAQContentItem) -> Bool {
        expandedFAQIds.contains(faq.id)
    }

    func selectCategory(_ category: FAQCategoryContent?) {
        selectedCategory = category
        // Clear search when selecting a category
        if category != nil {
            searchQuery = ""
        }
    }

    func clearFilters() {
        selectedCategory = nil
        searchQuery = ""
    }

    private func loadServerFAQsIfAvailable() async {
        guard let faqContentService else { return }
        isLoading = true
        loadFailed = false
        do {
            let categories = try await faqContentService.fetchFAQCategories(location: "help_center")
            let faqs = try await faqContentService.fetchFAQsForHelpCenter()

            if !categories.isEmpty, !faqs.isEmpty {
                self.categories = categories
                self.faqs = faqs
            }
        } catch {
            loadFailed = true
            self.categories = []
            self.faqs = []
        }
        isLoading = false
    }

    func faqs(for category: FAQCategoryContent) -> [FAQContentItem] {
        faqs.filter { $0.categoryId == category.id }
    }
}










