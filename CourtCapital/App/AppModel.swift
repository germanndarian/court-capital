import Observation
import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case today, docket, archive, settings

    var title: String {
        switch self {
        case .today: "Today"
        case .docket: "Docket"
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
    /// The Saved stories shelf.
    case saved
    /// A story from the shelf. It carries the saved story itself, so the page stays put when
    /// you take it off the shelf while reading.
    case savedStory(SavedStory)
}

/// Screens pushed from the Docket tab.
enum DocketRoute: Hashable {
    case file(TrackedFile.ID)
    case story(StoryRoute)
}

@MainActor
@Observable
final class AppModel {
    var tab: AppTab = .today
    var todayPath: [StoryRoute] = []
    var archivePath: [ArchiveRoute] = []
    var docketPath: [DocketRoute] = []
    var pendingAnchor: TodayAnchor?
    /// The file in the editor sheet.
    var draft: FileDraft?
    /// A short note that drops in from the top, such as "On your Docket".
    private(set) var toast: String?

    let store: EditionStore
    let docket: DocketStore
    let saved: SavedStore

    init(store: EditionStore, docket: DocketStore, saved: SavedStore) {
        self.store = store
        self.docket = docket
        self.saved = saved
    }

    /// The tab bar steps aside while a story is open.
    var isReadingStory: Bool {
        switch tab {
        case .today: !todayPath.isEmpty
        case .archive:
            switch archivePath.last {
            case .story, .savedStory: true
            default: false
            }
        case .docket: if case .story = docketPath.last { true } else { false }
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

    func openFile(_ id: TrackedFile.ID) {
        tab = .docket
        docketPath = [.file(id)]
    }

    /// Opens the editor on a new file for this story, its names already chosen.
    func follow(_ story: Story, in edition: Edition) {
        follow(story, editionDate: edition.date)
    }

    func follow(_ story: Story, editionDate: String) {
        draft = .new(from: story, editionDate: editionDate, seenThrough: docket.editionDates.first ?? editionDate)
    }

    /// Puts the story on the Saved shelf, or takes it off, and says which.
    func toggleSaved(_ story: SavedStory) {
        say(saved.toggle(story) ? "Saved" : "Removed from Saved")
    }

    func removeSaved(_ story: SavedStory) {
        saved.remove(story)
        say("Removed from Saved")
    }

    /// The toast, and the same words for VoiceOver, which doesn't read a toast by itself.
    private func say(_ message: String) {
        announce(message)
        AccessibilityNotification.Announcement(message).post()
    }

    func newFile() {
        draft = .new(from: nil, editionDate: nil, seenThrough: docket.editionDates.first ?? EditionCalendar.iso(.now))
    }

    func edit(_ file: TrackedFile) {
        draft = .editing(file)
    }

    func announce(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.8))
            if toast == message { toast = nil }
        }
    }

    /// `courtcapital://today`, `courtcapital://today/markets`, `courtcapital://story/<id>`,
    /// `courtcapital://docket`.
    func handle(_ url: URL) {
        guard url.scheme == "courtcapital" else { return }
        switch url.host() {
        case "docket":
            tab = .docket
            docketPath = []
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
