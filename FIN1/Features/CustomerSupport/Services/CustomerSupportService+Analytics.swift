import Foundation

// MARK: - Customer Support Service - Analytics Extension
/// Handles ticket and agent metrics calculations

extension CustomerSupportService {

    // MARK: - Ticket Metrics

    func getTicketMetrics(from startDate: Date, to endDate: Date) async throws -> TicketMetrics {
        let ticketsInPeriod = mockTickets.filter { ticket in
            ticket.createdAt >= startDate && ticket.createdAt <= endDate
        }

        let closedInPeriod = mockTickets.filter { ticket in
            guard let closedAt = ticket.closedAt else { return false }
            return closedAt >= startDate && closedAt <= endDate
        }

        // Count by status
        let openCount = ticketsInPeriod.filter { $0.status == .open }.count
        let inProgressCount = ticketsInPeriod.filter { $0.status == .inProgress }.count
        let waitingCount = ticketsInPeriod.filter { $0.status == .waitingForCustomer }.count
        let escalatedCount = ticketsInPeriod.filter { $0.status == .escalated }.count
        let resolvedCount = ticketsInPeriod.filter { $0.status == .resolved }.count
        let archivedCount = ticketsInPeriod.filter { $0.status == .archived }.count

        // Count reopened (tickets with parentTicketId)
        let reopenedCount = ticketsInPeriod.filter { $0.parentTicketId != nil }.count

        // Count by priority
        var priorityCounts: [String: Int] = [:]
        for priority in SupportTicket.TicketPriority.allCases {
            priorityCounts[priority.displayName] = ticketsInPeriod.filter { $0.priority == priority }.count
        }

        // Calculate time metrics (mock values - in production, calculate from actual data)
        let avgFirstResponse = self.calculateAverageFirstResponseTime(tickets: closedInPeriod)
        let avgResolution = self.calculateAverageResolutionTime(tickets: closedInPeriod)
        let medianResolution = self.calculateMedianResolutionTime(tickets: closedInPeriod)

        return TicketMetrics(
            periodStart: startDate,
            periodEnd: endDate,
            totalTickets: ticketsInPeriod.count,
            newTickets: ticketsInPeriod.count,
            closedTickets: closedInPeriod.count,
            reopenedTickets: reopenedCount,
            archivedTickets: archivedCount,
            openTickets: openCount,
            inProgressTickets: inProgressCount,
            waitingForCustomerTickets: waitingCount,
            escalatedTickets: escalatedCount,
            resolvedTickets: resolvedCount,
            averageFirstResponseTime: avgFirstResponse,
            averageResolutionTime: avgResolution,
            medianResolutionTime: medianResolution,
            ticketsByPriority: priorityCounts,
            ticketsByCategory: [:]  // Would need category field on tickets
        )
    }

    // MARK: - Agent Metrics

    func getAgentMetrics(agentId: String, from startDate: Date, to endDate: Date) async throws -> AgentMetrics {
        guard let agent = mockAgents.first(where: { $0.id == agentId }) else {
            return .empty
        }

        let agentTickets = mockTickets.filter { ticket in
            ticket.assignedTo == agentId &&
                ticket.createdAt >= startDate && ticket.createdAt <= endDate
        }

        let closedTickets = agentTickets.filter { $0.status == .closed || $0.status == .resolved }
        let escalatedTickets = agentTickets.filter { $0.status == .escalated }
        let reopenedTickets = agentTickets.filter { $0.parentTicketId != nil }

        // Get survey data for this agent (mock - would come from survey service)
        let surveyData = await getAgentSurveyData(agentId: agentId, from: startDate, to: endDate)

        return AgentMetrics(
            agentId: agentId,
            agentName: agent.name,
            periodStart: startDate,
            periodEnd: endDate,
            ticketsAssigned: agentTickets.count,
            ticketsClosed: closedTickets.count,
            ticketsEscalated: escalatedTickets.count,
            ticketsReopened: reopenedTickets.count,
            averageFirstResponseTime: self.calculateAverageFirstResponseTime(tickets: closedTickets),
            averageResolutionTime: self.calculateAverageResolutionTime(tickets: closedTickets),
            customerSatisfactionScore: surveyData.averageScore,
            surveysReceived: surveyData.totalSurveys,
            positiveRatings: surveyData.positiveCount,
            negativeRatings: surveyData.negativeCount
        )
    }

