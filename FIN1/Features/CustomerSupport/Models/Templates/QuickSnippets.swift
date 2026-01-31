import Foundation

// MARK: - Quick Snippets
/// Short, role-specific response snippets for common situations
enum QuickSnippets {

    /// Quick snippets indexed by key and role
    static let snippets: [String: [CSRRole: String]] = [
        "Bitte warten": [
            .level1: "Einen Moment bitte, ich prüfe das für Sie.",
            .level2: "Ich schaue mir das genauer an, einen Moment bitte.",
            .fraud: "Ich prüfe die Sicherheitslogs, bitte haben Sie einen Moment Geduld.",
            .compliance: "Ich überprüfe die Compliance-Daten, einen Moment bitte.",
            .techSupport: "Ich analysiere die Logs, das dauert einen kurzen Moment.",
            .teamlead: "Ich kümmere mich persönlich darum, einen Moment bitte."
        ],

        "Nicht möglich": [
            .level1: "Das liegt leider außerhalb meiner Befugnisse. Ich leite Sie an einen Spezialisten weiter.",
            .level2: "Diese Aktion erfordert eine Genehmigung. Ich erstelle eine entsprechende Anfrage.",
            .fraud: "Aus Sicherheitsgründen kann ich diese Information nicht teilen.",
            .compliance: "Aus regulatorischen Gründen ist das nicht möglich. Ich erkläre gerne warum.",
            .techSupport: "Das ist eine Systemeinschränkung. Ich erstelle einen Feature-Request.",
            .teamlead: "Ich verstehe Ihren Wunsch, aber aus regulatorischen Gründen ist das nicht möglich."
        ],

        "Eskalation": [
            .level1: "Ich leite Ihr Anliegen an einen erfahrenen Kollegen weiter.",
            .level2: "Ich eskaliere das an unser Spezialteam.",
            .fraud: "Das erfordert eine 4-Augen-Prüfung. Ich leite es ein.",
            .compliance: "Für diese Entscheidung benötige ich eine zweite Freigabe.",
            .techSupport: "Ich eskaliere das an unser Entwicklerteam.",
            .teamlead: "Ich kümmere mich persönlich um die schnelle Lösung."
        ],

        "Danke": [
            .level1: "Vielen Dank für Ihre Geduld!",
            .level2: "Danke für Ihr Verständnis.",
            .fraud: "Vielen Dank für Ihre Mitarbeit bei der Sicherheitsprüfung.",
            .compliance: "Danke für Ihre Kooperation.",
            .techSupport: "Danke für die detaillierte Fehlerbeschreibung!",
            .teamlead: "Vielen Dank für Ihr Vertrauen in unser Team."
        ],

        "Entschuldigung": [
            .level1: "Ich entschuldige mich für die Unannehmlichkeiten.",
            .level2: "Es tut mir leid, dass Sie dieses Problem haben.",
            .fraud: "Wir entschuldigen uns für die zusätzliche Sicherheitsprüfung.",
            .compliance: "Ich verstehe, dass dies frustrierend sein kann.",
            .techSupport: "Entschuldigung für die technischen Schwierigkeiten.",
            .teamlead: "Im Namen des Teams entschuldige ich mich aufrichtig."
        ]
    ]

    /// Get all available snippet keys
    static var allKeys: [String] {
        Array(snippets.keys).sorted()
    }

    /// Get snippet for a specific key and role
    static func snippet(_ key: String, for role: CSRRole) -> String? {
        snippets[key]?[role]
    }
}
