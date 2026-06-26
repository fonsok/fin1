import Foundation

/// Tracks which legal document versions each user explicitly acknowledged on this app install.
/// Server-side consent can survive across devices; this store ensures each user still confirms
/// AGB/DSE on this device (and `recordLegalConsent` runs) before using the app.
enum DeviceLegalConsentStore {
    private static let prefix = "FIN1.deviceLegalConsent"

    static func hasAcknowledged(user: User, consentType: String, version: String) -> Bool {
        self.candidateUserKeys(for: user).contains { userKey in
            self.hasAcknowledged(userKey: userKey, consentType: consentType, version: version)
        }
    }

    static func hasAcknowledgedBoth(user: User, termsVersion: String, privacyVersion: String) -> Bool {
        self.hasAcknowledged(user: user, consentType: "terms_of_service", version: termsVersion)
            && self.hasAcknowledged(user: user, consentType: "privacy_policy", version: privacyVersion)
    }

    static func markAcknowledged(user: User, consentType: String, version: String) {
        for userKey in self.candidateUserKeys(for: user) {
            self.markAcknowledged(userKey: userKey, consentType: consentType, version: version)
        }
    }

    /// Mirror server-side LegalConsent rows for this install (re-login / local store loss).
    static func syncAcknowledgementsFromServer(
        user: User,
        parseAPIClient: any ParseAPIClientProtocol
    ) async {
        struct Acknowledgement: Codable {
            let consentType: String
            let version: String
        }

        struct Response: Codable {
            let acknowledgements: [Acknowledgement]
        }

        guard let response: Response = try? await parseAPIClient.callFunction(
            "getDeviceLegalConsentAcknowledgements",
            parameters: ["deviceInstallId": DeviceInstallIdProvider.getOrCreate()]
        ) else {
            return
        }

        for acknowledgement in response.acknowledgements {
            self.markAcknowledged(
                user: user,
                consentType: acknowledgement.consentType,
                version: acknowledgement.version
            )
        }
    }

    /// After onboarding/sign-up the server already recorded consent; mirror locally for this user on this install.
    static func markAcknowledgedFromUser(_ user: User) {
        if let version = user.acceptedTermsVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !version.isEmpty,
           user.acceptedTerms {
            self.markAcknowledged(user: user, consentType: "terms_of_service", version: version)
        }
        if let version = user.acceptedPrivacyPolicyVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !version.isEmpty,
           user.acceptedPrivacyPolicy {
            self.markAcknowledged(user: user, consentType: "privacy_policy", version: version)
        }
    }

    /// Marks device acknowledgement for the active document versions shown in the legal gate.
    static func markAcknowledgedForActiveDocuments(
        user: User,
        termsVersion: String,
        privacyVersion: String
    ) {
        if user.acceptedTerms {
            self.markAcknowledged(user: user, consentType: "terms_of_service", version: termsVersion)
        }
        if user.acceptedPrivacyPolicy {
            self.markAcknowledged(user: user, consentType: "privacy_policy", version: privacyVersion)
        }
    }

    // MARK: - Private

    private static func hasAcknowledged(userKey: String, consentType: String, version: String) -> Bool {
        guard let key = self.storageKey(userKey: userKey, consentType: consentType, version: version) else {
            return false
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func markAcknowledged(userKey: String, consentType: String, version: String) {
        guard let key = self.storageKey(userKey: userKey, consentType: consentType, version: version) else {
            return
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    /// Email is the stable install-scoped identity; Parse `objectId` and legacy test ids are aliases.
    private static func candidateUserKeys(for user: User) -> [String] {
        var keys: [String] = []
        func append(_ raw: String) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !keys.contains(trimmed) else { return }
            keys.append(trimmed)
        }

        let email = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !email.isEmpty {
            append(email)
            append(UserFactory.stableUserId(for: email))
        }
        append(user.id)
        return keys
    }

    private static func storageKey(userKey: String, consentType: String, version: String) -> String? {
        let uid = userKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = consentType.trimmingCharacters(in: .whitespacesAndNewlines)
        let ver = version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty, !type.isEmpty, !ver.isEmpty else { return nil }

        let installId = DeviceInstallIdProvider.getOrCreate()
        return "\(self.prefix).\(installId).\(uid).\(type).\(ver)"
    }
}
