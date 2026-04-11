import Foundation

// MARK: - Customer Support Service - Ticket Operations Extension
/// Extension handling all support ticket operations (CSR and user self-service)

extension CustomerSupportService {

    // MARK: - Ticket Retrieval

    func getSupportTickets(userId: String?) async throws -> [SupportTicket] {
        try await validatePermission(.viewCustomerSupportHistory)

        // Try loading from backend first
        if let apiService = ticketAPIService {
            do {
                let backendTickets = try await apiService.fetchTickets(
                    userId: userId,
                    status: nil as SupportTicket.TicketStatus?,
                    limit: 100,
                    skip: 0
                )

                // Update local cache
                await MainActor.run {
                    // Merge with existing tickets (avoid duplicates)
                    for backendTicket in backendTickets {
                        if let index = self.mockTickets.firstIndex(where: { $0.id == backendTicket.id }) {
                            self.mockTickets[index] = backendTicket
                        } else {
                            self.mockTickets.append(backendTicket)
                        }
                    }
                }

                // Return filtered tickets
                if let uid = userId {
                    return backendTickets.filter { $0.userId == uid }
                }
                return backendTickets
            } catch {
                print("⚠️ CustomerSupportService: Failed to load tickets from backend: \(error.localizedDescription)")
                // Fall through to mock data
            }
        }

        // Fallback to mock data
        if let uid = userId {
            return mockTickets.filter { $0.userId == uid }
        }
        return mockTickets
    }

    func getUserTickets(userId: String) async throws -> [SupportTicket] {
        // Users can view their own tickets without permission check

        // Try loading from backend first
        if let apiService = ticketAPIService {
            do {
                let backendTickets = try await apiService.fetchTickets(
                    userId: userId,
                    status: nil as SupportTicket.TicketStatus?,
                    limit: 100,
                    skip: 0
                )

                // Update local cache
                await MainActor.run {
                    for backendTicket in backendTickets {
                        if let index = self.mockTickets.firstIndex(where: { $0.id == backendTicket.id }) {
                            self.mockTickets[index] = backendTicket
                        } else {
                            self.mockTickets.append(backendTicket)
                        }
                    }
                }

                return backendTickets
            } catch {
                print("⚠️ CustomerSupportService: Failed to load user tickets from backend: \(error.localizedDescription)")
                // Fall through to mock data
            }
        }

        // Fallback to mock data
        return mockTickets.filter { $0.userId == userId }
    }

    func getTicket(ticketId: String) async throws -> SupportTicket? {
        // Users can view their own tickets, CSR can view any ticket

        // Try loading from backend first
        if let apiService = ticketAPIService {
            do {
                if let backendTicket = try await apiService.fetchTicket(ticketId: ticketId) {
                    // Update local cache
                    await MainActor.run {
                        if let index = self.mockTickets.firstIndex(where: { $0.id == ticketId }) {
                            self.mockTickets[index] = backendTicket
                        } else {
                            self.mockTickets.append(backendTicket)
                        }
                    }
                    return backendTicket
                }
            } catch {
                print("⚠️ CustomerSupportService: Failed to load ticket from backend: \(error.localizedDescription)")
                // Fall through to mock data
            }
        }

        // Fallback to mock data
        return mockTickets.first(where: { $0.id == ticketId })
    }

    // MARK: - CSR Ticket Creation

