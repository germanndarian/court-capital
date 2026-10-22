import Foundation
import UserNotifications

/// The weekday morning notification. It's a local notification, so it works on a free Apple
/// account; it fires at the set time whether or not the edition has landed. A push sent by
/// a server would need a paid developer account.
///
/// Each weekday is scheduled as its own notification, about eight weeks ahead, so the days of
/// a break can be left out. `refresh()` tops the schedule up whenever the app runs.
enum MorningNotification {
    private static let prefix = "morning-edition-"
    /// iOS keeps at most 64 pending notifications per app.
    private static let daysAhead = 40

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Reschedules from the saved settings: on or off, the time, and any break.
    static func refresh() async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Preferences.morningNotification) else {
            await cancel()
            return
        }
        let minutes = defaults.object(forKey: Preferences.deliveryMinutes) as? Int ?? Preferences.defaultDeliveryMinutes
        let pausedThrough = defaults.string(forKey: Preferences.pausedThrough) ?? ""
        await schedule(minutesAfterMidnight: minutes, pausedThrough: pausedThrough)
    }

    static func schedule(minutesAfterMidnight minutes: Int, pausedThrough: String, from now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        await cancel()
        for day in deliveryDays(minutesAfterMidnight: minutes, pausedThrough: pausedThrough, from: now) {
            let content = UNMutableNotificationContent()
            content.title = "Court & Capital"
            content.body = "Today’s edition is ready."
            content.threadIdentifier = "morning-edition"
            let components = EditionCalendar.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: day)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: prefix + EditionCalendar.iso(day), content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// The coming weekday delivery times, leaving out the days of a break.
    static func deliveryDays(minutesAfterMidnight minutes: Int, pausedThrough: String, from now: Date) -> [Date] {
        let calendar = EditionCalendar.calendar
        var day = calendar.startOfDay(for: now)
        var days: [Date] = []
        while days.count < daysAhead {
            if EditionCalendar.isWeekday(day), !EditionPause.isPaused(day: EditionCalendar.iso(day), through: pausedThrough),
               let delivery = calendar.date(bySettingHour: minutes / 60 % 24, minute: minutes % 60, second: 0, of: day),
               delivery > now {
                days.append(delivery)
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return days
    }

    static func cancel() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
    }
}
