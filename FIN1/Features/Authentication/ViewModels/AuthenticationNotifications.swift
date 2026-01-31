import Foundation

// MARK: - Authentication Notification Names
extension Notification.Name {
    static let userDidSignIn = Notification.Name("userDidSignIn")
    static let userDidSignOut = Notification.Name("userDidSignOut")
    static let userDataDidUpdate = Notification.Name("userDataDidUpdate")
}
