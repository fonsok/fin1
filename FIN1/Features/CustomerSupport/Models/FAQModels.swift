import Foundation

// MARK: - FAQ Article

/// Knowledge base article created from resolved tickets
struct FAQArticle: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let summary: String
    let content: String
    let category: KnowledgeBaseCategory
    let tags: [String]
    let keywords: [String]

    // Source tracking
    let sourceTicketIds: [String]
    let solutionType: SolutionType?
    let relatedHelpCenterArticleId: String?

    // Usage metrics
    var viewCount: Int
    var helpfulCount: Int
    var notHelpfulCount: Int
    var usedInTicketCount: Int

    // Lifecycle
    let createdAt: Date
    var updatedAt: Date
    let createdBy: String
    var lastUpdatedBy: String?
    var isPublished: Bool
    var isArchived: Bool

    // Computed properties
    var helpfulnessRatio: Double {
        let total = self.helpfulCount + self.notHelpfulCount
        guard total > 0 else { return 0.0 }
        return Double(self.helpfulCount) / Double(total)
    }

    var helpfulnessPercentage: Int {
        Int(self.helpfulnessRatio * 100)
    }

    var isPopular: Bool {
        self.viewCount >= 50 || self.usedInTicketCount >= 10
    }

    var relevanceScore: Double {
        // Score based on usage, helpfulness, and recency
        let usageScore = Double(viewCount + self.usedInTicketCount * 5)
        let helpfulnessScore = self.helpfulnessRatio * 100
        let daysSinceUpdate = Calendar.current.dateComponents(
            [.day],
            from: self.updatedAt,
            to: Date()
        ).day ?? 0
        let recencyScore = max(0, 100 - Double(daysSinceUpdate))

        return (usageScore * 0.3) + (helpfulnessScore * 0.5) + (recencyScore * 0.2)
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        summary: String,
        content: String,
        category: KnowledgeBaseCategory,
        tags: [String] = [],
        keywords: [String] = [],
        sourceTicketIds: [String] = [],
        solutionType: SolutionType? = nil,
        relatedHelpCenterArticleId: String? = nil,
        viewCount: Int = 0,
        helpfulCount: Int = 0,
        notHelpfulCount: Int = 0,
        usedInTicketCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String,
        lastUpdatedBy: String? = nil,
        isPublished: Bool = true,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.content = content
        self.category = category
        self.tags = tags
        self.keywords = keywords
        self.sourceTicketIds = sourceTicketIds
        self.solutionType = solutionType
        self.relatedHelpCenterArticleId = relatedHelpCenterArticleId
        self.viewCount = viewCount
        self.helpfulCount = helpfulCount
        self.notHelpfulCount = notHelpfulCount
        self.usedInTicketCount = usedInTicketCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.lastUpdatedBy = lastUpdatedBy
        self.isPublished = isPublished
        self.isArchived = isArchived
    }
}

// MARK: - Knowledge Base Category

enum KnowledgeBaseCategory: String, Codable, CaseIterable, Identifiable {
    case account = "Konto"
    case login = "Login & Sicherheit"
    case investment = "Investment"
    case trading = "Trading"
    case payment = "Zahlung & Abrechnung"
    case documents = "Dokumente"
    case technical = "Technische Probleme"
    case legal = "Rechtliches"
    case general = "Allgemein"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .account: return "person.crop.circle.fill"
        case .login: return "lock.shield.fill"
        case .investment: return "chart.pie.fill"
        case .trading: return "arrow.left.arrow.right.circle.fill"
        case .payment: return "creditcard.fill"
        case .documents: return "doc.text.fill"
        case .technical: return "wrench.and.screwdriver.fill"
        case .legal: return "scale.3d"
        case .general: return "questionmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .account: return "#3182CE"
        case .login: return "#805AD5"
        case .investment: return "#38A169"
        case .trading: return "#DD6B20"
        case .payment: return "#319795"
        case .documents: return "#D69E2E"
        case .technical: return "#E53E3E"
        case .legal: return "#718096"
        case .general: return "#4A5568"
        }
    }
}

// MARK: - FAQ Search Result

struct FAQSearchResult: Identifiable {
    let id: String
    let article: FAQArticle
    let matchScore: Double
    let matchedTerms: [String]
    let highlightRanges: [Range<String.Index>]

    init(
        article: FAQArticle,
        matchScore: Double,
        matchedTerms: [String] = [],
        highlightRanges: [Range<String.Index>] = []
    ) {
        self.id = article.id
        self.article = article
        self.matchScore = matchScore
        self.matchedTerms = matchedTerms
        self.highlightRanges = highlightRanges
    }
}

// MARK: - FAQ Suggestion

/// Suggested FAQ articles based on ticket content
struct FAQSuggestion: Identifiable {
    let id: String
    let article: FAQArticle
    let relevanceScore: Double
    let matchReason: MatchReason

    enum MatchReason: String, Codable {
        case keywordMatch = "Keyword-Übereinstimmung"
        case categoryMatch = "Kategorie-Übereinstimmung"
        case similarTicket = "Ähnliches Ticket"
        case tagMatch = "Tag-Übereinstimmung"
        case popularInCategory = "Beliebt in dieser Kategorie"

