import Foundation

// MARK: - Level 1 Support Templates
/// Templates specific to Level 1 Support agents
enum Level1Templates {

    static let all: [ResponseTemplate] = [
        // MARK: - Account Issues

        ResponseTemplate(
            title: "Passwort-Reset Anleitung",
            category: .accountIssues,
            body: """
            Guten Tag {{KUNDENNAME}},

            um Ihr Passwort zurückzusetzen, gehen Sie bitte wie folgt vor:

            1. Öffnen Sie die \(AppBrand.appName) App
            2. Tippen Sie auf "Anmelden"
            3. Wählen Sie "Passwort vergessen?"
            4. Geben Sie Ihre E-Mail-Adresse ein
            5. Sie erhalten einen Link zum Zurücksetzen per E-Mail

            Der Link ist 24 Stunden gültig. Falls Sie keine E-Mail erhalten, prüfen Sie bitte auch Ihren Spam-Ordner.

            Bei weiteren Fragen stehe ich Ihnen gerne zur Verfügung.
            """,
            availableForRoles: [.level1, .level2, .teamlead],
            placeholders: ["{{KUNDENNAME}}"]
        ),

        ResponseTemplate(
            title: "E-Mail-Adresse ändern",
            category: .accountIssues,
            body: """
            Guten Tag {{KUNDENNAME}},

            ich habe Ihre E-Mail-Adresse wie gewünscht auf {{NEUE_EMAIL}} geändert.

            Bitte beachten Sie:
            • Sie erhalten eine Bestätigung an Ihre neue E-Mail-Adresse
            • Künftige Benachrichtigungen gehen an die neue Adresse
            • Ihre Login-Daten bleiben unverändert

            Die Änderung ist sofort wirksam.
            """,
            availableForRoles: [.level1, .level2, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{NEUE_EMAIL}}"]
        )
    ]
}
