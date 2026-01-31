import Foundation

/// German content for Privacy Policy
enum PrivacyPolicyGermanContent {

    typealias Section = PrivacyPolicyDataProvider.PrivacySection

    static var sections: [Section] {
        [
            introductionSection,
            dataCategoriesSection,
            legalBasisSection,
            purposeSection,
            dataSourcesSection,
            dataSharingSection,
            internationalTransfersSection,
            retentionSection,
            userRightsSection,
            securitySection,
            cookiesSection,
            breachSection,
            marketingSection,
            profilingSection,
            changesSection,
            contactSection,
            jurisdictionSection
        ]
    }

    // MARK: - Section 1: Introduction

    static let introductionSection = Section(
        id: "introduction",
        title: "1. Einleitung & Verantwortlicher",
        content: """
        **Verantwortlicher:**
        \(LegalIdentity.companyLegalName)
        [Registrierte Adresse]
        [Registernummer]
        E-Mail: privacy@fin1.com
        Telefon: +49 [Nummer]

        **Datenschutzbeauftragter:**
        [Name]
        E-Mail: dpo@fin1.com
        Telefon: +49 [Nummer]

        **Richtlinienversion:**
        Version 1.0
        Zuletzt aktualisiert: [Datum]
        Gültig ab: [Datum]

        **Geltungsbereich:**
        Diese Datenschutzerklärung gilt für alle Nutzer der \(LegalIdentity.platformName)-Plattform, einschließlich Investoren und Trader. Sie beschreibt, wie wir personenbezogene Daten sammeln, verwenden, speichern und schützen.
        """,
        icon: "info.circle.fill"
    )

    // MARK: - Section 2: Data Categories

    static let dataCategoriesSection = Section(
        id: "data-categories",
        title: "2. Kategorien personenbezogener Daten",
        content: """
        Wir verarbeiten folgende Kategorien personenbezogener Daten:

        **A. Personenbezogene Identifikationsdaten:**
        - Vollständiger Name (Vor- und Nachname, Anrede, akademischer Titel)
        - Geburtsdatum
        - Geburtsort
        - Geburtsland
        - Nationalität (einschließlich zusätzlicher Nationalitäten)
        - Ausweisdokumentnummern
        - Kunden-ID / Benutzer-ID

        **B. Kontaktdaten:**
        - E-Mail-Adresse
        - Telefonnummer
        - Postanschrift (Straße, Stadt, Postleitzahl, Bundesland, Land)
        - Zusätzliche Adressen (falls zutreffend)

        **C. Finanzdaten:**
        - Steueridentifikationsnummer (TIN)
        - Zusätzliche Steuerwohnsitze
        - Steuernummern für mehrere Gerichtsbarkeiten
        - Einkommensinformationen (Betrag, Bereich, Quellen)
        - Beschäftigungsstatus
        - Bargeld und liquide Vermögenswerte
        - Bankverbindungsdaten (falls erfasst)
        - Zahlungsmethodeninformationen

        **D. Identitätsverifizierungsdokumente (Besondere Kategorie):**
        - Passbilder (Vorder- und Rückseite)
        - Ausweisbilder (Vorder- und Rückseite)
        - Adressverifizierungsdokumente
        - KYC-Verifizierungsstatus
        - AML-Compliance-Status

        **E. Handels- und Investitionsdaten:**
        - Investitionsbeträge
        - Investitionshistorie
        - Handelsaktivitäten
        - Handelsaufträge (Kauf/Verkauf)
        - Wertpapierbestände
        - Gewinn-/Verlustaufzeichnungen
        - Provisionsaufzeichnungen
        - Risikotoleranzbewertung
        - Anlageerfahrung
        - Handelshäufigkeit
        - Anlagekenntnisse
        - Gewünschte Renditeerwartungen

        **F. Kontodaten & Authentifizierung:**
        - Benutzername
        - Passwort (gehasht, niemals im Klartext gespeichert)
        - Sitzungstoken
        - Anmeldehistorie
        - Letztes Anmeldedatum
        - Kontenerstellungsdatum
        - Kontostatus (aktiv, gesperrt, geschlossen)
        - E-Mail-Verifizierungsstatus

        **G. Verhaltens- und Nutzungsdaten:**
        - App-Nutzungsmuster
        - Feature-Nutzungsstatistiken
        - Geräteinformationen
        - IP-Adresse
        - Browser/App-Version
        - Betriebssystem
        - Bildschirmauflösung
        - Zeitzone
        - Spracheinstellungen

        **H. Kommunikationsdaten:**
        - Support-Tickets
        - Kundenservice-Kommunikationen
        - Marketing-Einwilligungsstatus
        - Benachrichtigungseinstellungen

        **I. Rechts- und Compliance-Daten:**
        - Nutzungsbedingungen-Annahme (Version, Datum)
        - Datenschutzerklärung-Annahme (Version, Datum)
        - Marketing-Einwilligung (Version, Datum)
        - Insiderhandels-Erklärungen
        - Geldwäsche-Erklärungen
        - Regulatorische Compliance-Aufzeichnungen
        - KYC/AML-Dokumentation
        """,
        icon: "list.bullet.rectangle"
    )

