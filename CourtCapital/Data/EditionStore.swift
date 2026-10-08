import Foundation
import Observation
import SwiftData
import WidgetKit

/// Editions for the screens: whatever is cached on the iPhone first, then fresh copies from
/// Supabase. The latest ten editions are kept in full so they read offline.
@MainActor
@Observable
final class EditionStore {
    private(set) var latest: Edition?
    private(set) var archiveItems: [ArchiveItem] = []
    private(set) var isRefreshing = false
    /// Set when the last refresh couldn't reach Supabase.
    private(set) var refreshProblem: String?
    private(set) var hasLoadedOnce = false

    private let context: ModelContext
    private let service: EditionService?

    init(context: ModelContext) {
        self.context = context
        service = try? EditionService()
        loadCache()
    }

    // MARK: Reading

    /// A note under the masthead when the newest edition isn't the one due by now.
    var lateNote: String? {
        guard let latest, latest.date < EditionCalendar.expectedEditionDate() else { return nil }
        return "Today’s edition is running late. Here’s \(EditionFormat.weekday(latest.day))’s."
    }

    func cachedEdition(on date: String) -> Edition? {
        if latest?.date == date { return latest }
        var descriptor = FetchDescriptor<CachedEdition>(predicate: #Predicate { $0.date == date })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.edition
    }

    /// An edition from the cache, or downloaded and cached.
    func edition(on date: String) async throws -> Edition? {
        if let cached = cachedEdition(on: date) { return cached }
        guard let service else { throw EditionServiceError.notConfigured }
        guard let edition = try await service.edition(on: date) else { return nil }
        store(edition)
        try? context.save()
        return edition
    }

    // MARK: Refreshing

    func refresh() async {
        guard let service else {
            refreshProblem = EditionServiceError.notConfigured.errorDescription
            hasLoadedOnce = true
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            hasLoadedOnce = true
        }

        do {
            async let recent = service.latest(limit: 10)
            async let index = service.archive()
            let (editions, items) = try await (recent, index)
            let previous = latest?.date
            editions.forEach(store)
            items.forEach(store)
            try context.save()
            if let newest = editions.first { latest = newest }
            archiveItems = items
            refreshProblem = nil
            if latest?.date != previous {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            refreshProblem = latest == nil
                ? "Couldn’t reach the newsroom. Check your connection and pull to try again."
                : "Couldn’t reach the newsroom. Showing the editions saved on this iPhone."
        }
    }

    // MARK: Cache

    private func loadCache() {
        var newest = FetchDescriptor<CachedEdition>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        newest.fetchLimit = 1
        latest = try? context.fetch(newest).first?.edition

        let index = FetchDescriptor<CachedArchiveItem>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        archiveItems = ((try? context.fetch(index)) ?? []).map(\.item)
        if let latest, !archiveItems.contains(where: { $0.editionDate == latest.date }) {
            archiveItems.insert(ArchiveItem(editionDate: latest.date, number: latest.number, bigStory: latest.bigStory.text, readingMinutes: latest.readingMinutes), at: 0)
        }
    }

    private func store(_ edition: Edition) {
        guard let json = try? JSONEncoder.edition.encode(edition) else { return }
        let date = edition.date
        var descriptor = FetchDescriptor<CachedEdition>(predicate: #Predicate { $0.date == date })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.json = json
            existing.number = edition.number
            existing.fetchedAt = .now
        } else {
            context.insert(CachedEdition(edition: edition, json: json))
        }
    }

    private func store(_ item: ArchiveItem) {
        let date = item.editionDate
        var descriptor = FetchDescriptor<CachedArchiveItem>(predicate: #Predicate { $0.date == date })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.number = item.number
            existing.bigStory = item.bigStory
            existing.readingMinutes = item.readingMinutes
        } else {
            context.insert(CachedArchiveItem(item: item))
        }
    }
}
