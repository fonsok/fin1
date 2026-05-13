import Foundation

/// German content for Terms of Service
enum TermsOfServiceGermanContent {

    typealias Section = TermsOfServiceDataProvider.TermsSection

    static func sections(commissionRate: Double) -> [Section] {
        [
            self.introSection,
            self.acceptanceSection,
            self.regulatorySection,
            self.appServiceScopeSection,
            self.accountSection,
            self.tradingSection,
            self.investmentSection(commissionRate: commissionRate),
            self.taxSection,
            self.risksSection,
            self.responsibilitiesSection,
            self.limitationsSection,
            self.ipSection,
            self.privacySection,
            self.terminationSection,
            self.disputesSection,
            self.changesSection,
            self.contactSection,
            self.specialSection,
            self.severabilitySection
        ]
    }

    // MARK: - Sections 1-5

    static let introSection = Section(
        id: "introduction",
        title: "1. Einleitung & Definitionen",
        content: """
        \(LegalIdentity.platformName) ist eine Technologie-App, die Wertpapierhandel und Vermögensanlage-/Investmentmanagement-Dienstleistungen erleichtert. Die App verbindet Trader und Investoren und ermöglicht Vermögensanlage-/Investitionsmöglichkeiten in Wertpapierhandelsaktivitäten mit Derivaten.
        
        **Definitionen:**
        - **App** oder **Service**: Die \(LegalIdentity.platformName)-Anwendung und zugehörige Dienstleistungen
        - **Nutzer**: Jede Person oder Entität, die die App nutzt
        - **Trader**: Nutzer, die Wertpapiergeschäfte in der App ausführen
        - **Investor**: Nutzer, die Kapital bei Tradern über die App investieren
        - **Investition**: Kapital, das von Investoren an Trader für Handelsaktivitäten zugewiesen wird
        - **Wertpapiere**: Finanzinstrumente, die in der App gehandelt werden
        """,
        icon: "info.circle.fill"
    )

    static let acceptanceSection = Section(
        id: "acceptance",
        title: "2. Annahme der Bedingungen",
        content: """
        Durch den Zugriff auf oder die Nutzung der \(LegalIdentity.platformName)-App erklären Sie sich damit einverstanden, an diese Nutzungsbedingungen gebunden zu sein. Wenn Sie diesen Bedingungen nicht zustimmen, dürfen Sie die App nicht nutzen.
        
        **Änderungen:**
        Wir behalten uns das Recht vor, diese Bedingungen jederzeit zu ändern. Wesentliche Änderungen werden mit mindestens 30 Tagen Vorlaufzeit mitgeteilt. Die fortgesetzte Nutzung der App nach Änderungen stellt die Annahme der geänderten Bedingungen dar.
        
        **Berechtigung:**
        Sie müssen mindestens 18 Jahre alt sein und die rechtliche Handlungsfähigkeit haben, um rechtsverbindliche Vereinbarungen einzugehen. Sie müssen alle geltenden Gesetze und Vorschriften in Ihrer Gerichtsbarkeit einhalten.
        """,
        icon: "checkmark.circle.fill"
    )

    static let regulatorySection = Section(
        id: "regulatory",
        title: "3. Regulatorische Compliance",
        content: """
        **Deutsche Wertpapierhandelsvorschriften:**
        Die App arbeitet in Übereinstimmung mit:
        - **Wertpapierhandelsgesetz (WpHG)** - Deutsches Wertpapierhandelsgesetz
        - **Wertpapierhandelsverordnung (WpDVerOV)** - Deutsche Wertpapierhandelsverordnung
        - Alle Transaktionen werden in Übereinstimmung mit diesen Vorschriften ausgeführt
        
        **Steuerrechtliche Compliance:**
        - Alle Steuerberechnungen erfolgen gemäß **§ 20 EStG** (Deutsches Einkommensteuergesetz)
        - Kapitalgewinne unterliegen der **Abgeltungsteuer** (25% + Soli) auf realisierte Gewinne
        - Die Steuereinbehaltung wird von der ausführenden Bank durchgeführt, nicht von der App
        - Nutzer sind allein für ihre Steuercompliance verantwortlich
        
        **DSGVO-Compliance:**
        Die App entspricht der Datenschutz-Grundverordnung (DSGVO) und dem Bundesdatenschutzgesetz (BDSG). Bitte beachten Sie unsere Datenschutzerklärung für detaillierte Informationen zur Datenverarbeitung.
        """,
        icon: "shield.checkered"
    )