    // MARK: - Section 3: Legal Basis

    static let legalBasisSection = Section(
        id: "legal-basis",
        title: "3. Rechtsgrundlage der Verarbeitung (DSGVO Art. 6)",
        content: """
        Wir verarbeiten Ihre personenbezogenen Daten auf Grundlage folgender Rechtsgrundlagen:

        **A. Vertragserfüllung (Art. 6 Abs. 1 lit. b DSGVO):**
        - **Gilt für**: Kontenerstellung, Handelsausführung, Investmentmanagement
        - **Daten**: Personenbezogene Identifikation, Kontaktdaten, Finanzdaten, Handelsdaten
        - **Begründung**: Notwendig zur Bereitstellung der Plattformdienste

        **B. Rechtliche Verpflichtung (Art. 6 Abs. 1 lit. c DSGVO):**
        - **Gilt für**: KYC/AML-Compliance, Steuerberichterstattung, regulatorische Anforderungen
        - **Daten**: Identitätsdokumente, Steuerinformationen, Transaktionsaufzeichnungen
        - **Begründung**: Erforderlich durch WpHG, GwG, Steuergesetze

        **C. Berechtigte Interessen (Art. 6 Abs. 1 lit. f DSGVO):**
        - **Gilt für**: Analysen, Betrugsprävention, Sicherheit, Geschäftsbetrieb
        - **Daten**: Nutzungsdaten, Geräteinformationen, Verhaltensdaten
        - **Begründung**: Plattformsicherheit, Serviceverbesserung, Betrugsprävention
        - **Widerspruchsrecht**: Sie können der Verarbeitung widersprechen

        **D. Einwilligung (Art. 6 Abs. 1 lit. a DSGVO):**
        - **Gilt für**: Marketing-Kommunikationen, optionale Analysen, Cookies
        - **Daten**: Marketing-Präferenzen, optionale Verhaltensverfolgung
        - **Begründung**: Sie haben ausdrücklich eingewilligt
        - **Widerruf**: Jederzeit widerrufbar

        **Besondere Kategorien personenbezogener Daten (Art. 9 DSGVO):**
        - **Identitätsdokumente**: Rechtliche Verpflichtung (KYC/AML) oder ausdrückliche Einwilligung
        - **Biometrische Daten**: Falls Gesichtserkennung verwendet wird
        """,
        icon: "scale.3d"
    )

    // MARK: - Section 4: Purpose

