import Foundation

// MARK: - The JSON your scheduled task writes into each Notion edition

/// The edition exactly as it appears in the "Data" code block of a Notion edition page.
/// Keys are snake_case in the JSON.
struct EditionDocument: Codable, Sendable, Hashable {
    var schemaVersion: Int?
    let date: String
    let bigStory: String
    var markets: [MarketDocument]?
    let sections: [SectionDocument]
    /// Written by the task but never shown: the app prints its own footer, so nothing on
    /// screen says how the edition was made.
    var footer: String?

    struct MarketDocument: Codable, Sendable, Hashable {
        let name: String
        let level: Double
        let changePct: Double
    }

    struct SectionDocument: Codable, Sendable, Hashable {
        let numeral: String
        let title: String
        let stories: [StoryDocument]
    }

    struct StoryDocument: Codable, Sendable, Hashable {
        let headline: String
        let region: String
        var whosWho: String?
        let body: String
        var whyItMatters: String?
        var inPlainWords: [String]?
        var sources: [Source]?
    }

    static func decode(_ data: Data) throws -> EditionDocument {
        let document = try JSONDecoder.edition.decode(EditionDocument.self, from: data)
        guard EditionCalendar.date(from: document.date) != nil else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "date isn’t YYYY-MM-DD: \(document.date)"))
        }
        guard document.sections.contains(where: { !$0.stories.isEmpty }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The edition has no stories"))
        }
        return document
    }
}

// MARK: - The edition as the app shows it

/// An edition ready for the screens: the document plus what the app works out itself
/// (story ids, reading times, edition number, who's who pairs).
struct Edition: Sendable, Identifiable, Hashable {
    /// YYYY-MM-DD, Zürich calendar date
    let date: String
    let number: Int
    let volume: Int
    let bigStory: BigStory
    let markets: Markets
    let sections: [EditionSection]
    let readingMinutes: Int

    var id: String { date }

    struct BigStory: Sendable, Hashable {
        let text: String
        /// The story the Big Story line is about, when it can be told from the headlines.
        let storyId: String?
    }

    struct Markets: Sendable, Hashable {
        /// The trading day the figures are from: the weekday before the edition.
        let asOf: String
        let quotes: [Quote]
    }

    init(document: EditionDocument) {
        date = document.date
        number = EditionCalendar.editionNumber(for: document.date)
        volume = EditionCalendar.volume(for: document.date)

        sections = document.sections.enumerated().map { sectionIndex, section in
            EditionSection(
                key: section.title.lowercased().replacingOccurrences(of: " ", with: "-"),
                numeral: section.numeral,
                title: section.title,
                stories: section.stories.enumerated().map { storyIndex, story in
                    Story(document: story, id: "\(sectionIndex + 1)-\(storyIndex + 1)")
                }
            )
        }
        let stories = sections.flatMap(\.stories)
        readingMinutes = ReadingTime.minutes(words: stories.reduce(0) { $0 + $1.wordCount })
        bigStory = BigStory(text: document.bigStory, storyId: BigStoryMatcher.match(document.bigStory, in: stories))

        let day = EditionCalendar.date(from: document.date) ?? .now
        markets = Markets(
            asOf: EditionCalendar.iso(EditionCalendar.previousWeekday(before: day)),
            quotes: (document.markets ?? []).map(Quote.init)
        )
    }

    var day: Date { EditionCalendar.date(from: date) ?? .now }
    var stories: [Story] { sections.flatMap(\.stories) }
    var storyCount: Int { stories.count }

    func story(id: Story.ID) -> Story? {
        stories.first { $0.id == id }
    }

    func section(containing id: Story.ID) -> EditionSection? {
        sections.first { $0.stories.contains { $0.id == id } }
    }

    /// "At Wednesday’s close"
    var marketsNote: String {
        guard let asOf = EditionCalendar.date(from: markets.asOf) else { return "At the last close" }
        return "At \(EditionFormat.weekday(asOf))’s close"
    }

    /// The three figures on the medium widget.
    var widgetQuotes: [Quote] {
        let preferred = ["S&P 500", "SMI", "USD/CHF"].compactMap { name in markets.quotes.first { $0.name == name } }
        return preferred.count == 3 ? preferred : Array(markets.quotes.prefix(3))
    }

    var archiveItem: ArchiveItem {
        ArchiveItem(editionDate: date, number: number, bigStory: bigStory.text, readingMinutes: readingMinutes)
    }
}

struct EditionSection: Sendable, Identifiable, Hashable {
    let key: String
    let numeral: String
    let title: String
    let stories: [Story]

    var id: String { key }
    var kicker: String { "\(numeral). \(title)" }
}

struct Story: Sendable, Identifiable, Hashable {
    let id: String
    let headline: String
    let region: Region
    let whosWho: [Term]
    /// Markdown-light: `*(…)*` marks an inline explanation, `*…*` other italics.
    let body: String
    let whyItMatters: String?
    let plainWords: [String]
    let sources: [Source]
    let readingMinutes: Int

    init(document: EditionDocument.StoryDocument, id: String) {
        self.id = id
        headline = document.headline
        region = Region(document.region)
        whosWho = Term.parse(document.whosWho ?? "")
        body = document.body
        let why = document.whyItMatters?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        whyItMatters = why.isEmpty ? nil : why
        plainWords = document.inPlainWords ?? []
        sources = document.sources ?? []
        readingMinutes = ReadingTime.minutes(words: Self.countWords(headline, whosWho, body, whyItMatters, plainWords))
    }

