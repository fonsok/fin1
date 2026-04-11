import Foundation

// MARK: - Customer Support Service - Notification Helpers Extension
/// Extension for sending various support-related notifications

extension CustomerSupportService {

    // MARK: - Survey Request

    func sendSurveyRequest(ticket: SupportTicket) async {
        let customer = mockCustomers.first(where: { $0.id == ticket.userId })
        let userId = customer?.id ?? ticket.userId

        do {
            // Create survey request through the dedicated service
            let surveyRequest = try await satisfactionSurveyService.createSurveyRequest(
                for: ticket,
                agentName: currentAgentName,
                userId: userId
            )
            logger.info("📋 Survey request created for ticket \(ticket.ticketNumber), surveyId: \(surveyRequest.id), userId: \(userId)")
        } catch {
            // Fallback: send simple notification if survey service fails
            notificationService.createNotification(
                title: "Wie war Ihr Support-Erlebnis?",
                message: "Bitte bewerten Sie unseren Service für Ticket \(ticket.ticketNumber)",
                type: .system,
                priority: .medium,
                for: userId,
                metadata: [
                    "ticketId": ticket.id,
                    "ticketNumber": ticket.ticketNumber,
                    "agentId": ticket.assignedTo ?? "unknown",
                    "agentName": currentAgentName,
                    "surveyType": "satisfaction"
                ]
            )
            logger.warning("⚠️ Survey service failed, sent fallback notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Solution Notification

    func sendSolutionNotification(ticket: SupportTicket, solution: SolutionDetails) async {
        let customer = mockCustomers.first(where: { $0.id == ticket.userId })
        let userId = customer?.id ?? ticket.userId

        var message = "Eine Lösung wurde für Ihr Ticket \"\(ticket.subject)\" bereitgestellt."
        if let articleTitle = solution.helpCenterArticleTitle {
            message += " Siehe Help Center: \(articleTitle)"
        }

        notificationService.createNotification(
            title: "Lösung für Ihr Support-Ticket",
            message: message,
            type: .system,
            priority: .high,
            for: userId,
            metadata: [
                "ticketId": ticket.id,
                "ticketNumber": ticket.ticketNumber,
                "solutionType": solution.solutionType.rawValue
            ]
        )

        logger.info("📧 Solution notification sent to customer for ticket \(ticket.ticketNumber)")
    }

    // MARK: - Confirmation Request Notification

    func sendConfirmationRequestNotification(ticket: SupportTicket) async {
        let customer = mockCustomers.first(where: { $0.id == ticket.userId })
        let userId = customer?.id ?? ticket.userId

        notificationService.createNotification(
            title: "Bestätigung erforderlich",
            message: "Bitte bestätigen Sie, dass das Problem mit Ticket \"\(ticket.subject)\" gelöst wurde.",
            type: .system,
            priority: .medium,
            for: userId,
            metadata: [
                "ticketId": ticket.id,
                "ticketNumber": ticket.ticketNumber,
                "action": "confirm_resolution"
            ]
        )

        logger.info("📧 Confirmation request sent to customer for ticket \(ticket.ticketNumber)")
    }

    // MARK: - Resolution Notification

    func sendResolutionNotification(ticket: SupportTicket, customerConfirmed: Bool) async {
        let customer = mockCustomers.first(where: { $0.id == ticket.userId })
        let userId = customer?.id ?? ticket.userId

        notificationService.createNotification(
            title: "Support-Ticket gelöst",
            message: "Ihr Ticket \"\(ticket.subject)\" wurde als gelöst markiert. Vielen Dank für Ihre Anfrage!",
            type: .system,
            priority: .low,
            for: userId,
            metadata: [
                "ticketId": ticket.id,
                "ticketNumber": ticket.ticketNumber,
                "resolved": "true",
                "customerConfirmed": String(customerConfirmed)
            ]
        )

        logger.info("📧 Resolution notification sent to customer for ticket \(ticket.ticketNumber)")
    }

    // MARK: - Severity to Priority Mapping

    func mapSeverityToPriority(_ severity: BugSeverity) -> SupportTicket.TicketPriority {
        switch severity {
        case .critical: return .urgent
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}