    func createSupportTicket(_ ticket: SupportTicketCreate) async throws -> SupportTicket {
        try await validatePermission(.createSupportTicket)

        let customer = mockCustomers.first(where: { $0.id == ticket.userId })
        let customerName = customer?.fullName ?? "Kunde"
        let customerLanguage = customer?.language

        await logAction(
            .createSupportTicket,
            customerId: ticket.userId,
            description: "Support-Ticket erstellt: \(ticket.subject)"
        )

        var newTicket = SupportTicket(
            id: UUID().uuidString,
            ticketNumber: generateTicketNumber(),
            userId: ticket.userId,
            customerName: customerName,
            subject: ticket.subject,
            description: ticket.description,
            status: .open,
            priority: ticket.priority,
            assignedTo: nil,  // Will be auto-assigned
            createdAt: Date(),
            updatedAt: Date(),
            responses: []
        )

        // Auto-assign ticket using round-robin with workload consideration
        let assignmentResult = assignmentService.findBestAgent(
            for: newTicket,
            agents: mockAgents,
            customerLanguage: customerLanguage
        )

        switch assignmentResult {
        case .assigned(let agentId, let agentName, let reason):
            newTicket.assignedTo = agentId
            newTicket.status = .inProgress
            logger.info("🎯 Auto-assigned ticket \(newTicket.ticketNumber) to \(agentName): \(reason)")

            // Update agent workload and notify (use local copy to avoid concurrent capture)
            if let agentIndex = mockAgents.firstIndex(where: { $0.id == agentId }) {
                mockAgents[agentIndex].currentTicketCount += 1
                let ticketForNotification = newTicket
                await sendAgentAssignmentNotification(ticket: ticketForNotification, agent: mockAgents[agentIndex])
            }

        case .queued(let reason):
            logger.info("📥 Ticket \(newTicket.ticketNumber) queued: \(reason)")

        case .failed(let error):
            logger.error("❌ Auto-assignment failed: \(error)")
        }

        // Write-through: Sync immediately if API service available
        if let apiService = ticketAPIService {
            do {
                let syncedTicket = try await apiService.createTicket(ticket)

                await MainActor.run {
                    self.mockTickets.append(syncedTicket)
                }

                logger.info("✅ Support ticket created and synced: \(syncedTicket.ticketNumber)")
                return syncedTicket
            } catch {
                logger.error("⚠️ Failed to sync ticket immediately: \(error.localizedDescription)")
                // Fall through to local storage
            }
        }

        let ticketToAppend = newTicket
        await MainActor.run {
            self.mockTickets.append(ticketToAppend)
        }
        logger.info("✅ Support ticket created: \(newTicket.ticketNumber)")
        return newTicket
    }

    // MARK: - User Self-Service Ticket Creation

    func createUserTicket(
        userId: String,
        subject: String,
        description: String,
        category: String
    ) async throws -> SupportTicket {
        // No CSR permission required - users can create their own tickets

        let customer = mockCustomers.first(where: { $0.id == userId })
        let customerName = customer?.fullName ?? "Benutzer"
        let customerLanguage = customer?.language
        let priority = mapCategoryToPriority(category)

        logger.info("📧 User \(userId) creating support ticket: \(subject)")

        var newTicket = SupportTicket(
            id: UUID().uuidString,
            ticketNumber: generateTicketNumber(),
            userId: userId,
            customerName: customerName,
            subject: subject,
            description: description,
            status: .open,
            priority: priority,
            assignedTo: nil,  // Will be auto-assigned
            createdAt: Date(),
            updatedAt: Date(),
            responses: []
        )

        // Auto-assign ticket using round-robin with workload consideration
        let assignmentResult = assignmentService.findBestAgent(
            for: newTicket,
            agents: mockAgents,
            customerLanguage: customerLanguage
        )

        switch assignmentResult {
        case .assigned(let agentId, let agentName, let reason):
            newTicket.assignedTo = agentId
            newTicket.status = .inProgress
            logger.info("🎯 Auto-assigned user ticket \(newTicket.ticketNumber) to \(agentName): \(reason)")

            // Update agent workload and notify (use local copy to avoid concurrent capture)
            if let agentIndex = mockAgents.firstIndex(where: { $0.id == agentId }) {
                mockAgents[agentIndex].currentTicketCount += 1
                let ticketForNotification = newTicket
                await sendAgentAssignmentNotification(ticket: ticketForNotification, agent: mockAgents[agentIndex])
            }

        case .queued(let reason):
            logger.info("📥 User ticket \(newTicket.ticketNumber) queued: \(reason)")

        case .failed(let error):
            logger.error("❌ Auto-assignment failed for user ticket: \(error)")
        }

        // Write-through: Sync immediately if API service available
        if let apiService = ticketAPIService {
            do {
                let ticketCreate = SupportTicketCreate(
                    userId: userId,
                    subject: subject,
                    description: description,
                    priority: priority
                )

                let syncedTicket = try await apiService.createTicket(ticketCreate)

                await MainActor.run {
                    self.mockTickets.append(syncedTicket)
                }

                logger.info("✅ Support ticket created and synced: \(syncedTicket.ticketNumber) for user \(userId)")
                return syncedTicket
            } catch {
                logger.error("⚠️ Failed to sync user ticket immediately: \(error.localizedDescription)")
                // Fall through to local storage
            }
        }

        let ticketToAppend = newTicket
        await MainActor.run {
            self.mockTickets.append(ticketToAppend)
        }
        logger.info("✅ Support ticket created: \(newTicket.ticketNumber) for user \(userId)")

        return newTicket
    }

    // MARK: - Ticket Response

