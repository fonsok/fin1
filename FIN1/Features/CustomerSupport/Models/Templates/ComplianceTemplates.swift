import Foundation

// MARK: - Compliance Officer Templates
/// Templates specific to Compliance Officer role
enum ComplianceTemplates {

    static let all: [ResponseTemplate] = [
        // MARK: - KYC/Onboarding

        ResponseTemplate(
            title: "KYC-Verifizierung abgeschlossen",
            category: .kycOnboarding,
            subject: "Ihre Identitätsprüfung wurde erfolgreich abgeschlossen",
            body: """
            Guten Tag {{KUNDENNAME}},

            Ihre Identitätsprüfung (KYC) wurde erfolgreich abgeschlossen.

            **Ihr Verifizierungsstatus:** ✅ Vollständig verifiziert

            Sie können nun alle Funktionen der \(AppBrand.appName) App nutzen:
            • Investitionen tätigen
            • Trades ausführen
            • Ein-/Auszahlungen vornehmen

            Vielen Dank für Ihre Geduld während des Prüfungsprozesses.

            Mit freundlichen Grüßen
            {{AGENTNAME}}
            \(AppBrand.appName) Compliance Team
            """,
            availableForRoles: [.compliance, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{AGENTNAME}}"],
            isEmail: true
        ),

        ResponseTemplate(
            title: "KYC-Ablehnung",
            category: .kycOnboarding,
            subject: "Information zu Ihrer Identitätsprüfung",
            body: """
            Guten Tag {{KUNDENNAME}},

            leider konnten wir Ihre Identitätsprüfung nicht erfolgreich abschließen.

            **Grund:** {{ABLEHNUNGSGRUND}}

            **Mögliche nächste Schritte:**
            {{NAECHSTE_SCHRITTE}}

            Bei Fragen zu dieser Entscheidung können Sie uns kontaktieren.

            Mit freundlichen Grüßen
            {{AGENTNAME}}
            \(AppBrand.appName) Compliance Team

            Rechtsgrundlage: Geldwäschegesetz (GwG) §10, §11
            """,
            availableForRoles: [.compliance, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{ABLEHNUNGSGRUND}}", "{{NAECHSTE_SCHRITTE}}", "{{AGENTNAME}}"],
            isEmail: true
        ),

        // MARK: - GDPR

        ResponseTemplate(
            title: "DSGVO-Datenauskunft (Art. 15)",
            category: .gdpr,
            subject: "Ihre DSGVO-Datenauskunft",
            body: """
            Guten Tag {{KUNDENNAME}},

            gemäß Ihrer Anfrage nach Art. 15 DSGVO übermitteln wir Ihnen hiermit eine vollständige Auskunft über die bei uns gespeicherten personenbezogenen Daten.

            **Im Anhang finden Sie:**
            • Übersicht aller gespeicherten Daten
            • Verarbeitungszwecke
            • Empfänger der Daten
            • Speicherdauer

            **Hinweis zu Aufbewahrungspflichten:**
            Einige Daten unterliegen gesetzlichen Aufbewahrungsfristen:
            • Transaktionsdaten: 10 Jahre (§147 AO)
            • KYC-Daten: 5 Jahre nach Geschäftsbeziehungsende (§8 GwG)

            Bei Rückfragen erreichen Sie uns unter datenschutz@fin1.com.

            Mit freundlichen Grüßen
            {{AGENTNAME}}
            \(AppBrand.appName) Datenschutz-Team

            Rechtsgrundlage: Art. 15 DSGVO, Art. 12 Abs. 3 DSGVO
            """,
            availableForRoles: [.compliance, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{AGENTNAME}}"],
            isEmail: true
        ),

        ResponseTemplate(
            title: "DSGVO-Löschung (Art. 17) - Teilweise",
            category: .gdpr,
            subject: "Ihre Anfrage auf Datenlöschung",
            body: """
            Guten Tag {{KUNDENNAME}},

            wir haben Ihre Anfrage auf Löschung Ihrer personenbezogenen Daten gemäß Art. 17 DSGVO erhalten und bearbeitet.

            **Gelöschte Daten:**
            {{GELOESCHTE_DATEN}}

            **Nicht löschbare Daten (gesetzliche Aufbewahrungspflicht):**
            {{NICHT_LOESCHBAR}}

            **Begründung:**
            {{BEGRUENDUNG}}

            Die gesperrten Daten werden automatisch nach Ablauf der Aufbewahrungsfrist gelöscht.

            Mit freundlichen Grüßen
            {{AGENTNAME}}
            \(AppBrand.appName) Datenschutz-Team

            Rechtsgrundlage: Art. 17 Abs. 3 DSGVO, §147 AO, §8 GwG
            """,
            availableForRoles: [.compliance, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{GELOESCHTE_DATEN}}", "{{NICHT_LOESCHBAR}}", "{{BEGRUENDUNG}}", "{{AGENTNAME}}"],
            isEmail: true
        ),

        // MARK: - Compliance (Internal)

        ResponseTemplate(
            title: "AML-Prüfung abgeschlossen",
            category: .compliance,
            body: """
            **Interne Notiz - Vertraulich**

            AML-Prüfung für Kunde {{KUNDEN_ID}} abgeschlossen.

            **Ergebnis:** {{ERGEBNIS}}
            **Risikostufe:** {{RISIKOSTUFE}}
            **Maßnahmen:** {{MASSNAHMEN}}

            Prüfung durchgeführt von: {{AGENTNAME}}
            Datum: {{DATUM}}

            4-Augen-Freigabe: {{FREIGABE_STATUS}}
            """,
            availableForRoles: [.compliance, .teamlead],
            placeholders: ["{{KUNDEN_ID}}", "{{ERGEBNIS}}", "{{RISIKOSTUFE}}", "{{MASSNAHMEN}}", "{{AGENTNAME}}", "{{DATUM}}", "{{FREIGABE_STATUS}}"]
        )
    ]
}
