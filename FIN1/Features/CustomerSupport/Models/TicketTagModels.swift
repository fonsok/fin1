import Foundation
import SwiftUI

// MARK: - Ticket Tag

/// Tag/Label for categorizing support tickets
struct TicketTag: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let colorHex: String
    let icon: String?
    var usageCount: Int

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String,
        icon: String? = nil,
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.usageCount = usageCount
    }

    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Default Tags

extension TicketTag {
    static let defaults: [TicketTag] = [
        // Issue Types
        TicketTag(name: "Bug", colorHex: "#E53E3E", icon: "ladybug.fill"),
        TicketTag(name: "Feature Request", colorHex: "#805AD5", icon: "sparkles"),
        TicketTag(name: "Frage", colorHex: "#3182CE", icon: "questionmark.circle.fill"),
        TicketTag(name: "Dokumentation", colorHex: "#38A169", icon: "doc.text.fill"),

        // Priority/Urgency
        TicketTag(name: "Dringend", colorHex: "#E53E3E", icon: "exclamationmark.triangle.fill"),
        TicketTag(name: "VIP-Kunde", colorHex: "#D69E2E", icon: "star.fill"),

        // Topics
        TicketTag(name: "Login", colorHex: "#319795", icon: "person.badge.key.fill"),
        TicketTag(name: "Zahlung", colorHex: "#38A169", icon: "creditcard.fill"),
        TicketTag(name: "Investment", colorHex: "#3182CE", icon: "chart.line.uptrend.xyaxis"),
        TicketTag(name: "Trading", colorHex: "#805AD5", icon: "arrow.left.arrow.right"),
        TicketTag(name: "Konto", colorHex: "#DD6B20", icon: "person.crop.circle.fill"),
        TicketTag(name: "App-Absturz", colorHex: "#E53E3E", icon: "xmark.app.fill"),

        // Status
        TicketTag(name: "Bekanntes Problem", colorHex: "#718096", icon: "checkmark.circle.fill"),
        TicketTag(name: "Wartet auf Entwicklung", colorHex: "#805AD5", icon: "hammer.fill"),
        TicketTag(name: "Rückerstattung", colorHex: "#38A169", icon: "arrow.uturn.backward.circle.fill"),
        TicketTag(name: "Eskaliert", colorHex: "#E53E3E", icon: "arrow.up.circle.fill")
    ]
}

// MARK: - Ticket with Tags Extension

extension SupportTicket {
    /// Tags associated with this ticket (stored as tag IDs)
    var tagIds: [String] {
        // In a real implementation, this would be stored in the ticket
        // For now, return empty array
        []
    }
}

