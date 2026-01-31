import Foundation
import os

// MARK: - Support Analytics Service

/// Implementation of support metrics and analytics
final class SupportAnalyticsService: SupportAnalyticsServiceProtocol {

    // MARK: - Properties

    private let surveyService: SatisfactionSurveyServiceProtocol
    private let supportService: CustomerSupportServiceProtocol
    private let logger = Logger(subsystem: "com.fin.app", category: "SupportAnalyticsService")

    // MARK: - Initialization

    init(
        surveyService: SatisfactionSurveyServiceProtocol,
        supportService: CustomerSupportServiceProtocol
    ) {
        self.surveyService = surveyService
        self.supportService = supportService
    }

    // MARK: - Overall Metrics

    func getMetrics(from startDate: Date, to endDate: Date) async throws -> SupportMetrics {
        let surveys = try await surveyService.getSurveys(from: startDate, to: endDate)
        let tickets = try await supportService.getSupportTickets(customerId: nil)

        let filteredTickets = tickets.filter {
            $0.createdAt >= startDate && $0.createdAt <= endDate
        }

        let closedTickets = filteredTickets.filter { $0.status == .closed || $0.status == .resolved }
        let escalatedTickets = filteredTickets.filter { $0.status == .escalated }

        // Calculate average CSAT
        let avgCSAT = surveys.isEmpty ? 0.0 : Double(surveys.map { $0.rating }.reduce(0, +)) / Double(surveys.count)
        let positiveCount = surveys.filter { $0.isPositive }.count
        let negativeCount = surveys.filter { $0.isNegative }.count

        // Calculate resolution times (mock calculation)
        let avgResolutionTime = calculateAverageResolutionTime(tickets: closedTickets)

        // Category breakdown
        var ticketsByCategory: [String: Int] = [:]
        for ticket in filteredTickets {
            let category = extractCategory(from: ticket)
            ticketsByCategory[category, default: 0] += 1
        }

        // Priority breakdown
        var ticketsByPriority: [String: Int] = [:]
        for ticket in filteredTickets {
            ticketsByPriority[ticket.priority.displayName, default: 0] += 1
        }

        return SupportMetrics(
            periodStart: startDate,
            periodEnd: endDate,
            totalTickets: filteredTickets.count,
            openTickets: filteredTickets.filter { $0.status == .open || $0.status == .inProgress }.count,
            closedTickets: closedTickets.count,
            escalatedTickets: escalatedTickets.count,
            averageFirstResponseTime: 2.5, // Mock: 2.5 hours
            averageResolutionTime: avgResolutionTime,
            medianResolutionTime: avgResolutionTime * 0.8,
            surveysCompleted: surveys.count,
            surveyResponseRate: closedTickets.isEmpty ? 0 : Double(surveys.count) / Double(closedTickets.count),
            averageCSATScore: avgCSAT,
            positiveRatingPercentage: surveys.isEmpty ? 0 : Double(positiveCount) / Double(surveys.count) * 100,
            negativeRatingPercentage: surveys.isEmpty ? 0 : Double(negativeCount) / Double(surveys.count) * 100,
            issueResolvedPercentage: surveys.isEmpty ? 0 : Double(surveys.filter { $0.wasIssueResolved }.count) / Double(surveys.count) * 100,
            agentHelpfulPercentage: surveys.isEmpty ? 0 : Double(surveys.filter { $0.wasAgentHelpful }.count) / Double(surveys.count) * 100,
            responseTimeSatisfactoryPercentage: surveys.isEmpty ? 0 : Double(surveys.filter { $0.wasResponseTimeSatisfactory }.count) / Double(surveys.count) * 100,
            ticketsByCategory: ticketsByCategory,
            ticketsByPriority: ticketsByPriority
        )
    }

    func getTodayMetrics() async throws -> SupportMetrics {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        return try await getMetrics(from: startOfDay, to: endOfDay)
    }

    func getWeeklyMetrics() async throws -> SupportMetrics {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? Date()
        return try await getMetrics(from: startOfWeek, to: endOfWeek)
    }

