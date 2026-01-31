import Foundation
import Combine

// MARK: - FAQ Knowledge Base ViewModel
/// ViewModel for FAQ Knowledge Base views
/// Handles article browsing, search, and management

@MainActor
final class FAQKnowledgeBaseViewModel: ObservableObject {

    // MARK: - Dependencies

    let faqService: FAQKnowledgeBaseServiceProtocol
    let auditService: AuditLoggingServiceProtocol
    var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties - UI State

    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    @Published var successMessage: String?

    // MARK: - Published Properties - Articles

    @Published var articles: [FAQArticle] = []
    @Published var filteredArticles: [FAQArticle] = []
    @Published var popularArticles: [FAQArticle] = []
    @Published var recentArticles: [FAQArticle] = []
    @Published var articlesNeedingReview: [FAQArticle] = []

    // MARK: - Published Properties - Search

    @Published var searchQuery = ""
    @Published var searchResults: [FAQSearchResult] = []
    @Published var isSearching = false

    // MARK: - Published Properties - Filter

    @Published var selectedCategory: KnowledgeBaseCategory?
    @Published var showUnpublished = false
    @Published var showArchived = false

    // MARK: - Published Properties - Selection

    @Published var selectedArticle: FAQArticle?

    // MARK: - Published Properties - Sheets

    @Published var showCreateArticleSheet = false
    @Published var showEditArticleSheet = false
    @Published var showArticleDetail = false
    @Published var showStatistics = false

    // MARK: - Published Properties - Create/Edit

    @Published var editingArticle: FAQArticle?
    @Published var newArticleTitle = ""
    @Published var newArticleSummary = ""
    @Published var newArticleContent = ""
    @Published var newArticleCategory: KnowledgeBaseCategory = .general
    @Published var newArticleTags: [String] = []
    @Published var newArticleKeywords: [String] = []

    // MARK: - Published Properties - Statistics

    @Published var statistics: FAQStatistics?

    // MARK: - Computed Properties

    var categories: [KnowledgeBaseCategory] {
        KnowledgeBaseCategory.allCases
    }

    var articlesByCategory: [KnowledgeBaseCategory: [FAQArticle]] {
        Dictionary(grouping: filteredArticles, by: { $0.category })
    }

    var hasSearchResults: Bool {
        !searchQuery.isEmpty && !searchResults.isEmpty
    }

    var isSearchActive: Bool {
        !searchQuery.isEmpty
    }

    var formattedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Formatted Properties for Views

    var formattedStatisticsTotalArticles: String {
        "\(statistics?.totalArticles ?? 0)"
    }

    var formattedStatisticsPublished: String {
        "\(statistics?.publishedArticles ?? 0)"
    }

    var formattedStatisticsHelpfulness: String {
        "\(statistics?.overallHelpfulnessPercentage ?? 0)%"
    }

    var formattedStatisticsViews: String {
        "\(statistics?.totalViews ?? 0)"
    }

    // MARK: - Date Formatting

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }

    // MARK: - Initialization

    init(
        faqService: FAQKnowledgeBaseServiceProtocol,
        auditService: AuditLoggingServiceProtocol
    ) {
        self.faqService = faqService
        self.auditService = auditService

        setupSearchDebounce()
        setupArticlesObservation()
    }

    // MARK: - Setup

    func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task {
                    await self?.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }

    private func setupArticlesObservation() {
        faqService.articlesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] articles in
                self?.articles = articles
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            articles = try await faqService.getArticles(
                includeUnpublished: showUnpublished,
                includeArchived: showArchived
            )
            popularArticles = try await faqService.getPopularArticles(limit: 5)
            recentArticles = try await faqService.getRecentArticles(limit: 5)
            articlesNeedingReview = try await faqService.getArticlesNeedingReview()
            statistics = try await faqService.getStatistics()

            applyFilters()
        } catch {
            handleError(error)
        }
    }

    func refresh() async {
        await load()
    }


    // MARK: - Error Handling

    func handleError(_ error: Error) {
        let appError = error.toAppError()
        errorMessage = appError.errorDescription ?? "An error occurred"
        showError = true
    }

    func clearError() {
        showError = false
        errorMessage = nil
    }

    func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }

    func clearSuccess() {
        showSuccess = false
        successMessage = nil
    }
}