    var bodyRuns: [BodyRun] { BodyRun.parse(body) }
    var plainWordsText: String { plainWords.joined(separator: " ") }

    var wordCount: Int { Self.countWords(headline, whosWho, body, whyItMatters, plainWords) }

    private static func countWords(_ headline: String, _ whosWho: [Term], _ body: String, _ why: String?, _ plainWords: [String]) -> Int {
        let parts = [headline, body, why ?? ""] + whosWho.map { "\($0.name) \($0.description)" } + plainWords
        return parts.joined(separator: " ").split(whereSeparator: \.isWhitespace).count
    }
}

/// One "Name = what it is" entry from the Who's who line.
struct Term: Sendable, Hashable, Identifiable {
    let name: String
    let description: String
    var id: String { name }

    /// "SEC = US stock-market regulator · Fed = US central bank" → two terms.
    static func parse(_ line: String) -> [Term] {
        line.components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { entry in
                guard let equals = entry.range(of: "=") else { return Term(name: entry, description: "") }
                return Term(
                    name: entry[..<equals.lowerBound].trimmingCharacters(in: .whitespaces),
                    description: entry[equals.upperBound...].trimmingCharacters(in: .whitespaces)
                )
            }
    }
}

struct Source: Codable, Sendable, Hashable, Identifiable {
    let outlet: String
    let url: String
    var id: String { url }
    var link: URL? { URL(string: url) }
}

enum Region: Sendable, Hashable {
    case us, ch, eu, uk, asia, global
    case other(String)

    init(_ raw: String) {
        self = switch raw.trimmingCharacters(in: .whitespaces).uppercased() {
        case "US", "USA": .us
        case "CH": .ch
        case "EU": .eu
        case "UK": .uk
        case "ASIA": .asia
        case "GLOBAL": .global
        default: .other(raw)
        }
    }

    var code: String {
        switch self {
        case .us: "US"
        case .ch: "CH"
        case .eu: "EU"
        case .uk: "UK"
        case .asia: "ASIA"
        case .global: "GLOBAL"
        case .other(let raw): raw.uppercased()
        }
    }
}

struct Quote: Sendable, Hashable, Identifiable {
    let name: String
    let level: Double
    /// Percent change on the day
    let change: Double

    var id: String { name }

    init(name: String, level: Double, change: Double) {
        self.name = name
        self.level = level
        self.change = change
    }

    init(_ market: EditionDocument.MarketDocument) {
        self.init(name: market.name, level: market.level, change: market.changePct)
    }

    enum Direction: Sendable {
        case up, down, flat
    }

    var direction: Direction {
        change > 0 ? .up : change < 0 ? .down : .flat
    }

    private static let english = Locale(identifier: "en_US")

    /// "7,801.77", "5.28%", "0.8322", "$100.20"
    var levelLabel: String {
        switch name {
        case "US 10Y": String(format: "%.2f%%", level)
        case "USD/CHF": String(format: "%.4f", level)
        case "Brent", ExtraMarket.acwi.name: "$" + level.formatted(.number.precision(.fractionLength(2)).locale(Self.english))
        default: level.formatted(.number.precision(.fractionLength(2)).locale(Self.english))
        }
    }

    /// "+0.66%", "−1.90%"
    var changeLabel: String {
        let sign = change > 0 ? "+" : change < 0 ? "−" : "±"
        return "\(sign)\(String(format: "%.2f", abs(change)))%"
    }

    /// "▲ +0.66%"
    var changeWithArrow: String {
        switch direction {
        case .up: "▲ \(changeLabel)"
        case .down: "▼ \(changeLabel)"
        case .flat: changeLabel
        }
    }
}

/// One entry in the archive: enough to list an edition.
struct ArchiveItem: Sendable, Hashable, Identifiable {
    let editionDate: String
    let number: Int
    let bigStory: String
    var readingMinutes: Int?

    var id: String { editionDate }
    var day: Date { EditionCalendar.date(from: editionDate) ?? .now }
}

// MARK: - Worked out by the app

enum ReadingTime {
    /// At about 180 words a minute: careful reading, not skimming.
    static func minutes(words: Int) -> Int {
        max(1, Int((Double(words) / 180).rounded()))
    }
}

/// Finds the story the Big Story line is about by the words it shares with each headline,
/// so tapping the Big Story can open it. Gives up when no headline clearly matches.
enum BigStoryMatcher {
    private static let ignored: Set<String> = [
        "about", "after", "again", "against", "before", "their", "there", "these", "those", "which", "while",
        "would", "could", "should", "since", "every", "another", "biggest", "highest", "first", "agreed",
    ]

    static func match(_ bigStory: String, in stories: [Story]) -> String? {
        let target = words(bigStory)
        let scored = stories.map { story in (story.id, words(story.headline).intersection(target).count) }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 >= 3 else { return nil }
        return best.0
    }

    private static func words(_ text: String) -> Set<String> {
        Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 4 && !ignored.contains($0) }
        )
    }
}

extension JSONDecoder {
    static let edition: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
