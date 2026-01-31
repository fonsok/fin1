import Foundation

// MARK: - Tech Support Templates
/// Templates specific to Tech Support role
enum TechSupportTemplates {

    static let all: [ResponseTemplate] = [
        // MARK: - Technical

        ResponseTemplate(
            title: "App-Update erforderlich",
            category: .technical,
            body: """
            Guten Tag {{KUNDENNAME}},

            das von Ihnen beschriebene Problem ist uns bekannt und wurde in der neuesten App-Version behoben.

            **Ihre aktuelle Version:** {{AKTUELLE_VERSION}}
            **Empfohlene Version:** {{NEUE_VERSION}}

            **So aktualisieren Sie:**
            • iOS: App Store → Updates → \(AppBrand.appName) aktualisieren
            • Android: Play Store → Meine Apps → \(AppBrand.appName) aktualisieren

            Nach dem Update sollte das Problem behoben sein. Falls nicht, melden Sie sich bitte erneut.
            """,
            availableForRoles: [.techSupport, .level1, .level2, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{AKTUELLE_VERSION}}", "{{NEUE_VERSION}}"]
        ),

        ResponseTemplate(
            title: "Cache leeren Anleitung",
            category: .technical,
            body: """
            Guten Tag {{KUNDENNAME}},

            bitte versuchen Sie, den App-Cache zu leeren:

            **iOS:**
            1. App löschen (Daten bleiben erhalten)
            2. App neu aus dem App Store installieren
            3. Erneut anmelden

            **Android:**
            1. Einstellungen → Apps → \(AppBrand.appName)
            2. Speicher → Cache leeren
            3. App neu starten

            Dies behebt häufig Anzeigeprobleme und Ladeprobleme.
            """,
            availableForRoles: [.techSupport, .level1, .level2, .teamlead],
            placeholders: ["{{KUNDENNAME}}"]
        ),

        ResponseTemplate(
            title: "Bug-Report erstellt",
            category: .technical,
            body: """
            Guten Tag {{KUNDENNAME}},

            vielen Dank für Ihre detaillierte Fehlerbeschreibung.

            **Ich habe einen Bug-Report erstellt:**
            • Referenz: BUG-{{BUG_ID}}
            • Priorität: {{PRIORITAET}}
            • Betroffene Version: {{VERSION}}

            Unser Entwicklerteam wird sich dem Problem annehmen. Sie werden informiert, sobald eine Lösung verfügbar ist.

            **Workaround bis dahin:**
            {{WORKAROUND}}

            Vielen Dank für Ihre Geduld.
            """,
            availableForRoles: [.techSupport, .teamlead],
            placeholders: ["{{KUNDENNAME}}", "{{BUG_ID}}", "{{PRIORITAET}}", "{{VERSION}}", "{{WORKAROUND}}"]
        ),

        ResponseTemplate(
            title: "Verbindungsproblem",
            category: .technical,
            body: """
            Guten Tag {{KUNDENNAME}},

            bei Verbindungsproblemen helfen oft folgende Schritte:

            1. **Internetverbindung prüfen**
               • WLAN aus- und einschalten
               • Mobile Daten testen

            2. **App neu starten**
               • App vollständig schließen
               • 10 Sekunden warten
               • App erneut öffnen

            3. **VPN deaktivieren**
               • Falls aktiv, VPN vorübergehend ausschalten

            4. **Firewall/Antivirus prüfen**
               • \(AppBrand.appName) als vertrauenswürdige App hinzufügen

            Falls das Problem weiterhin besteht, teilen Sie mir bitte mit:
            • Ihre Internetverbindung (WLAN/Mobil)
            • Ihr Mobilfunkanbieter
            • Fehlermeldung (Screenshot)
            """,
            availableForRoles: [.techSupport, .level1, .level2, .teamlead],
            placeholders: ["{{KUNDENNAME}}"]
        )
    ]
}