    static let appServiceScopeSection = Section(
        id: "platform",
        title: "4. Appbeschreibung & Serviceumfang",
        content: """
        **Art des Services:**
        \(LegalIdentity.platformName) ist eine **Technologie-App**, die Wertpapierhandel und Investmentmanagement erleichtert. Die App bietet Technologieinfrastruktur, verbindet Trader und Investoren, führt Geschäfte über lizenzierte Broker aus und stellt Transaktionsaufzeichnungen bereit.
        
        **Was wir NICHT anbieten:**
        - Anlageberatung oder Empfehlungen
        - Garantierte Anlagerenditen oder Performance
        - Finanzberatungsdienstleistungen
        - Garantierte Trader-Verfügbarkeit oder Investitionsmöglichkeiten
        - Steuerberatung (Nutzer müssen Steuerberater konsultieren)
        
        **Serviceeinschränkungen:**
        - Die App fungiert als Vermittler, nicht als Hauptpartei
        - Nutzer treffen unabhängige Anlageentscheidungen
        - Die App garantiert keine Ausführung zu angezeigten Preisen
        - Die Serviceverfügbarkeit ist nicht garantiert unterbrechungsfrei
        """,
        icon: "app.badge"
    )

    static let accountSection = Section(
        id: "account",
        title: "5. Nutzerberechtigung & Kontenanforderungen",
        content: """
        **Kontoberechtigung:**
        Um die App zu nutzen, müssen Sie mindestens 18 Jahre alt sein, rechtliche Handlungsfähigkeit haben, genaue Informationen bereitstellen, die Identitätsprüfung (KYC) abschließen und alle geltenden Gesetze einhalten.
        
        **Kontotypen:**
        - **Trader-Konten**: Für Nutzer, die Wertpapiergeschäfte ausführen
        - **Investor-Konten**: Für Nutzer, die Kapital bei Tradern investieren
        
        **Kontoguthaben:**
        - Anfangsguthaben: Sofern Administratoren in **Configuration** (über die App) nichts anderes festlegen, beginnen neue Konten mit **0,00 €**; Aufladung z. B. per Einzahlung oder andere von der App freigegebene Vorgänge.
        - Mindestbargeldreserve: Konten müssen eine Mindestbargeldreserve von €20 aufrechterhalten
        - Guthabenzweck: Kontoguthaben sind nur für die App-Nutzung bestimmt (ggf. Demo vs. echtes Guthaben klären)
        - Einschränkungen: Guthaben können App-Richtlinien und aufsichtsrechtlichen Vorgaben unterliegen
        """,
        icon: "person.circle.fill"
    )

    // MARK: - Sections 6-10

    static let tradingSection = Section(
        id: "trading",
        title: "6. Handelsbedingungen",
        content: """
        **Auftragsausführung:**
        - Aufträge werden über lizenzierte Broker und Börsen ausgeführt
        - Ausführungspreise unterliegen Marktbedingungen
        - Die App garantiert keine Ausführung zu angezeigten Preisen
        
        **Auftragsgebühren & Kosten:**
        - **Auftragsgebühr**: 0,5% des Auftragswerts (Mindestbetrag €5, Höchstbetrag €50)
        - **Börsenplatzgebühr**: 0,1% des Auftragswerts (Mindestbetrag €1, Höchstbetrag €20)
        - **Fremdkosten**: €1,50 pro Transaktion
        - Gebühren werden auf den Gesamtwertpapierwert berechnet und sind nach Ausführung nicht erstattungsfähig
        
        **Handelslimits:**
        Aufträge müssen Mindestschwellen erfüllen und ausreichendes Guthaben muss verfügbar sein (einschließlich Gebühren und Mindestreserve).
        """,
        icon: "chart.line.uptrend.xyaxis"
    )

