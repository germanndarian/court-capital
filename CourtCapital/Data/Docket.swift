import Foundation
import Observation

// MARK: - A file on the docket

/// Something you follow over weeks: a merger in talks, an IPO, a case on its way to the
/// Supreme Court. A file is a few names or words; every story in the editions on the iPhone
/// that mentions them joins its record, earlier editions included. Files are kept on the
/// iPhone only: the app never writes to Notion.
struct TrackedFile: Codable, Sendable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var keywords: [String]
    var match = Match.all
    /// Only the words as typed. Off by default: the file also finds other wordings of the
    /// same topic ("listing" for an IPO) and the names the Who's who ties to it.
    var exactWords = false
    var cover = Cover.navy
    var note = ""
    var keyDate: KeyDate?
    var isPinned = false
    /// YYYY-MM-DD, the day the file was opened.
    var openedOn: String
    /// The story the file was opened from.
    var origin: Origin?
    /// Stories from editions after this date are new to you.
    var seenThrough: String
    /// YYYY-MM-DD. A closed case keeps its record but leaves Today and the tab bar.
    var closedOn: String?

    enum Match: String, Codable, Sendable, CaseIterable {
        /// Every word has to appear: "SpaceX" and "Tesla".
        case all
        /// One of them is enough.
        case any
    }

    /// The leather the file is bound in, from the archive shelf.
    enum Cover: String, Codable, Sendable, CaseIterable {
        case navy, green, burgundy
    }

    /// A day to look out for, counted down on the file: "Hearing", "IPO pricing".
    struct KeyDate: Codable, Sendable, Hashable {
        /// YYYY-MM-DD
        var date: String
        var label: String
    }

    struct Origin: Codable, Sendable, Hashable {
        var editionDate: String
        var headline: String
    }

    var isClosed: Bool { closedOn != nil }
}

extension TrackedFile {
    /// Fields added later decode with their defaults, so an older docket.json still opens.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        keywords = try container.decode([String].self, forKey: .keywords)
        match = (try? container.decodeIfPresent(Match.self, forKey: .match)) ?? .all
        exactWords = try container.decodeIfPresent(Bool.self, forKey: .exactWords) ?? false
        cover = (try? container.decodeIfPresent(Cover.self, forKey: .cover)) ?? .navy
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        keyDate = try? container.decodeIfPresent(KeyDate.self, forKey: .keyDate)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        openedOn = try container.decodeIfPresent(String.self, forKey: .openedOn) ?? EditionCalendar.iso(.now)
        origin = try? container.decodeIfPresent(Origin.self, forKey: .origin)
        seenThrough = try container.decodeIfPresent(String.self, forKey: .seenThrough) ?? openedOn
        closedOn = try container.decodeIfPresent(String.self, forKey: .closedOn)
    }
}

/// One story on a file's record.
struct DocketEntry: Sendable, Hashable, Identifiable {
    let editionDate: String
    /// "II. Finance"
    let sectionKicker: String
    let story: Story

    var id: String { DocketEntry.key(editionDate: editionDate, storyID: story.id) }
    var day: Date { EditionCalendar.date(from: editionDate) ?? .now }

    static func key(editionDate: String, storyID: Story.ID) -> String { "\(editionDate)/\(storyID)" }
}

/// How a file is doing in the news, from how recently an edition mentioned it.
enum Momentum: Sendable, Equatable {
    /// In the newest edition
    case latest
    /// Within the last five editions
    case developing
    /// Within the last fifteen
    case quiet
    case cold
    /// No edition has mentioned it yet.
    case awaiting

    var title: String {
        switch self {
        case .latest: "In the news"
        case .developing: "Developing"
        case .quiet: "Gone quiet"
        case .cold: "Gone cold"
        case .awaiting: "Awaiting news"
        }
    }

    static func of(latest editionDate: String?, editionDates: [String]) -> Momentum {
        guard let editionDate else { return .awaiting }
        return switch editionDates.firstIndex(of: editionDate) ?? editionDates.count {
        case 0: .latest
        case 1..<5: .developing
        case 5..<15: .quiet
        default: .cold
        }
    }
}

// MARK: - Matching stories

