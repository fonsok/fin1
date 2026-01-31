import Foundation

// MARK: - FAQKnowledgeBaseService + Search & Suggestions
/// Extension handling article search and suggestions

extension FAQKnowledgeBaseService {

    // MARK: - Search

    func searchArticles(query: String) async throws -> [FAQSearchResult] {
        guard !query.isEmpty else { return [] }

        let searchTerms = query.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var results: [FAQSearchResult] = []

        for article in articles where article.isPublished && !article.isArchived {
            let (score, matchedTerms) = calculateSearchScore(article: article, searchTerms: searchTerms)

            if score > 0 {
                results.append(FAQSearchResult(
                    article: article,
                    matchScore: score,
                    matchedTerms: matchedTerms
                ))
            }
        }

        return results.sorted { $0.matchScore > $1.matchScore }
    }

    func getSuggestions(forTicket ticket: SupportTicket) async throws -> [FAQSuggestion] {
        let keywords = extractKeywords(from: ticket.subject + " " + ticket.description)
        return try await getSuggestions(forKeywords: keywords, category: nil)
    }

    func getSuggestions(forKeywords keywords: [String], category: KnowledgeBaseCategory?) async throws -> [FAQSuggestion] {
        var suggestions: [FAQSuggestion] = []
        let searchTerms = keywords.map { $0.lowercased() }

        for article in articles where article.isPublished && !article.isArchived {
            var relevanceScore: Double = 0
            var matchReason: FAQSuggestion.MatchReason = .keywordMatch

            // Check keyword matches
            let (keywordScore, _) = calculateSearchScore(article: article, searchTerms: searchTerms)
            if keywordScore > 0 {
                relevanceScore = keywordScore
                matchReason = .keywordMatch
            }

            // Check category match
            if let targetCategory = category, article.category == targetCategory {
                relevanceScore += 0.3
                if matchReason == .keywordMatch && keywordScore == 0 {
                    matchReason = .categoryMatch
                }
            }

            // Boost popular articles in category
            if article.isPopular && (category == nil || article.category == category) {
                relevanceScore += 0.2
                if relevanceScore == 0.2 {
                    matchReason = .popularInCategory
                }
            }

            // Check tag matches
            let tagMatches = article.tags.filter { keywords.contains($0.lowercased()) }.count
            if tagMatches > 0 {
                relevanceScore += Double(tagMatches) * 0.15
                if matchReason == .keywordMatch && keywordScore == 0 {
                    matchReason = .tagMatch
                }
            }

            if relevanceScore > 0.1 {
                suggestions.append(FAQSuggestion(
                    article: article,
                    relevanceScore: relevanceScore,
                    matchReason: matchReason
                ))
            }
        }

        return suggestions
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Private Helpers

    func calculateSearchScore(article: FAQArticle, searchTerms: [String]) -> (Double, [String]) {
        var score: Double = 0
        var matchedTerms: [String] = []

        let titleLower = article.title.lowercased()
        let summaryLower = article.summary.lowercased()
        let contentLower = article.content.lowercased()
        let keywordsLower = article.keywords.map { $0.lowercased() }
        let tagsLower = article.tags.map { $0.lowercased() }

        for term in searchTerms {
            var termScore: Double = 0

            // Title match (highest weight)
            if titleLower.contains(term) {
                termScore += 1.0
                matchedTerms.append(term)
            }

            // Keyword match (high weight)
            if keywordsLower.contains(where: { $0.contains(term) }) {
                termScore += 0.8
                if !matchedTerms.contains(term) { matchedTerms.append(term) }
            }

            // Tag match
            if tagsLower.contains(where: { $0.contains(term) }) {
                termScore += 0.6
                if !matchedTerms.contains(term) { matchedTerms.append(term) }
            }

            // Summary match
            if summaryLower.contains(term) {
                termScore += 0.4
                if !matchedTerms.contains(term) { matchedTerms.append(term) }
            }

            // Content match (lowest weight)
            if contentLower.contains(term) {
                termScore += 0.2
                if !matchedTerms.contains(term) { matchedTerms.append(term) }
            }

            score += termScore
        }

        // Boost by helpfulness
        if article.helpfulnessRatio > 0.7 {
            score *= 1.2
        }

        return (score, matchedTerms)
    }

    func extractKeywords(from text: String) -> [String] {
        let stopWords = Set(["der", "die", "das", "und", "oder", "ein", "eine", "ist", "sind", "hat", "haben", "ich", "sie", "wir", "mein", "ihr", "nicht", "kann", "können", "bitte", "für", "mit", "auf", "bei", "nach", "von", "zu"])

        return text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !stopWords.contains($0) }
    }
}

