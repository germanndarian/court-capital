import Foundation

/// A break from the edition, set in Settings for a number of days. While it lasts the app
/// stays quiet: no morning notification and no "running late" note.
///
/// The app only reads Notion, so it can't stop the Claude scheduled task: editions written
/// during a break still arrive and stay in the archive. To stop the task itself, pause it in
/// Claude.
enum EditionPause {
    static let maxDays = 60

    /// The last paused day (YYYY-MM-DD) for a break of `days` calendar days starting today.
    static func lastDay(forDays days: Int, from now: Date = .now) -> String {
        let calendar = EditionCalendar.calendar
        let today = calendar.startOfDay(for: now)
        let last = calendar.date(byAdding: .day, value: max(days, 1) - 1, to: today) ?? today
        return EditionCalendar.iso(last)
    }

    /// Whether `date` falls inside a break that runs through `lastDay`.
    static func isPaused(on date: Date = .now, through lastDay: String) -> Bool {
        guard !lastDay.isEmpty else { return false }
        return EditionCalendar.iso(date) <= lastDay
    }

    static func isPaused(day iso: String, through lastDay: String) -> Bool {
        !lastDay.isEmpty && iso <= lastDay
    }

    /// The first weekday after the break: when the edition is back.
    static func resumeDay(after lastDay: String) -> Date? {
        guard let last = EditionCalendar.date(from: lastDay) else { return nil }
        let calendar = EditionCalendar.calendar
        var day = calendar.date(byAdding: .day, value: 1, to: last)!
        while !EditionCalendar.isWeekday(day) {
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return day
    }

    /// "Editions paused until Monday, 2 November."
    static func note(through lastDay: String) -> String? {
        guard isPaused(through: lastDay), let resume = resumeDay(after: lastDay) else { return nil }
        return "Editions paused. Back \(EditionFormat.storyDate(resume))."
    }
}
