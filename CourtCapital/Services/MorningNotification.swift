import UserNotifications

/// The weekday morning notification. Scheduled locally for now; once the edition feed exists,
/// a push carrying the day's Big Story should replace it.
enum MorningNotification {
    private static let weekdays = 2...6 // Monday to Friday in the Gregorian calendar
    private static func identifier(_ weekday: Int) -> String { "morning-edition-\(weekday)" }

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func schedule(minutesAfterMidnight minutes: Int) async {
        let center = UNUserNotificationCenter.current()
        cancel()
        for weekday in weekdays {
            let content = UNMutableNotificationContent()
            content.title = "Court & Capital"
            content.body = "This morning’s edition is on the tray."
            content.threadIdentifier = "morning-edition"
            var components = DateComponents()
            components.weekday = weekday
            components.hour = minutes / 60
            components.minute = minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: identifier(weekday), content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: weekdays.map(identifier))
    }
}
