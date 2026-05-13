import Foundation

// MARK: - FAQKnowledgeBaseService + Analytics & Usage Tracking
/// Extension handling usage tracking, feedback, statistics, and ticket integration

extension FAQKnowledgeBaseService {

    // MARK: - Usage Tracking

    func recordView(articleId: String) async throws {
        guard let index = self.articles.firstIndex(where: { $0.id == articleId }) else {
            throw FAQServiceError.articleNotFound
        }

        articles[index].viewCount += 1
        articlesSubject.send(articles)
    }

    func recordUsedInTicket(articleId: String, ticketId: String) async throws {
        guard let index = articles.firstIndex(where: { $0.id == articleId }) else {
            throw FAQServiceError.articleNotFound
        }

        let articleTitle = articles[index].title
        articles[index].usedInTicketCount += 1
        articlesSubject.send(articles)

        try await self.linkTicketToArticle(ticketId: ticketId, articleId: articleId)

        logger.info("📊 FAQ article used in ticket: \(articleTitle)")
    }

    // MARK: - Feedback

    func submitFeedback(_ feedback: FAQFeedback) async throws {
        // Check for existing feedback from same user
        if let userId = feedback.userId,
           feedbackStore.contains(where: { $0.articleId == feedback.articleId && $0.userId == userId }) {
            throw FAQServiceError.feedbackAlreadySubmitted
        }

        feedbackStore.append(feedback)

        // Update article counts
        if let index = self.articles.firstIndex(where: { $0.id == feedback.articleId }) {
            if feedback.isHelpful {
                articles[index].helpfulCount += 1
            } else {
                articles[index].notHelpfulCount += 1
            }
            articlesSubject.send(articles)
        }

        logger.info("📝 Feedback submitted for article \(feedback.articleId): \(feedback.isHelpful ? "helpful" : "not helpful")")
    }

    func getFeedback(forArticleId articleId: String) async throws -> [FAQFeedback] {
        return feedbackStore
            .filter { $0.articleId == articleId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Analytics

    func getStatistics() async throws -> FAQStatistics {
        let published = articles.filter { $0.isPublished && !$0.isArchived }
        let archived = articles.filter { $0.isArchived }
        let totalViews = articles.reduce(0) { $0 + $1.viewCount }
        let totalHelpful = articles.reduce(0) { $0 + $1.helpfulCount }
        let totalNotHelpful = articles.reduce(0) { $0 + $1.notHelpfulCount }

        let categoryCount = Dictionary(grouping: published, by: { $0.category.rawValue })
            .mapValues { $0.count }

        let topViewed = published
            .sorted { $0.viewCount > $1.viewCount }
            .prefix(5)
            .map { $0.id }

        let recent = published
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(5)
            .map { $0.id }

        let needingReview = try await getArticlesNeedingReview().count

        let avgHelpfulness: Double
        if totalHelpful + totalNotHelpful > 0 {
            avgHelpfulness = Double(totalHelpful) / Double(totalHelpful + totalNotHelpful)
        } else {
            avgHelpfulness = 0
        }

        return FAQStatistics(
            totalArticles: articles.count,
            publishedArticles: published.count,
            archivedArticles: archived.count,
            totalViews: totalViews,
            totalHelpfulVotes: totalHelpful,
            totalNotHelpfulVotes: totalNotHelpful,
            averageHelpfulness: avgHelpfulness,
            articlesByCategory: categoryCount,
            topViewedArticles: Array(topViewed),
            recentlyUpdatedArticles: Array(recent),
            articlesNeedingReview: needingReview
        )
    }

    func getArticlesNeedingReview() async throws -> [FAQArticle] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        return articles.filter { article in
            guard article.isPublished && !article.isArchived else { return false }

            // Low helpfulness (< 50% with at least 5 votes)
            let totalVotes = article.helpfulCount + article.notHelpfulCount
            if totalVotes >= 5 && article.helpfulnessRatio < 0.5 {
                return true
            }

            // Not updated in 30+ days with high usage
            if article.updatedAt < thirtyDaysAgo && article.viewCount > 100 {
                return true
            }

            return false
        }
    }

    // MARK: - Ticket Integration

    func linkTicketToArticle(ticketId: String, articleId: String) async throws {
        guard articles.contains(where: { $0.id == articleId }) else {
            throw FAQServiceError.articleNotFound
        }

        var links = ticketArticleLinks[articleId] ?? []
        if !links.contains(ticketId) {
            links.append(ticketId)
            ticketArticleLinks[articleId] = links
        }
    }

    func getLinkedTickets(forArticleId articleId: String) async throws -> [String] {
        guard articles.contains(where: { $0.id == articleId }) else {
            throw FAQServiceError.articleNotFound
        }

        return ticketArticleLinks[articleId] ?? []
    }
}

