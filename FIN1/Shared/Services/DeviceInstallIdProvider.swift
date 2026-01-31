import Foundation

/// Provides a stable, pseudonymous install identifier for audit logs.
/// - Note: Stored in `UserDefaults` to keep dependencies minimal.
enum DeviceInstallIdProvider {
    private static let key = "FIN1.DeviceInstallId"

    static func getOrCreate() -> String {
        if let existing = UserDefaults.standard.string(forKey: key),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}

enum AppBuildInfo {
    static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    }

    static var buildNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""
    }

    /// Conservative platform tag for backend audit logs.
    static var platform: String {
        #if os(iOS)
        return "ios"
        #elseif os(macOS)
        return "macos"
        #else
        return "apple"
        #endif
    }
}