    func getMonthlyMetrics() async throws -> SupportMetrics {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: components) ?? Date()
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? Date()
        return try await getMetrics(from: startOfMonth, to: endOfMonth)
    }

    // MARK: - Agent Performance

    func getAgentPerformance(agentId: String, from startDate: Date, to endDate: Date) async throws -> AgentPerformanceMetrics {
        let surveys = try await surveyService.getAgentSurveys(agentId: agentId)
        let filteredSurveys = surveys.filter {
            $0.submittedAt >= startDate && $0.submittedAt <= endDate
        }

        let tickets = try await supportService.getSupportTickets(customerId: nil)
        let agentTickets = tickets.filter {
            $0.assignedTo == agentId && $0.createdAt >= startDate && $0.createdAt <= endDate
        }

        let avgCSAT = filteredSurveys.isEmpty ? 0.0 : Double(filteredSurveys.map { $0.rating }.reduce(0, +)) / Double(filteredSurveys.count)

        return AgentPerformanceMetrics(
            id: agentId,
            agentName: getAgentName(for: agentId),
            periodStart: startDate,
            periodEnd: endDate,
            ticketsHandled: agentTickets.count,
            ticketsClosed: agentTickets.filter { $0.status == .closed || $0.status == .resolved }.count,
            ticketsEscalated: agentTickets.filter { $0.status == .escalated }.count,
            averageFirstResponseTime: 2.0,
            averageResolutionTime: calculateAverageResolutionTime(tickets: agentTickets),
            surveysReceived: filteredSurveys.count,
            averageCSATScore: avgCSAT,
            positiveRatings: filteredSurveys.filter { $0.isPositive }.count,
            negativeRatings: filteredSurveys.filter { $0.isNegative }.count
        )
    }

    func getAllAgentPerformance(from startDate: Date, to endDate: Date) async throws -> [AgentPerformanceMetrics] {
        let agents = try await supportService.getAvailableAgents()
        var performances: [AgentPerformanceMetrics] = []

        for agent in agents {
            let performance = try await getAgentPerformance(agentId: agent.id, from: startDate, to: endDate)
            performances.append(performance)
        }

        return performances.sorted { $0.averageCSATScore > $1.averageCSATScore }
    }

    func getTopPerformingAgents(limit: Int) async throws -> [AgentPerformanceMetrics] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let allPerformance = try await getAllAgentPerformance(from: thirtyDaysAgo, to: Date())
        return Array(allPerformance.prefix(limit))
    }

    // MARK: - Issue Analysis

    func getRecurringIssues(minOccurrences: Int) async throws -> [RecurringIssue] {
        // Mock implementation - in production, this would analyze ticket patterns
        return [
            RecurringIssue(
                id: UUID().uuidString,
                category: "Login",
                description: "Passwort-Reset funktioniert nicht",
                occurrenceCount: 15,
                affectedCustomers: 12,
                averageResolutionTime: 4.5,
                suggestedAction: .productFix,
                firstOccurrence: Date().addingTimeInterval(-30 * 24 * 3600),
                lastOccurrence: Date().addingTimeInterval(-2 * 24 * 3600)
            ),
            RecurringIssue(
                id: UUID().uuidString,
                category: "Abrechnung",
                description: "Gebühren werden nicht korrekt angezeigt",
                occurrenceCount: 8,
                affectedCustomers: 8,
                averageResolutionTime: 2.0,
                suggestedAction: .documentationUpdate,
                firstOccurrence: Date().addingTimeInterval(-14 * 24 * 3600),
                lastOccurrence: Date().addingTimeInterval(-1 * 24 * 3600)
            )
        ].filter { $0.occurrenceCount >= minOccurrences }
    }

    func getIssuesByCategory() async throws -> [String: Int] {
        let tickets = try await supportService.getSupportTickets(customerId: nil)
        var categoryCount: [String: Int] = [:]

        for ticket in tickets {
            let category = extractCategory(from: ticket)
            categoryCount[category, default: 0] += 1
        }

        return categoryCount
    }

    func getResolutionTimeByCategory() async throws -> [String: Double] {
        // Mock implementation
        return [
            "Technisch": 24.5,
            "Abrechnung": 12.0,
            "Konto": 8.0,
            "Allgemein": 18.0
        ]
    }

    // MARK: - Trend Analysis

    func getCSATTrend(days: Int) async throws -> [(date: Date, score: Double)] {
        var trend: [(date: Date, score: Double)] = []
        let calendar = Calendar.current

        for dayOffset in (0..<days).reversed() {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            // Mock scores with slight variation
            let baseScore = 4.2
            let variation = Double.random(in: -0.3...0.3)
            trend.append((date: date, score: baseScore + variation))
        }

        return trend
    }

    func getTicketVolumeTrend(days: Int) async throws -> [(date: Date, count: Int)] {
        var trend: [(date: Date, count: Int)] = []
        let calendar = Calendar.current

        for dayOffset in (0..<days).reversed() {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            // Mock volume
            let baseVolume = 15
            let variation = Int.random(in: -5...10)
            trend.append((date: date, count: max(0, baseVolume + variation)))
        }

        return trend
    }

    // MARK: - Private Helpers

    private func calculateAverageResolutionTime(tickets: [SupportTicket]) -> Double {
        let closedTickets = tickets.filter { $0.status == .closed || $0.status == .resolved }
        guard !closedTickets.isEmpty else { return 0 }

        let totalHours = closedTickets.map { ticket in
            ticket.updatedAt.timeIntervalSince(ticket.createdAt) / 3600
        }.reduce(0, +)

        return totalHours / Double(closedTickets.count)
    }

    private func extractCategory(from ticket: SupportTicket) -> String {
        // Simple category extraction from subject
        let subject = ticket.subject.lowercased()
        if subject.contains("login") || subject.contains("passwort") { return "Login" }
        if subject.contains("zahlung") || subject.contains("gebühr") || subject.contains("abrechnung") { return "Abrechnung" }
        if subject.contains("konto") { return "Konto" }
        if subject.contains("technisch") || subject.contains("fehler") || subject.contains("bug") { return "Technisch" }
        return "Allgemein"
    }

    private func getAgentName(for agentId: String) -> String {
        if agentId.contains("csr1") { return "Stefan Müller" }
        if agentId.contains("csr2") { return "Anna Schmidt" }
        if agentId.contains("csr3") { return "Markus Weber" }
        return "Unbekannt"
    }
}

