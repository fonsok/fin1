import Foundation

// MARK: - Test User Constants
// Single source of truth for all debug/test user data.
// Used by MockAuthProvider, UserFactory, LandingDebugButtonsView, and seed scripts.

enum TestConstants {
    static let password = "TestPassword123!"

    static let investorNames: [(first: String, last: String, username: String)] = [
        ("Maximilian", "Fischer", "mfischer"),
        ("Sophie", "Müller", "smueller"),
        ("Oliver", "Schneider", "oschneider"),
        ("Emma", "Weber", "eweber"),
        ("David", "Braun", "dbraun"),
    ]

    static let traderNames: [(first: String, last: String, username: String)] = [
        ("Jan", "Becker", "jbecker"),
        ("Alexander", "Wolf", "awolf"),
        ("Lena", "Wagner", "lwagner"),
        ("Tobias", "Hoffmann", "thoffmann"),
        ("Julia", "Richter", "jrichter"),
        ("Markus", "Klein", "mklein"),
        ("Anna", "Lehmann", "alehmann"),
        ("Florian", "Schmitt", "fschmitt"),
        ("Laura", "Koch", "lkoch"),
        ("Niklas", "Hartmann", "nhartmann"),
    ]

    static let customerIdPrefixInvestor = "ANL"
    static let customerIdPrefixTrader = "TRD"

    static func investorDisplayName(for number: Int) -> String {
        let entry = self.investorNames[(number - 1) % self.investorNames.count]
        return "\(entry.first.prefix(1)). \(entry.last)"
    }

    static func traderDisplayName(for number: Int) -> String {
        let entry = self.traderNames[(number - 1) % self.traderNames.count]
        return "\(entry.first.prefix(1)). \(entry.last)"
    }
}
