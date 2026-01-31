import Foundation

extension String {
    /// Returns the security description without issuer prefix, in the form "Typ - Basiswert"
    /// Example: "SG-Call - Apple" -> "Call - Apple"
    var formattedBezeichnung: String {
        let parts = self.split(separator: " - ").map(String.init)
        if parts.count > 2 {
            return parts.dropFirst().joined(separator: " - ")
        }
        return self
    }
}