/// Decides which stories belong on a file. It ignores case and accents and counts whole
/// words only, so "Meta" finds "Meta’s" but not "metadata", and "IPO" also finds "IPOs".
enum DocketMatcher {
    /// A story's words, folded once so every file can search them quickly.
    static func searchText(_ story: Story) -> String {
        let parts = [story.headline, story.body, story.whyItMatters ?? ""]
            + story.whosWho.map { "\($0.name) \($0.description)" }
            + story.plainWords
        return fold(parts.joined(separator: " \n "))
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether folded `text` mentions the file's words: all of them, or any one.
    static func matches(_ text: String, keywords: [String], match: TrackedFile.Match) -> Bool {
        let words = keywords.map(fold).filter { !$0.isEmpty }
        guard !words.isEmpty else { return false }
        return switch match {
        case .all: words.allSatisfy { mentions(text, $0) }
        case .any: words.contains { mentions(text, $0) }
        }
    }

    /// Whether folded `text` matches the file's words as the matcher reads them.
    static func matches(_ text: String, queries: [TopicQuery], match: TrackedFile.Match) -> Bool {
        guard !queries.isEmpty else { return false }
        return switch match {
        case .all: queries.allSatisfy { $0.matches(text) }
        case .any: queries.contains { $0.matches(text) }
        }
    }

    /// Whether folded `word` appears in folded `text` as a whole word, or with a plural "s".
    static func mentions(_ text: String, _ word: String) -> Bool {
        var start = text.startIndex
        while start < text.endIndex, let range = text.range(of: word, range: start..<text.endIndex) {
            if startsWord(range.lowerBound, in: text, word: word), endsWord(range.upperBound, in: text, word: word) {
                return true
            }
            start = text.index(after: range.lowerBound)
        }
        return false
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    private static func startsWord(_ index: String.Index, in text: String, word: String) -> Bool {
        guard let first = word.first, isWordCharacter(first), index > text.startIndex else { return true }
        return !isWordCharacter(text[text.index(before: index)])
    }

    private static func endsWord(_ index: String.Index, in text: String, word: String) -> Bool {
        guard let last = word.last, isWordCharacter(last), index < text.endIndex else { return true }
        let next = text[index]
        if !isWordCharacter(next) { return true }
        // "IPOs", "SPACs"
        let afterPlural = text.index(after: index)
        return next == "s" && (afterPlural == text.endIndex || !isWordCharacter(text[afterPlural]))
    }
}

/// What the editor offers when you open a file on a story.
enum DocketSuggestions {
    /// The names in the story's Who's who, in order, split where one entry names several
    /// ("BlackRock, Vanguard, State Street"), without repeats.
    static func names(in story: Story) -> [String] {
        var seen = Set<String>()
        return story.whosWho
            .flatMap { split($0.name) }
            .filter { seen.insert(DocketMatcher.fold($0)).inserted }
    }

    /// One Who's who entry can name several: "Microsoft, Alphabet, Amazon".
    static func split(_ name: String) -> [String] {
        name.components(separatedBy: CharacterSet(charactersIn: ",/"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// The names the headline itself mentions, at most two: usually the parties to the
    /// story. If the headline names none of them, the first one. Then the first topic the
    /// headline is about, if it has one: "Anthropic" and "IPO".
    static func chosen(from names: [String], headline: String) -> [String] {
        let folded = DocketMatcher.fold(headline)
        let inHeadline = names.filter { DocketMatcher.mentions(folded, DocketMatcher.fold($0)) }
        let parties = inHeadline.isEmpty ? Array(names.prefix(1)) : Array(inHeadline.prefix(2))
        return parties + TopicLexicon.concepts(in: headline).prefix(1)
    }

    /// "SpaceX", "SpaceX & Tesla", "SpaceX, Tesla & xAI", and a topic after the names:
    /// "SpaceX & Tesla merger", "Anthropic IPO".
    static func title(for keywords: [String]) -> String {
        let words = keywords.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let topics = words.filter { TopicLexicon.concept(DocketMatcher.fold($0)) != nil }
        let names = Array(words.filter { TopicLexicon.concept(DocketMatcher.fold($0)) == nil }.prefix(3))
        let topic = topics.prefix(2).joined(separator: " ")
        guard let last = names.last else { return topic }
        let parties = names.count > 1 ? names.dropLast().joined(separator: ", ") + " & " + last : last
        return topic.isEmpty ? parties : parties + " " + topic
    }
}

/// A file being opened or edited in the editor sheet.
struct FileDraft: Identifiable, Sendable {
    let id = UUID()
    var file: TrackedFile
    /// Names offered as chips, from the story's Who's who.
    var suggestions: [String]
    let isNew: Bool

    /// A new file on a story: its names on offer, the parties chosen, and the title left
    /// empty so it follows the chosen names until you type your own.
    static func new(from story: Story?, editionDate: String?, seenThrough: String, today: String = EditionCalendar.iso(.now)) -> FileDraft {
        let names = story.map(DocketSuggestions.names(in:)) ?? []
        let topics = story.map { TopicLexicon.concepts(in: $0.headline) } ?? []
        let file = TrackedFile(
            title: "",
            keywords: story.map { DocketSuggestions.chosen(from: names, headline: $0.headline) } ?? [],
            openedOn: today,
            origin: story.flatMap { story in editionDate.map { TrackedFile.Origin(editionDate: $0, headline: story.headline) } },
            seenThrough: seenThrough
        )
        return FileDraft(file: file, suggestions: names + topics, isNew: true)
    }

    static func editing(_ file: TrackedFile) -> FileDraft {
        FileDraft(file: file, suggestions: file.keywords, isNew: false)
    }
}

// MARK: - The docket

/// Your files and their records. The records are worked out from the editions on the
/// iPhone whenever they change, so a file opened today fills with earlier coverage at once,
/// and tomorrow's edition joins it as soon as it's downloaded.
@MainActor
@Observable
final class DocketStore {
    private(set) var files: [TrackedFile] = []
    /// Each file's stories, newest first.
    private(set) var records: [TrackedFile.ID: [DocketEntry]] = [:]
    /// Readable editions on the iPhone, newest first.
    private(set) var editionDates: [String] = []

    private struct IndexedStory {
        let entry: DocketEntry
        let text: String
    }

    private var index: [IndexedStory] = []
    /// Entry id → the story's folded text
    private var texts: [String: String] = [:]
    /// Names the editions' Who's who teach the matcher.
    private(set) var vocabulary = TopicVocabulary()
    /// Entry id → the files whose record has it.
    private var followers: [String: [TrackedFile.ID]] = [:]
    private let url: URL?

    nonisolated static let defaultURL = URL.applicationSupportDirectory.appending(path: "docket.json")

    /// `url: nil` keeps the docket in memory only, for tests.
    init(url: URL? = DocketStore.defaultURL) {
        self.url = url
        load()
    }

    // MARK: Reading

    /// Pinned first, then by the latest development.
    var openFiles: [TrackedFile] {
        files.filter { !$0.isClosed }.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            let latestA = records[a.id]?.first?.editionDate ?? "", latestB = records[b.id]?.first?.editionDate ?? ""
            if latestA != latestB { return latestA > latestB }
            if a.openedOn != b.openedOn { return a.openedOn > b.openedOn }
            return a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }

    var closedFiles: [TrackedFile] {
        files.filter(\.isClosed).sorted { ($0.closedOn ?? "") > ($1.closedOn ?? "") }
    }

    func file(_ id: TrackedFile.ID) -> TrackedFile? {
        files.first { $0.id == id }
    }

    func record(for id: TrackedFile.ID) -> [DocketEntry] {
        records[id] ?? []
    }

    /// Stories from editions you haven't seen on this file yet.
    func newEntries(for file: TrackedFile) -> [DocketEntry] {
        record(for: file.id).filter { $0.editionDate > file.seenThrough }
    }

    /// Open files with stories you haven't seen yet.
    var filesWithNews: [TrackedFile] {
        files.filter { !$0.isClosed && !newEntries(for: $0).isEmpty }
    }

    func momentum(for file: TrackedFile) -> Momentum {
        Momentum.of(latest: record(for: file.id).first?.editionDate, editionDates: editionDates)
    }

    /// One mark per weekday, oldest first, up to the edition due today: how many of the file's
    /// stories that day's edition carried, or nil where there's no edition on the iPhone.
    func heat(for file: TrackedFile, weekdays: Int = 20, endingOn end: String = EditionCalendar.expectedEditionDate()) -> [Int?] {
        Self.heat(entries: record(for: file.id), editionDates: Set(editionDates), endingOn: max(end, editionDates.first ?? end), weekdays: weekdays)
    }

    nonisolated static func heat(entries: [DocketEntry], editionDates: Set<String>, endingOn end: String, weekdays: Int) -> [Int?] {
        guard var day = EditionCalendar.date(from: end) else { return [] }
        let counts = Dictionary(grouping: entries, by: \.editionDate).mapValues(\.count)
        let calendar = EditionCalendar.calendar
        var marks: [Int?] = []
        while marks.count < weekdays {
            if EditionCalendar.isWeekday(day) {
                let iso = EditionCalendar.iso(day)
                marks.append(editionDates.contains(iso) ? counts[iso, default: 0] : nil)
            }
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return marks.reversed()
    }

    /// Open files that follow this story.
    func files(following story: Story, on editionDate: String) -> [TrackedFile] {
        (followers[DocketEntry.key(editionDate: editionDate, storyID: story.id)] ?? [])
            .compactMap(file)
            .filter { !$0.isClosed }
    }

    /// Open files with stories in this edition, and how many.
    func movement(in edition: Edition) -> [(file: TrackedFile, stories: Int)] {
        openFiles.compactMap { file in
            let count = record(for: file.id).count(where: { $0.editionDate == edition.date })
            return count > 0 ? (file, count) : nil
        }
    }

    /// The file's words as the matcher reads them.
    func queries(for file: TrackedFile) -> [TopicQuery] {
        file.keywords
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { TopicQuery.read($0, vocabulary: vocabulary, exact: file.exactWords) }
    }

    /// A name for the file from its words as understood: "anthropic ipo" → "Anthropic IPO".
    func suggestedTitle(for file: TrackedFile) -> String {
        DocketSuggestions.title(for: queries(for: file).map(\.tidied))
    }

    /// The stories a file with these words would have, for the editor's live count.
    func preview(for file: TrackedFile) -> [DocketEntry] {
        let queries = queries(for: file)
        return index.filter { DocketMatcher.matches($0.text, queries: queries, match: file.match) }.map(\.entry)
    }

    /// The other wordings an entry was found through, where it doesn't use the file's own.
    func foundThrough(_ entry: DocketEntry, for file: TrackedFile) -> [String] {
        guard let text = texts[entry.id] else { return [] }
        var seen = Set<String>()
        return queries(for: file)
            .filter { $0.matches(text) }
            .flatMap { $0.foundThrough(text) }
            .filter { seen.insert(DocketMatcher.fold($0)).inserted }
    }

    // MARK: Changing

    func update(editions: [Edition]) {
        editionDates = editions.map(\.date)
        vocabulary = TopicVocabulary(stories: editions.flatMap(\.stories))
        index = editions.flatMap { edition in
            edition.sections.flatMap { section in
                section.stories.map { story in
                    IndexedStory(
                        entry: DocketEntry(editionDate: edition.date, sectionKicker: section.kicker, story: story),
                        text: DocketMatcher.searchText(story)
                    )
                }
            }
        }
        texts = Dictionary(index.map { ($0.entry.id, $0.text) }, uniquingKeysWith: { first, _ in first })
        rebuildRecords()
    }

    /// Adds the file, or replaces the one with the same id.
    func save(_ file: TrackedFile) {
        if let position = files.firstIndex(where: { $0.id == file.id }) {
            files[position] = file
        } else {
            files.append(file)
        }
        rebuildRecords()
        persist()
    }

    func remove(_ id: TrackedFile.ID) {
        files.removeAll { $0.id == id }
        rebuildRecords()
        persist()
    }

    func setPinned(_ id: TrackedFile.ID, _ isPinned: Bool) {
        change(id) { $0.isPinned = isPinned }
    }

    func close(_ id: TrackedFile.ID, on day: String = EditionCalendar.iso(.now)) {
        change(id) {
            $0.closedOn = day
            $0.isPinned = false
        }
    }

    func reopen(_ id: TrackedFile.ID) {
        change(id) {
            $0.closedOn = nil
            $0.seenThrough = max($0.seenThrough, self.editionDates.first ?? $0.seenThrough)
        }
    }

    /// Everything on the file so far has been seen.
    func markSeen(_ id: TrackedFile.ID) {
        guard let file = file(id), let newest = editionDates.first, newest > file.seenThrough else { return }
        change(id) { $0.seenThrough = newest }
    }

    private func change(_ id: TrackedFile.ID, _ edit: (inout TrackedFile) -> Void) {
        guard let position = files.firstIndex(where: { $0.id == id }) else { return }
        edit(&files[position])
        persist()
    }

    private func rebuildRecords() {
        var records: [TrackedFile.ID: [DocketEntry]] = [:]
        var followers: [String: [TrackedFile.ID]] = [:]
        for file in files {
            let entries = preview(for: file)
            records[file.id] = entries
            for entry in entries {
                followers[entry.id, default: []].append(file.id)
            }
        }
        self.records = records
        self.followers = followers
    }

    // MARK: Saving

    private struct Saved: Codable {
        var version = 1
        var files: [TrackedFile]
    }

    private func load() {
        guard let url, let data = try? Data(contentsOf: url) else { return }
        do {
            files = try JSONDecoder().decode(Saved.self, from: data).files
        } catch {
            // Set the unreadable file aside rather than overwrite it with an empty docket.
            let aside = url.deletingLastPathComponent().appending(path: "docket-unreadable-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: aside)
        }
    }

    private func persist() {
        guard let url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Saved(files: files)) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Wording

extension EditionFormat {
    /// "Today", "Tomorrow", "In nine days", "Yesterday", "Nine days ago"
    static func countdown(to iso: String, from now: Date = .now) -> String {
        let days = daysBetween(EditionCalendar.iso(now), iso)
        return switch days {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        case 2...: "In \(spelled(days)) days"
        default: "\(spelledCapitalised(-days)) days ago"
        }
    }

    /// Calendar days from one YYYY-MM-DD date to another.
    static func daysBetween(_ from: String, _ to: String) -> Int {
        guard let start = EditionCalendar.date(from: from), let end = EditionCalendar.date(from: to) else { return 0 }
        return EditionCalendar.calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}