    func respondToTicket(ticketId: String, response: String, isInternal: Bool) async throws {
        try await validatePermission(.respondToSupportTicket)

        // Write-through: Sync response to backend immediately if API service available
        if let apiService = ticketAPIService {
            do {
                let backendResponse = try await apiService.replyToTicket(
                    ticketId: ticketId,
                    message: response,
                    isInternal: isInternal
                )

                // Update local ticket with response
                await MainActor.run {
                    if let ticketIndex = self.mockTickets.firstIndex(where: { $0.id == ticketId }) {
                        var ticket = self.mockTickets[ticketIndex]
                        ticket.responses.append(backendResponse)
                        ticket.updatedAt = Date()
                        self.mockTickets[ticketIndex] = ticket
                    }
                }

                logger.info("✅ Ticket response synced to backend")
                return
            } catch {
                logger.error("⚠️ Failed to sync ticket response immediately: \(error.localizedDescription)")
                // Fall through to local storage
            }
        }

        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]
        let endUserObjectId = ticket.userId

        // Create response locally
        let ticketResponse = TicketResponse(
            id: UUID().uuidString,
            agentId: currentAgentId,
            agentName: currentAgentName,
            message: response,
            isInternal: isInternal,
            createdAt: Date()
        )

        var updatedResponses = ticket.responses
        updatedResponses.append(ticketResponse)

        let updatedTicket = SupportTicket(
            id: ticket.id,
            ticketNumber: ticket.ticketNumber,
            userId: ticket.userId,
            customerName: ticket.customerName,
            subject: ticket.subject,
            description: ticket.description,
            status: isInternal ? ticket.status : .inProgress,
            priority: ticket.priority,
            assignedTo: ticket.assignedTo,
            createdAt: ticket.createdAt,
            updatedAt: Date(),
            responses: updatedResponses
        )

        await MainActor.run {
            self.mockTickets[ticketIndex] = updatedTicket
        }

        let actionDescription = isInternal ? "Interne Notiz auf Ticket \(ticketId)" : "Antwort auf Ticket \(ticketId)"
        await logAction(.respondToSupportTicket, customerId: endUserObjectId, description: actionDescription)

