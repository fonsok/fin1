import Foundation

// MARK: - Year Group
/// Groups weeks by year for trader performance display
struct YearGroup: Identifiable {
    let id: String
    let year: Int
    let monthGroups: [MonthGroup]

    init(year: Int, monthGroups: [MonthGroup]) {
        self.id = "year-\(year)"
        self.year = year
        self.monthGroups = monthGroups
    }
}

// MARK: - Month Group
/// Groups weeks by month within a year for trader performance display
struct MonthGroup: Identifiable {
    let id: String
    let month: String
    let weeks: [WeekTradeData]

    init(month: String, weeks: [WeekTradeData]) {
        self.id = "\(month)-\(UUID().uuidString)"
        self.month = month
        self.weeks = weeks
    }
}