    static func investmentSection(commissionRate: Double) -> Section {
        let commissionPercentage = (commissionRate * 100)
            .formatted(.number.precision(.fractionLength(0...2)))
        return Section(
            id: "investment",
            title: "7. Investitionsbedingungen (Investor-spezifisch)",
            content: """
            **Investitionserstellung:**
            - Investoren können Investitionen bei verfügbaren Tradern erstellen
            - Der Mindestinvestitionsbetrag variiert je nach Trader
            - Bis zu 10 Investitionen pro Nutzer (vorbehaltlich App-Limits)
            - Die App garantiert keine Investitionszuweisung oder Trader-Verfügbarkeit
            
            **App-Servicegebühr:**
            - **Satz**: 2% des Investitionsbetrags (Bruttobetrag, einschließlich 19% MwSt.)
            - **Zeitpunkt**: Bei Investitionserstellung berechnet
            - **Nicht erstattungsfähig**: Servicegebühren sind nicht erstattungsfähig
            - **MwSt.**: Die 2% enthalten 19% MwSt. (deutsche Umsatzsteuer)
            
            **Investitionsrenditen:**
            - Renditen hängen von der Trader-Performance und Marktbedingungen ab
            - **Keine garantierten Renditen**: Die App garantiert keine Renditen
            - **Verlustrisiko**: Kapitalverlust ist möglich
            - **Provisionen**: Trader-Provisionen (\(commissionPercentage)%, konfigurierbar) werden von den Renditen abgezogen
            """,
            icon: "eurosign.circle.fill"
        )
    }

    static let taxSection = Section(
        id: "tax",
        title: "8. Steuerpflichten & Verantwortlichkeiten",
        content: """
        **Steuerverantwortung des Nutzers:**
        Nutzer sind allein für ihre Steuercompliance verantwortlich. Die App stellt Transaktionsaufzeichnungen und Rechnungen bereit, berechnet Steuerschätzungen nur zu Informationszwecken und bietet keine Steuerberatung.
        
        **Steuereinbehaltung:**
        - Die Steuereinbehaltung auf realisierte Gewinne wird von der ausführenden Bank durchgeführt
        - **Abgeltungsteuer**: 25% + Soli gilt für realisierte Kapitalgewinne
        - Die App behält keine Steuern ein
        
        **Steuerdokumentation:**
        - Rechnungen werden für alle Transaktionen bereitgestellt
        - Monatliche Kontoumsätze sind verfügbar
        - Nutzer müssen Aufzeichnungen für Steuerzwecke aufbewahren (mindestens 10 Jahre in Deutschland)
        - Nutzer sollten qualifizierte Steuerberater konsultieren
        
        **Steuerhinweise:**
        - Kaufaufträge: Keine Steuern beim Kauf abgezogen. Besteuerung erfolgt beim Verkauf gemäß § 20 EStG
        - Verkaufsaufträge: Besteuerung erfolgt beim Verkauf gemäß Abgeltungsteuer (25% + Soli). Bank führt Einbehaltung durch
        - Servicegebühren: Unterliegen 19% MwSt. (Umsatzsteuer)
        """,
        icon: "doc.text.fill"
    )

