import Foundation

// MARK: - Satisfaction Survey

/// Customer satisfaction survey submitted after ticket closure
struct SatisfactionSurvey: Identifiable, Codable {
    let id: String
    let ticketId: String
    let ticketNumber: String
    let userId: String
    let agentId: String
    let agentName: String

    // Rating (1-5 stars)
    let rating: Int

    // Quick feedback options
    let wasIssueResolved: Bool
    let wasAgentHelpful: Bool
    let wasResponseTimeSatisfactory: Bool

    // Optional comment
    let comment: String?

    // Metadata
    let ticketClosedAt: Date
    let submittedAt: Date

    // Computed properties
    var isPositive: Bool { self.rating >= 4 }
    var isNegative: Bool { self.rating <= 2 }
    var isNeutral: Bool { self.rating == 3 }

    var ratingDescription: String {
        switch self.rating {
        case 1: return "Sehr unzufrieden"
        case 2: return "Unzufrieden"
        case 3: return "Neutral"
        case 4: return "Zufrieden"
        case 5: return "Sehr zufrieden"
        default: return "Unbekannt"
        }
    }
}

// MARK: - Survey Request

/// Request sent to customer after ticket closure
struct SurveyRequest: Identifiable, Codable {
    let id: String
    let ticketId: String
    let ticketNumber: String
    let userId: String
    let agentId: String
    let agentName: String
    let ticketSubject: String
    let ticketClosedAt: Date
    let requestSentAt: Date
    var isCompleted: Bool
    var completedAt: Date?

    /// Survey link expires after 7 days
    var isExpired: Bool {
        Date().timeIntervalSince(self.requestSentAt) > 7 * 24 * 60 * 60
    }
}

// MARK: - Support Analytics

/// Aggregated support metrics for a time period
struct SupportMetrics: Codable {
    let periodStart: Date
    let periodEnd: Date

    // Volume metrics
    let totalTickets: Int
    let openTickets: Int
    let closedTickets: Int
    let escalatedTickets: Int

    // Time metrics (in hours)
    let averageFirstResponseTime: Double
    let averageResolutionTime: Double
    let medianResolutionTime: Double

    // Satisfaction metrics
    let surveysCompleted: Int
    let surveyResponseRate: Double
    let averageCSATScore: Double
    let positiveRatingPercentage: Double
    let negativeRatingPercentage: Double

    // Issue resolution metrics
    let issueResolvedPercentage: Double
    let agentHelpfulPercentage: Double
    let responseTimeSatisfactoryPercentage: Double

    // Category breakdown
    let ticketsByCategory: [String: Int]
    let ticketsByPriority: [String: Int]

    // Computed display values
    var csatScoreFormatted: String {
        String(format: "%.1f", self.averageCSATScore)
    }

    var responseRateFormatted: String {
        String(format: "%.0f%%", self.surveyResponseRate * 100)
    }
}

// MARK: - Agent Performance

/// Individual agent performance metrics
struct AgentPerformanceMetrics: Identifiable, Codable {
    let id: String // Agent ID
    let agentName: String
    let periodStart: Date
    let periodEnd: Date

    // Volume
    let ticketsHandled: Int
    let ticketsClosed: Int
    let ticketsEscalated: Int

    // Time metrics
    let averageFirstResponseTime: Double
    let averageResolutionTime: Double

    // Satisfaction
    let surveysReceived: Int
    let averageCSATScore: Double
    let positiveRatings: Int
    let negativeRatings: Int

    // Computed
    var positiveRatingPercentage: Double {
        guard self.surveysReceived > 0 else { return 0 }
        return Double(self.positiveRatings) / Double(self.surveysReceived) * 100
    }

    var performanceLevel: PerformanceLevel {
        if self.averageCSATScore >= 4.5 { return .excellent }
        if self.averageCSATScore >= 4.0 { return .good }
        if self.averageCSATScore >= 3.0 { return .average }
        return .needsImprovement
    }

    enum PerformanceLevel: String, Codable {
        case excellent = "Ausgezeichnet"
        case good = "Gut"
        case average = "Durchschnittlich"
        case needsImprovement = "Verbesserungsbedarf"

        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "cyan"
            case .average: return "orange"
            case .needsImprovement: return "red"
            }
        }
    }
}

// MARK: - Recurring Issue

/// Identifies patterns in support tickets for product improvement
struct RecurringIssue: Identifiable, Codable {
    let id: String
    let category: String
    let description: String
    let occurrenceCount: Int
    let affectedCustomers: Int
    let averageResolutionTime: Double
    let suggestedAction: SuggestedAction
    let firstOccurrence: Date
    let lastOccurrence: Date

    enum SuggestedAction: String, Codable {
        case documentationUpdate = "Dokumentation aktualisieren"
        case productFix = "Produktfix erforderlich"
        case processImprovement = "Prozessverbesserung"
        case trainingNeeded = "Schulung erforderlich"
        case featureRequest = "Feature-Anfrage prüfen"

        var icon: String {
            switch self {
            case .documentationUpdate: return "doc.text.fill"
            case .productFix: return "ladybug.fill"
            case .processImprovement: return "gearshape.2.fill"
            case .trainingNeeded: return "person.3.fill"
            case .featureRequest: return "lightbulb.fill"
            }
        }
    }
}

