import Foundation

// MARK: - Emittent (Issuer) from WKN
/// Shared mapping from WKN/ISIN prefix to issuer (Emittent) name.
/// Used for invoices, collection bills, and trade statements to show the real issuer instead of placeholders.
extension String {

    /// Returns the issuer (Emittent) display name for a given WKN/ISIN.
    /// Uses the first 2 characters as issuer code (e.g. VO → Vontobel).
    static func emittentName(forWKN wkn: String) -> String {
        guard !wkn.isEmpty else { return "Unknown" }
        let code = String(wkn.prefix(2))
        switch code {
        case "SG": return "Société Générale"
        case "DB": return "Deutsche Bank"
        case "VT": return "Volksbank"
        case "DZ": return "DZ Bank"
        case "BN": return "BNP Paribas"
        case "CI": return "Citigroup"
        case "GS": return "Goldman Sachs"
        case "HS": return "HSBC"
        case "JP": return "J.P. Morgan"
        case "MS": return "Morgan Stanley"
        case "UB": return "UBS"
        case "VO": return "Vontobel"
        default:
            let prefix4 = String(wkn.prefix(4))
            switch prefix4 {
            case "AAPL", "TSLA", "MSFT", "GOOGL": return "US Stock"
            case "BMW", "DAX": return "German Stock"
            default: return "Unknown"
            }
        }
    }
}
