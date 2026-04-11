import Foundation
import os

// MARK: - Trend Detection Service

/// Service for detecting trends and patterns in support tickets
final class TrendDetectionService {

    private let logger = Logger(subsystem: "com.fin.app", category: "TrendDetection")
    private var config: TrendDetectionConfig
    private var alerts: [TrendAlert] = []

    init(config: TrendDetectionConfig = .default) {
        self.config = config
    }

    // MARK: - Main Detection

    /// Analyze tickets and detect trends
    func detectTrends(
        currentPeriodTickets: [SupportTicket],
        previousPeriodTickets: [SupportTicket],
        surveys: [SatisfactionSurvey] = []
    ) -> [SupportTrend] {
        var trends: [SupportTrend] = []

        // 1. Volume Spike Detection
        if let volumeTrend = detectVolumeSpike(current: currentPeriodTickets, previous: previousPeriodTickets) {
            trends.append(volumeTrend)
        }

        // 2. Recurring Issues Detection
        trends.append(contentsOf: detectRecurringIssues(tickets: currentPeriodTickets))

        // 3. Long Resolution Time Detection
        if let resolutionTrend = detectLongResolutionTimes(tickets: currentPeriodTickets) {
            trends.append(resolutionTrend)
        }

        // 4. High Escalation Rate Detection
        if let escalationTrend = detectHighEscalationRate(tickets: currentPeriodTickets) {
            trends.append(escalationTrend)
        }

        // 5. Negative CSAT Detection
        if let csatTrend = detectNegativeCSAT(surveys: surveys) {
            trends.append(csatTrend)
        }

        // 6. Reopened Tickets Detection
        if let reopenTrend = detectHighReopenRate(tickets: currentPeriodTickets) {
            trends.append(reopenTrend)
        }

        logger.info("🔍 Detected \(trends.count) trends")
        return trends
    }

    // MARK: - Volume Spike

    private func detectVolumeSpike(current: [SupportTicket], previous: [SupportTicket]) -> SupportTrend? {
        let currentCount = current.count
        let previousCount = max(previous.count, 1)  // Avoid division by zero

        let percentageChange = (Double(currentCount - previousCount) / Double(previousCount)) * 100

        guard currentCount >= config.volumeSpikeThreshold,
              percentageChange >= config.volumeSpikePercentage else {
            return nil
        }

        return SupportTrend(
            id: UUID().uuidString,
            type: .volumeSpike,
            title: "Ticket-Volumen um \(Int(percentageChange))% gestiegen",
            description: "\(currentCount) Tickets in diesem Zeitraum (zuvor: \(previousCount))",
            severity: percentageChange > 100 ? .critical : .warning,
            ticketCount: currentCount,
            affectedCustomers: Set(current.map { $0.userId }).count,
            percentageChange: percentageChange,
            detectedAt: Date(),
            relatedTicketIds: current.prefix(10).map { $0.id },
            suggestedAction: "Überprüfen Sie die häufigsten Ticket-Themen und erwägen Sie zusätzliche Ressourcen."
        )
    }

    // MARK: - Recurring Issues

    private func detectRecurringIssues(tickets: [SupportTicket]) -> [SupportTrend] {
        var trends: [SupportTrend] = []
        var categories = IssueCategory.predefinedCategories

        // Count tickets per category based on keywords
        for ticket in tickets {
            let searchText = "\(ticket.subject) \(ticket.description)".lowercased()

            for (index, category) in categories.enumerated() {
                if category.keywords.contains(where: { searchText.contains($0) }) {
                    categories[index].ticketCount += 1
                    categories[index].lastOccurrence = max(categories[index].lastOccurrence, ticket.createdAt)
                }
            }
        }

        // Create trends for categories exceeding threshold
        for category in categories where category.ticketCount >= config.recurringIssueThreshold {
            let relatedTickets = tickets.filter { ticket in
                let searchText = "\(ticket.subject) \(ticket.description)".lowercased()
                return category.keywords.contains(where: { searchText.contains($0) })
            }

            let trend = SupportTrend(
                id: UUID().uuidString,
                type: .recurringIssue,
                title: "\(category.ticketCount) Tickets zu \"\(category.name)\"",
                description: "Wiederkehrendes Problem erkannt. Möglicherweise ist eine technische Lösung erforderlich.",
                severity: category.ticketCount >= config.recurringIssueThreshold * 2 ? .critical : .warning,
                ticketCount: category.ticketCount,
                affectedCustomers: Set(relatedTickets.map { $0.userId }).count,
                percentageChange: 0,
                detectedAt: Date(),
                relatedTicketIds: relatedTickets.prefix(10).map { $0.id },
                suggestedAction: "Prüfen Sie ob ein Produktfehler vorliegt oder die Dokumentation verbessert werden kann."
            )
            trends.append(trend)
        }

        return trends
    }

    // MARK: - Long Resolution Times

