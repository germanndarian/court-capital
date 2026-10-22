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

/// A story in a particular edition.
struct StoryRoute: Hashable {
    let editionDate: String
    let storyID: Story.ID
}

/// Screens pushed from the Archive tab.
enum ArchiveRoute: Hashable {
    case edition(String)
    case story(StoryRoute)
}

@MainActor
@Observable
final class AppModel {
    var tab: AppTab = .today
    var todayPath: [StoryRoute] = []
    var archivePath: [ArchiveRoute] = []
    var pendingAnchor: TodayAnchor?

    let store: EditionStore

    init(store: EditionStore) {
        self.store = store
    }

    /// The tab bar steps aside while a story is open.
    var isReadingStory: Bool {
        switch tab {
        case .today: !todayPath.isEmpty
        case .archive: if case .story = archivePath.last { true } else { false }
        case .settings: false
        }
    }

    func openToday(story id: Story.ID) {
        guard let latest = store.latest else { return }
        tab = .today
        todayPath = [StoryRoute(editionDate: latest.date, storyID: id)]
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
            if let id = url.pathComponents.dropFirst().first, store.latest?.story(id: id) != nil {
                openToday(story: id)
            } else {
                showToday()
            }
        default:
            showToday(anchor: url.pathComponents.contains("markets") ? .markets : nil)
        }
    }
}
