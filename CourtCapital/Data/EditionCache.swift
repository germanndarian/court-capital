import Foundation
import SwiftData

/// A downloaded edition, kept so it can be read offline.
@Model
final class CachedEdition {
    @Attribute(.unique) var date: String
    var number: Int
    var json: Data
    var fetchedAt: Date

    init(edition: Edition, json: Data) {
        date = edition.date
        number = edition.number
        self.json = json
        fetchedAt = .now
    }

    var edition: Edition? {
        try? JSONDecoder.edition.decode(Edition.self, from: json)
    }
}

/// One line of the archive index, kept so the archive lists editions offline too.
@Model
final class CachedArchiveItem {
    @Attribute(.unique) var date: String
    var number: Int
    var bigStory: String
    var readingMinutes: Int?

    init(item: ArchiveItem) {
        date = item.editionDate
        number = item.number
        bigStory = item.bigStory
        readingMinutes = item.readingMinutes
    }

    var item: ArchiveItem {
        ArchiveItem(editionDate: date, number: number, bigStory: bigStory, readingMinutes: readingMinutes)
    }
}

enum EditionCache {
    static let schema: [any PersistentModel.Type] = [CachedEdition.self, CachedArchiveItem.self]
}
