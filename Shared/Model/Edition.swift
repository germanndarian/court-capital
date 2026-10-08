import Foundation

// The edition exactly as the pipeline stores it in Supabase (editions.content), decoded
// with snake_case keys. Source of truth: pipeline/src/schema.ts → Edition.

struct Edition: Codable, Sendable, Identifiable, Hashable {
    let schemaVersion: Int
    /// YYYY-MM-DD, Zürich calendar date
    let date: String
    let number: Int
    let volume: Int
    let bigStory: BigStory
    let markets: Markets
    let sections: [EditionSection]
    let readingMinutes: Int
    let footer: String
    let model: String
    let generatedAt: String

    var id: String { date }

    struct BigStory: Codable, Sendable, Hashable {
        let text: String
        let storyId: String?
    }

    struct Markets: Codable, Sendable, Hashable {
        /// Date of the close the figures are from, YYYY-MM-DD
        let asOf: String
        let quotes: [Quote]
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
        ["S&P 500", "SMI", "USD/CHF"].compactMap { name in markets.quotes.first { $0.name == name } }
    }
}

struct EditionSection: Codable, Sendable, Identifiable, Hashable {
    let key: String
    let numeral: String
    let title: String
    let note: String
    let stories: [Story]

    var id: String { key }
    var kicker: String { "\(numeral). \(title)" }
}

struct Story: Codable, Sendable, Identifiable, Hashable {
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

    var bodyRuns: [BodyRun] { BodyRun.parse(body) }
    var plainWordsText: String { plainWords.joined(separator: " ") }
}

struct Term: Codable, Sendable, Hashable, Identifiable {
    let name: String
    let description: String
    var id: String { name }
}

struct Source: Codable, Sendable, Hashable, Identifiable {
    let outlet: String
    let url: String
    var id: String { url }
    var link: URL? { URL(string: url) }
}

enum Region: Sendable, Hashable, Codable {
    case us, ch, eu, uk, asia, global
    case other(String)

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = switch raw.uppercased() {
        case "US": .us
        case "CH": .ch
        case "EU": .eu
        case "UK": .uk
        case "ASIA": .asia
        case "GLOBAL": .global
        default: .other(raw)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(code)
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

struct Quote: Codable, Sendable, Hashable, Identifiable {
    let name: String
    let level: Double
    /// Percent, or basis points when `changeUnit` is "bp"
    let change: Double
    let changeUnit: String
    let unit: String

    var id: String { name }

    enum Direction: Sendable {
        case up, down, flat
    }

    var direction: Direction {
        change > 0 ? .up : change < 0 ? .down : .flat
    }

    /// "7,801.77", "5.28%", "0.8322", "$100.20"
    var levelLabel: String {
        switch unit {
        case "yield": String(format: "%.2f%%", level)
        case "fx": String(format: "%.4f", level)
        case "usd": "$" + level.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US")))
        default: level.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US")))
        }
    }

    /// "+0.66%", "−1.90%", "+0.8 bp"
    var changeLabel: String {
        let sign = change > 0 ? "+" : change < 0 ? "−" : "±"
        return changeUnit == "bp"
            ? "\(sign)\(String(format: "%.1f", abs(change))) bp"
            : "\(sign)\(String(format: "%.2f", abs(change)))%"
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

/// One entry in the archive index: enough to list an edition without downloading it.
struct ArchiveItem: Codable, Sendable, Hashable, Identifiable {
    let editionDate: String
    let number: Int
    let bigStory: String
    var readingMinutes: Int?

    var id: String { editionDate }
    var day: Date { EditionCalendar.date(from: editionDate) ?? .now }
}

extension JSONDecoder {
    static let edition: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

extension JSONEncoder {
    static let edition: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}
