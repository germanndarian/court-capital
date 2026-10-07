import Foundation

/// Editions appear every weekday. The edition number counts weekdays since 1 January of the
/// volume's year, and Volume I is 2026.
enum EditionCalendar {
    static let firstVolumeYear = 2026
    static let deliveryHour = 6
    static let deliveryMinute = 30

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }

    static func isWeekday(_ date: Date) -> Bool {
        !calendar.isDateInWeekend(date)
    }

    static func volume(for date: Date) -> Int {
        calendar.component(.year, from: date) - firstVolumeYear + 1
    }

    static func editionNumber(for date: Date) -> Int {
        editionDays(through: date).count
    }

    /// Every weekday from 1 January of the date's year up to and including the date.
    static func editionDays(through date: Date) -> [Date] {
        let calendar = calendar
        let end = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: end)
        var day = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        var days: [Date] = []
        while day <= end {
            if !calendar.isDateInWeekend(day) { days.append(day) }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return days
    }

    /// The next weekday delivery strictly after `date`.
    static func nextDelivery(after date: Date) -> Date {
        let calendar = calendar
        var day = calendar.startOfDay(for: date)
        while true {
            let delivery = calendar.date(bySettingHour: deliveryHour, minute: deliveryMinute, second: 0, of: day)!
            if delivery > date && !calendar.isDateInWeekend(day) { return delivery }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
    }

    /// The weekday before `date`, whose close the markets strip reports.
    static func previousWeekday(before date: Date) -> Date {
        var day = calendar.date(byAdding: .day, value: -1, to: date)!
        while calendar.isDateInWeekend(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return day
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

    /// 6:30 a.m.
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
