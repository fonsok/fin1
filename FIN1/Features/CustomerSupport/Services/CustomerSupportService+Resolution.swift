import Foundation

// MARK: - Customer Support Service - Solution & Resolution Extension
/// Extension handling solution development, documentation, and ticket resolution

extension CustomerSupportService {

    // MARK: - Solution Development

    func addSolution(
        ticketId: String,
        solution: SolutionDetails,
        customerMessage: String
    ) async throws {
        try await validatePermission(.respondToSupportTicket)

        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]

        // Create solution response for the customer
        let solutionResponse = TicketResponse(
            id: UUID().uuidString,
            agentId: currentAgentId,
            agentName: currentAgentName,
            message: customerMessage,
            isInternal: false,
            createdAt: Date(),
            responseType: .solution,
            solutionDetails: solution
        )

        var updatedResponses = ticket.responses
        updatedResponses.append(solutionResponse)

        // Update ticket with solution
        let updatedTicket = SupportTicket(
            id: ticket.id,
            ticketNumber: ticket.ticketNumber,
            userId: ticket.userId,
            customerName: ticket.customerName,
            subject: ticket.subject,
            description: ticket.description,
            status: .inProgress,
            priority: ticket.priority,
            assignedTo: ticket.assignedTo ?? currentAgentId,
            createdAt: ticket.createdAt,
            updatedAt: Date(),
            responses: updatedResponses
        )
        mockTickets[ticketIndex] = updatedTicket

        // Log the solution
        await logAction(
            .respondToSupportTicket,
            customerId: ticket.userId,
            description: "Lösung bereitgestellt für Ticket \(ticket.ticketNumber): \(solution.solutionType.displayName)"
        )

        // Notify customer about the solution
        await sendSolutionNotification(ticket: updatedTicket, solution: solution)

