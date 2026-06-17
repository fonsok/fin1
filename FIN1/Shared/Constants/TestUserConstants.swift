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

    // MARK: - Sign-Up Flow Prefill (DEBUG manual testing)
    static let signupTestPhone = "+491771234567"
    static let signupTestStreet = "Musterstraße 123"
    static let signupTestPostalCode = "80331"
    static let signupTestCity = "München"
    static let signupTestState = "Bayern"
    static let signupTestCountry = "Deutschland"
    static let signupTestTaxNumber = "12345678901"

    /// Fixed OTP for DEBUG Get Started — accepted when server has
    /// `ALLOW_DEV_ONBOARDING_OTP_BYPASS=true` (iobox) or NODE_ENV≠production.
    static let devVerificationCode = "000000"

    /// Unique credentials for repeated Get Started runs (avoids duplicate-email errors).
    static func signupTestEmail() -> String {
        "signup+\(Int(Date().timeIntervalSince1970))@test.com"
    }

    /// 4–10 alphanumeric username for sign-up validation.
    static func signupTestUsername() -> String {
        let suffix = String(Int(Date().timeIntervalSince1970) % 10_000_000)
        return "su" + String(suffix.suffix(8))
    }

    static func investorDisplayName(for number: Int) -> String {
        let entry = self.investorNames[(number - 1) % self.investorNames.count]
        return "\(entry.first.prefix(1)). \(entry.last)"
    }

    static func traderDisplayName(for number: Int) -> String {
        let entry = self.traderNames[(number - 1) % self.traderNames.count]
        return "\(entry.first.prefix(1)). \(entry.last)"
    }
}
