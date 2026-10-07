import Foundation

/// One row of the archive ledger.
struct ArchiveEntry: Identifiable, Sendable {
    let number: Int
    let date: Date
    let headline: String
    let readMinutes: Int
    let isCurrent: Bool
    var id: Int { number }
}

/// A bound month of editions: one spine on the shelf.
struct ArchiveMonth: Identifiable, Sendable {
    let month: Int
    let year: Int
    let entries: [ArchiveEntry]
    var id: Int { month }
}

/// The year's editions so far, bound by month.
struct Archive: Sendable {
    let months: [ArchiveMonth]
    let editionCount: Int
    let volume: Int

    init(current edition: Edition) {
        let calendar = EditionCalendar.calendar
        let days = EditionCalendar.editionDays(through: edition.date)
        let entries = days.enumerated().map { index, day in
            let number = index + 1
            let isCurrent = number == days.count
            return ArchiveEntry(
                number: number,
                date: day,
                headline: isCurrent ? edition.bigStory : SampleEdition.pastHeadlines[number % SampleEdition.pastHeadlines.count],
                readMinutes: isCurrent ? edition.readMinutes : 8 + number % 5,
                isCurrent: isCurrent
            )
        }
        let year = calendar.component(.year, from: edition.date)
        let lastMonth = calendar.component(.month, from: edition.date)
        months = (1...lastMonth).map { month in
            ArchiveMonth(
                month: month,
                year: year,
                entries: entries.filter { calendar.component(.month, from: $0.date) == month }
            )
        }
        editionCount = entries.count
        volume = edition.volume
    }
}

extension ArchiveMonth {
    var firstDay: Date {
        EditionCalendar.calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }
}
