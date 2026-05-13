import Combine
import Foundation

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
        Dictionary(grouping: self.filteredArticles, by: { $0.category })
    }

    var hasSearchResults: Bool {
        !self.searchQuery.isEmpty && !self.searchResults.isEmpty
    }

    var isSearchActive: Bool {
        !self.searchQuery.isEmpty
    }

    var formattedSearchQuery: String {
        self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Formatted Properties for Views

    var formattedStatisticsTotalArticles: String {
        "\(self.statistics?.totalArticles ?? 0)"
    }

    var formattedStatisticsPublished: String {
        "\(self.statistics?.publishedArticles ?? 0)"
    }

    var formattedStatisticsHelpfulness: String {
        "\(self.statistics?.overallHelpfulnessPercentage ?? 0)%"
    }

    var formattedStatisticsViews: String {
        "\(self.statistics?.totalViews ?? 0)"
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

        self.setupSearchDebounce()
        self.setupArticlesObservation()
    }

    // MARK: - Setup

    func setupSearchDebounce() {
        self.$searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task {
                    await self?.performSearch(query: query)
                }
            }
            .store(in: &self.cancellables)
    }

    private func setupArticlesObservation() {
        self.faqService.articlesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] articles in
                self?.articles = articles
                self?.applyFilters()
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Loading

    func load() async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            self.articles = try await self.faqService.getArticles(
                includeUnpublished: self.showUnpublished,
                includeArchived: self.showArchived
            )
            self.popularArticles = try await self.faqService.getPopularArticles(limit: 5)
            self.recentArticles = try await self.faqService.getRecentArticles(limit: 5)
            self.articlesNeedingReview = try await self.faqService.getArticlesNeedingReview()
            self.statistics = try await self.faqService.getStatistics()

            applyFilters()
        } catch {
            self.handleError(error)
        }
    }

    func refresh() async {
        await self.load()
    }


    // MARK: - Error Handling

    func handleError(_ error: Error) {
        let appError = error.toAppError()
        self.errorMessage = appError.errorDescription ?? "An error occurred"
        self.showError = true
    }

    func clearError() {
        self.showError = false
        self.errorMessage = nil
    }

    func showSuccessMessage(_ message: String) {
        self.successMessage = message
        self.showSuccess = true
    }

    func clearSuccess() {
        self.showSuccess = false
        self.successMessage = nil
    }
}


