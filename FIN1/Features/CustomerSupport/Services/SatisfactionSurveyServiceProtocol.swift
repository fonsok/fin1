import Foundation

// MARK: - Satisfaction Survey Service Protocol

/// Service for managing customer satisfaction surveys after ticket closure
protocol SatisfactionSurveyServiceProtocol {

    // MARK: - Survey Request Management

    /// Creates a survey request when a ticket is closed
    /// - Parameters:
    ///   - ticket: The closed/resolved support ticket
    ///   - agentName: Name of the CSR who handled the ticket
    ///   - userId: The user ID to send the notification to (e.g., "user:max@test.com")
    func createSurveyRequest(for ticket: SupportTicket, agentName: String, userId: String) async throws -> SurveyRequest

    /// Gets pending survey requests for a customer
    func getPendingSurveyRequests(customerId: String) async throws -> [SurveyRequest]

    /// Gets a specific survey request by ID
    func getSurveyRequest(id: String) async throws -> SurveyRequest?

    // MARK: - Survey Submission

    /// Submits a completed satisfaction survey
    func submitSurvey(
        surveyRequestId: String,
        rating: Int,
        wasIssueResolved: Bool,
        wasAgentHelpful: Bool,
        wasResponseTimeSatisfactory: Bool,
        comment: String?
    ) async throws -> SatisfactionSurvey

    // MARK: - Survey Retrieval

    /// Gets all surveys for a specific ticket
    func getSurveys(ticketId: String) async throws -> [SatisfactionSurvey]

    /// Gets all surveys submitted by a customer
    func getCustomerSurveys(customerId: String) async throws -> [SatisfactionSurvey]

    /// Gets all surveys for an agent
    func getAgentSurveys(agentId: String) async throws -> [SatisfactionSurvey]

    /// Gets surveys within a date range
    func getSurveys(from startDate: Date, to endDate: Date) async throws -> [SatisfactionSurvey]
}

// MARK: - Survey Service Error

enum SurveyServiceError: LocalizedError {
    case surveyRequestNotFound
    case surveyAlreadySubmitted
    case surveyExpired
    case invalidRating
    case ticketNotClosed

    var errorDescription: String? {
        switch self {
        case .surveyRequestNotFound: return "Umfrageanfrage nicht gefunden"
        case .surveyAlreadySubmitted: return "Umfrage wurde bereits eingereicht"
        case .surveyExpired: return "Die Umfrage ist abgelaufen"
        case .invalidRating: return "Ungültige Bewertung (1-5 erforderlich)"
        case .ticketNotClosed: return "Ticket muss geschlossen sein für Umfrage"
        }
    }
}
