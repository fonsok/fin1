import Foundation

// MARK: - Authentication Notification Names
extension Notification.Name {
    static let userDidSignIn = Notification.Name("userDidSignIn")
    static let userDidSignOut = Notification.Name("userDidSignOut")
    static let userDataDidUpdate = Notification.Name("userDataDidUpdate")
    /// Posted when blocking legal consent modal completed (AGB + DSE on this device).
    static let legalConsentAcceptanceCompleted = Notification.Name("legalConsentAcceptanceCompleted")
    /// Posted when BackendHealthMonitor transitions from unhealthy → healthy.
    static let backendBecameHealthy = Notification.Name("backendBecameHealthy")
}