    static let purposeSection = Section(
        id: "purpose",
        title: "4. Zweck der Verarbeitung",
        content: """
        Wir verarbeiten Ihre Daten für folgende Zwecke:

        **A. Diensterbringung:**
        - Kontenerstellung und -verwaltung
        - Benutzerauthentifizierung und -autorisierung
        - Betrieb der Handelsplattform
        - Investmentpool-Verwaltung
        - Auftragsausführung
        - Gewinn-/Verlustberechnung und -verteilung
        - Rechnungserstellung
        - Kontoumsatzgenerierung

        **B. Rechtliche & Regulatorische Compliance:**
        - KYC (Know Your Customer) Verifizierung
        - AML (Anti-Money Laundering) Compliance
        - Steuerberichterstattung und -compliance
        - Wertpapierhandelsvorschriften (WpHG)
        - Regulatorische Berichterstattung an BaFin (falls zutreffend)
        - Aufbewahrungspflichten

        **C. Sicherheit & Betrugsprävention:**
        - Kontosicherheit
        - Betrugserkennung und -prävention
        - Überwachung verdächtiger Aktivitäten
        - Identitätsverifizierung
        - Transaktionsüberwachung

        **D. Kommunikation:**
        - Kundensupport
        - Service-Benachrichtigungen
        - Wichtige Kontoupdates
        - Updates zu Rechtsdokumenten

        **E. Geschäftsbetrieb:**
        - Serviceverbesserung
        - Analysen und Berichterstattung
        - Leistungsüberwachung
        - Technische Fehlerbehebung
        - Systemwartung

        **F. Marketing (Mit Einwilligung):**
        - Werbekommunikationen
        - Produktupdates
        - Bildungsinhalte
        """,
        icon: "target"
    )

    // MARK: - Section 5: Data Sources

    static let dataSourcesSection = Section(
        id: "data-sources",
        title: "5. Datenquellen",
        content: """
        Wir erhalten Ihre personenbezogenen Daten aus folgenden Quellen:

        **A. Direkt vom Nutzer:**
        - Registrierungsformulare
        - Profilaktualisierungen
        - Dokumenten-Uploads
        - Support-Kommunikationen

        **B. Von der Plattform generiert:**
        - Transaktionsaufzeichnungen
        - Kontoumsätze
        - Rechnungen
        - Nutzungsanalysen
        - Systemprotokolle

        **C. Von Drittanbietern:**
        - **Broker/Börsen**: Handelsausführungsdaten
        - **Identitätsverifizierungsdienste**: KYC-Verifizierung (falls verwendet)
        - **Kreditauskunfteien**: Bonitätsprüfungen (falls durchgeführt)
        - **Regulatorische Datenbanken**: PEP (Politisch exponierte Personen) Screening
        - **Marktdatenanbieter**: Wertpapierpreise, Marktdaten

        **D. Öffentliche Quellen:**
        - Unternehmensregister (für Unternehmenskonten)
        - Regulatorische Einreichungen
        """,
        icon: "arrow.down.circle.fill"
    )

    // MARK: - Section 6: Data Sharing

    static let dataSharingSection = Section(
        id: "data-sharing",
        title: "6. Datenweitergabe & Drittanbieter",
        content: """
        Wir geben Ihre Daten an folgende Drittanbieter weiter:

        **A. Dienstleister (Auftragsverarbeiter):**
        - **Parse Server**: Backend-Infrastruktur
        - **MongoDB**: Datenbank-Hosting
        - **PostgreSQL**: Analysedatenbank
        - **Redis**: Caching-Dienste
        - **MinIO/S3**: Dateispeicher (Dokumentenspeicher)
        - **Cloud-Hosting-Anbieter**: AWS, Azure, etc.
        - **E-Mail-Dienstanbieter**: Transaktions-E-Mails
        - **Push-Benachrichtigungsdienste**: APNS (Apple), FCM (Google)
        - **Analysedienste**: Interne Analysedienste
        - **Marktdatenanbieter**: Echtzeit-Handelsdaten

        **B. Finanzinstitute:**
        - **Broker**: Auftragsausführung
        - **Börsen**: Handelsausführung (z.B. XETRA)
        - **Zahlungsabwickler**: Falls zutreffend
        - **Banken**: Falls Bankverbindungsdaten geteilt werden

        **C. Regulatorische & Rechtliche Behörden:**
        - **BaFin**: Bundesanstalt für Finanzdienstleistungsaufsicht
        - **Steuerbehörden**: Steuerberichterstattung
        - **Strafverfolgungsbehörden**: Falls gesetzlich erforderlich
        - **Gerichte**: Falls Gerichtsbeschluss erhalten

        **D. Geschäftspartner:**
        - **Lizenzierte Broker**: Handelsausführungspartner
        - **Compliance-Dienstanbieter**: KYC/AML-Dienste

        **E. Unternehmensübertragungen:**
        - **Fusionen/Übernahmen**: Datenübertragung bei Geschäftsübertragungen
        - **Tochtergesellschaften**: Falls zutreffend

        Alle Auftragsverarbeiter sind durch Datenverarbeitungsverträge (DSGVO Art. 28) gebunden.
        """,
        icon: "person.2.fill"
    )

