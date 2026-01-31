import Foundation
import Combine

// MARK: - FAQ Knowledge Base Service Protocol
/// Defines the contract for FAQ knowledge base operations
/// Manages FAQ articles derived from resolved support tickets

protocol FAQKnowledgeBaseServiceProtocol: AnyObject {

    // MARK: - Publishers

    /// Published list of all FAQ articles
    var articlesPublisher: AnyPublisher<[FAQArticle], Never> { get }

    // MARK: - Article Retrieval

    /// Get all FAQ articles
    func getArticles(includeUnpublished: Bool, includeArchived: Bool) async throws -> [FAQArticle]

    /// Get FAQ articles by category
    func getArticles(byCategory category: KnowledgeBaseCategory) async throws -> [FAQArticle]

    /// Get a specific FAQ article by ID
    func getArticle(byId articleId: String) async throws -> FAQArticle?

    /// Get popular FAQ articles (most viewed/helpful)
    func getPopularArticles(limit: Int) async throws -> [FAQArticle]

    /// Get recently updated FAQ articles
    func getRecentArticles(limit: Int) async throws -> [FAQArticle]

    // MARK: - Search

    /// Search FAQ articles by query string
    func searchArticles(query: String) async throws -> [FAQSearchResult]

    /// Get FAQ suggestions based on ticket content
    func getSuggestions(forTicket ticket: SupportTicket) async throws -> [FAQSuggestion]

    /// Get FAQ suggestions based on keywords
    func getSuggestions(forKeywords keywords: [String], category: KnowledgeBaseCategory?) async throws -> [FAQSuggestion]

    // MARK: - Article Management (CSR/Admin)

    /// Create a new FAQ article
    func createArticle(_ article: FAQArticleCreate, createdBy: String) async throws -> FAQArticle

    /// Create FAQ article from resolved ticket
    func createArticleFromTicket(
        _ ticket: SupportTicket,
        solutionResponse: TicketResponse,
        category: KnowledgeBaseCategory,
        createdBy: String
    ) async throws -> FAQArticle

    /// Update an existing FAQ article
    func updateArticle(articleId: String, update: FAQArticleUpdate, updatedBy: String) async throws -> FAQArticle

    /// Publish a draft FAQ article
    func publishArticle(articleId: String) async throws

    /// Unpublish a FAQ article (set to draft)
    func unpublishArticle(articleId: String) async throws

    /// Archive a FAQ article
    func archiveArticle(articleId: String) async throws

    /// Delete a FAQ article (permanent)
    func deleteArticle(articleId: String) async throws

    // MARK: - Usage Tracking

    /// Record that an article was viewed
    func recordView(articleId: String) async throws

    /// Record that an article was used to resolve a ticket
    func recordUsedInTicket(articleId: String, ticketId: String) async throws

    // MARK: - Feedback

    /// Submit feedback for an article
    func submitFeedback(_ feedback: FAQFeedback) async throws

    /// Get feedback for an article
    func getFeedback(forArticleId articleId: String) async throws -> [FAQFeedback]

    // MARK: - Analytics

    /// Get FAQ statistics
    func getStatistics() async throws -> FAQStatistics

    /// Get articles that need review (low helpfulness, outdated)
    func getArticlesNeedingReview() async throws -> [FAQArticle]

    // MARK: - Ticket Integration

    /// Link a ticket to an existing FAQ article (for tracking similar issues)
    func linkTicketToArticle(ticketId: String, articleId: String) async throws

    /// Get tickets linked to an FAQ article
    func getLinkedTickets(forArticleId articleId: String) async throws -> [String]
}

// MARK: - FAQ Service Error

enum FAQServiceError: Error, LocalizedError {
    case articleNotFound
    case duplicateTitle
    case invalidArticle(String)
    case permissionDenied
    case searchFailed(String)
    case feedbackAlreadySubmitted

    var errorDescription: String? {
        switch self {
        case .articleNotFound:
            return "FAQ-Artikel nicht gefunden"
        case .duplicateTitle:
            return "Ein Artikel mit diesem Titel existiert bereits"
        case .invalidArticle(let reason):
            return "Ungültiger Artikel: \(reason)"
        case .permissionDenied:
            return "Keine Berechtigung für diese Aktion"
        case .searchFailed(let reason):
            return "Suche fehlgeschlagen: \(reason)"
        case .feedbackAlreadySubmitted:
            return "Sie haben bereits Feedback für diesen Artikel gegeben"
        }
    }
}