    // MARK: - All Agents Metrics

    func getAllAgentMetrics(from startDate: Date, to endDate: Date) async throws -> [AgentMetrics] {
        var metrics: [AgentMetrics] = []
        for agent in mockAgents {
            let agentMetrics = try await getAgentMetrics(agentId: agent.id, from: startDate, to: endDate)
            metrics.append(agentMetrics)
        }
        return metrics.sorted { $0.customerSatisfactionScore > $1.customerSatisfactionScore }
    }

    // MARK: - Private Helpers

    private func calculateAverageFirstResponseTime(tickets: [SupportTicket]) -> Double {
        guard !tickets.isEmpty else { return 0 }

        var totalHours: Double = 0
        var count = 0

        for ticket in tickets {
            if let firstResponse = ticket.responses.first(where: { !$0.isInternal }) {
                let hours = firstResponse.createdAt.timeIntervalSince(ticket.createdAt) / 3_600
                totalHours += hours
                count += 1
            }
        }

        guard count > 0 else { return 0 }
        return totalHours / Double(count)
    }

    private func calculateAverageResolutionTime(tickets: [SupportTicket]) -> Double {
        guard !tickets.isEmpty else { return 0 }

        var totalHours: Double = 0
        var count = 0

        for ticket in tickets {
            if let closedAt = ticket.closedAt {
                let hours = closedAt.timeIntervalSince(ticket.createdAt) / 3_600
                totalHours += hours
                count += 1
            }
        }

        guard count > 0 else { return 0 }
        return totalHours / Double(count)
    }

    private func calculateMedianResolutionTime(tickets: [SupportTicket]) -> Double {
        let resolutionTimes = tickets.compactMap { ticket -> Double? in
            guard let closedAt = ticket.closedAt else { return nil }
            return closedAt.timeIntervalSince(ticket.createdAt) / 3_600
        }.sorted()

        guard !resolutionTimes.isEmpty else { return 0 }

        let middle = resolutionTimes.count / 2
        if resolutionTimes.count % 2 == 0 {
            return (resolutionTimes[middle - 1] + resolutionTimes[middle]) / 2
        } else {
            return resolutionTimes[middle]
        }
    }

    private func getAgentSurveyData(agentId: String, from: Date, to: Date) async -> (
        averageScore: Double,
        totalSurveys: Int,
        positiveCount: Int,
        negativeCount: Int
    ) {
        // Mock survey data - in production, would query satisfactionSurveyService
        do {
            let surveys = try await satisfactionSurveyService.getAgentSurveys(agentId: agentId)
            let filteredSurveys = surveys.filter { $0.submittedAt >= from && $0.submittedAt <= to }

            guard !filteredSurveys.isEmpty else {
                return (0, 0, 0, 0)
            }

            let totalRating = filteredSurveys.reduce(0) { $0 + $1.rating }
            let avgScore = Double(totalRating) / Double(filteredSurveys.count)
            let positiveCount = filteredSurveys.filter { $0.rating >= 4 }.count
            let negativeCount = filteredSurveys.filter { $0.rating <= 2 }.count

            return (avgScore, filteredSurveys.count, positiveCount, negativeCount)
        } catch {
            return (0, 0, 0, 0)
        }
    }
}

// MARK: - TicketPriority CaseIterable

extension SupportTicket.TicketPriority: CaseIterable {
    static var allCases: [SupportTicket.TicketPriority] {
        [.low, .medium, .high, .urgent]
    }
}