    // MARK: - Section 7: International Transfers

    static let internationalTransfersSection = Section(
        id: "international-transfers",
        title: "7. Internationale Datenübertragungen",
        content: """
        **EU-US-Übertragungen:**
        - **Rechtsmechanismus**: Standardvertragsklauseln (SCCs) oder EU-US Data Privacy Framework
        - **Sicherheitsmaßnahmen**: Technische und organisatorische Maßnahmen
        - **Risiken**: Erläuterung potenzieller Risiken für betroffene Personen

        **Drittländer:**
        - **Liste aller Länder**: Wo Daten übertragen werden können
        - **Rechtsgrundlage**: Für jede Übertragung
        - **Sicherheitsmaßnahmen**: Technische und organisatorische Maßnahmen
        - **Nutzerrechte**: Wie Sie Übertragungen widersprechen können

        **Datenlokalisierung:**
        - **EU-Daten**: In der EU gespeichert (falls zutreffend)
        - **US-Daten**: In den USA gespeichert (falls zutreffend)
        - **Backup-Standorte**: Wo Backups gespeichert werden

        Sie haben das Recht, eine Kopie der Sicherheitsmaßnahmen (SCCs) anzufordern.
        """,
        icon: "globe"
    )

    // MARK: - Section 8: Retention

    static let retentionSection = Section(
        id: "retention",
        title: "8. Speicherdauer",
        content: """
        Wir speichern Ihre Daten für folgende Zeiträume:

        **A. Kontodaten:**
        - **Aktive Konten**: Gespeichert, solange das Konto aktiv ist
        - **Geschlossene Konten**:
          - Finanzaufzeichnungen: 10 Jahre (deutsches Steuerrecht)
          - KYC-Dokumente: 5-10 Jahre (AML-Anforderungen)
          - Transaktionsaufzeichnungen: 10 Jahre (WpHG)
          - Personenbezogene Daten: Bis gesetzliche Aufbewahrung abläuft

        **B. Transaktionsdaten:**
        - **Handelsaufzeichnungen**: 10 Jahre (WpHG § 34)
        - **Investitionsaufzeichnungen**: 10 Jahre
        - **Rechnungen**: 10 Jahre (deutsches Steuerrecht)
        - **Kontoumsätze**: 10 Jahre

        **C. KYC/AML-Daten:**
        - **Identitätsdokumente**: 5-10 Jahre nach Kontoschließung (GwG)
        - **Verifizierungsaufzeichnungen**: 5-10 Jahre
        - **Compliance-Dokumentation**: Gemäß regulatorischen Anforderungen

        **D. Marketing-Daten:**
        - **Einwilligungsaufzeichnungen**: Bis Einwilligung widerrufen + 3 Jahre
        - **Marketing-Listen**: Bis Opt-out

        **E. Analysedaten:**
        - **Nutzungsanalysen**: 2-3 Jahre (nach 1 Jahr anonymisiert)
        - **Leistungsmetriken**: 3-5 Jahre

        **F. Rechtsdokumente:**
        - **Bedingungen-Annahme**: Dauerhaft (für Rechtsverteidigung)
        - **Datenschutzerklärung-Annahme**: Dauerhaft

        Nach Ablauf der Speicherdauer werden Daten gelöscht oder anonymisiert.
        """,
        icon: "clock.fill"
    )

    // MARK: - Section 9: User Rights

