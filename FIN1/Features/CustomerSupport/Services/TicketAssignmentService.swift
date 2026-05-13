import Foundation
import os.log

// MARK: - Ticket Assignment Service
/// Handles automatic ticket assignment using round-robin with workload consideration
/// Designed for medium-sized teams (3-10 CSRs)

final class TicketAssignmentService {

    // MARK: - Configuration

    struct Configuration {
        /// Maximum open tickets per agent before they're considered at capacity
        var maxTicketsPerAgent: Int = 8

        /// Weight for language match in scoring (0-1)
        var languageMatchWeight: Double = 0.4

        /// Weight for specialization match in scoring (0-1)
        var specializationMatchWeight: Double = 0.4

        /// Weight for current workload (lower is better) in scoring (0-1)
        var workloadWeight: Double = 0.2

        /// Whether to auto-assign tickets on creation
        var autoAssignOnCreation: Bool = true

        /// Fallback behavior when no agent available
        var fallbackBehavior: FallbackBehavior = .queueForManualAssignment

        static let `default` = Configuration()
    }

    enum FallbackBehavior {
        case queueForManualAssignment  // Leave unassigned in queue
        case assignToLeastBusy         // Assign anyway to least busy agent
        case notifyAdmins              // Alert admins about unassigned ticket
    }

    // MARK: - Assignment Result

    enum AssignmentResult {
        case assigned(agentId: String, agentName: String, reason: String)
        case queued(reason: String)
        case failed(error: String)

        var isAssigned: Bool {
            if case .assigned = self { return true }
            return false
        }
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.fin.app", category: "TicketAssignment")
    private var configuration: Configuration
    private var lastAssignedAgentIndex: Int = -1  // For round-robin tracking
    private var unassignedTicketQueue: [String] = []  // Ticket IDs waiting for assignment

    // MARK: - Initialization

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public Methods

    /// Finds the best agent for a ticket using round-robin with workload and skills consideration
    /// - Parameters:
    ///   - ticket: The ticket to assign
    ///   - agents: Available CSR agents
    ///   - customerLanguage: Optional customer's preferred language
    /// - Returns: Assignment result with agent info or queue status
    func findBestAgent(
        for ticket: SupportTicket,
        agents: [CSRAgent],
        customerLanguage: String? = nil
    ) -> AssignmentResult {

        self.logger.info("🎯 Finding best agent for ticket \(ticket.ticketNumber)")

        // Step 1: Filter available agents
        let availableAgents = agents.filter { $0.isAvailable }
        guard !availableAgents.isEmpty else {
            self.logger.warning("⚠️ No available agents")
            return self.handleNoAvailableAgents(ticket: ticket, agents: agents)
        }

        // Step 2: Filter by workload capacity
        let agentsWithCapacity = availableAgents.filter {
            $0.currentTicketCount < self.configuration.maxTicketsPerAgent
        }

        if agentsWithCapacity.isEmpty {
            self.logger.warning("⚠️ All agents at capacity")
            return self.handleAllAgentsAtCapacity(ticket: ticket, agents: availableAgents)
        }

        // Step 3: Score agents by skills match
        let ticketLanguage = customerLanguage ?? self.detectTicketLanguage(ticket)
        let ticketSpecializations = self.mapTicketToSpecializations(ticket)

        var scoredAgents: [(agent: CSRAgent, score: Double)] = agentsWithCapacity.map { agent in
            let score = self.calculateAgentScore(
                agent: agent,
                ticketLanguage: ticketLanguage,
                ticketSpecializations: ticketSpecializations
            )
            return (agent, score)
        }

        // Sort by score (highest first)
        scoredAgents.sort { $0.score > $1.score }

        // Step 4: Apply round-robin for agents with similar scores
        let topScore = scoredAgents.first?.score ?? 0
        let tolerance = 0.1  // Consider scores within 10% as "similar"
        let topAgents = scoredAgents.filter { $0.score >= topScore - tolerance }

        // Round-robin selection among top candidates
        let selectedAgent = self.selectWithRoundRobin(from: topAgents.map { $0.agent }, allAgents: agents)

        let reason = self.buildAssignmentReason(
            agent: selectedAgent,
            ticketLanguage: ticketLanguage,
            ticketSpecializations: ticketSpecializations
        )

        self.logger.info("✅ Assigned ticket \(ticket.ticketNumber) to \(selectedAgent.name): \(reason)")

        return .assigned(agentId: selectedAgent.id, agentName: selectedAgent.name, reason: reason)
    }

