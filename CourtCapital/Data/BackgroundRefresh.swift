import BackgroundTasks
import Foundation

/// Asks iOS to wake the app shortly after the edition is ready, so it's already downloaded
/// when you open it. iOS decides the exact time, based on how often you use the app.
enum BackgroundRefresh {
    static let identifier = "com.germanndarian.courtcapital.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = EditionCalendar.nextReady(after: .now).addingTimeInterval(10 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