    static let userRightsSection = Section(
        id: "user-rights",
        title: "9. Ihre Rechte (DSGVO Kapitel III)",
        content: """
        Sie haben folgende Rechte bezüglich Ihrer personenbezogenen Daten:

        **A. Auskunftsrecht (Art. 15 DSGVO):**
        - **Was**: Anforderung einer Kopie aller personenbezogenen Daten
        - **Wie**: Kontaktieren Sie den DPO oder Support
        - **Frist**: Innerhalb von 1 Monat (verlängerbar auf 3 Monate)
        - **Format**: Maschinenlesbares Format (JSON, CSV)

        **B. Recht auf Berichtigung (Art. 16 DSGVO):**
        - **Was**: Korrektur unrichtiger Daten
        - **Wie**: Profil aktualisieren oder Support kontaktieren
        - **Frist**: Unverzüglich
        - **Verifizierung**: Kann Dokumentation erfordern

        **C. Recht auf Löschung ("Recht auf Vergessenwerden") (Art. 17 DSGVO):**
        - **Was**: Anforderung der Löschung personenbezogener Daten
        - **Einschränkungen**:
          - Gesetzliche Aufbewahrungspflichten (Steuer, AML)
          - Laufende vertragliche Verpflichtungen
          - Rechtliche Ansprüche
        - **Wie**: Support oder DPO kontaktieren
        - **Frist**: Innerhalb von 1 Monat

        **D. Recht auf Einschränkung der Verarbeitung (Art. 18 DSGVO):**
        - **Was**: Einschränkung der Datenverarbeitung
        - **Wann**:
          - Datenrichtigkeit bestritten
          - Verarbeitung rechtswidrig
          - Widerspruch anhängig

        **E. Recht auf Datenübertragbarkeit (Art. 20 DSGVO):**
        - **Was**: Daten in strukturiertem, maschinenlesbarem Format erhalten
        - **Umfang**: Vom Nutzer bereitgestellte Daten, verarbeitet durch Einwilligung oder Vertrag
        - **Format**: JSON, CSV, XML
        - **Übertragung**: Kann direkte Übertragung an anderen Anbieter anfordern

        **F. Widerspruchsrecht (Art. 21 DSGVO):**
        - **Was**: Widerspruch gegen Verarbeitung aufgrund berechtigter Interessen
        - **Umfang**: Marketing, Analysen, Profiling
        - **Wirkung**: Verarbeitung stoppt, es sei denn, zwingende berechtigte Gründe

        **G. Rechte bezüglich automatisierter Entscheidungsfindung (Art. 22 DSGVO):**
        - **Was**: Recht, nicht automatisierter Entscheidungen unterworfen zu werden
        - **Umfang**: Falls automatisierte Handelsentscheidungen, Risikobewertungen
        - **Sicherheitsmaßnahmen**: Menschliche Überprüfung verfügbar
        - **Erklärung**: Wie automatisierte Entscheidungen funktionieren

        **H. Recht auf Widerruf der Einwilligung (Art. 7 Abs. 3 DSGVO):**
        - **Was**: Widerruf zuvor erteilter Einwilligung
        - **Wirkung**: Verarbeitung stoppt (wenn Einwilligung einzige Rechtsgrundlage)
        - **Wie**: Einstellungen, Support kontaktieren
        - **Leichtigkeit**: So einfach wie Erteilung der Einwilligung

        **I. Beschwerderecht (Art. 77 DSGVO):**
        - **Was**: Beschwerde bei Aufsichtsbehörde einreichen
        - **Deutschland**:
          - Bundesbeauftragte für den Datenschutz und die Informationsfreiheit (BfDI)
          - Landesdatenschutzbehörden
        - **EU**: Datenschutzbehörde in Ihrem Land
        - **Kontaktinformationen**: In der Richtlinie bereitgestellt

        **Ausübung Ihrer Rechte:**
        - E-Mail: privacy@fin1.com oder dpo@fin1.com
        - In-App: Support-Funktion
        - Schriftlich: Postanschrift bereitgestellt
        - **Verifizierung**: Identitätsprüfung erforderlich
        - **Frist**: Antwort innerhalb von 1 Monat
        - **Gebühren**: Generell kostenlos (kann für übermäßige Anfragen berechnet werden)
        """,
        icon: "hand.raised.fill"
    )

