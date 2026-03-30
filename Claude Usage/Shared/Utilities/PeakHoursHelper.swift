import Foundation

/// Determines whether the current time falls within Anthropic's peak hours.
/// Peak hours: weekdays (Mon–Fri), 5:00 AM – 11:00 AM Pacific Time.
/// During peak hours, the 5-hour session window depletes faster.
enum PeakHoursHelper {

    private static let peakStartHour = 5
    private static let peakEndHour = 11

    private static var pacificCalendar: Calendar? {
        guard let pacific = TimeZone(identifier: "America/Los_Angeles") else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pacific
        return calendar
    }

    /// Returns true if the current moment is within peak hours.
    static var isPeakHours: Bool {
        isPeakHours(at: Date())
    }

    /// Testable variant: returns true if the given date falls within peak hours.
    static func isPeakHours(at date: Date) -> Bool {
        guard let cal = pacificCalendar else { return false }
        let weekday = cal.component(.weekday, from: date)
        guard (2...6).contains(weekday) else { return false }
        let hour = cal.component(.hour, from: date)
        return (peakStartHour..<peakEndHour).contains(hour)
    }

    /// Returns the time interval until peak hours end (if currently peak),
    /// or until they start (if currently off-peak on a weekday or weekend).
    /// The associated Bool is true if we are currently in peak hours.
    static func countdown(at date: Date = Date()) -> (isPeak: Bool, timeRemaining: TimeInterval)? {
        guard let cal = pacificCalendar else { return nil }

        if isPeakHours(at: date) {
            // Currently peak — calculate time until 11:00 AM PT today
            guard let endToday = cal.nextDate(
                after: date,
                matching: DateComponents(hour: peakEndHour, minute: 0, second: 0),
                matchingPolicy: .nextTime,
                direction: .forward
            ) else { return nil }
            return (true, endToday.timeIntervalSince(date))
        } else {
            // Off-peak — find the next weekday 5:00 AM PT
            return (false, timeUntilNextPeak(from: date, calendar: cal))
        }
    }

    /// Formats a TimeInterval as "Xh Ym" or "Ym" if less than an hour.
    static func formatCountdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Returns the local end time (if peak) or local start time (if off-peak) formatted as "HH:mm".
    static func localTargetTime(at date: Date = Date()) -> String? {
        guard let cd = countdown(at: date) else { return nil }
        let target = date.addingTimeInterval(cd.timeRemaining)
        let formatter = DateFormatter()
        formatter.timeZone = .current  // user's local timezone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: target)
    }

    // MARK: - Private

    private static func timeUntilNextPeak(from date: Date, calendar cal: Calendar) -> TimeInterval {
        // Try today first if it's a weekday and before peak start
        let weekday = cal.component(.weekday, from: date)
        let hour = cal.component(.hour, from: date)

        if (2...6).contains(weekday) && hour < peakStartHour {
            // Today, peak hasn't started yet
            if let startToday = cal.nextDate(
                after: cal.startOfDay(for: date),
                matching: DateComponents(hour: peakStartHour, minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) {
                return startToday.timeIntervalSince(date)
            }
        }

        // Otherwise, find the next weekday
        var candidate = cal.startOfDay(for: date)
        for _ in 0..<7 {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate)!
            let wd = cal.component(.weekday, from: candidate)
            if (2...6).contains(wd) {
                if let nextStart = cal.date(bySettingHour: peakStartHour, minute: 0, second: 0, of: candidate) {
                    return nextStart.timeIntervalSince(date)
                }
            }
        }
        return 0
    }
}
