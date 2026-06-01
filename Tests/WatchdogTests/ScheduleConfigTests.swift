import XCTest
@testable import Watchdog

final class ScheduleConfigTests: XCTestCase {

    /// A fixed UTC calendar so weekday/hour components are deterministic regardless of
    /// the machine's timezone.
    private let utc: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// Build a UTC date for a known weekday. 2024-01-01 is a Monday.
    private func date(year: Int = 2024, month: Int = 1, day: Int, hour: Int, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        return utc.date(from: comps)!
    }

    func testDisabledScheduleIsAlwaysActive() {
        var config = ScheduleConfig()
        config.isEnabled = false
        XCTAssertTrue(config.isCurrentlyActive())
    }

    func testSameDayWindowActiveInsideRange() {
        // Active 9 AM–5 PM, all weekdays. Monday 1 PM should be active.
        var config = ScheduleConfig()
        config.isEnabled = true
        config.startHour = 9
        config.endHour = 17
        config.activeWeekdays = Set(Weekday.allCases)

        XCTAssertTrue(config.isCurrentlyActive(now: date(day: 1, hour: 13), calendar: utc))   // Mon 1 PM
        XCTAssertFalse(config.isCurrentlyActive(now: date(day: 1, hour: 8), calendar: utc))   // Mon 8 AM
        XCTAssertFalse(config.isCurrentlyActive(now: date(day: 1, hour: 17), calendar: utc))  // exclusive end
    }

    func testOvernightWindowSpansMidnight() {
        // Active 9 PM–7 AM, all weekdays.
        var config = ScheduleConfig()
        config.isEnabled = true
        config.startHour = 21
        config.endHour = 7
        config.activeWeekdays = Set(Weekday.allCases)

        XCTAssertTrue(config.isCurrentlyActive(now: date(day: 1, hour: 23), calendar: utc))  // Mon 11 PM (evening)
        XCTAssertTrue(config.isCurrentlyActive(now: date(day: 2, hour: 3), calendar: utc))   // Tue 3 AM (morning-after)
        XCTAssertFalse(config.isCurrentlyActive(now: date(day: 1, hour: 12), calendar: utc)) // Mon noon (outside)
        XCTAssertFalse(config.isCurrentlyActive(now: date(day: 2, hour: 7), calendar: utc))  // exclusive end
    }

    func testOvernightMorningChecksPreviousDayWeekday() {
        // Active only on Mondays, 9 PM–7 AM. Tuesday 3 AM belongs to Monday's window.
        var config = ScheduleConfig()
        config.isEnabled = true
        config.startHour = 21
        config.endHour = 7
        config.activeWeekdays = [.monday]

        XCTAssertTrue(config.isCurrentlyActive(now: date(day: 2, hour: 3), calendar: utc))   // Tue 3 AM → Mon window
        XCTAssertFalse(config.isCurrentlyActive(now: date(day: 3, hour: 3), calendar: utc))  // Wed 3 AM → Tue window (inactive)
    }

    func testSameDayWindowRespectsWeekday() {
        // Active only Tuesdays, 9 AM–5 PM.
        var config = ScheduleConfig()
        config.isEnabled = true
        config.startHour = 9
        config.endHour = 17
        config.activeWeekdays = [.tuesday]

        XCTAssertFalse(config.isCurrentlyActive(now: date(day: 1, hour: 13), calendar: utc)) // Mon → inactive
        XCTAssertTrue(config.isCurrentlyActive(now: date(day: 2, hour: 13), calendar: utc))  // Tue → active
    }

    func testEmptyWeekdaysNeverActiveWhenEnabled() {
        var config = ScheduleConfig()
        config.isEnabled = true
        config.startHour = 0
        config.endHour = 23
        config.activeWeekdays = []
        XCTAssertFalse(config.isCurrentlyActive(now: date(day: 1, hour: 12), calendar: utc))
    }

    func testOvernightWindowEncodesAndDecodes() throws {
        var config = ScheduleConfig()
        config.isEnabled = true
        config.startHour = 21
        config.endHour = 7
        config.activeWeekdays = [.monday, .friday]

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ScheduleConfig.self, from: data)

        XCTAssertEqual(decoded, config)
        XCTAssertEqual(decoded.startHour, 21)
        XCTAssertEqual(decoded.endHour, 7)
        XCTAssertEqual(decoded.activeWeekdays, [.monday, .friday])
    }

    func testFormattedTimeRange() {
        var config = ScheduleConfig()
        config.startHour = 21
        config.startMinute = 0
        config.endHour = 7
        config.endMinute = 30
        XCTAssertEqual(config.formattedTimeRange, "9 PM – 7:30 AM")
    }

    func testFormattedTimeRangeMidnightAndNoon() {
        var config = ScheduleConfig()
        config.startHour = 0
        config.startMinute = 0
        config.endHour = 12
        config.endMinute = 0
        XCTAssertEqual(config.formattedTimeRange, "12 AM – 12 PM")
    }

    func testWeekdayRawValuesMatchCalendarComponent() {
        // Calendar.component(.weekday) is 1...7 with Sunday = 1.
        XCTAssertEqual(Weekday.sunday.rawValue, 1)
        XCTAssertEqual(Weekday.saturday.rawValue, 7)
        XCTAssertEqual(Weekday(rawValue: 4), .wednesday)
    }
}
