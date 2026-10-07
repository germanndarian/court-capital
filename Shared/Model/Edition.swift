import Foundation

enum Region: String, Sendable {
    case us = "US"
    case eu = "EU"
    case ch = "CH"
}

struct Market: Identifiable, Sendable {
    enum Direction: Sendable {
        case up, down, flat
    }

    let name: String
    let value: String
    /// Percentage change, or a note such as "Yield" when there is nothing to compare.
    let change: String
    let direction: Direction

    var id: String { name }

    var changeLabel: String {
        switch direction {
        case .up: "▲ \(change)"
        case .down: "▼ \(change)"
        case .flat: change
        }
    }
}

struct Term: Identifiable, Sendable {
    let term: String
    let definition: String
    var id: String { term }
}

struct Source: Identifiable, Sendable {
    let name: String
    let url: URL
    var id: String { name }
}

/// A run of body copy. Asides are the inline plain-English explanations, set in italic.
enum BodyRun: Sendable {
    case text(String)
    case aside(String)

    var string: String {
        switch self {
        case .text(let string), .aside(let string): string
        }
    }
}

/// The full write-up behind a headline. Stories without one show where feed content lands.
struct StoryContent: Sendable {
    let whosWho: [Term]
    let body: [BodyRun]
    let whyItMatters: String
    let plainWords: String
    let sources: [Source]
}

struct Story: Identifiable, Sendable {
    let id: String
    let title: String
    let region: Region
    let readMinutes: Int
    var content: StoryContent?
}

struct EditionSection: Identifiable, Sendable {
    let numeral: String
    let name: String
    let stories: [Story]
    var id: String { name }

    var kicker: String { "\(numeral). \(name)" }
}

struct Edition: Sendable {
    let date: Date
    let bigStory: String
    let bigStoryID: Story.ID
    let marketsNote: String
    let markets: [Market]
    /// The four markets shown on the medium widget.
    let widgetMarketNames: [String]
    let sections: [EditionSection]
    let readMinutes: Int

    var number: Int { EditionCalendar.editionNumber(for: date) }
    var volume: Int { EditionCalendar.volume(for: date) }
    var storyCount: Int { sections.reduce(0) { $0 + $1.stories.count } }

    var widgetMarkets: [Market] {
        widgetMarketNames.compactMap { name in markets.first { $0.name == name } }
    }

    func story(id: Story.ID) -> Story? {
        sections.lazy.flatMap(\.stories).first { $0.id == id }
    }

    func section(containing id: Story.ID) -> EditionSection? {
        sections.first { $0.stories.contains { $0.id == id } }
    }
}
