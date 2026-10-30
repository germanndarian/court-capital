import Foundation
import Observation

// MARK: - A saved story

/// A story you bookmarked, with its own copy of what the story page shows.
///
/// A story's id ("2-1") is only its position in the edition, worked out by the app, so it
/// shifts whenever the Notion page is edited, and the edition itself can be replaced or
/// dropped from the cache. A saved story is therefore identified by the edition's date and
/// its headline, never by the id (kept only as a hint), and carries a copy of the text so it
/// can still be opened when the edition is gone. Saved stories are kept on the iPhone only:
/// the app never writes to Notion.
struct SavedStory: Codable, Sendable, Hashable, Identifiable {
    /// YYYY-MM-DD, the edition it was saved from.
    var editionDate: String
    /// The id the edition gave the story when it was saved. A hint, nothing more.
    var storyID: Story.ID
    /// "II. Finance"
    var sectionKicker: String
    var savedAt: Date
    /// Everything the story page shows.
    var story: EditionDocument.StoryDocument

    var id: String { Self.key(editionDate: editionDate, headline: story.headline) }
    var headline: String { story.headline }
    var day: Date { EditionCalendar.date(from: editionDate) ?? .now }

    /// A story is the same story when it has the same edition date and the same headline,
    /// ignoring spaces around the headline.
    static func key(editionDate: String, headline: String) -> String {
        "\(editionDate)/\(headline.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    init(editionDate: String, storyID: Story.ID, sectionKicker: String, savedAt: Date = .now, story: EditionDocument.StoryDocument) {
        self.editionDate = editionDate
        self.storyID = storyID
        self.sectionKicker = sectionKicker
        self.savedAt = savedAt
        self.story = story
    }

    /// Takes a copy of a story as the edition shows it now.
    init(_ story: Story, editionDate: String, sectionKicker: String, savedAt: Date = .now) {
        self.init(editionDate: editionDate, storyID: story.id, sectionKicker: sectionKicker, savedAt: savedAt, story: .init(story))
    }

    /// The story to open: the live one, when the edition on the iPhone still has a story with
    /// this headline (fresh text, and the id it has today), otherwise the stored copy. It never
    /// falls back to whichever story now has the old id.
    func resolve(in edition: Edition?) -> PlacedStory {
        if let edition, edition.date == editionDate {
            let matches = edition.sections.flatMap { section in section.stories.map { (section: section, story: $0) } }
                .filter { Self.key(editionDate: edition.date, headline: $0.story.headline) == id }
            // Two stories can share a headline; the old id then tells them apart.
            if let match = matches.first(where: { $0.story.id == storyID }) ?? matches.first {
                return PlacedStory(match.story, in: edition, section: match.section)
            }
        }
        return PlacedStory(copy: self)
    }
}

extension SavedStory {
    /// Fields added later decode with their defaults, so an older saved.json still opens.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        editionDate = try container.decode(String.self, forKey: .editionDate)
        story = try container.decode(EditionDocument.StoryDocument.self, forKey: .story)
        storyID = try container.decodeIfPresent(String.self, forKey: .storyID) ?? ""
        sectionKicker = try container.decodeIfPresent(String.self, forKey: .sectionKicker) ?? ""
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? .distantPast
    }
}

// MARK: - Copying a story

extension EditionDocument.StoryDocument {
    /// The story as the edition's JSON would hold it. Who's who goes back to its
    /// "Name = what it is · Name = …" line.
    init(_ story: Story) {
        self.init(
            headline: story.headline,
            region: story.region.raw,
            whosWho: story.whosWho.isEmpty ? nil : Term.line(story.whosWho),
            body: story.body,
            whyItMatters: story.whyItMatters,
            inPlainWords: story.plainWords,
            sources: story.sources
        )
    }
}

extension Term {
    /// "SEC = US stock-market regulator · Fed = US central bank", the form `parse` reads.
    static func line(_ terms: [Term]) -> String {
        terms.map { $0.description.isEmpty ? $0.name : "\($0.name) = \($0.description)" }.joined(separator: " · ")
    }
}

private extension Region {
    /// The region as written in the edition, so a region the app doesn't know keeps its case.
    var raw: String {
        if case .other(let raw) = self { raw } else { code }
    }
}

// MARK: - A story placed in an edition

/// A story with where it sits: what the story page needs besides the story itself.
struct PlacedStory: Sendable, Hashable {
    let story: Story
    /// YYYY-MM-DD
    let editionDate: String
    /// "II. Finance"
    let sectionKicker: String
    let number: Int
    /// Whether `story.id` is the id the edition on the iPhone gives this story. It isn't for the
    /// stored copy of a saved story whose edition is gone or has changed: that id is only the
    /// position the story had when it was saved, so the Docket, which follows stories by
    /// edition date and id, must not be asked about it.
    let isLive: Bool