        logger.info("✅ Solution added to ticket \(ticket.ticketNumber): \(solution.solutionType.displayName)")
    }

    func addInternalNote(ticketId: String, note: String) async throws {
        try await validatePermission(.respondToSupportTicket)

        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]

        // Create internal note response
        let internalNote = TicketResponse(
            id: UUID().uuidString,
            agentId: currentAgentId,
            agentName: currentAgentName,
            message: note,
            isInternal: true,
            createdAt: Date(),
            responseType: .internalNote,
            solutionDetails: nil
        )

        var updatedResponses = ticket.responses
        updatedResponses.append(internalNote)

        // Update ticket
        let updatedTicket = SupportTicket(
            id: ticket.id,
            ticketNumber: ticket.ticketNumber,
            userId: ticket.userId,
            customerName: ticket.customerName,
            subject: ticket.subject,
            description: ticket.description,
            status: ticket.status,
            priority: ticket.priority,
            assignedTo: ticket.assignedTo,
            createdAt: ticket.createdAt,
            updatedAt: Date(),
            responses: updatedResponses
        )
        mockTickets[ticketIndex] = updatedTicket

        logger.info("📝 Internal note added to ticket \(ticket.ticketNumber)")
    }

    // MARK: - Dev Team Escalation

    func escalateToDevTeam(ticketId: String, escalation: DevEscalation) async throws {
        try await validatePermission(.escalateToAdmin)

        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]

        // Create solution details with dev escalation
        let solutionDetails = SolutionDetails(
            solutionType: .devEscalation,
            devEscalation: escalation,
            workaround: escalation.workaroundProvided ? "Workaround bereitgestellt - siehe Kundennachricht" : nil
        )

        // Create escalation response
        let escalationResponse = TicketResponse(
            id: UUID().uuidString,
            agentId: currentAgentId,
            agentName: currentAgentName,
            message: "Problem an Entwicklungsteam (\(escalation.devTeam)) weitergeleitet. Severity: \(escalation.severity.displayName). JIRA: \(escalation.jiraTicketId ?? "Wird erstellt")",
            isInternal: true,
            createdAt: Date(),
            responseType: .escalation,
            solutionDetails: solutionDetails
        )

        var updatedResponses = ticket.responses
        updatedResponses.append(escalationResponse)

        // Update ticket status to escalated
        let updatedTicket = SupportTicket(
            id: ticket.id,
            ticketNumber: ticket.ticketNumber,
            userId: ticket.userId,
            customerName: ticket.customerName,
            subject: ticket.subject,
            description: ticket.description,
            status: .escalated,
            priority: mapSeverityToPriority(escalation.severity),
            assignedTo: ticket.assignedTo,
            createdAt: ticket.createdAt,
            updatedAt: Date(),
            responses: updatedResponses
        )
        mockTickets[ticketIndex] = updatedTicket

        // Log escalation
        await logAction(
            .escalateToAdmin,
            customerId: ticket.userId,
            description: "Bug an \(escalation.devTeam) eskaliert: \(escalation.description). Severity: \(escalation.severity.displayName)",
            actionType: .escalation
        )

        // Log compliance event
        let event = ComplianceEvent(
            eventType: .escalation,
            agentId: currentAgentId,
            customerId: ticket.userId,
            description: "Bug-Eskalation an Entwicklung: \(escalation.description)",
            severity: escalation.severity == .critical ? .high : .medium,
            requiresReview: escalation.severity == .critical
        )
        await auditService.logComplianceEvent(event)

        logger.info("🐛 Bug escalated to \(escalation.devTeam) for ticket \(ticket.ticketNumber)")
    }

    // MARK: - Ticket Resolution

    func requestCustomerConfirmation(ticketId: String, message: String) async throws {
        try await validatePermission(.respondToSupportTicket)

        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]

        // Create confirmation request response
        let confirmationRequest = TicketResponse(
            id: UUID().uuidString,
            agentId: currentAgentId,
            agentName: currentAgentName,
            message: message + "\n\n⏳ Bitte bestätigen Sie, dass das Problem gelöst wurde.",
            isInternal: false,
            createdAt: Date(),
            responseType: .message,
            solutionDetails: nil
        )

        var updatedResponses = ticket.responses
        updatedResponses.append(confirmationRequest)

        // Set status to waiting for customer
        let updatedTicket = SupportTicket(
            id: ticket.id,
            ticketNumber: ticket.ticketNumber,
            userId: ticket.userId,
            customerName: ticket.customerName,
            subject: ticket.subject,
            description: ticket.description,
            status: .waitingForCustomer,
            priority: ticket.priority,
            assignedTo: ticket.assignedTo,
            createdAt: ticket.createdAt,
            updatedAt: Date(),
            responses: updatedResponses
        )
        mockTickets[ticketIndex] = updatedTicket

        // Notify customer about the new response (which already contains the confirmation request)
        // No separate confirmation notification needed - the response itself includes the confirmation request
        let customer = mockCustomers.first(where: { $0.id == ticket.userId })
        let userId = customer?.id ?? ticket.userId

        notificationService.createNotification(
            title: "Neue Antwort auf Support-Ticket",
            message: "Ihr Ticket \"\(ticket.subject)\" hat eine neue Antwort erhalten.",
            type: .system,
            priority: .medium,
            for: userId,
            metadata: ["ticketId": ticketId]
        )

        // Log the action
        await logAction(
            .respondToSupportTicket,
            customerId: ticket.userId,
            description: "Bestätigungsanfrage für Ticket \(ticket.ticketNumber) gesendet"
        )

        logger.info("⏳ Waiting for customer confirmation on ticket \(ticket.ticketNumber)")
    }

    func resolveTicket(ticketId: String, resolutionNote: String, customerConfirmed: Bool) async throws {
        try await validatePermission(.respondToSupportTicket)

        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]

        // Create resolution response
        let resolutionResponse = TicketResponse(
            id: UUID().uuidString,
            agentId: currentAgentId,
            agentName: currentAgentName,
            message: resolutionNote + (customerConfirmed ? " ✓ Vom Kunden bestätigt" : ""),
            isInternal: false,
            createdAt: Date(),
            responseType: .statusChange,
            solutionDetails: nil
        )

        var updatedResponses = ticket.responses
        updatedResponses.append(resolutionResponse)

        // Set status to resolved and record closure time
        mockTickets[ticketIndex].status = .resolved
        mockTickets[ticketIndex].updatedAt = Date()
        mockTickets[ticketIndex].closedAt = Date()
        mockTickets[ticketIndex].responses = updatedResponses
        let updatedTicket = mockTickets[ticketIndex]

        // Decrease agent ticket count
        if let assignedAgentId = ticket.assignedTo,
           let agentIndex = mockAgents.firstIndex(where: { $0.id == assignedAgentId }) {
            let currentAgent = mockAgents[agentIndex]
            let updatedAgent = CSRAgent(
                id: currentAgent.id,
                name: currentAgent.name,
                email: currentAgent.email,
                specializations: currentAgent.specializations,
                languages: currentAgent.languages,
                isAvailable: currentAgent.isAvailable,
                currentTicketCount: max(0, currentAgent.currentTicketCount - 1)
            )
            mockAgents[agentIndex] = updatedAgent
        }

        // Log resolution
        await logAction(
            .respondToSupportTicket,
            customerId: ticket.userId,
            description: "Ticket \(ticket.ticketNumber) gelöst. Kundenbestätigung: \(customerConfirmed ? "Ja" : "Nein")"
        )

        // Notify customer
        await sendResolutionNotification(ticket: updatedTicket, customerConfirmed: customerConfirmed)

        // Send satisfaction survey request to customer
        await sendSurveyRequest(ticket: updatedTicket)

        logger.info("✅ Ticket \(ticket.ticketNumber) resolved (customer confirmed: \(customerConfirmed))")
    }

    func closeTicket(ticketId: String, closureReason: String) async throws {
        try await validatePermission(.respondToSupportTicket)

        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]

        // Create closure response
        let closureResponse = TicketResponse(
            id: UUID().uuidString,
            agentId: currentAgentId,
            agentName: currentAgentName,
            message: "Ticket geschlossen: \(closureReason)",
            isInternal: true,
            createdAt: Date(),
            responseType: .statusChange,
            solutionDetails: nil
        )

        var updatedResponses = ticket.responses
        updatedResponses.append(closureResponse)

        // Set status to closed and record closure time
        mockTickets[ticketIndex].status = .closed
        mockTickets[ticketIndex].updatedAt = Date()
        mockTickets[ticketIndex].closedAt = Date()
        mockTickets[ticketIndex].responses = updatedResponses
        let updatedTicket = mockTickets[ticketIndex]

        // Decrease agent ticket count if not already resolved
        if ticket.status != .resolved,
           let assignedAgentId = ticket.assignedTo,
           let agentIndex = mockAgents.firstIndex(where: { $0.id == assignedAgentId }) {
            let currentAgent = mockAgents[agentIndex]
            let updatedAgent = CSRAgent(
                id: currentAgent.id,
                name: currentAgent.name,
                email: currentAgent.email,
                specializations: currentAgent.specializations,
                languages: currentAgent.languages,
                isAvailable: currentAgent.isAvailable,
                currentTicketCount: max(0, currentAgent.currentTicketCount - 1)
            )
            mockAgents[agentIndex] = updatedAgent
        }

        // Log closure
        await logAction(
            .respondToSupportTicket,
            customerId: ticket.userId,
            description: "Ticket \(ticket.ticketNumber) geschlossen: \(closureReason)"
        )

        // Send satisfaction survey request to customer
        await sendSurveyRequest(ticket: updatedTicket)

        logger.info("🔒 Ticket \(ticket.ticketNumber) closed: \(closureReason)")
    }
}