    static let risksSection = Section(
        id: "risks",
        title: "9. Risikohinweise",
        content: """
        **WICHTIG: Die Investition in Wertpapiere birgt erhebliche Verlustrisiken.**
        
        **Anlagerisiken:**
        - **Kapitalverlustrisiko**: Sie können einen Teil oder Ihr gesamtes investiertes Kapital verlieren
        - **Marktvolatilität**: Wertpapierpreise schwanken basierend auf Marktbedingungen
        - **Keine Renditegarantie**: Vergangene Performance garantiert keine zukünftigen Ergebnisse
        - **Trader-Performance-Risiko**: Renditen hängen von der Trader-Performance ab, die variiert
        - **Liquiditätsrisiko**: Investitionen sind möglicherweise nicht sofort liquidierbar
        
        **App-Risiken:**
        - Technische Ausfälle, Serviceunterbrechungen, Datenqualitätseinschränkungen
        - Cybersicherheitsrisiken trotz Sicherheitsmaßnahmen
        
        **Bestätigung:**
        Durch die Nutzung der App bestätigen Sie, dass Sie die beteiligten Risiken verstehen, in der Lage sind, die finanziellen Risiken zu tragen, und unabhängige Anlageentscheidungen treffen.
        """,
        icon: "exclamationmark.triangle.fill"
    )

    static let responsibilitiesSection = Section(
        id: "responsibilities",
        title: "10. Nutzerverantwortlichkeiten & Verbotene Aktivitäten",
        content: """
        **Nutzerpflichten:**
        Nutzer müssen genaue Informationen bereitstellen, sichere Zugangsdaten aufrechterhalten, Gesetze einhalten, verdächtige Aktivitäten melden und mit App-Untersuchungen zusammenarbeiten.
        
        **Verbotene Aktivitäten:**
        Nutzern ist untersagt:
        - Betrügerische Aktivitäten, Marktmanipulation, unbefugter Zugriff
        - Umgehung von App-Kontrollen, Bereitstellung falscher Informationen
        - Geldwäsche, Terrorismusfinanzierung, Gesetzesverstöße
        - Störung des App-Betriebs oder anderer Nutzer
        
        **Konsequenzen:**
        Verstöße können zu Kontosperrung oder -kündigung, rechtlichen Schritten, Meldung an Aufsichtsbehörden, Verlust von Geldern oder anderen gesetzlich verfügbaren Abhilfemaßnahmen führen.
        """,
        icon: "hand.raised.fill"
    )

    // MARK: - Sections 11-15

    static let limitationsSection = Section(
        id: "limitations",
        title: "11. App-Einschränkungen & Haftungsausschlüsse",
        content: """
        **Serviceverfügbarkeit:**
        - Die App garantiert keinen unterbrechungsfreien oder fehlerfreien Service
        - Geplante und ungeplante Wartungsarbeiten können auftreten
        - Der Service kann aufgrund von Umständen außerhalb unserer Kontrolle unterbrochen werden
        
        **Datenqualität:**
        - Marktdaten, Preise und Berechnungen werden "wie besehen" bereitgestellt
        - Wir garantieren keine Genauigkeit, Vollständigkeit oder Aktualität
        - Nutzer sollten kritische Informationen unabhängig überprüfen
        
        **Haftungsbeschränkungen:**
        Im gesetzlich zulässigen Rahmen:
        - Die App-Haftung ist auf direkte Schäden beschränkt
        - Wir haften nicht für indirekte, Folgeschäden, zufällige oder Strafschäden
        - Die Gesamthaftung ist auf in den 12 Monaten vor dem Anspruch gezahlte Gebühren beschränkt
        - Wir haften nicht für Verluste aufgrund von Marktbedingungen oder Nutzerentscheidungen
        """,
        icon: "info.circle"
    )

    static let ipSection = Section(
        id: "ip",
        title: "12. Geistiges Eigentum",
        content: """
        **Geistiges Eigentum der App:**
        - Alle App-Inhalte, Software, Designs und Materialien sind Eigentum
        - Nutzern wird eine begrenzte, nicht-exklusive, nicht übertragbare Lizenz zur Nutzung der App gewährt
        - Nutzer dürfen nicht kopieren, modifizieren, verteilen oder abgeleitete Werke erstellen
        - Alle Rechte vorbehalten
        
        **Nutzerdaten:**
        - Nutzer behalten das Eigentum an ihren Daten
        - Nutzer gewähren der App eine Lizenz zur Datenverarbeitung für die Diensterbringung
        - Die Datenverarbeitung unterliegt unserer Datenschutzerklärung und der DSGVO
        
        **Marken:**
        - \(LegalIdentity.platformName) und verwandte Marken sind Eigentum der App
        - Nutzer dürfen Marken nicht ohne schriftliche Genehmigung verwenden
        """,
        icon: "lock.shield.fill"
    )

