import Foundation

/// A bound month of editions: one spine on the shelf.
struct ArchiveMonth: Identifiable, Sendable, Hashable {
    let year: Int
    let month: Int
    /// Newest first
    let items: [ArchiveItem]

    var id: String { "\(year)-\(month)" }

    var firstDay: Date {
        EditionCalendar.calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }
}

/// The published editions, bound by month for the shelf and ledger.
struct Archive: Sendable {
    /// Oldest month first, as the books stand on the shelf.
    let months: [ArchiveMonth]
    let editionCount: Int

    init(items: [ArchiveItem]) {
        let calendar = EditionCalendar.calendar
        let grouped = Dictionary(grouping: items) { item -> DateComponents in
            calendar.dateComponents([.year, .month], from: item.day)
        }
        months = grouped
            .map { components, items in
                ArchiveMonth(
                    year: components.year ?? 0,
                    month: components.month ?? 0,
                    items: items.sorted { $0.editionDate > $1.editionDate }
                )
            }
            .sorted { ($0.year, $0.month) < ($1.year, $1.month) }
        editionCount = items.count
    }

    /// The shelf shows the twelve most recent months.
    var shelf: [ArchiveMonth] { Array(months.suffix(12)) }
}
