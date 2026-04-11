import Foundation
import os

// MARK: - Satisfaction Survey Service

/// Implementation of satisfaction survey management
final class SatisfactionSurveyService: SatisfactionSurveyServiceProtocol {

    // MARK: - Properties

    private let notificationService: any NotificationServiceProtocol
    private let logger = Logger(subsystem: "com.fin.app", category: "SatisfactionSurveyService")

    // Mock data storage
    private var surveyRequests: [SurveyRequest] = []
    private var surveys: [SatisfactionSurvey] = []

    // MARK: - Initialization

    init(notificationService: any NotificationServiceProtocol) {
        self.notificationService = notificationService
    }

    // MARK: - Survey Request Management

    func createSurveyRequest(for ticket: SupportTicket, agentName: String, userId: String) async throws -> SurveyRequest {
        guard ticket.status == .closed || ticket.status == .resolved else {
            throw SurveyServiceError.ticketNotClosed
        }

        let request = SurveyRequest(
            id: UUID().uuidString,
            ticketId: ticket.id,
            ticketNumber: ticket.ticketNumber,
            userId: ticket.userId,
            agentId: ticket.assignedTo ?? "unassigned",
            agentName: agentName,
            ticketSubject: ticket.subject,
            ticketClosedAt: ticket.updatedAt,
            requestSentAt: Date(),
            isCompleted: false,
            completedAt: nil
        )

        surveyRequests.append(request)

        // Send notification to customer using the resolved user ID
        sendSurveyNotification(request: request, userId: userId)

        logger.info("📋 Survey request created for ticket \(ticket.ticketNumber), userId: \(userId)")
        return request
    }

    func getPendingSurveyRequests(userId: String) async throws -> [SurveyRequest] {
        surveyRequests.filter {
            $0.userId == userId && !$0.isCompleted && !$0.isExpired
        }
    }

    func getSurveyRequest(id: String) async throws -> SurveyRequest? {
        surveyRequests.first { $0.id == id }
    }

    // MARK: - Survey Submission

    func submitSurvey(
        surveyRequestId: String,
        rating: Int,
        wasIssueResolved: Bool,
        wasAgentHelpful: Bool,
        wasResponseTimeSatisfactory: Bool,
        comment: String?
    ) async throws -> SatisfactionSurvey {
        guard rating >= 1 && rating <= 5 else {
            throw SurveyServiceError.invalidRating
        }

        guard let requestIndex = surveyRequests.firstIndex(where: { $0.id == surveyRequestId }) else {
            throw SurveyServiceError.surveyRequestNotFound
        }

        let request = surveyRequests[requestIndex]

        guard !request.isCompleted else {
            throw SurveyServiceError.surveyAlreadySubmitted
        }

        guard !request.isExpired else {
            throw SurveyServiceError.surveyExpired
        }

        let survey = SatisfactionSurvey(
            id: UUID().uuidString,
            ticketId: request.ticketId,
            ticketNumber: request.ticketNumber,
            userId: request.userId,
            agentId: request.agentId,
            agentName: request.agentName,
            rating: rating,
            wasIssueResolved: wasIssueResolved,
            wasAgentHelpful: wasAgentHelpful,
            wasResponseTimeSatisfactory: wasResponseTimeSatisfactory,
            comment: comment,
            ticketClosedAt: request.ticketClosedAt,
            submittedAt: Date()
        )

        surveys.append(survey)

        // Mark request as completed
        surveyRequests[requestIndex].isCompleted = true
        surveyRequests[requestIndex].completedAt = Date()

        logger.info("⭐ Survey submitted for ticket \(request.ticketNumber): \(rating)/5 stars")

        return survey
    }

    // MARK: - Survey Retrieval

    func getSurveys(ticketId: String) async throws -> [SatisfactionSurvey] {
        surveys.filter { $0.ticketId == ticketId }
    }

    func getCustomerSurveys(userId: String) async throws -> [SatisfactionSurvey] {
        surveys.filter { $0.userId == userId }
    }

    func getAgentSurveys(agentId: String) async throws -> [SatisfactionSurvey] {
        surveys.filter { $0.agentId == agentId }
    }

    func getSurveys(from startDate: Date, to endDate: Date) async throws -> [SatisfactionSurvey] {
        surveys.filter { $0.submittedAt >= startDate && $0.submittedAt <= endDate }
    }

    // MARK: - Private Methods

    private func sendSurveyNotification(request: SurveyRequest, userId: String) {
        notificationService.createNotification(
            title: "Wie war unser Support?",
            message: "Bitte bewerten Sie unseren Service für Ticket \(request.ticketNumber)",
            type: .system,
            priority: .medium,
            for: userId,  // Use the resolved user ID, not customerId
            metadata: ["surveyRequestId": request.id, "ticketNumber": request.ticketNumber]
        )
        logger.info("🔔 Survey notification sent to user \(userId) for ticket \(request.ticketNumber)")
    }
}

