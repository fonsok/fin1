import Foundation

/// Bundled fallback sections when server-driven role agreements are unavailable.
enum RoleAgreementBundledContent {
    static func sections(for role: UserRole) -> [TermsContentSection] {
        switch role {
        case .trader:
            return self.traderSections
        case .investor:
            return self.investorSections
        default:
            return []
        }
    }

    static func title(for role: UserRole) -> String {
        switch role {
        case .trader:
            return "Signalgeber-Vereinbarung"
        case .investor:
            return "Investor-Vereinbarung"
        default:
            return "Rollenvereinbarung"
        }
    }

    private static let traderSections: [TermsContentSection] = [
        TermsContentSection(
            id: "trader_freistellung",
            title: "1. Freistellung des App-Betreibers",
            content: "Der Trader stellt den App-Betreiber von allen Ansprüchen Dritter frei, die durch eine missbräuchliche oder gesetzeswidrige Nutzung seines Accounts entstehen.",
            icon: "shield"
        ),
        TermsContentSection(
            id: "trader_regulatorisch",
            title: "2. Regulatorischer Vorbehalt (Sperrklausel)",
            content: "Der App-Betreiber behält sich das Recht vor, das Konto des Traders ohne Angabe von Gründen temporär oder dauerhaft zu sperren, falls regulatorische Behörden (z. B. BaFin, ESMA) dies fordern oder sich die Lizenzanforderungen für die App ändern.",
            icon: "exclamationmark.shield"
        ),
        TermsContentSection(
            id: "trader_vertragsaenderung",
            title: "3. Recht auf einseitige Vertragsänderung",
            content: "Änderungen dieser Vereinbarung werden dem Trader mindestens vier Wochen im Voraus in der App angekündigt. Bei kritischen Updates blockiert die App das Platzieren neuer Trades, bis der Trader den geänderten Bedingungen aktiv zustimmt.",
            icon: "doc.badge.gearshape"
        ),
        TermsContentSection(
            id: "trader_status",
            title: "4. Vertragsgegenstand & Status des Traders",
            content: "Der Trader agiert ausschließlich als privater Signalgeber / unabhängiger Creator für sein eigenes, privates Depot. Es wird ausdrücklich vereinbart, dass der Trader keine Anlageberatung, keine Finanzportfolioverwaltung und keine Anlagevermittlung für Dritte erbringt.",
            icon: "person.crop.circle"
        ),
        TermsContentSection(
            id: "trader_blind_execution",
            title: "5. Blind-Execution-Klausel",
            content: "Der Trader erteilt der App die Erlaubnis, seine getätigten Orders nach deren vollständiger Ausführung (Post-Trade) anonymisiert zu Replikationszwecken auszulesen. Der Trader hat zu keinem Zeitpunkt vor oder während der Orderplatzierung Einblick in das potenzielle Pool-Mirror-Volumen oder die Anzahl der beteiligten Investoren.",
            icon: "eye.slash"
        ),
        TermsContentSection(
            id: "trader_haftung",
            title: "6. Haftungsausschluss",
            content: "Der Trader übernimmt keine Gewähr oder Haftung für die Performance seiner Handelsstrategie. Der Investor kopiert den Trader via Pool-Mirror-Trade auf eigenes Risiko.",
            icon: "hand.raised.slash"
        ),
        TermsContentSection(
            id: "trader_verguetung",
            title: "7. Vergütung (Performance Fee)",
            content: "Der Trader erhält eine Erfolgsbeteiligung in Höhe von derzeit 5 % des realisierten Nettogewinns des Pool-Mirror-Trades. Die Abrechnung erfolgt automatisiert über die App.",
            icon: "percent"
        ),
    ]

    private static let investorSections: [TermsContentSection] = [
        TermsContentSection(
            id: "investor_freistellung",
            title: "1. Freistellung des App-Betreibers",
            content: "Der Investor stellt den App-Betreiber von allen Ansprüchen Dritter frei, die durch eine missbräuchliche oder gesetzeswidrige Nutzung seines Accounts entstehen.",
            icon: "shield"
        ),
        TermsContentSection(
            id: "investor_regulatorisch",
            title: "2. Regulatorischer Vorbehalt (Sperrklausel)",
            content: "Der App-Betreiber behält sich das Recht vor, das Konto des Investors ohne Angabe von Gründen temporär oder dauerhaft zu sperren, falls regulatorische Behörden dies fordern oder sich die Lizenzanforderungen ändern.",
            icon: "exclamationmark.shield"
        ),
        TermsContentSection(
            id: "investor_vertragsaenderung",
            title: "3. Recht auf einseitige Vertragsänderung",
            content: "Änderungen dieser Vereinbarung werden dem Investor mindestens vier Wochen im Voraus in der App angekündigt. Bei kritischen Updates blockiert die App das Platzieren neuer Investments, bis der Investor den geänderten Bedingungen aktiv zustimmt.",
            icon: "doc.badge.gearshape"
        ),
        TermsContentSection(
            id: "investor_mandat",
            title: "4. Erteilung des Verwaltungsmandats",
            content: "Der Investor bevollmächtigt die App, Kauf- und Verkaufsorders auf sein jeweils reserviertes Investment (Pool-Mirror-Volumen-Anteil) vollautomatisch und ohne vorherige Einzelfreigabe auszuführen, sobald ein vom Investor ausgewählter Trader (Signalgeber) eine Order ausführt.",
            icon: "signature"
        ),
        TermsContentSection(
            id: "investor_gebuehren",
            title: "5. Gebührenstruktur",
            content: "Volumengebühr: 1 % des reservierten Investmentvolumens (sofort pro Transaktion). Erfolgsgebühr: derzeit 10 % auf realisierte Gewinne.",
            icon: "eurosign.circle"
        ),
        TermsContentSection(
            id: "investor_latenz",
            title: "6. Technische Risikoaufklärung & Latenz",
            content: "Es kann aufgrund von Marktbedingungen, Liquiditätsengpässen und technischer Datenübertragung zu Verzögerungen (Slippage) kommen. Einstands- und Verkaufspreis können minimal vom Signalgeber abweichen.",
            icon: "clock.arrow.circlepath"
        ),
        TermsContentSection(
            id: "investor_schutz",
            title: "7. Risikomanagement & Instant-Opt-Out",
            content: "Der Investor kann reservierte Investments jederzeit stoppen. Bereits aktive Pool-Mirror-Beteiligungen können nicht gestoppt werden. Das Volumen kann auf bis zu 10 aufeinanderfolgende Trades verteilt werden.",
            icon: "hand.raised"
        ),
    ]
}