    // MARK: - Section 10: Security

    static let securitySection = Section(
        id: "security",
        title: "10. Sicherheitsmaßnahmen",
        content: """
        Wir implementieren folgende Sicherheitsmaßnahmen:

        **A. Technische Maßnahmen:**
        - **Verschlüsselung**:
          - AES-256 für Daten im Ruhezustand
          - TLS 1.3 für Daten während der Übertragung
          - Keychain-Integration für sensible Daten (iOS)
        - **Authentifizierung**:
          - Starke Passwortanforderungen
          - Biometrische Authentifizierung (Face ID, Touch ID)
          - Multi-Faktor-Authentifizierung (falls verfügbar)
          - Sitzungsverwaltung
        - **Zugriffskontrollen**:
          - Rollenbasierte Zugriffskontrolle
          - Prinzip der geringsten Berechtigung
          - Regelmäßige Zugriffsüberprüfungen
        - **Netzwerksicherheit**:
          - Firewalls
          - Intrusion Detection
          - DDoS-Schutz
        - **Datenbackup**:
          - Regelmäßige Backups
          - Verschlüsselte Backups
          - Disaster-Recovery-Pläne

        **B. Organisatorische Maßnahmen:**
        - **Mitarbeiterschulung**: Datenschutzschulungen
        - **Zugriffsprotokollierung**: Audit-Trails
        - **Incident Response**: Datenverletzungsverfahren
        - **Regelmäßige Audits**: Sicherheitsbewertungen
        - **Vendor-Management**: Datenverarbeitungsverträge

        **C. Physische Sicherheit:**
        - **Rechenzentren**: Physische Sicherheitsmaßnahmen
        - **Bürosicherheit**: Zugriffskontrollen

        **Wichtig**: Kein System ist 100% sicher. Wir bemühen uns um höchste Sicherheitsstandards, können jedoch absolute Sicherheit nicht garantieren.
        """,
        icon: "lock.shield.fill"
    )

    // MARK: - Section 11: Cookies

    static let cookiesSection = Section(
        id: "cookies",
        title: "11. Cookies & Tracking-Technologien",
        content: """
        **A. Notwendige Cookies:**
        - **Zweck**: Plattformfunktionalität
        - **Rechtsgrundlage**: Berechtigte Interessen (Art. 6 Abs. 1 lit. f DSGVO)
        - **Beispiele**: Sitzungs-Cookies, Authentifizierungstoken
        - **Opt-Out**: Nicht möglich (für Service erforderlich)

        **B. Analyse-Cookies:**
        - **Zweck**: Serviceverbesserung, Nutzungsanalysen
        - **Rechtsgrundlage**: Einwilligung (Art. 6 Abs. 1 lit. a DSGVO) oder berechtigte Interessen
        - **Beispiele**: Interne Analysedienste
        - **Opt-Out**: Einstellungen oder Support kontaktieren
        - **Drittanbieter**: Falls Analysedienstanbieter verwendet werden

        **C. Marketing-Cookies:**
        - **Zweck**: Werbung, Retargeting
        - **Rechtsgrundlage**: Einwilligung (Art. 6 Abs. 1 lit. a DSGVO)
        - **Opt-Out**: Immer möglich
        - **Drittanbieter**: Falls Marketinganbieter verwendet werden

        **D. Mobile App Tracking:**
        - **Geräte-IDs**: IDFA (iOS), GAID (Android)
        - **Zweck**: Analysen, Personalisierung
        - **Rechtsgrundlage**: Einwilligung
        - **Opt-Out**: Geräteeinstellungen oder App-Einstellungen

        Sie können Ihre Cookie-Präferenzen in den App-Einstellungen verwalten.
        """,
        icon: "eye.slash.fill"
    )

    // MARK: - Section 12: Breach