        // Send notification to customer if it's a public response
        if !isInternal {
            await sendTicketResponseNotification(ticket: ticket, endUserObjectId: endUserObjectId, ticketId: ticketId)
        }
    }

    // MARK: - Ticket Escalation

    func escalateTicket(ticketId: String, reason: String) async throws {
        try await validatePermission(.escalateToAdmin)
        try await escalateTicketInternal(ticketId: ticketId, reason: reason, isAutomatic: false)
    }

    /// Internal escalation method that can be called without permission check (for automatic escalations)
    func escalateTicketInternal(ticketId: String, reason: String, isAutomatic: Bool) async throws {
        // Find the ticket
        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]

        // Update ticket status to escalated if not already
        if ticket.status != .escalated {
            mockTickets[ticketIndex].status = .escalated
            mockTickets[ticketIndex].updatedAt = Date()
        }

        // Log action
        await logAction(
            .escalateToAdmin,
            customerId: ticket.userId,
            description: isAutomatic ? "Automatische Eskalation: Ticket \(ticketId) - \(reason)" : "Ticket \(ticketId) eskaliert: \(reason)",
            actionType: .escalation
        )

        // Log compliance event
        let event = ComplianceEvent(
            eventType: .escalation,
            agentId: isAutomatic ? "system" : currentAgentId,
            customerId: ticket.userId,
            description: isAutomatic ? "Automatische Eskalation: Ticket \(ticket.ticketNumber) - \(reason)" : "Support-Ticket \(ticket.ticketNumber) an Admin eskaliert",
            severity: .high,
            requiresReview: isAutomatic
        )
        await auditService.logComplianceEvent(event)

        logger.info("📈 Ticket \(ticket.ticketNumber) escalated: \(reason) (automatic: \(isAutomatic))")
    }

    // MARK: - Agent and Assignment Operations

    func getAvailableAgents() async throws -> [CSRAgent] {
        try await validatePermission(.viewCustomerSupportHistory)
        // Return all agents - caller can filter by canAcceptTickets if needed
        return mockAgents
    }

    func assignTicket(ticketId: String, to agentId: String) async throws {
        try await validatePermission(.respondToSupportTicket)

        // Find the ticket
        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]
        let previousAgentId = ticket.assignedTo

        // Check if reassigning to the same agent - no action needed
        if previousAgentId == agentId {
            logger.info("ℹ️ Ticket \(ticket.ticketNumber) bereits diesem Agent zugewiesen")
            return
        }

        // Find the new agent
        guard let newAgentIndex = mockAgents.firstIndex(where: { $0.id == agentId }) else {
            throw CustomerSupportError.invalidRequest("Agent nicht gefunden")
        }

        // Check new agent availability
        guard mockAgents[newAgentIndex].canAcceptTickets else {
            throw CustomerSupportError.invalidRequest("Agent kann keine weiteren Tickets annehmen (\(mockAgents[newAgentIndex].currentTicketCount)/\(CSRAgent.maxTickets) Tickets)")
        }

        // Decrease old agent's ticket count if reassigning
        if let oldAgentId = previousAgentId,
           let oldAgentIndex = mockAgents.firstIndex(where: { $0.id == oldAgentId }) {
            self.mockAgents[oldAgentIndex].currentTicketCount = max(0, self.mockAgents[oldAgentIndex].currentTicketCount - 1)
            logger.info("📉 Agent \(self.mockAgents[oldAgentIndex].name) Ticket-Anzahl verringert")
        }

        // Increase new agent's ticket count
        mockAgents[newAgentIndex].currentTicketCount += 1

        // Update ticket assignment
        mockTickets[ticketIndex].assignedTo = agentId
        mockTickets[ticketIndex].updatedAt = Date()
        if mockTickets[ticketIndex].status == .open {
            mockTickets[ticketIndex].status = .inProgress
        }

        let newAgentName = mockAgents[newAgentIndex].name

        // Log the assignment action
        await logAction(
            .respondToSupportTicket,
            customerId: ticket.userId,
            description: "Ticket \(ticket.ticketNumber) zugewiesen an \(newAgentName)"
        )

        // Send notification to assigned agent
        await sendAgentAssignmentNotification(ticket: mockTickets[ticketIndex], agent: mockAgents[newAgentIndex])

        logger.info("✅ Ticket \(ticket.ticketNumber) assigned to \(newAgentName) (\(agentId))")
    }

    // MARK: - Private Helpers

    private func generateTicketNumber() -> String {
        "TKT-\(Int.random(in: 10000...99999))"
    }

    private func mapCategoryToPriority(_ category: String) -> SupportTicket.TicketPriority {
        switch category {
        case "Security Concern", "Account Issue":
            return .high
        case "Technical Problem", "Billing & Payments":
            return .medium
        default:
            return .low
        }
    }

    private func sendTicketResponseNotification(ticket: SupportTicket, endUserObjectId: String, ticketId: String) async {
        let customer = mockCustomers.first(where: { $0.id == endUserObjectId })
        let notifyUserId = customer?.id ?? endUserObjectId

        notificationService.createNotification(
            title: "Neue Antwort auf Support-Ticket",
            message: "Ihr Ticket \"\(ticket.subject)\" hat eine neue Antwort erhalten.",
            type: .system,
            priority: .medium,
            for: notifyUserId,
            metadata: ["ticketId": ticketId]
        )

        logger.info("📧 Notification sent to user \(notifyUserId) (userId: \(endUserObjectId)) for ticket \(ticketId)")

        if let concreteService = notificationService as? NotificationService {
            logger.info("📧 NotificationService has \(concreteService.notifications.count) total notifications")
            let userNotifications = concreteService.notifications.filter { $0.userId == notifyUserId }
            logger.info("📧 User \(notifyUserId) has \(userNotifications.count) notifications")
        }
    }

    private func sendAgentAssignmentNotification(ticket: SupportTicket, agent: CSRAgent) async {
        // Notify the assigned CSR agent about the new ticket
        notificationService.createNotification(
            title: "Neues Ticket zugewiesen",
            message: "Ticket \(ticket.ticketNumber): \"\(ticket.subject)\" wurde Ihnen zugewiesen. Priorität: \(ticket.priority.displayName)",
            type: .system,
            priority: ticket.priority == .urgent || ticket.priority == .high ? .high : .medium,
            for: agent.id,
            metadata: [
                "ticketId": ticket.id,
                "ticketNumber": ticket.ticketNumber,
                "userId": ticket.userId,
                "priority": ticket.priority.rawValue
            ]
        )

        logger.info("📧 Assignment notification sent to CSR \(agent.name) (\(agent.id)) for ticket \(ticket.ticketNumber)")

        if let concreteService = notificationService as? NotificationService {
            let agentNotifications = concreteService.notifications.filter { $0.userId == agent.id }
            logger.info("📧 Agent \(agent.name) has \(agentNotifications.count) notifications")
        }
    }
}

