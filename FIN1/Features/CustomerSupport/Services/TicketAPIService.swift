import Foundation

// MARK: - Ticket API Service Protocol

/// Protocol for syncing support tickets to Parse Server backend via Cloud Functions
protocol TicketAPIServiceProtocol: Sendable {
    /// Fetches tickets from the backend
    func fetchTickets(
        userId: String?,
        status: SupportTicket.TicketStatus?,
        limit: Int?,
        skip: Int?
    ) async throws -> [SupportTicket]

    /// Fetches a single ticket by ID
    func fetchTicket(ticketId: String) async throws -> SupportTicket?

    /// Creates a new ticket on the backend
    func createTicket(_ ticket: SupportTicketCreate) async throws -> SupportTicket

    /// Updates a ticket (status, priority, assignment)
    func updateTicket(
        ticketId: String,
        status: SupportTicket.TicketStatus?,
        priority: SupportTicket.TicketPriority?,
        assignedTo: String?
    ) async throws -> SupportTicket

    /// Adds a response/message to a ticket
    func replyToTicket(
        ticketId: String,
        message: String,
        isInternal: Bool
    ) async throws -> TicketResponse
}

// MARK: - Parse Ticket Response Models

/// Response from getTickets Cloud Function
private struct ParseTicketsResponse: Decodable {
    let tickets: [ParseTicket]
    let total: Int
}

/// Parse Server representation of a SupportTicket
private struct ParseTicket: Codable {
    let objectId: String
    let ticketNumber: String
    /// Canonical on server (`SupportTicket.userId`); legacy docs may only have `customerId`.
    let userId: String?
    let customerId: String?
    let customerName: String?
    let subject: String
    let description: String
    let status: String
    let priority: String
    let assignedTo: String?
    let assignedToName: String?
    let category: String?
    let createdAt: String
    let updatedAt: String
    let closedAt: String?
    let resolvedAt: String?
    let messages: [ParseTicketMessage]?
    let userEmail: String?

    func toSupportTicket() -> SupportTicket? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let createdDate = dateFormatter.date(from: createdAt),
              let updatedDate = dateFormatter.date(from: updatedAt),
              let ticketStatus = SupportTicket.TicketStatus(rawValue: status),
              let ticketPriority = SupportTicket.TicketPriority(rawValue: priority) else {
            return nil
        }

        let closedDate = closedAt.flatMap { dateFormatter.date(from: $0) }
        let resolvedDate = resolvedAt.flatMap { dateFormatter.date(from: $0) }

        let endCustomerUserId = [userId, customerId].compactMap { $0 }.first(where: { !$0.isEmpty })
        guard let endCustomerUserId else {
            return nil
        }

        // Convert messages to responses
        let responses = (messages ?? []).compactMap { $0.toTicketResponse() }

        return SupportTicket(
            id: objectId,
            ticketNumber: ticketNumber,
            userId: endCustomerUserId,
            customerName: customerName ?? endCustomerUserId,
            subject: subject,
            description: description,
            status: ticketStatus,
            priority: ticketPriority,
            assignedTo: assignedTo,
            createdAt: createdDate,
            updatedAt: updatedDate,
            responses: responses,
            closedAt: closedDate ?? resolvedDate,
            archivedAt: nil,
            parentTicketId: nil
        )
    }
}

/// Parse Server representation of a TicketMessage
private struct ParseTicketMessage: Codable {
    let objectId: String
    let ticketId: String
    let message: String
    let senderId: String
    let senderRole: String?
    let senderName: String?
    let isInternal: Bool
    let createdAt: String

    func toTicketResponse() -> TicketResponse? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let createdDate = dateFormatter.date(from: createdAt) else {
            return nil
        }

        return TicketResponse(
            id: objectId,
            agentId: senderId,
            agentName: senderName ?? senderRole ?? "Support",
            message: message,
            isInternal: isInternal,
            createdAt: createdDate,
            responseType: isInternal ? .internalNote : .message,
            solutionDetails: nil
        )
    }
}

// MARK: - Ticket API Service Implementation

final class TicketAPIService: TicketAPIServiceProtocol, @unchecked Sendable {

    private let apiClient: ParseAPIClientProtocol

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Public Methods