        var icon: String {
            switch self {
            case .keywordMatch: return "text.magnifyingglass"
            case .categoryMatch: return "folder.fill"
            case .similarTicket: return "doc.on.doc.fill"
            case .tagMatch: return "tag.fill"
            case .popularInCategory: return "star.fill"
            }
        }
    }

    init(
        article: FAQArticle,
        relevanceScore: Double,
        matchReason: MatchReason
    ) {
        self.id = article.id
        self.article = article
        self.relevanceScore = relevanceScore
        self.matchReason = matchReason
    }
}

// MARK: - FAQ Article Create/Update DTOs

struct FAQArticleCreate {
    let title: String
    let summary: String
    let content: String
    let category: KnowledgeBaseCategory
    let tags: [String]
    let keywords: [String]
    let sourceTicketIds: [String]
    let solutionType: SolutionType?
    let relatedHelpCenterArticleId: String?
}

struct FAQArticleUpdate {
    let title: String?
    let summary: String?
    let content: String?
    let category: KnowledgeBaseCategory?
    let tags: [String]?
    let keywords: [String]?
    let isPublished: Bool?
}

// MARK: - FAQ Statistics

struct FAQStatistics: Codable {
    let totalArticles: Int
    let publishedArticles: Int
    let archivedArticles: Int
    let totalViews: Int
    let totalHelpfulVotes: Int
    let totalNotHelpfulVotes: Int
    let averageHelpfulness: Double
    let articlesByCategory: [String: Int]
    let topViewedArticles: [String] // Article IDs
    let recentlyUpdatedArticles: [String] // Article IDs
    let articlesNeedingReview: Int // Low helpfulness or outdated

    var overallHelpfulnessPercentage: Int {
        let total = self.totalHelpfulVotes + self.totalNotHelpfulVotes
        guard total > 0 else { return 0 }
        return Int((Double(self.totalHelpfulVotes) / Double(total)) * 100)
    }
}

// MARK: - FAQ Feedback

struct FAQFeedback: Identifiable, Codable {
    let id: String
    let articleId: String
    let userId: String?
    let isHelpful: Bool
    let comment: String?
    let ticketId: String? // If feedback provided while resolving a ticket
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        articleId: String,
        userId: String? = nil,
        isHelpful: Bool,
        comment: String? = nil,
        ticketId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.articleId = articleId
        self.userId = userId
        self.isHelpful = isHelpful
        self.comment = comment
        self.ticketId = ticketId
        self.createdAt = createdAt
    }
}

// MARK: - FAQ Article from Ticket

extension FAQArticle {
    /// Creates a draft FAQ article from a resolved ticket
    static func fromResolvedTicket(
        _ ticket: SupportTicket,
        solutionResponse: TicketResponse,
        category: KnowledgeBaseCategory,
        createdBy: String
    ) -> FAQArticle {
        let title = ticket.subject
        let summary = String(ticket.description.prefix(200))
        let content = self.buildContentFromTicket(ticket, solutionResponse: solutionResponse)
        let keywords = self.extractKeywords(from: ticket)

        return FAQArticle(
            title: title,
            summary: summary,
            content: content,
            category: category,
            tags: ticket.tagIds,
            keywords: keywords,
            sourceTicketIds: [ticket.id],
            solutionType: solutionResponse.solutionDetails?.solutionType,
            relatedHelpCenterArticleId: solutionResponse.solutionDetails?.helpCenterArticleId,
            createdBy: createdBy,
            isPublished: false // Draft by default
        )
    }

    private static func buildContentFromTicket(
        _ ticket: SupportTicket,
        solutionResponse: TicketResponse
    ) -> String {
        var content = """
        ## Problem
        
        \(ticket.description)
        
        ## Lösung
        
        \(solutionResponse.message)
        """

        if let details = solutionResponse.solutionDetails {
            if !details.verificationSteps.isEmpty {
                content += "\n\n## Prüfschritte\n\n"
                for (index, step) in details.verificationSteps.enumerated() {
                    content += "\(index + 1). \(step)\n"
                }
            }

            if let workaround = details.workaround {
                content += "\n\n## Workaround\n\n\(workaround)"
            }
        }

        return content
    }

    private static func extractKeywords(from ticket: SupportTicket) -> [String] {
        // Simple keyword extraction - in production, use NLP
        let text = "\(ticket.subject) \(ticket.description)".lowercased()
        let commonWords = Set(
            [
                "der",
                "die",
                "das",
                "und",
                "oder",
                "ein",
                "eine",
                "ist",
                "sind",
                "hat",
                "haben",
                "ich",
                "sie",
                "wir",
                "mein",
                "ihr",
                "nicht",
                "kann",
                "können",
                "bitte",
                "für",
                "mit",
                "auf",
                "bei",
                "nach",
                "von",
                "zu"
            ]
        )

        let words = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !commonWords.contains($0) }

        // Return unique keywords
        return Array(Set(words)).prefix(10).map { $0 }
    }
}

