import Foundation

/// One edition page in the feed: a child page of Court & Capital in Notion, or a sample.
struct EditionPageRef: Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let createdTime: Date
    let lastEditedTime: Date
}

/// Where editions come from. The app and the widgets read through this, so the sample
/// editions and Notion are interchangeable.
protocol EditionFeed: Sendable {
    /// Edition pages, newest first.
    func pages() async throws -> [EditionPageRef]

    /// The edition's JSON, or nil when the page has no Data block (editions from before the
    /// app). Throws `DecodingError` when the block is there but isn't a valid edition.
    func documentData(for page: EditionPageRef) async throws -> Data?
}

extension EditionFeed {
    /// The newest edition that reads cleanly, trying at most `attempts` pages.
    func latestEdition(attempts: Int = 3) async throws -> (page: EditionPageRef, data: Data, document: EditionDocument)? {
        for page in try await pages().prefix(attempts) {
            guard let data = try? await documentData(for: page),
                  let document = try? EditionDocument.decode(data)
            else { continue }
            return (page, data, document)
        }
        return nil
    }
}

/// The two bundled example editions, used until a Notion token is configured.
struct SampleFeed: EditionFeed {
    func pages() async throws -> [EditionPageRef] {
        SampleEdition.documents.map { document in
            let morning = (EditionCalendar.date(from: document.date) ?? .now).addingTimeInterval(5 * 3600)
            return EditionPageRef(
                id: "sample-\(document.date)",
                title: "Edition — \(EditionFormat.dateline(EditionCalendar.date(from: document.date) ?? .now))",
                createdTime: morning,
                lastEditedTime: morning
            )
        }
    }

    func documentData(for page: EditionPageRef) async throws -> Data? {
        let date = page.id.replacingOccurrences(of: "sample-", with: "")
        guard let url = Bundle.main.url(forResource: "edition-\(date)", withExtension: "json") else { return nil }
        return try Data(contentsOf: url)
    }
}

enum EditionFeeds {
    /// Notion when it's configured in Config/Secrets.xcconfig, otherwise the samples.
    static func current() -> any EditionFeed {
        guard let config = NotionConfig.current else { return SampleFeed() }
        return NotionFeed(config: config)
    }

    static var isSample: Bool { NotionConfig.current == nil }
}
