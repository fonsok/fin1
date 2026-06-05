import Foundation

extension Investment {
    /// Gespeicherter Parse-`username` (falls beim Anlegen gesetzt).
    var storedTraderUsername: String {
        (self.traderUsername ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Anzeige-Zeile für Trader: gespeicherter Username → optional Live-Lookup → Anzeigename.
    func displayTraderUsername(using traderDataService: (any TraderDataServiceProtocol)? = nil) -> String {
        if !self.storedTraderUsername.isEmpty { return self.storedTraderUsername }
        if let traderDataService,
           let trader = traderDataService.getTrader(by: self.traderId) {
            let live = trader.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !live.isEmpty { return live }
        }
        let name = self.traderName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "—" : name
    }
}
