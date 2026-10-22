import Foundation
import Testing

@Suite("Taking a break")
struct PauseTests {
    /// Thursday 22 October 2026, 20:00 in Zürich
    private let thursdayEvening = Date(timeIntervalSince1970: 1_792_692_000)

    private func iso(_ date: Date) -> String { EditionCalendar.iso(date) }

    @Test("A break of N days starts today and lasts N calendar days")
    func lastDay() {
        #expect(EditionPause.lastDay(forDays: 1, from: thursdayEvening) == "2026-10-22")
        #expect(EditionPause.lastDay(forDays: 4, from: thursdayEvening) == "2026-10-25")
    }

    @Test("The edition is back on the first weekday after the break")
    func resumeDay() throws {
        // A break through Saturday ends on Monday.
        let resume = try #require(EditionPause.resumeDay(after: "2026-10-24"))
        #expect(iso(resume) == "2026-10-26")
    }

    @Test("A break that has ended is no longer active")
    func ended() {
        #expect(EditionPause.isPaused(day: "2026-10-22", through: "2026-10-23"))
        #expect(!EditionPause.isPaused(day: "2026-10-24", through: "2026-10-23"))
        #expect(!EditionPause.isPaused(day: "2026-10-22", through: ""))
    }

    @Test("Notifications skip weekends, today once the time has passed, and the days of a break")
    func deliveryDays() {
        let days = MorningNotification.deliveryDays(minutesAfterMidnight: 5 * 60 + 30, pausedThrough: "2026-10-27", from: thursdayEvening)
            .map(iso)
        // Thursday evening is past 05:30; Friday to Tuesday are the break; Wednesday is next.
        #expect(days.first == "2026-10-28")
        #expect(!days.contains("2026-10-31") && !days.contains("2026-11-01"))
        #expect(days.count == 40)
    }

    @Test("Without a break, the next weekday gets the notification")
    func noBreak() {
        let days = MorningNotification.deliveryDays(minutesAfterMidnight: 5 * 60 + 30, pausedThrough: "", from: thursdayEvening)
        #expect(days.first.map(iso) == "2026-10-23")
        let time = EditionCalendar.calendar.dateComponents([.hour, .minute], from: days[0])
        #expect(time.hour == 5 && time.minute == 30)
    }
}

@Suite("Your ETF")
struct MarketQuoteTests {
    /// Daily bars for Monday 26 to Thursday 29 October, stamped at 08:00 UTC like Yahoo's
    /// London listing, the last one still trading on the edition's own day.
    private let chart = Data("""
    {"chart":{"result":[{"timestamp":[1793001600,1793088000,1793174400,1793260800],
     "indicators":{"quote":[{"close":[122.63,null,123.22,121.54]}]}}]}}
    """.utf8)

    @Test("Takes the last close before the edition's date and its change on the day")
    func lastClose() throws {
        // Bars: 26, 27 (no close), 28 and 29 October. An edition dated 29 October uses the
        // close of the 28th against the 26th, skipping the missing one.
        let close = try #require(MarketQuotes.lastClose(in: chart, before: "2026-10-29"))
        #expect(close.level == 123.22)
        #expect(close.change == 0.48)
    }

    @Test("Needs two closes before the edition")
    func notEnough() {
        #expect(MarketQuotes.lastClose(in: chart, before: "2026-10-27") == nil)
        #expect(MarketQuotes.lastClose(in: Data("not json".utf8), before: "2026-10-29") == nil)
    }

    @Test("Shows in dollars")
    func label() {
        let quote = Quote(name: ExtraMarket.acwi.name, level: 121.54, change: -1.36)
        #expect(quote.levelLabel == "$121.54")
        #expect(quote.changeWithArrow == "▼ −1.36%")
    }
}
