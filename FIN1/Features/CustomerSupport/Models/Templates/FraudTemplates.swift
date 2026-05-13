import Foundation

// MARK: - Fraud Analyst Templates
/// Templates specific to Fraud Analyst role
enum FraudTemplates {

    static let all: [ResponseTemplate] = [
        // MARK: - Security

        ResponseTemplate(
            title: "Konto temporär gesperrt (Sicherheit)",
            category: .security,
            subject: "Wichtig: Ihr \(AppBrand.appName) Konto wurde vorübergehend gesperrt",
            body: """
            Guten Tag {{KUNDENNAME}},
            
            aus Sicherheitsgründen haben wir Ihr \(AppBrand.appName) Konto vorübergehend gesperrt.
            
            **Grund:** Wir haben ungewöhnliche Aktivitäten auf Ihrem Konto festgestellt.
            
            **Was Sie jetzt tun sollten:**
            1. Prüfen Sie Ihre letzten Transaktionen
            2. Ändern Sie Ihr Passwort nach der Entsperrung
            3. Aktivieren Sie 2FA, falls noch nicht geschehen
            
            **Zur Entsperrung:**
            Bitte kontaktieren Sie uns telefonisch unter +49 (0)30 1234567 oder antworten Sie auf diese E-Mail mit einem gültigen Ausweisdokument zur Verifizierung.
            
            Diese Maßnahme dient ausschließlich Ihrem Schutz.
            
            Mit freundlichen Grüßen
            {{AGENTNAME}}
            \(AppBrand.appName) Sicherheitsteam
            """,
            availableForRoles: [.fraud, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{AGENTNAME}}"],
            isEmail: true
        ),

        // MARK: - Fraud

        ResponseTemplate(
            title: "Karte blockiert (Verdacht)",
            category: .fraud,
            subject: "Ihre \(AppBrand.appName) Karte wurde aus Sicherheitsgründen blockiert",
            body: """
            Guten Tag {{KUNDENNAME}},
            
            wir haben Ihre \(AppBrand.appName) Karte (endend auf {{KARTENNUMMER_LETZTE4}}) vorsorglich blockiert.
            
            **Grund:** Verdächtige Transaktionsversuche wurden erkannt.
            
            **Nächste Schritte:**
            1. Prüfen Sie Ihre letzten Kartentransaktionen in der App
            2. Melden Sie unbekannte Transaktionen sofort
            3. Eine Ersatzkarte kann kostenlos angefordert werden
            
            **Zum Entsperren oder für eine neue Karte:**
            Kontaktieren Sie uns unter +49 (0)30 1234567 oder in der App unter "Hilfe".
            
            Wir entschuldigen uns für etwaige Unannehmlichkeiten.
            
            Mit freundlichen Grüßen
            {{AGENTNAME}}
            \(AppBrand.appName) Fraud Prevention
            """,
            availableForRoles: [.fraud, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{KARTENNUMMER_LETZTE4}}", "{{AGENTNAME}}"],
            isEmail: true
        ),

        ResponseTemplate(
            title: "Chargeback eingeleitet",
            category: .fraud,
            subject: "Chargeback-Verfahren für Ihre Transaktion eingeleitet",
            body: """
            Guten Tag {{KUNDENNAME}},
            
            wir haben Ihr Chargeback-Verfahren für folgende Transaktion eingeleitet:
            
            **Transaktionsdetails:**
            • Datum: {{DATUM}}
            • Betrag: {{BETRAG}}
            • Händler: {{HAENDLER}}
            • Referenz: {{REFERENZ}}
            
            **Wie geht es weiter?**
            1. Wir haben Ihre Bank über das Chargeback informiert
            2. Der Händler hat 30 Tage Zeit zur Stellungnahme
            3. Sie werden über das Ergebnis informiert
            
            **Mögliche Ergebnisse:**
            • Vollständige Rückerstattung
            • Teilweise Rückerstattung
            • Ablehnung (mit Begründung)
            
            Die Bearbeitung dauert in der Regel 4-6 Wochen.
            
            Mit freundlichen Grüßen
            {{AGENTNAME}}
            \(AppBrand.appName) Dispute Resolution
            """,
            availableForRoles: [.fraud, .compliance, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{DATUM}}", "{{BETRAG}}", "{{HAENDLER}}", "{{REFERENZ}}", "{{AGENTNAME}}"],
            isEmail: true
        )
    ]
}
