import Foundation

struct StreakSummary: Equatable {
    var current: Int
    var longest: Int
}

enum StreakCalculator {
    /// Counts consecutive calendar days with at least one session.
    /// The current streak survives until the end of today, so a streak that ended yesterday still counts.
    static func summary(activeDays dates: [Date], today: Date = .now, calendar: Calendar = .current) -> StreakSummary {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return StreakSummary(current: 0, longest: 0) }

        let todayStart = calendar.startOfDay(for: today)
        var current = 0
        var cursor: Date? = nil
        if days.contains(todayStart) {
            cursor = todayStart
        } else if let yesterday = previousDay(before: todayStart, calendar: calendar), days.contains(yesterday) {
            cursor = yesterday
        }
        while let day = cursor, days.contains(day) {
            current += 1
            cursor = previousDay(before: day, calendar: calendar)
        }

        let sorted = days.sorted()
        var longest = 1
        var run = 1
        for index in sorted.indices.dropFirst() {
            if let next = calendar.date(byAdding: .day, value: 1, to: sorted[index - 1]),
               calendar.isDate(next, inSameDayAs: sorted[index]) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }

        return StreakSummary(current: current, longest: max(longest, current))
    }

    private static func previousDay(before day: Date, calendar: Calendar) -> Date? {
        calendar.date(byAdding: .day, value: -1, to: day).map { calendar.startOfDay(for: $0) }
    }
}
