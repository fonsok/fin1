import Foundation

// MARK: - Common Templates
/// Templates available to all CSR roles (greetings, closings)
enum CommonTemplates {

    // MARK: - All Roles
    static let allRoles: [CSRRole] = [.level1, .level2, .fraud, .compliance, .techSupport, .teamlead]

    // MARK: - Greetings

    static let greetings: [ResponseTemplate] = [
        ResponseTemplate(
            title: "Standard-Begrüßung",
            category: .greeting,
            body: """
            Guten Tag {{KUNDENNAME}},
            
            vielen Dank für Ihre Nachricht. Mein Name ist {{AGENTNAME}} und ich helfe Ihnen gerne weiter.
            
            Wie kann ich Ihnen heute behilflich sein?
            """,
            availableForRoles: allRoles,
            placeholders: ["{{KUNDENNAME}}", "{{AGENTNAME}}"]
        ),

        ResponseTemplate(
            title: "Begrüßung mit Ticket-Referenz",
            category: .greeting,
            body: """
            Guten Tag {{KUNDENNAME}},
            
            vielen Dank für Ihre Anfrage. Ihr Anliegen wurde unter der Ticket-Nummer #{{TICKETNUMMER}} erfasst.
            
            Ich werde mich umgehend darum kümmern.
            """,
            availableForRoles: allRoles,
            placeholders: ["{{KUNDENNAME}}", "{{TICKETNUMMER}}"]
        )
    ]

    // MARK: - Closings

    static let closings: [ResponseTemplate] = [
        ResponseTemplate(
            title: "Standard-Abschluss",
            category: .closing,
            body: """
            Gibt es noch etwas, wobei ich Ihnen helfen kann?
            
            Falls nicht, wünsche ich Ihnen einen angenehmen Tag!
            
            Mit freundlichen Grüßen
            {{AGENTNAME}}
            \(AppBrand.appName) Kundensupport
            """,
            availableForRoles: allRoles,
            placeholders: ["{{AGENTNAME}}"]
        ),

        ResponseTemplate(
            title: "Ticket geschlossen mit Zufriedenheitsumfrage",
            category: .closing,
            body: """
            Ich freue mich, dass wir Ihr Anliegen lösen konnten!
            
            **Wir würden uns über Ihr Feedback freuen:**
            Bitte nehmen Sie sich einen Moment Zeit für unsere kurze Zufriedenheitsumfrage.
            
            Vielen Dank und bis bald!
            {{AGENTNAME}}
            """,
            availableForRoles: allRoles,
            placeholders: ["{{AGENTNAME}}"]
        ),

        ResponseTemplate(
            title: "Follow-up angekündigt",
            category: .closing,
            body: """
            Guten Tag {{KUNDENNAME}},
            
            Ihr Anliegen wird derzeit bearbeitet.
            
            **Nächste Schritte:**
            • {{NAECHSTE_SCHRITTE}}
            • Voraussichtliche Bearbeitungszeit: {{BEARBEITUNGSZEIT}}
            
            Ich melde mich bei Ihnen, sobald es Neuigkeiten gibt.
            
            Mit freundlichen Grüßen
            {{AGENTNAME}}
            """,
            availableForRoles: allRoles,
            placeholders: ["{{KUNDENNAME}}", "{{NAECHSTE_SCHRITTE}}", "{{BEARBEITUNGSZEIT}}", "{{AGENTNAME}}"]
        )
    ]
}
