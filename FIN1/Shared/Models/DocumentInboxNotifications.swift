import Foundation

extension Notification.Name {
    /// Posted after backend settlement or investment completion; inbox should refresh (force).
    static let userDocumentInboxShouldRefresh = Notification.Name("userDocumentInboxShouldRefresh")
}
