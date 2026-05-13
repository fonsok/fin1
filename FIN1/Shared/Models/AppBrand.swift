import Foundation

// MARK: - App Branding
/// Centralized app branding values for user-facing copy.
///
/// Notes:
/// - `CFBundleDisplayName` is the user-visible app name on the Home Screen.
/// - `CFBundleName` is the bundle name fallback.
/// - Keep **legal entity** names separate (e.g., `CompanyContactInfo.companyName`) to avoid
///   accidentally changing accounting/legal wording.
enum AppBrand {
    static var appName: String {
        if let displayName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !displayName.isEmpty {
            return displayName
        }

        if let bundleName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !bundleName.isEmpty {
            return bundleName
        }

        // Fallback for unusual runtime contexts (tests, previews, misconfigured Info.plist).
        return "FIN1"
    }
}

