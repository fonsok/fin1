import Foundation

// MARK: - Email Template

/// Email template for support notifications
struct EmailTemplate: Identifiable, Codable {
    let id: String
    let type: EmailTemplateType
    let subject: String
    let bodyTemplate: String
    let isActive: Bool
    let lastModified: Date

    init(
        id: String = UUID().uuidString,
        type: EmailTemplateType,
        subject: String,
        bodyTemplate: String,
        isActive: Bool = true,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.subject = subject
        self.bodyTemplate = bodyTemplate
        self.isActive = isActive
        self.lastModified = lastModified
    }

    /// Available placeholders for this template type
    var availablePlaceholders: [String] {
        type.availablePlaceholders
    }

    /// Fill template with values
    func render(with values: [String: String]) -> (subject: String, body: String) {
        var filledSubject = subject
        var filledBody = bodyTemplate

        for (key, value) in values {
            filledSubject = filledSubject.replacingOccurrences(of: "{{\(key)}}", with: value)
            filledBody = filledBody.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        return (filledSubject, filledBody)
    }
}

// MARK: - Email Template Type

enum EmailTemplateType: String, Codable, CaseIterable {
    case ticketCreated = "Ticket erstellt"
    case ticketResponse = "Neue Antwort"
    case ticketStatusChange = "Status geändert"
    case ticketResolved = "Ticket gelöst"
    case ticketClosed = "Ticket geschlossen"
    case surveyRequest = "Umfrage-Anfrage"
    case slaWarning = "SLA-Warnung"

    var icon: String {
        switch self {
        case .ticketCreated: return "plus.circle.fill"
        case .ticketResponse: return "bubble.left.fill"
        case .ticketStatusChange: return "arrow.triangle.2.circlepath"
        case .ticketResolved: return "checkmark.circle.fill"
        case .ticketClosed: return "xmark.circle.fill"
        case .surveyRequest: return "star.fill"
        case .slaWarning: return "exclamationmark.triangle.fill"
        }
    }

