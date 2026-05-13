import Foundation

// MARK: - Ticket Metrics

/// Aggregated ticket metrics for a time period
struct TicketMetrics: Codable {
    let periodStart: Date
    let periodEnd: Date

    // Volume metrics
    let totalTickets: Int
    let newTickets: Int
    let closedTickets: Int
    let reopenedTickets: Int
    let archivedTickets: Int

    // Status breakdown
    let openTickets: Int
    let inProgressTickets: Int
    let waitingForCustomerTickets: Int
    let escalatedTickets: Int
    let resolvedTickets: Int

    // Time metrics (in hours)
    let averageFirstResponseTime: Double
    let averageResolutionTime: Double
    let medianResolutionTime: Double

    // Priority breakdown
    let ticketsByPriority: [String: Int]

    // Category breakdown (if applicable)
    let ticketsByCategory: [String: Int]

    // Computed display values
    var firstResponseTimeFormatted: String {
        self.formatHours(self.averageFirstResponseTime)
    }

    var resolutionTimeFormatted: String {
        self.formatHours(self.averageResolutionTime)
    }

    var closureRate: Double {
        guard self.totalTickets > 0 else { return 0 }
        return Double(self.closedTickets) / Double(self.totalTickets) * 100
    }

    var escalationRate: Double {
        guard self.totalTickets > 0 else { return 0 }
        return Double(self.escalatedTickets) / Double(self.totalTickets) * 100
    }

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return String(format: "%.0f Min", hours * 60)
        } else if hours < 24 {
            return String(format: "%.1f Std", hours)
        } else {
            return String(format: "%.1f Tage", hours / 24)
        }
    }

    static var empty: TicketMetrics {
        TicketMetrics(
            periodStart: Date(),
            periodEnd: Date(),
            totalTickets: 0,
            newTickets: 0,
            closedTickets: 0,
            reopenedTickets: 0,
            archivedTickets: 0,
            openTickets: 0,
            inProgressTickets: 0,
            waitingForCustomerTickets: 0,
            escalatedTickets: 0,
            resolvedTickets: 0,
            averageFirstResponseTime: 0,
            averageResolutionTime: 0,
            medianResolutionTime: 0,
            ticketsByPriority: [:],
            ticketsByCategory: [:]
        )
    }
}

// MARK: - Agent Metrics

/// Individual agent performance metrics
struct AgentMetrics: Identifiable, Codable {
    var id: String { self.agentId }

    let agentId: String
    let agentName: String
    let periodStart: Date
    let periodEnd: Date

    // Volume
    let ticketsAssigned: Int
    let ticketsClosed: Int
    let ticketsEscalated: Int
    let ticketsReopened: Int

    // Time metrics (in hours)
    let averageFirstResponseTime: Double
    let averageResolutionTime: Double

    // Quality metrics
    let customerSatisfactionScore: Double  // 1-5 average
    let surveysReceived: Int
    let positiveRatings: Int
    let negativeRatings: Int

    // Computed properties
    var closureRate: Double {
        guard self.ticketsAssigned > 0 else { return 0 }
        return Double(self.ticketsClosed) / Double(self.ticketsAssigned) * 100
    }

    var escalationRate: Double {
        guard self.ticketsAssigned > 0 else { return 0 }
        return Double(self.ticketsEscalated) / Double(self.ticketsAssigned) * 100
    }

    var reopenRate: Double {
        guard self.ticketsClosed > 0 else { return 0 }
        return Double(self.ticketsReopened) / Double(self.ticketsClosed) * 100
    }

    var positiveRatingPercentage: Double {
        guard self.surveysReceived > 0 else { return 0 }
        return Double(self.positiveRatings) / Double(self.surveysReceived) * 100
    }

    var performanceLevel: PerformanceLevel {
        if self.customerSatisfactionScore >= 4.5 && self.closureRate >= 80 { return .excellent }
        if self.customerSatisfactionScore >= 4.0 && self.closureRate >= 70 { return .good }
        if self.customerSatisfactionScore >= 3.0 && self.closureRate >= 50 { return .average }
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

        var icon: String {
            switch self {
            case .excellent: return "star.fill"
            case .good: return "hand.thumbsup.fill"
            case .average: return "minus.circle.fill"
            case .needsImprovement: return "exclamationmark.triangle.fill"
            }
        }
    }

    static var empty: AgentMetrics {
        AgentMetrics(
            agentId: "",
            agentName: "",
            periodStart: Date(),
            periodEnd: Date(),
            ticketsAssigned: 0,
            ticketsClosed: 0,
            ticketsEscalated: 0,
            ticketsReopened: 0,
            averageFirstResponseTime: 0,
            averageResolutionTime: 0,
            customerSatisfactionScore: 0,
            surveysReceived: 0,
            positiveRatings: 0,
            negativeRatings: 0
        )
    }
}

// MARK: - Time Period

enum MetricsPeriod: String, CaseIterable {
    case today = "Heute"
    case week = "Diese Woche"
    case month = "Dieser Monat"
    case quarter = "Dieses Quartal"
    case year = "Dieses Jahr"
    case custom = "Benutzerdefiniert"

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return (start, now)
        case .quarter:
            let start = calendar.date(byAdding: .month, value: -3, to: now)!
            return (start, now)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now)!
            return (start, now)
        case .custom:
            return (now, now)  // Should be set manually
        }
    }
}

