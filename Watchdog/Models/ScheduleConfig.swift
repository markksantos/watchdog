import Foundation

enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

struct ScheduleConfig: Codable, Equatable {
    var isEnabled: Bool = false
    var startHour: Int = 21    // 9 PM
    var startMinute: Int = 0
    var endHour: Int = 7       // 7 AM
    var endMinute: Int = 0
    var activeWeekdays: Set<Weekday> = Set(Weekday.allCases)

    /// Returns true if the current time falls within the configured schedule window.
    /// Supports overnight windows (e.g., 9 PM to 7 AM).
    func isCurrentlyActive() -> Bool {
        guard isEnabled else { return true } // If scheduling disabled, always active

        let calendar = Calendar.current
        let now = Date()

        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTime = currentHour * 60 + currentMinute
        let startTime = startHour * 60 + startMinute
        let endTime = endHour * 60 + endMinute

        let weekdayComponent = calendar.component(.weekday, from: now)

        if startTime <= endTime {
            // Same-day window (e.g., 9 AM to 5 PM) — check today's weekday
            guard let currentWeekday = Weekday(rawValue: weekdayComponent),
                  activeWeekdays.contains(currentWeekday) else {
                return false
            }
            return currentTime >= startTime && currentTime < endTime
        } else {
            // Overnight window (e.g., 9 PM to 7 AM)
            if currentTime >= startTime {
                // Evening portion — check today's weekday
                guard let currentWeekday = Weekday(rawValue: weekdayComponent),
                      activeWeekdays.contains(currentWeekday) else {
                    return false
                }
                return true
            } else if currentTime < endTime {
                // Morning-after portion — check previous day's weekday
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
                let yesterdayWeekdayComponent = calendar.component(.weekday, from: yesterday)
                guard let yesterdayWeekday = Weekday(rawValue: yesterdayWeekdayComponent),
                      activeWeekdays.contains(yesterdayWeekday) else {
                    return false
                }
                return true
            } else {
                return false
            }
        }
    }

    var formattedTimeRange: String {
        let startFormatted = formatTime(hour: startHour, minute: startMinute)
        let endFormatted = formatTime(hour: endHour, minute: endMinute)
        return "\(startFormatted) – \(endFormatted)"
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        if minute == 0 {
            return "\(displayHour) \(period)"
        }
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}