    static let breachSection = Section(
        id: "breach",
        title: "12. Datenverletzungsbenachrichtigung",
        content: """
        **A. Benutzerbenachrichtigung:**
        - **Frist**: Unverzüglich, innerhalb von 72 Stunden bei hohem Risiko (DSGVO Art. 33)
        - **Inhalt**:
          - Art der Verletzung
          - Betroffene Datenkategorien
          - Wahrscheinliche Folgen
          - Ergreifene Maßnahmen
          - Empfehlungen für Nutzer
        - **Methode**: E-Mail, In-App-Benachrichtigung oder beides

        **B. Behördenbenachrichtigung:**
        - **Frist**: Innerhalb von 72 Stunden (DSGVO Art. 33)
        - **Behörde**: Relevante Datenschutzbehörde
        - **Inhalt**: Detaillierte Verletzungsinformationen

        **C. Dokumentation:**
        - **Verletzungsregister**: Wird gemäß DSGVO Art. 33(5) geführt
        - **Aufzeichnungen**: Alle Verletzungen dokumentiert

        Wenn Sie eine vermutete Datenverletzung bemerken, kontaktieren Sie uns bitte umgehend.
        """,
        icon: "exclamationmark.triangle.fill"
    )

    // MARK: - Section 13: Marketing

    static let marketingSection = Section(
        id: "marketing",
        title: "13. Marketing & Kommunikationen",
        content: """
        **A. Marketing-Kommunikationen:**
        - **Arten**: E-Mail, Push-Benachrichtigungen, In-App-Nachrichten
        - **Inhalt**: Werbung, Bildung, Updates
        - **Häufigkeit**: Wie in Präferenzen angegeben

        **B. Einwilligungsverwaltung:**
        - **Opt-In**: Ausdrückliche Einwilligung erforderlich (DSGVO)
        - **Opt-Out**: Einfacher Widerrufsmechanismus
        - **Präferenzen**: Granulare Kontrolle (E-Mail, Push, SMS)
        - **Aufzeichnung**: Einwilligungsversion, Datum werden verfolgt

        **C. Drittanbieter-Marketing:**
        - **Weitergabe**: Ob Daten für Marketing geteilt werden
        - **Opt-Out**: Wie Weitergabe verhindert werden kann

        Sie können Ihre Marketing-Präferenzen jederzeit in den App-Einstellungen ändern.
        """,
        icon: "megaphone.fill"
    )

    // MARK: - Section 14: Profiling

    static let profilingSection = Section(
        id: "profiling",
        title: "14. Profiling & Automatisierte Entscheidungsfindung",
        content: """
        **A. Profiling-Aktivitäten:**
        - **Risikobewertung**: Automatisierte Risikotoleranzberechnung
        - **Trader-Matching**: Algorithmusbasierte Trader-Auswahl
        - **Anlageempfehlungen**: Falls automatisierte Empfehlungen
        - **Zweck**: Service-Personalisierung, Risikomanagement

        **B. Automatisierte Entscheidungen:**
        - **Handelsentscheidungen**: Falls automatisiertes Trading aktiviert
        - **Risikoklassifizierung**: Automatisierte Risikobewertung
        - **Kontogenehmigung**: Automatisierte KYC-Verifizierung (falls zutreffend)

        **C. Nutzerrechte:**
        - **Menschliche Überprüfung**: Recht auf menschliche Intervention
        - **Erklärung**: Recht auf Erklärung der Logik
        - **Widerspruch**: Recht, Profiling zu widersprechen

        Sie haben das Recht, nicht automatisierter Entscheidungsfindung unterworfen zu werden und eine menschliche Überprüfung zu verlangen.
        """,
        icon: "brain.head.profile"
    )

    // MARK: - Section 15: Changes