    /// Process the unassigned ticket queue
    func processQueue(agents: [CSRAgent]) -> [(ticketId: String, result: AssignmentResult)] {
        var results: [(String, AssignmentResult)] = []

        // Process queue from oldest to newest
        for ticketId in self.unassignedTicketQueue {
            // In a real implementation, we'd fetch the ticket details
            // For now, return that it needs manual handling
            results.append((ticketId, .queued(reason: "Wartet auf manuelle Zuweisung")))
        }

        return results
    }

    /// Add ticket to unassigned queue
    func addToQueue(ticketId: String) {
        if !self.unassignedTicketQueue.contains(ticketId) {
            self.unassignedTicketQueue.append(ticketId)
            self.logger.info("📥 Ticket \(ticketId) added to assignment queue")
        }
    }

    /// Remove ticket from queue (when manually assigned)
    func removeFromQueue(ticketId: String) {
        self.unassignedTicketQueue.removeAll { $0 == ticketId }
        self.logger.info("📤 Ticket \(ticketId) removed from assignment queue")
    }

    /// Get current queue status
    var queueStatus: (count: Int, ticketIds: [String]) {
        (self.unassignedTicketQueue.count, self.unassignedTicketQueue)
    }

    /// Update configuration
    func updateConfiguration(_ newConfig: Configuration) {
        self.configuration = newConfig
        self.logger.info("⚙️ Assignment configuration updated")
    }

    // MARK: - Private Methods

    private func calculateAgentScore(
        agent: CSRAgent,
        ticketLanguage: String?,
        ticketSpecializations: [String]
    ) -> Double {
        var score: Double = 0

        // Language match score
        if let language = ticketLanguage {
            let languageMatch = agent.languages.contains { $0.lowercased() == language.lowercased() }
            if languageMatch {
                score += self.configuration.languageMatchWeight
            }
        } else {
            // No language requirement, give partial score
            score += self.configuration.languageMatchWeight * 0.5
        }

        // Specialization match score
        if !ticketSpecializations.isEmpty {
            let matchingSpecs = ticketSpecializations.filter { spec in
                agent.specializations.contains { $0.lowercased().contains(spec.lowercased()) }
            }
            let specScore = Double(matchingSpecs.count) / Double(ticketSpecializations.count)
            score += self.configuration.specializationMatchWeight * specScore
        } else {
            // No specialization requirement, give partial score
            score += self.configuration.specializationMatchWeight * 0.5
        }

        // Workload score (lower workload = higher score)
        let workloadRatio = Double(agent.currentTicketCount) / Double(self.configuration.maxTicketsPerAgent)
        let workloadScore = 1.0 - workloadRatio
        score += self.configuration.workloadWeight * workloadScore

        return score
    }

    private func selectWithRoundRobin(from candidates: [CSRAgent], allAgents: [CSRAgent]) -> CSRAgent {
        guard !candidates.isEmpty else {
            fatalError("No candidates for round-robin selection")
        }

        // Find indices of candidates in the full agent list
        let candidateIndices = candidates.compactMap { candidate in
            allAgents.firstIndex(where: { $0.id == candidate.id })
        }

        // Find the next candidate after the last assigned agent
        let sortedIndices = candidateIndices.sorted()

        for index in sortedIndices {
            if index > self.lastAssignedAgentIndex {
                self.lastAssignedAgentIndex = index
                return allAgents[index]
            }
        }

        // Wrap around to the beginning
        if let firstIndex = sortedIndices.first {
            self.lastAssignedAgentIndex = firstIndex
            return allAgents[firstIndex]
        }

        // Fallback: return first candidate
        self.lastAssignedAgentIndex = candidateIndices.first ?? 0
        return candidates.first!
    }

    private func detectTicketLanguage(_ ticket: SupportTicket) -> String? {
        // Simple language detection based on common German/English words
        let germanIndicators = ["ich", "bitte", "danke", "mein", "nicht", "können", "möchte", "habe", "wurde", "konto"]
        let englishIndicators = ["please", "thank", "my", "account", "would", "could", "have", "been", "help"]

        let text = (ticket.subject + " " + ticket.description).lowercased()

        let germanCount = germanIndicators.filter { text.contains($0) }.count
        let englishCount = englishIndicators.filter { text.contains($0) }.count

        if germanCount > englishCount {
            return "German"
        } else if englishCount > germanCount {
            return "English"
        }

        return "German"  // Default to German
    }