    private func detectLongResolutionTimes(tickets: [SupportTicket]) -> SupportTrend? {
        let closedTickets = tickets.filter { $0.closedAt != nil }
        guard !closedTickets.isEmpty else { return nil }

        let slowTickets = closedTickets.filter { ticket in
            guard let closedAt = ticket.closedAt else { return false }
            let hours = closedAt.timeIntervalSince(ticket.createdAt) / 3600
            return hours > config.longResolutionHours
        }

        let slowPercentage = (Double(slowTickets.count) / Double(closedTickets.count)) * 100
        guard slowPercentage > 20 else { return nil }  // More than 20% are slow

        return SupportTrend(
            id: UUID().uuidString,
            type: .longResolutionTime,
            title: "\(Int(slowPercentage))% der Tickets mit langer Lösungszeit",
            description: "\(slowTickets.count) von \(closedTickets.count) Tickets brauchten länger als \(Int(config.longResolutionHours)) Stunden.",
            severity: slowPercentage > 40 ? .critical : .warning,
            ticketCount: slowTickets.count,
            affectedCustomers: Set(slowTickets.map { $0.userId }).count,
            percentageChange: slowPercentage,
            detectedAt: Date(),
            relatedTicketIds: slowTickets.prefix(10).map { $0.id },
            suggestedAction: "Analysieren Sie Engpässe im Support-Prozess und prüfen Sie die Agent-Auslastung."
        )
    }

    // MARK: - High Escalation Rate

    private func detectHighEscalationRate(tickets: [SupportTicket]) -> SupportTrend? {
        guard !tickets.isEmpty else { return nil }

        let escalatedTickets = tickets.filter { $0.status == .escalated }
        let escalationRate = (Double(escalatedTickets.count) / Double(tickets.count)) * 100

        guard escalationRate >= config.highEscalationRateThreshold else { return nil }

        return SupportTrend(
            id: UUID().uuidString,
            type: .highEscalationRate,
            title: "Eskalationsrate bei \(Int(escalationRate))%",
            description: "\(escalatedTickets.count) von \(tickets.count) Tickets wurden eskaliert.",
            severity: escalationRate > 30 ? .critical : .warning,
            ticketCount: escalatedTickets.count,
            affectedCustomers: Set(escalatedTickets.map { $0.userId }).count,
            percentageChange: escalationRate,
            detectedAt: Date(),
            relatedTicketIds: escalatedTickets.prefix(10).map { $0.id },
            suggestedAction: "Überprüfen Sie die Schulung der Agents und die Komplexität der Anfragen."
        )
    }

    // MARK: - Negative CSAT

    private func detectNegativeCSAT(surveys: [SatisfactionSurvey]) -> SupportTrend? {
        guard !surveys.isEmpty else { return nil }

        let avgScore = Double(surveys.reduce(0) { $0 + $1.rating }) / Double(surveys.count)
        guard avgScore < config.lowCSATThreshold else { return nil }

        let negativeSurveys = surveys.filter { $0.rating <= 2 }

        return SupportTrend(
            id: UUID().uuidString,
            type: .negativeCSAT,
            title: "CSAT-Score bei \(String(format: "%.1f", avgScore))/5",
            description: "\(negativeSurveys.count) von \(surveys.count) Bewertungen waren negativ (1-2 Sterne).",
            severity: avgScore < 2.5 ? .critical : .warning,
            ticketCount: surveys.count,
            affectedCustomers: Set(surveys.map { $0.userId }).count,
            percentageChange: 0,
            detectedAt: Date(),
            relatedTicketIds: negativeSurveys.prefix(10).map { $0.ticketId },
            suggestedAction: "Analysieren Sie die negativen Bewertungen und verbessern Sie die Servicequalität."
        )
    }

    // MARK: - High Reopen Rate

    private func detectHighReopenRate(tickets: [SupportTicket]) -> SupportTrend? {
        guard !tickets.isEmpty else { return nil }

        let reopenedTickets = tickets.filter { $0.parentTicketId != nil }
        let reopenRate = (Double(reopenedTickets.count) / Double(tickets.count)) * 100

        guard reopenRate >= config.highReopenRateThreshold else { return nil }

        return SupportTrend(
            id: UUID().uuidString,
            type: .reopenedTickets,
            title: "\(Int(reopenRate))% Wiedereröffnungsrate",
            description: "\(reopenedTickets.count) Tickets wurden als Folgeanfragen erstellt.",
            severity: reopenRate > 25 ? .critical : .warning,
            ticketCount: reopenedTickets.count,
            affectedCustomers: Set(reopenedTickets.map { $0.userId }).count,
            percentageChange: reopenRate,
            detectedAt: Date(),
            relatedTicketIds: reopenedTickets.prefix(10).map { $0.id },
            suggestedAction: "Prüfen Sie ob Lösungen vollständig sind und Kunden zufrieden sind."
        )
    }

    // MARK: - Alert Management

    func createAlert(from trend: SupportTrend) -> TrendAlert {
        let alert = TrendAlert(trend: trend)
        alerts.append(alert)
        return alert
    }

    func getActiveAlerts() -> [TrendAlert] {
        alerts.filter { !$0.isDismissed }
    }

    func acknowledgeAlert(_ alertId: String, by agentId: String) {
        if let index = alerts.firstIndex(where: { $0.id == alertId }) {
            alerts[index].isRead = true
            alerts[index].acknowledgedBy = agentId
            alerts[index].acknowledgedAt = Date()
        }
    }

    func dismissAlert(_ alertId: String) {
        if let index = alerts.firstIndex(where: { $0.id == alertId }) {
            alerts[index].isDismissed = true
        }
    }
}