    static let changesSection = Section(
        id: "changes",
        title: "15. Änderungen der Datenschutzerklärung",
        content: """
        **A. Benachrichtigung über Änderungen:**
        - **Wesentliche Änderungen**: 30 Tage Vorlaufzeit (gemäß Nutzungsbedingungen)
        - **Methoden**: E-Mail, In-App-Benachrichtigung, Website-Hinweis
        - **Versionskontrolle**: Versionsnummern, Daten werden verfolgt

        **B. Annahme:**
        - **Fortgesetzte Nutzung**: Stellt Annahme dar
        - **Widerspruch**: Kann Konto kündigen, wenn nicht einverstanden
        - **Geschichte**: Vorherige Versionen verfügbar

        **C. Wesentliche Änderungen:**
        - **Beispiele**: Neue Datenkategorien, neue Zwecke, neue Drittanbieter
        - **Einwilligung**: Kann neue Einwilligung für wesentliche Änderungen erfordern

        Wir werden Sie über alle wesentlichen Änderungen dieser Datenschutzerklärung informieren.
        """,
        icon: "arrow.triangle.2.circlepath"
    )

    // MARK: - Section 16: Contact

    static let contactSection = Section(
        id: "contact",
        title: "16. Kontaktinformationen & Rechteausübung",
        content: """
        **A. Datenschutzbeauftragter (DPO):**
        - **Name**: [Name]
        - **E-Mail**: dpo@fin1.com
        - **Telefon**: [Nummer]
        - **Adresse**: [Adresse]

        **B. Allgemeine Datenschutzanfragen:**
        - **E-Mail**: privacy@fin1.com
        - **Support**: In-App-Support-Funktion
        - **Telefon**: [Nummer]
        - **Adresse**: [Adresse]

        **C. Rechteausübung:**
        - **Wie**: E-Mail, In-App-Anfrage, schriftliche Anfrage
        - **Verifizierung**: Identitätsprüfung erforderlich
        - **Frist**: Antwort innerhalb von 1 Monat
        - **Gebühren**: Generell kostenlos (kann für übermäßige Anfragen berechnet werden)

        **D. Beschwerden:**
        - **Intern**: Kontaktieren Sie zuerst den DPO
        - **Extern**:
          - **Deutschland**: BfDI oder Landesbehörde
          - **EU**: Lokale Datenschutzbehörde
          - **USA**: State Attorney General (falls zutreffend)

        **Aufsichtsbehörde (Deutschland):**
        Bundesbeauftragte für den Datenschutz und die Informationsfreiheit (BfDI)
        [Adresse]
        Website: [URL]
        """,
        icon: "envelope.fill"
    )

    // MARK: - Section 17: Jurisdiction

    static let jurisdictionSection = Section(
        id: "jurisdiction",
        title: "17. Geltendes Recht & Gerichtsbarkeit",
        content: """
        **A. Anwendbares Recht:**
        - **Primäres Recht**: DSGVO (Datenschutz-Grundverordnung), BDSG (Bundesdatenschutzgesetz)
        - **Zusätzliche Gesetze**:
          - TTDSG (Telekommunikation-Telemedien-Datenschutz-Gesetz)
          - WpHG (Wertpapierhandelsgesetz) - für Handelsdaten
          - GwG (Geldwäschegesetz) - für KYC/AML-Daten
          - Steuergesetze - für Aufbewahrungspflichten

        **B. Aufsichtsbehörden:**
        - **Bundesbeauftragte für den Datenschutz und die Informationsfreiheit (BfDI)**
        - **Landesdatenschutzbehörden** (je nach Bundesland)
        - **BaFin** (Bundesanstalt für Finanzdienstleistungsaufsicht) - für Finanzdienstleistungen

        **C. Gerichtsstand:**
        - Diese Datenschutzerklärung unterliegt deutschem Recht
        - Streitigkeiten unterliegen der ausschließlichen Zuständigkeit deutscher Gerichte
        - Der spezifische Gerichtsstand wird durch die registrierte Adresse der Plattform oder gesetzliche Bestimmungen bestimmt

        **D. EU-weite Geltung:**
        - Diese Datenschutzerklärung gilt für alle Nutzer in Deutschland und der Europäischen Union
        - Die DSGVO gilt einheitlich in allen EU-Mitgliedstaaten
        - Ihre Rechte sind in allen EU-Ländern gleich

        Diese Datenschutzerklärung wurde speziell für deutsche und EU-Nutzer erstellt und entspricht den geltenden deutschen und EU-Datenschutzgesetzen.
        """,
        icon: "globe.europe.africa"
    )
}

