import Foundation

enum ISO8601DisplayDateFormatter {
    static func formattedDateOrNil(from iso: String) -> String? {
        let date: Date? = {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return isoFormatter.date(from: iso)
        }() ?? {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            return isoFormatter.date(from: iso)
        }()

        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

