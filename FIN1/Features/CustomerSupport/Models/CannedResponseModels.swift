import Foundation

// MARK: - Canned Response

/// Pre-written response templates for CSRs
struct CannedResponse: Identifiable, Codable {
    let id: String
    let title: String
    let content: String
    let category: CannedResponseCategory
    let shortcut: String?  // Quick keyboard shortcut like "/greeting"
    let placeholders: [String]  // e.g., ["{{customerName}}", "{{ticketNumber}}"]
    var usageCount: Int
    let createdBy: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        content: String,
        category: CannedResponseCategory,
        shortcut: String? = nil,
        placeholders: [String] = [],
        usageCount: Int = 0,
        createdBy: String = "system",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.shortcut = shortcut
        self.placeholders = placeholders
        self.usageCount = usageCount
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Replace placeholders with actual values
    func fillPlaceholders(_ values: [String: String]) -> String {
        var filledContent = self.content
        for (key, value) in values {
            filledContent = filledContent.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return filledContent
    }
}

// MARK: - Canned Response Category

enum CannedResponseCategory: String, Codable, CaseIterable {
    case greeting = "Begrüßung"
    case acknowledgment = "Bestätigung"
    case solution = "Lösung"
    case followUp = "Nachfrage"
    case closing = "Abschluss"
    case apology = "Entschuldigung"
    case technical = "Technisch"
    case billing = "Abrechnung"