    private func mapTicketToSpecializations(_ ticket: SupportTicket) -> [String] {
        var specializations: [String] = []

        let text = (ticket.subject + " " + ticket.description).lowercased()

        // Map keywords to specializations
        let mappings: [(keywords: [String], specialization: String)] = [
            (["zahlung", "payment", "rechnung", "invoice", "gebühr", "fee", "geld", "money", "überweisung", "transfer"],
             AgentSpecialization.billing.rawValue),

            (["login", "passwort", "password", "zugang", "access", "konto gesperrt", "locked", "authentifizierung", "2fa"],
             AgentSpecialization.security.rawValue),

            (["fehler", "error", "bug", "funktioniert nicht", "doesn't work", "problem", "absturz", "crash", "laden", "loading"],
             AgentSpecialization.technical.rawValue),

            (["investment", "anlage", "investments", "rendite", "return", "aktie", "stock", "handel", "trade"],
             AgentSpecialization.investments.rawValue),

            (["konto", "account", "profil", "profile", "daten", "data", "ändern", "change", "persönlich", "personal"],
             AgentSpecialization.account.rawValue)
        ]

        for mapping in mappings {
            if mapping.keywords.contains(where: { text.contains($0) }) {
                specializations.append(mapping.specialization)
            }
        }

        // If no specialization detected, mark as general
        if specializations.isEmpty {
            specializations.append(AgentSpecialization.general.rawValue)
        }

        return specializations
    }

    private func buildAssignmentReason(
        agent: CSRAgent,
        ticketLanguage: String?,
        ticketSpecializations: [String]
    ) -> String {
        var reasons: [String] = []

        if let language = ticketLanguage, agent.languages.contains(where: { $0.lowercased() == language.lowercased() }) {
            reasons.append("Sprache: \(language)")
        }

        let matchingSpecs = ticketSpecializations.filter { spec in
            agent.specializations.contains { $0.lowercased().contains(spec.lowercased()) }
        }
        if !matchingSpecs.isEmpty {
            reasons.append("Expertise: \(matchingSpecs.joined(separator: ", "))")
        }

        reasons.append("Auslastung: \(agent.currentTicketCount)/\(self.configuration.maxTicketsPerAgent)")

        return reasons.joined(separator: " | ")
    }

    private func handleNoAvailableAgents(ticket: SupportTicket, agents: [CSRAgent]) -> AssignmentResult {
        switch self.configuration.fallbackBehavior {
        case .queueForManualAssignment:
            self.addToQueue(ticketId: ticket.id)
            return .queued(reason: "Keine verfügbaren Agenten - in Warteschlange")

        case .assignToLeastBusy:
            if let leastBusy = agents.min(by: { $0.currentTicketCount < $1.currentTicketCount }) {
                return .assigned(
                    agentId: leastBusy.id,
                    agentName: leastBusy.name,
                    reason: "Notfall-Zuweisung an am wenigsten ausgelasteten Agent"
                )
            }
            return .failed(error: "Keine Agenten im System")

        case .notifyAdmins:
            self.addToQueue(ticketId: ticket.id)
            return .queued(reason: "Admins benachrichtigt - manuelle Zuweisung erforderlich")
        }
    }

    private func handleAllAgentsAtCapacity(ticket: SupportTicket, agents: [CSRAgent]) -> AssignmentResult {
        switch self.configuration.fallbackBehavior {
        case .queueForManualAssignment:
            self.addToQueue(ticketId: ticket.id)
            return .queued(reason: "Alle Agenten ausgelastet (\(self.configuration.maxTicketsPerAgent) Tickets) - in Warteschlange")

        case .assignToLeastBusy:
            if let leastBusy = agents.min(by: { $0.currentTicketCount < $1.currentTicketCount }) {
                return .assigned(
                    agentId: leastBusy.id,
                    agentName: leastBusy.name,
                    reason: "Kapazität überschritten - Zuweisung an \(leastBusy.name) (\(leastBusy.currentTicketCount) Tickets)"
                )
            }
            return .failed(error: "Keine Agenten verfügbar")

        case .notifyAdmins:
            self.addToQueue(ticketId: ticket.id)
            return .queued(reason: "Kapazitätsgrenze erreicht - Admins benachrichtigt")
        }
    }
}

// MARK: - Assignment Statistics

extension TicketAssignmentService {

    struct AssignmentStats {
        let totalAssigned: Int
        let totalQueued: Int
        let agentWorkloads: [(agentName: String, ticketCount: Int, capacity: Int)]
        let averageWorkload: Double
        let queueLength: Int
    }

    func getStatistics(agents: [CSRAgent]) -> AssignmentStats {
        let workloads = agents.map { agent in
            (agent.name, agent.currentTicketCount, self.configuration.maxTicketsPerAgent)
        }

        let totalTickets = agents.reduce(0) { $0 + $1.currentTicketCount }
        let avgWorkload = agents.isEmpty ? 0 : Double(totalTickets) / Double(agents.count)

        return AssignmentStats(
            totalAssigned: totalTickets,
            totalQueued: self.unassignedTicketQueue.count,
            agentWorkloads: workloads,
            averageWorkload: avgWorkload,
            queueLength: self.unassignedTicketQueue.count
        )
    }
}