    var availablePlaceholders: [String] {
        let common = ["customerName", "ticketNumber", "ticketSubject", "companyName", "supportEmail"]

        switch self {
        case .ticketCreated:
            return common + ["ticketDescription", "ticketPriority"]
        case .ticketResponse:
            return common + ["agentName", "responseMessage"]
        case .ticketStatusChange:
            return common + ["oldStatus", "newStatus"]
        case .ticketResolved:
            return common + ["agentName", "resolutionSummary"]
        case .ticketClosed:
            return common + ["closureReason"]
        case .surveyRequest:
            return common + ["agentName", "surveyLink"]
        case .slaWarning:
            return common + ["timeRemaining", "deadline"]
        }
    }
}

// MARK: - Default Templates

extension EmailTemplate {
    static let defaults: [EmailTemplate] = [
        // Ticket Created
        EmailTemplate(
            type: .ticketCreated,
            subject: "[{{companyName}}] Ticket {{ticketNumber}} wurde erstellt",
            bodyTemplate: """
            Guten Tag {{customerName}},

            vielen Dank für Ihre Anfrage. Wir haben Ihr Support-Ticket erfolgreich erstellt.

            Ticket-Details:
            • Ticket-Nummer: {{ticketNumber}}
            • Betreff: {{ticketSubject}}
            • Priorität: {{ticketPriority}}

            Ihr Anliegen:
            {{ticketDescription}}

            Unser Support-Team wird sich schnellstmöglich bei Ihnen melden.

            Mit freundlichen Grüßen,
            Ihr {{companyName}} Support-Team

            ---
            Sie können den Status Ihres Tickets jederzeit in der App verfolgen.
            """
        ),

        // Ticket Response
        EmailTemplate(
            type: .ticketResponse,
            subject: "[{{companyName}}] Neue Antwort auf Ticket {{ticketNumber}}",
            bodyTemplate: """
            Guten Tag {{customerName}},

            Sie haben eine neue Antwort auf Ihr Support-Ticket erhalten.

            Ticket: {{ticketNumber}} - {{ticketSubject}}

            Antwort von {{agentName}}:
            {{responseMessage}}

            ---

            Um zu antworten, öffnen Sie bitte die App oder antworten Sie direkt auf diese E-Mail.

            Mit freundlichen Grüßen,
            Ihr {{companyName}} Support-Team
            """
        ),

        // Ticket Status Change
        EmailTemplate(
            type: .ticketStatusChange,
            subject: "[{{companyName}}] Status-Update für Ticket {{ticketNumber}}",
            bodyTemplate: """
            Guten Tag {{customerName}},

            der Status Ihres Support-Tickets hat sich geändert.

            Ticket: {{ticketNumber}} - {{ticketSubject}}

            Alter Status: {{oldStatus}}
            Neuer Status: {{newStatus}}

            Sie können den aktuellen Stand jederzeit in der App einsehen.

            Mit freundlichen Grüßen,
            Ihr {{companyName}} Support-Team
            """
        ),

        // Ticket Resolved
        EmailTemplate(
            type: .ticketResolved,
            subject: "[{{companyName}}] Ticket {{ticketNumber}} wurde gelöst ✓",
            bodyTemplate: """
            Guten Tag {{customerName}},

            gute Nachrichten! Ihr Support-Ticket wurde gelöst.

            Ticket: {{ticketNumber}} - {{ticketSubject}}
            Bearbeitet von: {{agentName}}

            Zusammenfassung der Lösung:
            {{resolutionSummary}}

            Sollte das Problem weiterhin bestehen, können Sie dieses Ticket innerhalb von 7 Tagen wiedereröffnen.

            Mit freundlichen Grüßen,
            Ihr {{companyName}} Support-Team
            """
        ),

        // Ticket Closed
        EmailTemplate(
            type: .ticketClosed,
            subject: "[{{companyName}}] Ticket {{ticketNumber}} wurde geschlossen",
            bodyTemplate: """
            Guten Tag {{customerName}},

            Ihr Support-Ticket wurde geschlossen.

            Ticket: {{ticketNumber}} - {{ticketSubject}}

            Grund: {{closureReason}}

            Vielen Dank, dass Sie sich an unseren Support gewandt haben. Bei weiteren Fragen können Sie jederzeit ein neues Ticket erstellen.

            Mit freundlichen Grüßen,
            Ihr {{companyName}} Support-Team
            """
        ),

        // Survey Request
        EmailTemplate(
            type: .surveyRequest,
            subject: "[{{companyName}}] Wie war unser Support? ⭐",
            bodyTemplate: """
            Guten Tag {{customerName}},

            Ihr Support-Ticket {{ticketNumber}} wurde von {{agentName}} bearbeitet.

            Wir würden uns freuen, wenn Sie sich einen Moment Zeit nehmen könnten, um unseren Service zu bewerten.

            Ihre Meinung hilft uns, unseren Support kontinuierlich zu verbessern.

            → Jetzt bewerten: {{surveyLink}}

            Vielen Dank für Ihre Unterstützung!

            Mit freundlichen Grüßen,
            Ihr {{companyName}} Support-Team
            """
        ),

        // SLA Warning
        EmailTemplate(
            type: .slaWarning,
            subject: "⚠️ SLA-Warnung: Ticket {{ticketNumber}}",
            bodyTemplate: """
            Achtung!

            Das folgende Ticket nähert sich der SLA-Deadline:

            Ticket: {{ticketNumber}} - {{ticketSubject}}
            Kunde: {{customerName}}
            Verbleibende Zeit: {{timeRemaining}}
            Deadline: {{deadline}}

            Bitte bearbeiten Sie dieses Ticket umgehend.

            ---
            Diese E-Mail wurde automatisch generiert.
            """
        )
    ]
}