    var icon: String {
        switch self {
        case .greeting: return "hand.wave.fill"
        case .acknowledgment: return "checkmark.circle.fill"
        case .solution: return "lightbulb.fill"
        case .followUp: return "questionmark.circle.fill"
        case .closing: return "flag.checkered"
        case .apology: return "heart.fill"
        case .technical: return "wrench.and.screwdriver.fill"
        case .billing: return "creditcard.fill"
        }
    }
}

// MARK: - Default Canned Responses

extension CannedResponse {
    static let defaults: [CannedResponse] = [
        // Greetings
        CannedResponse(
            title: "Standard Begrüßung",
            content: "Guten Tag {{customerName}},\n\nvielen Dank für Ihre Nachricht. Ich werde mich um Ihr Anliegen kümmern.",
            category: .greeting,
            shortcut: "/hi",
            placeholders: ["customerName"]
        ),
        CannedResponse(
            title: "Formelle Begrüßung",
            content: "Sehr geehrte/r {{customerName}},\n\nvielen Dank für Ihre Kontaktaufnahme bezüglich Ticket {{ticketNumber}}.",
            category: .greeting,
            shortcut: "/formal",
            placeholders: ["customerName", "ticketNumber"]
        ),

        // Acknowledgments
        CannedResponse(
            title: "Ticket erhalten",
            content: "Wir haben Ihr Anliegen erhalten und werden es schnellstmöglich bearbeiten. Sie können den Status jederzeit in der App verfolgen.",
            category: .acknowledgment,
            shortcut: "/received"
        ),
        CannedResponse(
            title: "Prüfung eingeleitet",
            content: "Ich habe Ihren Fall an unsere Fachabteilung weitergeleitet. Sie werden innerhalb von 24 Stunden eine Rückmeldung erhalten.",
            category: .acknowledgment,
            shortcut: "/checking"
        ),

        // Solutions
        CannedResponse(
            title: "Passwort zurücksetzen",
            content: "Um Ihr Passwort zurückzusetzen, gehen Sie bitte wie folgt vor:\n\n1. Öffnen Sie die App\n2. Tippen Sie auf 'Passwort vergessen'\n3. Geben Sie Ihre E-Mail-Adresse ein\n4. Folgen Sie dem Link in der E-Mail\n\nSollten Sie keine E-Mail erhalten, prüfen Sie bitte Ihren Spam-Ordner.",
            category: .solution,
            shortcut: "/password"
        ),
        CannedResponse(
            title: "App aktualisieren",
            content: "Bitte aktualisieren Sie die App auf die neueste Version:\n\n• iOS: App Store → Updates → \(AppBrand.appName)\n• Android: Play Store → Meine Apps → \(AppBrand.appName)\n\nDie neueste Version behebt bekannte Probleme und verbessert die Stabilität.",
            category: .solution,
            shortcut: "/update"
        ),
        CannedResponse(
            title: "Cache leeren",
            content: "Bitte versuchen Sie folgende Schritte:\n\n1. App vollständig schließen (nicht nur minimieren)\n2. In den Geräte-Einstellungen → Apps → \(AppBrand.appName) → Cache leeren\n3. App neu starten\n\nSollte das Problem weiterhin bestehen, melden Sie sich bitte erneut.",
            category: .solution,
            shortcut: "/cache"
        ),

        // Follow-ups
        CannedResponse(
            title: "Weitere Informationen benötigt",
            content: "Um Ihnen besser helfen zu können, benötige ich noch folgende Informationen:\n\n• [Information 1]\n• [Information 2]\n\nVielen Dank für Ihre Mithilfe.",
            category: .followUp,
            shortcut: "/moreinfo"
        ),
        CannedResponse(
            title: "Screenshot anfordern",
            content: "Könnten Sie mir bitte einen Screenshot des Problems zusenden? Das hilft mir, die Ursache schneller zu identifizieren.",
            category: .followUp,
            shortcut: "/screenshot"
        ),

        // Closings
        CannedResponse(
            title: "Ticket abschließen",
            content: "Ich freue mich, dass wir Ihr Anliegen lösen konnten. Falls Sie weitere Fragen haben, stehe ich Ihnen gerne zur Verfügung.\n\nMit freundlichen Grüßen,\n{{agentName}}",
            category: .closing,
            shortcut: "/close",
            placeholders: ["agentName"]
        ),
        CannedResponse(
            title: "Bestätigung anfordern",
            content: "Ich hoffe, diese Lösung hilft Ihnen weiter. Bitte bestätigen Sie kurz, ob das Problem behoben ist, damit ich das Ticket abschließen kann.\n\nVielen Dank!",
            category: .closing,
            shortcut: "/confirm"
        ),

        // Apologies
        CannedResponse(
            title: "Entschuldigung für Verzögerung",
            content: "Ich entschuldige mich für die Verzögerung bei der Bearbeitung Ihres Anliegens. Wir arbeiten mit Hochdruck an einer Lösung.",
            category: .apology,
            shortcut: "/sorry"
        ),
        CannedResponse(
            title: "Entschuldigung für Unannehmlichkeiten",
            content: "Es tut uns aufrichtig leid, dass Sie diese Unannehmlichkeiten erfahren mussten. Wir nehmen Ihr Feedback sehr ernst und arbeiten kontinuierlich an Verbesserungen.",
            category: .apology,
            shortcut: "/apologize"
        ),

        // Technical
        CannedResponse(
            title: "Bekanntes Problem",
            content: "Vielen Dank für Ihre Meldung. Dies ist uns als bekanntes Problem bewusst, und unser Entwicklerteam arbeitet bereits an einer Lösung. Wir werden Sie informieren, sobald ein Update verfügbar ist.",
            category: .technical,
            shortcut: "/known"
        ),
        CannedResponse(
            title: "Bug gemeldet",
            content: "Ich habe dieses Problem an unser Entwicklerteam weitergeleitet (Ticket: {{devTicket}}). Wir werden Sie über den Fortschritt informieren.",
            category: .technical,
            shortcut: "/bug",
            placeholders: ["devTicket"]
        ),

        // Billing
        CannedResponse(
            title: "Rückerstattung eingeleitet",
            content: "Ich habe eine Rückerstattung für Sie eingeleitet. Der Betrag wird innerhalb von 5-7 Werktagen auf Ihrem Konto gutgeschrieben.",
            category: .billing,
            shortcut: "/refund"
        ),
        CannedResponse(
            title: "Gebühren erklärt",
            content: "Die angefragten Gebühren setzen sich wie folgt zusammen:\n\n• [Gebühr 1]: XX€\n• [Gebühr 2]: XX€\n\nEine detaillierte Aufstellung finden Sie in Ihrem Kontobereich unter 'Transaktionen'.",
            category: .billing,
            shortcut: "/fees"
        )
    ]
}