    var day: Date { EditionCalendar.date(from: editionDate) ?? .now }

    /// A story as the edition on the iPhone has it.
    init(_ story: Story, in edition: Edition, section: EditionSection? = nil) {
        self.story = story
        editionDate = edition.date
        sectionKicker = (section ?? edition.section(containing: story.id))?.kicker ?? ""
        number = edition.number
        isLive = true
    }

    /// The stored copy of a saved story.
    init(copy saved: SavedStory) {
        story = Story(document: saved.story, id: saved.storyID)
        editionDate = saved.editionDate
        sectionKicker = saved.sectionKicker
        number = EditionCalendar.editionNumber(for: saved.editionDate)
        isLive = false
    }

    /// This story as it would be kept on the shelf.
    func saved(at date: Date = .now) -> SavedStory {
        SavedStory(story, editionDate: editionDate, sectionKicker: sectionKicker, savedAt: date)
    }
}

// MARK: - The shelf

/// Your saved stories, newest saved first. They live in `saved.json` in Application Support,
/// apart from the edition cache, because the cache is rebuilt whenever it can't be opened and
/// editions are dropped when their Notion page is deleted.
@MainActor
@Observable
final class SavedStore {
    /// Newest saved first.
    private(set) var stories: [SavedStory] = []
    private let url: URL?

    nonisolated static let defaultURL = URL.applicationSupportDirectory.appending(path: "saved.json")

    /// `url: nil` keeps the shelf in memory only, for tests.
    init(url: URL? = SavedStore.defaultURL) {
        self.url = url
        load()
    }

    // MARK: Reading

    var count: Int { stories.count }

    /// Whether the edition's story with this headline is on the shelf. The story's id plays no
    /// part, so this stays right when the Notion page is edited and the ids shift.
    func isSaved(_ story: Story, on editionDate: String) -> Bool {
        isSaved(editionDate: editionDate, headline: story.headline)
    }

    func isSaved(editionDate: String, headline: String) -> Bool {
        let key = SavedStory.key(editionDate: editionDate, headline: headline)
        return stories.contains { $0.id == key }
    }

    // MARK: Changing

    /// Puts the story at the top of the shelf. Saving one that's already there changes nothing,
    /// not even its place.
    func save(_ story: SavedStory) {
        guard !stories.contains(where: { $0.id == story.id }) else { return }
        stories.insert(story, at: 0)
        persist()
    }

    func remove(_ story: SavedStory) {
        remove(editionDate: story.editionDate, headline: story.headline)
    }

    func remove(editionDate: String, headline: String) {
        let key = SavedStory.key(editionDate: editionDate, headline: headline)
        guard stories.contains(where: { $0.id == key }) else { return }
        stories.removeAll { $0.id == key }
        persist()
    }

    /// Saves the story, or takes it off the shelf if it's there. Returns whether it's saved now.
    @discardableResult
    func toggle(_ story: SavedStory) -> Bool {
        if isSaved(editionDate: story.editionDate, headline: story.headline) {
            remove(story)
            return false
        }
        save(story)
        return true
    }

    // MARK: Keeping

    private struct Shelf: Codable {
        var version = 1
        var stories: [SavedStory]

        init(stories: [SavedStory]) {
            self.stories = stories
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
            stories = try container.decode([SavedStory].self, forKey: .stories)
        }
    }

    /// Newest saved first, each story once. The sort keeps the file's order for stories saved
    /// at the same moment.
    private static func newestFirst(_ stories: [SavedStory]) -> [SavedStory] {
        var seen = Set<String>()
        return stories.enumerated()
            .sorted { a, b in a.element.savedAt != b.element.savedAt ? a.element.savedAt > b.element.savedAt : a.offset < b.offset }
            .map(\.element)
            .filter { seen.insert($0.id).inserted }
    }

    private func load() {
        // `path()` would give "Application%20Support", which no file system call finds.
        guard let url, FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            stories = Self.newestFirst(try decoder.decode(Shelf.self, from: Data(contentsOf: url)).stories)
        } catch {
            // Set the unreadable file aside rather than overwrite it with an empty shelf.
            let aside = url.deletingLastPathComponent().appending(path: "saved-unreadable-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: aside)
        }
    }

    private func persist() {
        guard let url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(Shelf(stories: stories)) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