    func fetchTickets(
        userId: String?,
        status: SupportTicket.TicketStatus?,
        limit: Int?,
        skip: Int?
    ) async throws -> [SupportTicket] {
        print("📡 TicketAPIService: Fetching tickets from backend")
        print("   👤 User ID: \(userId ?? "all")")
        print("   📊 Status: \(status?.rawValue ?? "all")")

        var parameters: [String: Any] = [:]
        if let userId = userId {
            parameters["userId"] = userId
        }
        if let status = status {
            parameters["status"] = status.rawValue
        }
        if let limit = limit {
            parameters["limit"] = limit
        }
        if let skip = skip {
            parameters["skip"] = skip
        }

        let response: ParseTicketsResponse = try await apiClient.callFunction(
            "getTickets",
            parameters: parameters.isEmpty ? nil : parameters
        )

        print("✅ TicketAPIService: Fetched \(response.tickets.count) tickets")

        // Convert Parse tickets to app tickets
        return response.tickets.compactMap { $0.toSupportTicket() }
    }

    func fetchTicket(ticketId: String) async throws -> SupportTicket? {
        print("📡 TicketAPIService: Fetching ticket: \(ticketId)")

        let parameters: [String: Any] = [
            "ticketId": ticketId
        ]

        let parseTicket: ParseTicket = try await apiClient.callFunction(
            "getTicket",
            parameters: parameters
        )

        print("✅ TicketAPIService: Fetched ticket \(parseTicket.ticketNumber)")

        return parseTicket.toSupportTicket()
    }

    func createTicket(_ ticket: SupportTicketCreate) async throws -> SupportTicket {
        print("📡 TicketAPIService: Creating ticket on backend")
        print("   📋 Subject: \(ticket.subject)")

        // Note: Backend creates ticket via SupportTicket Parse class
        // We'll use direct Parse class creation instead of Cloud Function
        // since there's no createTicket Cloud Function

        // For now, create via direct Parse class (similar to other services)
        // This requires creating a ParseSupportTicketInput struct

        // Actually, let's check if we should create via Cloud Function or direct class
        // Since backend has beforeSave trigger for ticketNumber generation,
        // we should use direct class creation

        let parseInput = ParseSupportTicketInput.from(ticket: ticket)

        let response = try await apiClient.createObject(
            className: "SupportTicket",
            object: parseInput
        )

        print("✅ TicketAPIService: Ticket created with objectId: \(response.objectId)")

        // Fetch the created ticket to get full details (including ticketNumber from trigger)
        return try await fetchTicket(ticketId: response.objectId) ?? SupportTicket(
            id: response.objectId,
            ticketNumber: "TKT-\(Calendar.current.component(.year, from: Date()))-00001",
            userId: ticket.userId,
            customerName: "",
            subject: ticket.subject,
            description: ticket.description,
            status: .open,
            priority: ticket.priority,
            assignedTo: nil,
            createdAt: Date(),
            updatedAt: Date(),
            responses: []
        )
    }

    func updateTicket(
        ticketId: String,
        status: SupportTicket.TicketStatus?,
        priority: SupportTicket.TicketPriority?,
        assignedTo: String?
    ) async throws -> SupportTicket {
        print("📡 TicketAPIService: Updating ticket: \(ticketId)")

        var parameters: [String: Any] = [
            "ticketId": ticketId
        ]

        if let status = status {
            parameters["status"] = status.rawValue
        }
        if let priority = priority {
            parameters["priority"] = priority.rawValue
        }
        if let assignedTo = assignedTo {
            parameters["assignedTo"] = assignedTo
        }

        let parseTicket: ParseTicket = try await apiClient.callFunction(
            "updateTicket",
            parameters: parameters
        )

        print("✅ TicketAPIService: Ticket updated")

        guard let ticket = parseTicket.toSupportTicket() else {
            throw ServiceError.invalidData
        }

        return ticket
    }

    func replyToTicket(
        ticketId: String,
        message: String,
        isInternal: Bool
    ) async throws -> TicketResponse {
        print("📡 TicketAPIService: Replying to ticket: \(ticketId)")

        let parameters: [String: Any] = [
            "ticketId": ticketId,
            "message": message,
            "isInternal": isInternal
        ]

        let parseMessage: ParseTicketMessage = try await apiClient.callFunction(
            "replyToTicket",
            parameters: parameters
        )

        print("✅ TicketAPIService: Reply added")

        guard let response = parseMessage.toTicketResponse() else {
            throw ServiceError.invalidData
        }

        return response
    }
}

// MARK: - Parse Support Ticket Input

/// Input struct for creating tickets on Parse Server
private struct ParseSupportTicketInput: Encodable {
    let userId: String
    let subject: String
    let description: String
    let priority: String
    let category: String
    let status: String

    static func from(ticket: SupportTicketCreate) -> ParseSupportTicketInput {
        ParseSupportTicketInput(
            userId: ticket.userId,
            subject: ticket.subject,
            description: ticket.description,
            priority: ticket.priority.rawValue,
            category: "general", // Default category
            status: "open"
        )
    }
}