    static let privacySection = Section(
        id: "privacy",
        title: "13. Datenschutz & Privatsphäre",
        content: """
        **DSGVO-Compliance:**
        Die App entspricht der DSGVO. Bitte beachten Sie unsere Datenschutzerklärung für:
        - Rechtsgrundlage der Datenverarbeitung
        - Nutzerrechte (Auskunft, Berichtigung, Löschung, Übertragbarkeit)
        - Speicherfristen
        - Internationale Datenübertragungen (falls zutreffend)
        - Kontaktinformationen für Datenschutzanfragen
        
        **Datensicherheit:**
        - Wir implementieren branchenübliche Sicherheitsmaßnahmen (AES-256-Verschlüsselung, TLS 1.3)
        - Daten werden sicher gespeichert (Keychain für sensible Daten)
        - Jedoch ist kein System 100% sicher
        - Nutzer müssen sichere Zugangsdaten aufrechterhalten
        
        **Datenweitergabe:**
        - Daten können bei Bedarf mit Brokern, Börsen und Dienstleistern geteilt werden
        - Daten können für regulatorische Compliance geteilt werden (KYC/AML)
        - Die Datenweitergabe unterliegt unserer Datenschutzerklärung
        """,
        icon: "hand.raised.slash.fill"
    )

    static let terminationSection = Section(
        id: "termination",
        title: "14. Kontokündigung & Sperrung",
        content: """
        **Kündigung durch Nutzer:**
        Nutzer können Konten jederzeit kündigen, indem sie den App-Support kontaktieren, Kontoschließungsverfahren befolgen und alle ausstehenden Verpflichtungen begleichen.
        
        **Kündigung durch App:**
        Die App kann Konten wegen Verstoßes gegen die Bedingungen, verdächtiger Aktivitäten, regulatorischer Anforderungen, Nichteinhaltung von KYC/AML oder anderen Gründen kündigen.
        
        **Kontosperrung:**
        Konten können während der Untersuchung, aus Sicherheitsgründen, regulatorischer Compliance oder Nichtzahlung von Gebühren gesperrt werden.
        
        **Nach Kündigung:**
        Ausstehende Verpflichtungen müssen beglichen werden, Datenspeicherungsrichtlinien gelten und der Zugriff auf App-Dienste endet.
        """,
        icon: "xmark.circle.fill"
    )

    static let disputesSection = Section(
        id: "disputes",
        title: "15. Streitbeilegung & Geltendes Recht",
        content: """
        **Geltendes Recht:**
        Diese Bedingungen unterliegen deutschem Recht.
        
        **Gerichtsstand:**
        Streitigkeiten unterliegen der ausschließlichen Zuständigkeit deutscher Gerichte.
        
        **Streitbeilegungsverfahren:**
        1. Informelle Lösung: Kontaktieren Sie zuerst den App-Support
        2. Mediation: Parteien können sich auf Mediation einigen
        3. Schiedsverfahren: Falls anwendbar, können Streitigkeiten durch Schiedsverfahren gelöst werden
        4. Gerichtsverfahren: Wenn andere Methoden scheitern, können Streitigkeiten vor Gericht gebracht werden
        
        **Regulatorische Beschwerden:**
        Nutzer können Beschwerden bei der BaFin (Bundesanstalt für Finanzdienstleistungsaufsicht) oder anderen Aufsichtsbehörden einreichen.
        """,
        icon: "scale.3d"
    )

    // MARK: - Sections 16-19

