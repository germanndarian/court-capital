import Foundation
import Observation
import SwiftData
import WidgetKit

/// Editions for the screens. Shows what's cached on the iPhone straight away, then syncs
/// with the feed (Notion, or the bundled samples until Notion is configured): new and
/// changed edition pages are downloaded, unchanged ones never are.
@MainActor
@Observable
final class EditionStore {
    /// Readable editions, newest first.
    private(set) var editions: [Edition] = []
    private(set) var isRefreshing = false
    /// Set when the last sync couldn't reach Notion.
    private(set) var refreshProblem: String?
    /// The newest edition page exists but its Data block is missing or doesn't decode.
    private(set) var newestIsUnreadable = false
    private(set) var hasLoadedOnce = false

    let isSample = EditionFeeds.isSample
    private let feed: any EditionFeed
    private let context: ModelContext

    init(context: ModelContext, feed: any EditionFeed = EditionFeeds.current()) {
        self.context = context
        self.feed = feed
        loadCache()
    }

    // MARK: Reading

    var latest: Edition? { editions.first }
    var archiveItems: [ArchiveItem] { editions.map(\.archiveItem) }

    func cachedEdition(on date: String) -> Edition? {
        editions.first { $0.date == date }
    }

    /// Every readable edition is cached, so this never needs the network.
    func edition(on date: String) async throws -> Edition? {
        cachedEdition(on: date)
    }

    /// A note under the masthead when the newest edition isn't the one due by now.
    var lateNote: String? {
        guard let latest else { return nil }
        let weekday = EditionFormat.weekday(latest.day)
        if isSample {
            return "Sample editions. Add your Notion token to read the real ones."
        }
        if newestIsUnreadable {
            return "Today’s edition couldn’t be read. Here’s \(weekday)’s."
        }
        if latest.date < EditionCalendar.expectedEditionDate() {
            return "Today’s edition is running late. Here’s \(weekday)’s."
        }
        return nil
    }

    // MARK: Syncing

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            hasLoadedOnce = true
        }
        let previousNewest = latest?.date

        do {
            let pages = try await feed.pages()
            let stored = Dictionary(uniqueKeysWithValues: fetchStored().map { ($0.pageID, $0) })

            // Pages deleted in Notion leave the archive too.
            let current = Set(pages.map(\.id))
            for record in stored.values where !current.contains(record.pageID) {
                context.delete(record)
            }

            // Newest first, so today's edition shows up before the archive fills in.
            for page in pages {
                if let record = stored[page.id], record.lastEditedTime >= page.lastEditedTime { continue }
                let record = stored[page.id] ?? {
                    let record = StoredEdition(page: page)
                    context.insert(record)
                    return record
                }()
                record.title = page.title
                record.createdTime = page.createdTime
                record.lastEditedTime = page.lastEditedTime
                record.checkedAt = .now
                do {
                    if let data = try await feed.documentData(for: page) {
                        let document = try EditionDocument.decode(data)
                        record.json = data
                        record.date = document.date
                        record.isReadable = true
                    } else {
                        record.json = nil
                        record.isReadable = false
                    }
                } catch is DecodingError {
                    record.json = nil
                    record.isReadable = false
                }
                try? context.save()
                loadCache()
            }
            try? context.save()
            loadCache()
            newestIsUnreadable = pages.first.flatMap { page in fetchStored().first { $0.pageID == page.id } }.map { !$0.isReadable } ?? false
            refreshProblem = nil
        } catch {
            refreshProblem = editions.isEmpty
                ? "Couldn’t reach Notion. Check your connection and pull to try again."
                : "Couldn’t reach Notion. Showing the editions saved on this iPhone."
        }

        if latest?.date != previousNewest {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: Cache

    private func fetchStored() -> [StoredEdition] {
        (try? context.fetch(FetchDescriptor<StoredEdition>())) ?? []
    }

    private func loadCache() {
        var seen = Set<String>()
        editions = fetchStored()
            .filter(\.isReadable)
            .sorted { ($0.date ?? "", $0.createdTime) > ($1.date ?? "", $1.createdTime) }
            .compactMap(\.edition)
            // If two pages carry the same date, the newer one wins.
            .filter { seen.insert($0.date).inserted }
    }
}
