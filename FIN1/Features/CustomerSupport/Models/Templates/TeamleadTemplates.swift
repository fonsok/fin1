import Foundation

// MARK: - Teamlead Templates
/// Templates specific to Teamlead role (escalations, approvals)
enum TeamleadTemplates {

    static let all: [ResponseTemplate] = [
        // MARK: - Escalation (Internal)

        ResponseTemplate(
            title: "Eskalation bestätigt",
            category: .escalation,
            body: """
            **Interne Notiz**

            Eskalation für Ticket #{{TICKETNUMMER}} genehmigt.

            **Details:**
            • Ursprünglicher Agent: {{URSPRUENGLICHER_AGENT}}
            • Eskalationsgrund: {{ESKALATIONSGRUND}}
            • Neue Priorität: {{NEUE_PRIORITAET}}
            • Zugewiesen an: {{ZUGEWIESEN_AN}}

            **Anweisungen:**
            {{ANWEISUNGEN}}

            Genehmigt von: {{TEAMLEAD_NAME}}
            Datum: {{DATUM}}
            """,
            availableForRoles: [.teamlead],
            placeholders: ["{{TICKETNUMMER}}", "{{URSPRUENGLICHER_AGENT}}", "{{ESKALATIONSGRUND}}", "{{NEUE_PRIORITAET}}", "{{ZUGEWIESEN_AN}}", "{{ANWEISUNGEN}}", "{{TEAMLEAD_NAME}}", "{{DATUM}}"]
        ),

        ResponseTemplate(
            title: "4-Augen-Freigabe erteilt",
            category: .escalation,
            body: """
            **4-Augen-Freigabe - Protokoll**

            **Anfrage-ID:** {{ANFRAGE_ID}}
            **Aktion:** {{AKTION}}
            **Beantragt von:** {{BEANTRAGT_VON}}
            **Kunde:** {{KUNDEN_ID}}

            **Prüfung:**
            ✅ Dokumentation vollständig
            ✅ Begründung plausibel
            ✅ Keine Compliance-Bedenken

            **Entscheidung:** GENEHMIGT
            **Genehmigt von:** {{GENEHMIGER}}
            **Datum/Uhrzeit:** {{DATUM_UHRZEIT}}

            **Anmerkungen:**
            {{ANMERKUNGEN}}
            """,
            availableForRoles: [.teamlead, .compliance],
            placeholders: ["{{ANFRAGE_ID}}", "{{AKTION}}", "{{BEANTRAGT_VON}}", "{{KUNDEN_ID}}", "{{GENEHMIGER}}", "{{DATUM_UHRZEIT}}", "{{ANMERKUNGEN}}"]
        ),

        ResponseTemplate(
            title: "4-Augen-Freigabe abgelehnt",
            category: .escalation,
            body: """
            **4-Augen-Freigabe - Protokoll**

            **Anfrage-ID:** {{ANFRAGE_ID}}
            **Aktion:** {{AKTION}}
            **Beantragt von:** {{BEANTRAGT_VON}}
            **Kunde:** {{KUNDEN_ID}}

            **Entscheidung:** ABGELEHNT

            **Ablehnungsgrund:**
            {{ABLEHNUNGSGRUND}}

            **Erforderliche Nachbesserungen:**
            {{NACHBESSERUNGEN}}

            **Abgelehnt von:** {{GENEHMIGER}}
            **Datum/Uhrzeit:** {{DATUM_UHRZEIT}}
            """,
            availableForRoles: [.teamlead, .compliance],
            placeholders: ["{{ANFRAGE_ID}}", "{{AKTION}}", "{{BEANTRAGT_VON}}", "{{KUNDEN_ID}}", "{{ABLEHNUNGSGRUND}}", "{{NACHBESSERUNGEN}}", "{{GENEHMIGER}}", "{{DATUM_UHRZEIT}}"]
        ),

        // MARK: - VIP Escalation (Email)

        ResponseTemplate(
            title: "VIP-Kunde Eskalation",
            category: .escalation,
            subject: "Dringende Eskalation: VIP-Kunde {{KUNDENNAME}}",
            body: """
            Guten Tag {{KUNDENNAME}},

            ich bin {{TEAMLEAD_NAME}}, Teamleiter im \(AppBrand.appName) Kundensupport.

            Ihr Anliegen wurde an mich persönlich eskaliert, und ich möchte sicherstellen, dass Sie die bestmögliche Unterstützung erhalten.

            **Zusammenfassung Ihres Anliegens:**
            {{ZUSAMMENFASSUNG}}

            **Unsere nächsten Schritte:**
            {{NAECHSTE_SCHRITTE}}

            Sie können mich direkt unter {{DIREKTKONTAKT}} erreichen.

            Mit freundlichen Grüßen
            {{TEAMLEAD_NAME}}
            Teamleiter Kundensupport
            \(AppBrand.appName)
            """,
            availableForRoles: [.teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{TEAMLEAD_NAME}}", "{{ZUSAMMENFASSUNG}}", "{{NAECHSTE_SCHRITTE}}", "{{DIREKTKONTAKT}}"],
            isEmail: true
        )
    ]
}
