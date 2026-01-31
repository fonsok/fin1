import Foundation

// MARK: - FAQKnowledgeBaseViewModel + Statistics & Suggestions
/// Extension handling statistics, suggestions, and feedback

extension FAQKnowledgeBaseViewModel {

    // MARK: - Feedback

    func submitFeedback(forArticle article: FAQArticle, isHelpful: Bool, comment: String?, userId: String?) async {
        do {
            let feedback = FAQFeedback(
                articleId: article.id,
                userId: userId,
                isHelpful: isHelpful,
                comment: comment
            )
            try await faqService.submitFeedback(feedback)
            showSuccessMessage("Danke für Ihr Feedback!")
            await load()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Suggestions

    func getSuggestions(forTicket ticket: SupportTicket) async -> [FAQSuggestion] {
        do {
            return try await faqService.getSuggestions(forTicket: ticket)
        } catch {
            handleError(error)
            return []
        }
    }

    func useSuggestion(_ suggestion: FAQSuggestion, inTicket ticketId: String) async {
        do {
            try await faqService.recordUsedInTicket(articleId: suggestion.article.id, ticketId: ticketId)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Statistics

    func loadStatistics() async {
        do {
            statistics = try await faqService.getStatistics()
            showStatistics = true
        } catch {
            handleError(error)
        }
    }
}

