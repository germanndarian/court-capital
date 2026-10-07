import Observation
import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case today, archive, settings

    var title: String {
        switch self {
        case .today: "Today"
        case .archive: "Archive"
        case .settings: "Settings"
        }
    }
}

/// Where a deep link asks the Today screen to scroll.
enum TodayAnchor: Hashable {
    case markets
}

struct StoryRoute: Hashable {
    let id: Story.ID
}

@MainActor
@Observable
final class AppModel {
    var tab: AppTab = .today
    var todayPath: [StoryRoute] = []
    var pendingAnchor: TodayAnchor?

    let edition = SampleEdition.edition
    let archive: Archive

    init() {
        archive = Archive(current: edition)
    }

    var isReadingStory: Bool { tab == .today && !todayPath.isEmpty }

    func open(_ id: Story.ID) {
        tab = .today
        todayPath = [StoryRoute(id: id)]
    }

    func showToday(anchor: TodayAnchor? = nil) {
        tab = .today
        todayPath = []
        pendingAnchor = anchor
    }

    /// `courtcapital://today`, `courtcapital://today/markets`, `courtcapital://story/<id>`.
    func handle(_ url: URL) {
        guard url.scheme == "courtcapital" else { return }
        switch url.host() {
        case "story":
            if let id = url.pathComponents.dropFirst().first, edition.story(id: id) != nil {
                open(id)
            } else {
                showToday()
            }
        default:
            showToday(anchor: url.pathComponents.contains("markets") ? .markets : nil)
        }
    }
}
