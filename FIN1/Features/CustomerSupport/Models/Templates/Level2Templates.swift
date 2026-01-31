import Foundation

// MARK: - Level 2 Support Templates
/// Templates specific to Level 2 Support agents
enum Level2Templates {

    static let all: [ResponseTemplate] = [
        // MARK: - Account Issues

        ResponseTemplate(
            title: "Konto entsperrt",
            category: .accountIssues,
            subject: "Ihr \(AppBrand.appName) Konto wurde entsperrt",
            body: """
            Guten Tag {{KUNDENNAME}},

            Ihr \(AppBrand.appName) Konto wurde erfolgreich entsperrt. Sie können sich jetzt wieder anmelden.

            **Wichtige Sicherheitshinweise:**
            • Verwenden Sie ein starkes, einzigartiges Passwort
            • Aktivieren Sie die Zwei-Faktor-Authentifizierung (2FA)
            • Melden Sie verdächtige Aktivitäten sofort

            Falls Sie die Sperrung nicht veranlasst haben, kontaktieren Sie uns bitte umgehend.

            Mit freundlichen Grüßen
            {{AGENTNAME}}
            \(AppBrand.appName) Kundensupport
            """,
            availableForRoles: [.level2, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{AGENTNAME}}"],
            isEmail: true
        ),

        // MARK: - KYC/Onboarding

        ResponseTemplate(
            title: "KYC-Dokumente nachfordern",
            category: .kycOnboarding,
            subject: "Zusätzliche Dokumente für Ihre Kontoverifizierung",
            body: """
            Guten Tag {{KUNDENNAME}},

            vielen Dank für Ihre Registrierung bei \(AppBrand.appName).

            Zur Vervollständigung Ihrer Identitätsprüfung (KYC) benötigen wir noch folgende Unterlagen:

            {{FEHLENDE_DOKUMENTE}}

            **Anforderungen an die Dokumente:**
            • Gut lesbar, nicht verschwommen
            • Vollständig sichtbar (alle Ecken)
            • Gültiges Ablaufdatum
            • Maximal 10 MB pro Datei (JPG, PNG oder PDF)

            Bitte laden Sie die Dokumente in der App unter "Profil" → "Dokumente" hoch.

            Bei Fragen stehen wir Ihnen gerne zur Verfügung.

            Mit freundlichen Grüßen
            {{AGENTNAME}}
            \(AppBrand.appName) Kundensupport
            """,
            availableForRoles: [.level2, .compliance, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{FEHLENDE_DOKUMENTE}}", "{{AGENTNAME}}"],
            isEmail: true
        ),

        // MARK: - Transactions

        ResponseTemplate(
            title: "Transaktion erklären",
            category: .transactions,
            body: """
            Guten Tag {{KUNDENNAME}},

            bezüglich Ihrer Anfrage zur Transaktion vom {{DATUM}}:

            **Transaktionsdetails:**
            • Betrag: {{BETRAG}}
            • Typ: {{TRANSAKTIONSTYP}}
            • Status: {{STATUS}}
            • Referenz: {{REFERENZ}}

            {{ERKLAERUNG}}

            Falls Sie weitere Fragen haben, helfe ich Ihnen gerne weiter.
            """,
            availableForRoles: [.level2, .fraud, .compliance, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{DATUM}}", "{{BETRAG}}", "{{TRANSAKTIONSTYP}}", "{{STATUS}}", "{{REFERENZ}}", "{{ERKLAERUNG}}"]
        ),

        // MARK: - Security

        ResponseTemplate(
            title: "Verdächtige Aktivität bestätigen",
            category: .security,
            body: """
            Guten Tag {{KUNDENNAME}},

            wir haben folgende Aktivität auf Ihrem Konto festgestellt:

            • Datum/Uhrzeit: {{DATUM_UHRZEIT}}
            • Aktivität: {{AKTIVITAET}}
            • IP-Adresse/Standort: {{STANDORT}}

            **Waren Sie das?**

            ✅ Ja, das war ich → Antworten Sie bitte mit "Bestätigt"
            ❌ Nein, das war ich nicht → Kontaktieren Sie uns sofort

            Ihre Sicherheit hat für uns höchste Priorität.
            """,
            availableForRoles: [.fraud, .level2, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{DATUM_UHRZEIT}}", "{{AKTIVITAET}}", "{{STANDORT}}"]
        )
    ]
}
