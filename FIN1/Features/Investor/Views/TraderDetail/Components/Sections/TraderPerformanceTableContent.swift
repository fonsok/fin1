import SwiftUI

// MARK: - Table Content with Year and Month Grouping
/// Displays the main content of the trader performance table with year and month grouping
struct TraderPerformanceTableContent: View {
    let weeks: [WeekTradeData]
    let currentYear: Int

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ForEach(Array(groupedByYearAndMonth.enumerated()), id: \.element.id) { yearIndex, yearGroup in
                // Year separator row (if not the first year group and not current year)
                if yearIndex > 0 && yearGroup.year < currentYear {
                    YearSeparatorRow(year: yearGroup.year)
                }

                // Month groups within this year
                ForEach(yearGroup.monthGroups) { monthGroup in
                    monthGroupRow(monthGroup: monthGroup)
                }
            }
        }
        .frame(minWidth: UIScreen.main.bounds.width - ResponsiveDesign.spacing(32))
        .clipped()
    }

    // MARK: - Month Group Row
    private func monthGroupRow(monthGroup: MonthGroup) -> some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(0)) {
            // Month Label Column (spans all weeks in this month)
            monthLabelColumn(monthGroup: monthGroup)

            // Weeks Column with Returns (scrollable section)
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                ForEach(monthGroup.weeks) { weekData in
                    TraderPerformanceWeekRow(weekData: weekData, showMonthLabel: false)
                }
            }
        }
        .clipped()
    }

    // MARK: - Month Label Column
    private func monthLabelColumn(monthGroup: MonthGroup) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            Spacer()
            Text(monthGroup.month)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .rotationEffect(.degrees(-90))
                .fixedSize()
            Spacer()
        }
        .frame(width: ResponsiveDesign.spacing(50))
        .frame(height: calculateMonthHeight(weekCount: monthGroup.weeks.count))
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .clipped()
        .background(AppTheme.sectionBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Grouping Logic
    private var groupedByYearAndMonth: [YearGroup] {
        let yearGroups = Dictionary(grouping: weeks) { $0.year }

        return yearGroups.map { year, weeks in
            var monthGroups: [MonthGroup] = []
            var currentMonth: String?
            var currentWeeks: [WeekTradeData] = []

            for week in weeks.sorted(by: { $0.date > $1.date }) {
                if week.month != currentMonth {
                    if let month = currentMonth, !currentWeeks.isEmpty {
                        monthGroups.append(MonthGroup(month: month, weeks: currentWeeks))
                    }
                    currentMonth = week.month
                    currentWeeks = [week]
                } else {
                    currentWeeks.append(week)
                }
            }

            if let month = currentMonth, !currentWeeks.isEmpty {
                monthGroups.append(MonthGroup(month: month, weeks: currentWeeks))
            }

            return YearGroup(year: year, monthGroups: monthGroups)
        }
        .sorted { $0.year > $1.year }
    }

    // MARK: - Height Calculation
    private func calculateMonthHeight(weekCount: Int) -> CGFloat {
        let rowPadding = ResponsiveDesign.spacing(12) * 2
        let rowContent = ResponsiveDesign.spacing(20)
        let divider = CGFloat(1)
        let rowHeight = rowPadding + rowContent + divider
        return rowHeight * CGFloat(weekCount)
    }
}











