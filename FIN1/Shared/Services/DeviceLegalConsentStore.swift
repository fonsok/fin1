import Foundation

/// Tracks which legal document versions were explicitly acknowledged on this app install.
/// Server-side user consent can survive across devices; this store ensures each fresh install
/// still presents AGB/DSE until the user confirms on this device (and `recordLegalConsent` runs).
enum DeviceLegalConsentStore {
    private static let prefix = "FIN1.deviceLegalConsent"

    static func hasAcknowledged(consentType: String, version: String) -> Bool {
        let key = self.storageKey(consentType: consentType, version: version)
        return UserDefaults.standard.bool(forKey: key)
    }

    static func markAcknowledged(consentType: String, version: String) {
        let key = self.storageKey(consentType: consentType, version: version)
        UserDefaults.standard.set(true, forKey: key)
    }

    /// After onboarding/sign-up the server already recorded consent; mirror locally for this install.
    static func markAcknowledgedFromUser(_ user: User) {
        if let version = user.acceptedTermsVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !version.isEmpty,
           user.acceptedTerms {
            self.markAcknowledged(consentType: "terms_of_service", version: version)
        }
        if let version = user.acceptedPrivacyPolicyVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !version.isEmpty,
           user.acceptedPrivacyPolicy {
            self.markAcknowledged(consentType: "privacy_policy", version: version)
        }
    }

    private static func storageKey(consentType: String, version: String) -> String {
        let installId = DeviceInstallIdProvider.getOrCreate()
        let type = consentType.trimmingCharacters(in: .whitespacesAndNewlines)
        let ver = version.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(self.prefix).\(installId).\(type).\(ver)"
    }
}
