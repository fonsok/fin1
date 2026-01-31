import Foundation

// MARK: - Support Analytics Service Protocol

/// Service for aggregating and analyzing support metrics
protocol SupportAnalyticsServiceProtocol {

    // MARK: - Overall Metrics

    /// Gets aggregated metrics for a time period
    func getMetrics(from startDate: Date, to endDate: Date) async throws -> SupportMetrics

    /// Gets metrics for the current day
    func getTodayMetrics() async throws -> SupportMetrics

    /// Gets metrics for the current week
    func getWeeklyMetrics() async throws -> SupportMetrics

    /// Gets metrics for the current month
    func getMonthlyMetrics() async throws -> SupportMetrics

    // MARK: - Agent Performance

    /// Gets performance metrics for a specific agent
    func getAgentPerformance(
        agentId: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> AgentPerformanceMetrics

    /// Gets performance metrics for all agents
    func getAllAgentPerformance(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [AgentPerformanceMetrics]

    /// Gets top performing agents
    func getTopPerformingAgents(limit: Int) async throws -> [AgentPerformanceMetrics]

    // MARK: - Issue Analysis

    /// Identifies recurring issues for product improvement
    func getRecurringIssues(minOccurrences: Int) async throws -> [RecurringIssue]

    /// Gets issues by category
    func getIssuesByCategory() async throws -> [String: Int]

    /// Gets average resolution time by category
    func getResolutionTimeByCategory() async throws -> [String: Double]

    // MARK: - Trend Analysis

    /// Gets CSAT score trend over time
    func getCSATTrend(days: Int) async throws -> [(date: Date, score: Double)]

    /// Gets ticket volume trend over time
    func getTicketVolumeTrend(days: Int) async throws -> [(date: Date, count: Int)]
}

