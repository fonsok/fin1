import Foundation

/// Tracks which legal document versions each user explicitly acknowledged on this app install.
/// Server-side consent can survive across devices; this store ensures each user still confirms
/// AGB/DSE on this device (and `recordLegalConsent` runs) before using the app.
enum DeviceLegalConsentStore {
    private static let prefix = "FIN1.deviceLegalConsent"

    static func hasAcknowledged(userId: String, consentType: String, version: String) -> Bool {
        guard let key = self.storageKey(userId: userId, consentType: consentType, version: version) else {
            return false
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func markAcknowledged(userId: String, consentType: String, version: String) {
        guard let key = self.storageKey(userId: userId, consentType: consentType, version: version) else {
            return
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    /// After onboarding/sign-up the server already recorded consent; mirror locally for this user on this install.
    static func markAcknowledgedFromUser(_ user: User) {
        let userId = user.id
        if let version = user.acceptedTermsVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !version.isEmpty,
           user.acceptedTerms {
            self.markAcknowledged(userId: userId, consentType: "terms_of_service", version: version)
        }
        if let version = user.acceptedPrivacyPolicyVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !version.isEmpty,
           user.acceptedPrivacyPolicy {
            self.markAcknowledged(userId: userId, consentType: "privacy_policy", version: version)
        }
    }

    private static func storageKey(userId: String, consentType: String, version: String) -> String? {
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = consentType.trimmingCharacters(in: .whitespacesAndNewlines)
        let ver = version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty, !type.isEmpty, !ver.isEmpty else { return nil }

        let installId = DeviceInstallIdProvider.getOrCreate()
        return "\(self.prefix).\(installId).\(uid).\(type).\(ver)"
    }
}
