import Foundation
import SwiftData

/// Every edition page the app has looked at. Readable ones keep their JSON, so they open
/// offline; unreadable ones (no Data block, or JSON that doesn't decode) are remembered so
/// they aren't downloaded again unless the page changes.
@Model
final class StoredEdition {
    @Attribute(.unique) var pageID: String
    var title: String
    var createdTime: Date
    var lastEditedTime: Date
    /// From the JSON, YYYY-MM-DD
    var date: String?
    /// The edition's JSON, when it reads cleanly.
    var json: Data?
    var isReadable: Bool
    var checkedAt: Date

    init(page: EditionPageRef) {
        pageID = page.id
        title = page.title
        createdTime = page.createdTime
        lastEditedTime = page.lastEditedTime
        isReadable = false
        checkedAt = .now
    }

    var edition: Edition? {
        guard isReadable, let json, let document = try? EditionDocument.decode(json) else { return nil }
        return Edition(document: document)
    }

    /// Whether the page is unchanged since it was downloaded. Notion rounds edit times down
    /// to the minute, so a page checked within a minute of its last edit may have changed
    /// without its time moving: that one is checked again.
    func isCurrent(for page: EditionPageRef) -> Bool {
        lastEditedTime >= page.lastEditedTime && checkedAt >= lastEditedTime.addingTimeInterval(60)
    }
}

enum EditionCache {
    /// The cache lives in its own file. If it can't be opened (for example after a model
    /// change), it's rebuilt from Notion rather than failing.
    static func makeContainer() -> ModelContainer {
        let schema = Schema([StoredEdition.self])
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "editions.store")
        let configuration = ModelConfiguration(schema: schema, url: url)
        if let container = try? ModelContainer(for: schema, configurations: configuration) {
            return container
        }
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path() + suffix))
        }
        if let container = try? ModelContainer(for: schema, configurations: configuration) {
            return container
        }
        return try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
