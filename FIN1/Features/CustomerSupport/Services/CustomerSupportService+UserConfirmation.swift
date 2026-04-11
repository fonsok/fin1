import Foundation

// MARK: - Customer Support Service - User Confirmation Extension
/// Extension handling user self-service confirmation for ticket resolution

extension CustomerSupportService {

    // MARK: - User Confirmation (Self-Service)

    func userConfirmProblemSolved(ticketId: String, userId: String) async throws {
        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]

        // Verify user owns this ticket
        let customer = mockCustomers.first(where: { $0.id == userId })
        guard ticket.userId == userId else {
            throw CustomerSupportError.invalidRequest("Sie können nur eigene Tickets bestätigen")
        }

        // Only allow confirmation if waiting for customer
        guard ticket.status == .waitingForCustomer else {
            throw CustomerSupportError.invalidRequest("Ticket wartet nicht auf Bestätigung")
        }

        // Add confirmation response
        let confirmationResponse = TicketResponse(
            id: UUID().uuidString,
            agentId: userId,
            agentName: customer?.fullName ?? "Kunde",
            message: "✅ Kunde hat bestätigt: Problem wurde gelöst.",
            isInternal: false,
            createdAt: Date(),
            responseType: .statusChange,
            solutionDetails: nil
        )

        var updatedResponses = ticket.responses
        updatedResponses.append(confirmationResponse)

        // Update ticket to resolved
        let updatedTicket = SupportTicket(
            id: ticket.id,
            ticketNumber: ticket.ticketNumber,
            userId: ticket.userId,
            customerName: ticket.customerName,
            subject: ticket.subject,
            description: ticket.description,
            status: .resolved,
            priority: ticket.priority,
            assignedTo: ticket.assignedTo,
            createdAt: ticket.createdAt,
            updatedAt: Date(),
            responses: updatedResponses
        )
        mockTickets[ticketIndex] = updatedTicket

        // Decrease agent ticket count
        if let agentId = ticket.assignedTo,
           let agentIndex = mockAgents.firstIndex(where: { $0.id == agentId }) {
            mockAgents[agentIndex].currentTicketCount = max(0, mockAgents[agentIndex].currentTicketCount - 1)
        }

        // Send survey request
        await sendSurveyRequest(ticket: updatedTicket)

        // Notify agent
        if let agentId = ticket.assignedTo {
            notificationService.createNotification(
                title: "Kunde hat Lösung bestätigt",
                message: "Ticket \(ticket.ticketNumber) wurde vom Kunden als gelöst bestätigt.",
                type: .system,
                priority: .low,
                for: agentId,
                metadata: ["ticketId": ticket.id, "ticketNumber": ticket.ticketNumber]
            )
        }

        logger.info("✅ Customer confirmed problem solved for ticket \(ticket.ticketNumber)")
    }

    func userReportProblemNotSolved(ticketId: String, userId: String, additionalInfo: String) async throws {
        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]

        // Verify user owns this ticket
        let customer = mockCustomers.first(where: { $0.id == userId })
        guard ticket.userId == userId else {
            throw CustomerSupportError.invalidRequest("Sie können nur eigene Tickets bearbeiten")
        }

        // Only allow if waiting for customer
        guard ticket.status == .waitingForCustomer else {
            throw CustomerSupportError.invalidRequest("Ticket wartet nicht auf Rückmeldung")
        }

        // Add customer response
        let customerResponse = TicketResponse(
            id: UUID().uuidString,
            agentId: userId,
            agentName: customer?.fullName ?? "Kunde",
            message: "❌ Problem nicht gelöst: \(additionalInfo)",
            isInternal: false,
            createdAt: Date(),
            responseType: .message,
            solutionDetails: nil
        )

        var updatedResponses = ticket.responses
        updatedResponses.append(customerResponse)

        // Reopen ticket
        let updatedTicket = SupportTicket(
            id: ticket.id,
            ticketNumber: ticket.ticketNumber,
            userId: ticket.userId,
            customerName: ticket.customerName,
            subject: ticket.subject,
            description: ticket.description,
            status: .inProgress,
            priority: ticket.priority,
            assignedTo: ticket.assignedTo,
            createdAt: ticket.createdAt,
            updatedAt: Date(),
            responses: updatedResponses
        )
        mockTickets[ticketIndex] = updatedTicket

        // Notify agent urgently
        if let agentId = ticket.assignedTo {
            notificationService.createNotification(
                title: "⚠️ Problem nicht gelöst",
                message: "Kunde meldet: Ticket \(ticket.ticketNumber) ist noch nicht gelöst. Bitte erneut prüfen.",
                type: .system,
                priority: .high,
                for: agentId,
                metadata: ["ticketId": ticket.id, "ticketNumber": ticket.ticketNumber, "reopened": "true"]
            )
        }

        logger.info("⚠️ Customer reported problem NOT solved for ticket \(ticket.ticketNumber)")
    }
}

