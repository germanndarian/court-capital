import Foundation

/// Editions are dated and delivered in Zürich time, every weekday. The pipeline publishes
/// by 05:00; the app expects today's edition from then on.
enum EditionCalendar {
    static let timeZone = TimeZone(identifier: "Europe/Zurich")!
    static let readyHour = 5
    static let readyMinute = 0

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = timeZone
        return calendar
    }

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Midnight in Zürich on a YYYY-MM-DD date.
    static func date(from iso: String) -> Date? {
        isoFormatter.date(from: iso)
    }

    static func iso(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func isWeekday(_ date: Date) -> Bool {
        !calendar.isDateInWeekend(date)
    }

    /// The moment today's edition should be ready, or the next weekday's after `date`.
    static func nextReady(after date: Date) -> Date {
        let calendar = calendar
        var day = calendar.startOfDay(for: date)
        while true {
            let ready = calendar.date(bySettingHour: readyHour, minute: readyMinute, second: 0, of: day)!
            if ready > date && isWeekday(day) { return ready }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
    }

    /// The edition the reader should have by now: today's after 05:00 on a weekday,
    /// otherwise the most recent weekday's.
    static func expectedEditionDate(at now: Date = .now) -> String {
        let calendar = calendar
        var day = calendar.startOfDay(for: now)
        let readyToday = calendar.date(bySettingHour: readyHour, minute: readyMinute, second: 0, of: day)!
        if !isWeekday(day) || now < readyToday {
            repeat {
                day = calendar.date(byAdding: .day, value: -1, to: day)!
            } while !isWeekday(day)
        }
        return iso(day)
    }
}

enum Roman {
    private static let table: [(Int, String)] = [
        (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
        (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I"),
    ]

    static func numeral(_ number: Int) -> String {
        var remaining = number
        var result = ""
        for (value, symbol) in table {
            while remaining >= value {
                result += symbol
                remaining -= value
            }
        }
        return result
    }
}

enum EditionFormat {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.calendar = EditionCalendar.calendar
        formatter.timeZone = EditionCalendar.timeZone
        formatter.dateFormat = format
        return formatter
    }

    private static let longDate = formatter("EEEE, d MMMM yyyy")
    private static let dayMonth = formatter("EEEE, d MMMM")
    private static let shortDate = formatter("EEE d MMM")
    private static let weekdayName = formatter("EEEE")
    private static let weekdayShort = formatter("EEE")
    private static let monthName = formatter("MMMM")
    private static let monthShort = formatter("MMM")

    /// Wednesday, 7 October 2026
    static func dateline(_ date: Date) -> String { longDate.string(from: date) }
    /// Wednesday, 7 October
    static func storyDate(_ date: Date) -> String { dayMonth.string(from: date) }
    /// Wed 7 Oct
    static func short(_ date: Date) -> String { shortDate.string(from: date) }
    static func weekday(_ date: Date) -> String { weekdayName.string(from: date) }
    static func weekdayAbbreviation(_ date: Date) -> String { weekdayShort.string(from: date) }
    static func month(_ date: Date) -> String { monthName.string(from: date) }
    static func monthAbbreviation(_ date: Date) -> String { monthShort.string(from: date) }

    /// 5:05 a.m.
    static func time(minutesAfterMidnight minutes: Int) -> String {
        let hour = minutes / 60 % 24
        let minute = minutes % 60
        let twelveHour = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", twelveHour, minute, hour < 12 ? "a.m." : "p.m.")
    }

    /// "ten", "two hundred"
    static func spelled(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }

    /// "Ten", "Eleven"
    static func spelledCapitalised(_ number: Int) -> String {
        let word = spelled(number)
        return word.prefix(1).uppercased() + word.dropFirst()
    }

    /// "Four stories", "One story"
    static func storyCount(_ count: Int) -> String {
        "\(spelledCapitalised(count)) \(count == 1 ? "story" : "stories")"
    }

    /// "Eleven-minute read"
    static func readTime(_ minutes: Int) -> String {
        "\(spelledCapitalised(minutes))-minute read"
    }
}
