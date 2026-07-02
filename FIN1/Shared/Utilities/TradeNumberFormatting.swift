import Foundation

/// Central formatting for trader trade numbers (annual reset per calendar year, Europe/Berlin).
enum TradeNumberFormatting {
    static let berlinTimeZone = TimeZone(identifier: "Europe/Berlin")!

    /// Calendar year in Europe/Berlin for trade-number sequences.
    static func calendarYear(for date: Date = Date()) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = self.berlinTimeZone
        return calendar.component(.year, from: date)
    }

    /// User-facing trade reference, e.g. `2026-001`.
    static func display(number: Int, year: Int?) -> String {
        guard number > 0 else { return "" }
        let sequence = String(format: "%03d", number)
        if let year, year > 0 {
            return "\(year)-\(sequence)"
        }
        return sequence
    }

    /// Prefix label used in PDFs and lists, e.g. `Trade #2026-001`.
    static func labeled(number: Int, year: Int?) -> String {
        let value = self.display(number: number, year: year)
        guard !value.isEmpty else { return "" }
        return "Trade #\(value)"
    }

    /// Filename-safe token, e.g. `2026-001` (same as display).
    static func filenameToken(number: Int, year: Int?) -> String {
        self.display(number: number, year: year)
    }
}