    static let changesSection = Section(
        id: "changes",
        title: "16. Änderungen der Bedingungen",
        content: """
        **Änderungsrechte:**
        Die App behält sich das Recht vor, diese Bedingungen jederzeit zu ändern.
        
        **Benachrichtigungsanforderungen:**
        - Wesentliche Änderungen: Mindestens 30 Tage Vorlaufzeit
        - Benachrichtigungsmethoden: E-Mail, In-App-Benachrichtigung oder App-Mitteilung
        - Wirksamkeitsdatum: Änderungen werden am angegebenen Datum wirksam
        
        **Annahme:**
        - Die fortgesetzte Nutzung der App nach Änderungen stellt die Annahme dar
        - Nutzer können Konten kündigen, wenn sie Änderungen nicht zustimmen
        - Bedingungen sind versioniert und datiert, mit archivierten vorherigen Versionen
        """,
        icon: "arrow.triangle.2.circlepath"
    )

    static let contactSection = Section(
        id: "contact",
        title: "17. Kontaktinformationen & Support",
        content: """
        **Support-Kanäle:**
        - Help Center: In-App verfügbar mit FAQs und Support-Artikeln
        - Support kontaktieren: In-App-Support-Messaging
        - Antwortzeiten: Wir bemühen uns, innerhalb angemessener Zeiträume zu antworten
        
        **Rechtliche Hinweise:**
        Unternehmensinformationen, Registrierungsdetails, regulatorische Genehmigungen und registrierte Adresse sind auf Anfrage verfügbar.
        
        **Datenschutzbeauftragter:**
        Kontaktinformationen für Datenschutzanfragen sind über die Datenschutzerklärung verfügbar.
        """,
        icon: "envelope.fill"
    )

    static let specialSection = Section(
        id: "special",
        title: "18. Besondere Bestimmungen",
        content: """
        **Demo-/Simulationskonten:**
        - Anfangsguthaben: Wie in der App konfiguriert (häufig **0,00 €** standardmäßig; Demo-Aktionen können abweichen)
        - Klarstellung: Nutzer müssen verstehen, ob Guthaben virtuell oder real sind
        - Umstellung: Demo-Konten können ggf. in echte Konten umgewandelt werden
        - Einschränkungen: Demo-Konten können gegenüber echten Konten eingeschränkt sein
        
        **Geldwäscheprävention:**
        - KYC-Anforderungen: Identitätsprüfung ist erforderlich
        - AML-Compliance: Anti-Geldwäsche-Verfahren gelten
        - Transaktionsüberwachung: Transaktionen werden auf verdächtige Aktivitäten überwacht
        - Meldung: Verdächtige Aktivitäten werden den Behörden gemeldet
        - Nutzerkooperation: Nutzer müssen mit KYC/AML-Verfahren zusammenarbeiten
        
        **Regulatorische Meldungen:**
        - Die App kann verpflichtet sein, an Aufsichtsbehörden zu berichten
        - Nutzerinformationen können für regulatorische Compliance geteilt werden
        - Nutzer müssen genaue Informationen für regulatorische Zwecke bereitstellen
        """,
        icon: "exclamationmark.shield.fill"
    )

    static let severabilitySection = Section(
        id: "severability",
        title: "19. Teilbarkeit & Sonstiges",
        content: """
        **Teilbarkeit:**
        Wenn eine Bestimmung dieser Bedingungen als ungültig oder nicht durchsetzbar befunden wird, bleiben die übrigen Bestimmungen in vollem Umfang in Kraft.
        
        **Vollständige Vereinbarung:**
        Diese Bedingungen bilden zusammen mit der Datenschutzerklärung die vollständige Vereinbarung zwischen Nutzern und der App.
        
        **Verzicht:**
        Die Nichtdurchsetzung einer Bestimmung stellt keinen Verzicht auf diese Bestimmung dar.
        
        **Übertragung:**
        Nutzer dürfen diese Bedingungen nicht ohne Zustimmung der App übertragen. Die App kann diese Bedingungen übertragen.
        
        **Sprache:**
        Diese Bedingungen werden auf Deutsch und Englisch bereitgestellt. Im Falle eines Konflikts hat die deutsche Version Vorrang.
        """,
        icon: "doc.text.magnifyingglass"
    )
}




