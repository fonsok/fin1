import Foundation

// MARK: - Date Extension for Parse Server
extension Date {
    /// ISO8601 string representation for Parse Server queries
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
