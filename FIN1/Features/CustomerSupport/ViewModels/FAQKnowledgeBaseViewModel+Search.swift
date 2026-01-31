import Foundation
import Combine

// MARK: - FAQKnowledgeBaseViewModel + Search & Filtering
/// Extension handling search, filtering, and article selection

extension FAQKnowledgeBaseViewModel {

    // MARK: - Search

    func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await faqService.searchArticles(query: query)
        } catch {
            handleError(error)
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }

    // MARK: - Filter

    func selectCategory(_ category: KnowledgeBaseCategory?) {
        selectedCategory = category
        applyFilters()
    }

    func toggleUnpublished() {
        showUnpublished.toggle()
        Task { await load() }
    }

    func toggleArchived() {
        showArchived.toggle()
        Task { await load() }
    }

    func applyFilters() {
        var result = articles

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !showUnpublished {
            result = result.filter { $0.isPublished }
        }

        if !showArchived {
            result = result.filter { !$0.isArchived }
        }

        filteredArticles = result
    }

    // MARK: - Article Selection

    func selectArticle(_ article: FAQArticle) {
        selectedArticle = article
        showArticleDetail = true

        // Record view
        Task {
            try? await faqService.recordView(articleId: article.id)
        }
    }

    func deselectArticle() {
        selectedArticle = nil
        showArticleDetail = false
    }
}

