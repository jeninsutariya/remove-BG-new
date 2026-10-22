import XCTest
@testable import Stillness

final class StreakCalculatorTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testNoSessionsIsZero() {
        let summary = StreakCalculator.summary(activeDays: [], today: date(2026, 5, 10), calendar: calendar)
        XCTAssertEqual(summary, StreakSummary(current: 0, longest: 0))
    }

    func testConsecutiveDaysEndingToday() {
        let days = [date(2026, 5, 8), date(2026, 5, 9), date(2026, 5, 10)]
        let summary = StreakCalculator.summary(activeDays: days, today: date(2026, 5, 10), calendar: calendar)
        XCTAssertEqual(summary, StreakSummary(current: 3, longest: 3))
    }

    func testStreakSurvivesUntilEndOfToday() {
        let days = [date(2026, 5, 8), date(2026, 5, 9)]
        let summary = StreakCalculator.summary(activeDays: days, today: date(2026, 5, 10, hour: 23), calendar: calendar)
        XCTAssertEqual(summary.current, 2)
    }

    func testMissedDayResetsCurrentButKeepsLongest() {
        let days = [date(2026, 5, 1), date(2026, 5, 2), date(2026, 5, 3), date(2026, 5, 9)]
        let summary = StreakCalculator.summary(activeDays: days, today: date(2026, 5, 11), calendar: calendar)
        XCTAssertEqual(summary, StreakSummary(current: 0, longest: 3))
    }

    func testSeveralSessionsOnOneDayCountOnce() {
        let days = [date(2026, 5, 10, hour: 7), date(2026, 5, 10, hour: 13), date(2026, 5, 10, hour: 22)]
        let summary = StreakCalculator.summary(activeDays: days, today: date(2026, 5, 10), calendar: calendar)
        XCTAssertEqual(summary, StreakSummary(current: 1, longest: 1))
    }

    func testLateNightAndEarlyMorningAreDifferentDays() {
        let days = [date(2026, 5, 9, hour: 23), date(2026, 5, 10, hour: 0)]
        let summary = StreakCalculator.summary(activeDays: days, today: date(2026, 5, 10), calendar: calendar)
        XCTAssertEqual(summary.current, 2)
    }

    func testStreakAcrossDaylightSavingChange() {
        // Clocks in New York go forward on 8 March 2026.
        let days = [date(2026, 3, 7), date(2026, 3, 8), date(2026, 3, 9)]
        let summary = StreakCalculator.summary(activeDays: days, today: date(2026, 3, 9), calendar: calendar)
        XCTAssertEqual(summary, StreakSummary(current: 3, longest: 3))
    }
}
