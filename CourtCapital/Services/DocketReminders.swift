import Foundation
import UserNotifications

/// A notification on the morning of a file's date to watch, at the edition's delivery time:
/// "Anthropic IPO: pricing." Local, like the morning notification, and only when
/// notifications are allowed.
enum DocketReminders {
    private static let prefix = "docket-"
    /// The morning notification keeps 40 of iOS's 64 pending slots.
    private static let limit = 20

    static func refresh(_ files: [TrackedFile], now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        let defaults = UserDefaults.standard
        let minutes = defaults.object(forKey: Preferences.deliveryMinutes) as? Int ?? Preferences.defaultDeliveryMinutes
        let calendar = EditionCalendar.calendar
        let reminders = files
            .filter { !$0.isClosed }
            .compactMap { file -> (file: TrackedFile, key: TrackedFile.KeyDate, at: Date)? in
                guard let key = file.keyDate, let day = EditionCalendar.date(from: key.date),
                      let at = calendar.date(bySettingHour: minutes / 60 % 24, minute: minutes % 60, second: 0, of: day),
                      at > now
                else { return nil }
                return (file, key, at)
            }
            .sorted { $0.at < $1.at }
            .prefix(limit)

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = "On your Docket today"
            let label = reminder.key.label.trimmingCharacters(in: .whitespaces)
            content.body = label.isEmpty ? "\(reminder.file.title): the date you were watching." : "\(reminder.file.title): \(label)."
            content.threadIdentifier = "docket"
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.at)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: prefix + reminder.file.id.uuidString, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
