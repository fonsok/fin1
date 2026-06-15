import Foundation

// MARK: - Trader monetary server-only (symmetric to investor GoB policy)

enum TraderMonetaryMessages {
    static let accountStatementUnavailable =
        "Kontoauszug konnte nicht vom Server geladen werden. Lokale Rechnungen werden nicht angezeigt."

    static let belegDetailUnavailable =
        "Strukturierte Belegdaten konnten nicht vom Server geladen werden. "
            + "Lokale Rechnungssynthese ist deaktiviert (Server-only)."
}

extension ConfigurationServiceProtocol {
    /// Investor paths: global readonly OR investor-specific server-only.
    var investorStatementServerOnly: Bool {
        self.frontendReadonlyMode || self.investorMonetaryServerOnly
    }

    /// Trader paths: global readonly OR trader-specific server-only.
    var traderStatementServerOnly: Bool {
        self.frontendReadonlyMode || self.traderMonetaryServerOnly
    }

    /// Blocks `InvoiceFactory` / `TradingNotificationService` local document generation.
    var blocksLocalInvoiceGeneration: Bool {
        self.traderStatementServerOnly
    }
}
