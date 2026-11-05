import Foundation

/// A stock's latest price and its change on the day, in percent.
struct HeatQuote: Codable, Hashable, Sendable {
    let price: Double
    let change: Double
}

/// What the last good fetch brought back. Kept on the device so the heatmap shows offline.
struct HeatmapSnapshot: Codable, Sendable, Equatable {
    var quotes: [String: HeatQuote]
    /// The time of the newest daily bar
    var asOf: Date
    var fetched: Date
}

/// Prices from Yahoo Finance's public spark endpoint (no key): a few requests carry every stock.
/// If Yahoo changes or blocks it, parsing fails quietly and the heatmap keeps the cached figures.
enum HeatmapFeed {
    /// Yahoo's spark endpoint answers "400" above 20 symbols.
    static let batchSize = 20
    private static let cacheKey = "heatmap.snapshot.v1"

    typealias Loader = @Sendable (URL) async -> Data?

    // MARK: URLs

    static func sparkURL(_ symbols: [String]) -> URL? {
        guard !symbols.isEmpty else { return nil }
        return URL(string: "https://query1.finance.yahoo.com/v8/finance/spark?symbols=\(symbols.joined(separator: ","))&range=5d&interval=1d")
    }

    static func chartURL(_ symbol: String) -> URL? {
        URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?range=5d&interval=1d")
    }

    // MARK: Parsing

    /// Spark's answer: `{"AAPL": {"timestamp": [...], "close": [...]}, ...}`. Symbols Yahoo doesn't
    /// know are missing, and a malformed entry only costs that one stock.
    static func parseSpark(_ data: Data) -> (quotes: [String: HeatQuote], asOf: Date?) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return ([:], nil) }
        var quotes: [String: HeatQuote] = [:]
        var asOf: Date?
        for (symbol, value) in root {
            guard let entry = value as? [String: Any],
                  let result = quote(closes: entry["close"], timestamps: entry["timestamp"])
            else { continue }
            quotes[symbol] = result.quote
            if let date = result.asOf, date > (asOf ?? .distantPast) { asOf = date }
        }
        return (quotes, asOf)
    }

    /// The chart endpoint's answer for one symbol (the fallback).
    static func parseChart(_ data: Data) -> (quote: HeatQuote, asOf: Date?)? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let chart = root["chart"] as? [String: Any],
              let result = (chart["result"] as? [Any])?.first as? [String: Any],
              let indicators = result["indicators"] as? [String: Any],
              let series = (indicators["quote"] as? [Any])?.first as? [String: Any]
        else { return nil }
        return quote(closes: series["close"], timestamps: result["timestamp"])
    }

    /// The last close against the one before it. Missing closes are skipped.
    private static func quote(closes: Any?, timestamps: Any?) -> (quote: HeatQuote, asOf: Date?)? {
        guard let closes = closes as? [Any] else { return nil }
        let times = timestamps as? [Any] ?? []
        var bars: [(close: Double, time: Double?)] = []
        for (index, raw) in closes.enumerated() {
            guard let close = (raw as? NSNumber)?.doubleValue, close.isFinite, close > 0 else { continue }
            bars.append((close, index < times.count ? (times[index] as? NSNumber)?.doubleValue : nil))
        }
        guard bars.count >= 2, let last = bars.last else { return nil }
        let previous = bars[bars.count - 2]
        let change = ((last.close / previous.close - 1) * 10_000).rounded() / 100
        return (HeatQuote(price: last.close, change: change), last.time.map { Date(timeIntervalSince1970: $0) })
    }

    // MARK: Fetching

    /// Fetches every symbol in batches. If the spark endpoint gives nothing at all, tries the chart
    /// endpoint symbol by symbol. Returns nil when nothing came back.
    static func fetch(symbols: [String], now: Date = .now, load: @escaping Loader = liveLoad) async -> HeatmapSnapshot? {
        let batches = stride(from: 0, to: symbols.count, by: batchSize).map { Array(symbols[$0..<min($0 + batchSize, symbols.count)]) }
        var quotes: [String: HeatQuote] = [:]
        var asOf: Date?

        await withTaskGroup(of: (quotes: [String: HeatQuote], asOf: Date?).self) { group in
            for batch in batches {
                group.addTask {
                    guard let url = sparkURL(batch), let data = await load(url) else { return ([:], nil) }
                    return parseSpark(data)
                }
            }
            for await part in group {
                quotes.merge(part.quotes) { $1 }
                if let date = part.asOf, date > (asOf ?? .distantPast) { asOf = date }
            }
        }

        if quotes.isEmpty {
            for chunk in stride(from: 0, to: symbols.count, by: 10).map({ Array(symbols[$0..<min($0 + 10, symbols.count)]) }) {
                await withTaskGroup(of: (String, HeatQuote, Date?)?.self) { group in
                    for symbol in chunk {
                        group.addTask {
                            guard let url = chartURL(symbol), let data = await load(url), let parsed = parseChart(data) else { return nil }
                            return (symbol, parsed.quote, parsed.asOf)
                        }
                    }
                    for await part in group {
                        guard let part else { continue }
                        quotes[part.0] = part.1
                        if let date = part.2, date > (asOf ?? .distantPast) { asOf = date }
                    }
                }
            }
        }
        guard !quotes.isEmpty else { return nil }
        return HeatmapSnapshot(quotes: quotes, asOf: asOf ?? now, fetched: now)
    }

    static let liveLoad: Loader = { url in
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (Court & Capital)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return data
    }

    // MARK: Cache

    static func cached(defaults: UserDefaults = .standard) -> HeatmapSnapshot? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(HeatmapSnapshot.self, from: data)
    }

    static func store(_ snapshot: HeatmapSnapshot, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: cacheKey) }
    }

    // MARK: Words

    private static let newYork: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return calendar
    }()

    /// "At Wednesday’s close", or "During Wednesday’s trading" while the New York session is still on.
    static func caption(asOf: Date, now: Date) -> String {
        let weekday = EditionFormat.weekday(asOf)
        let parts = newYork.dateComponents([.hour, .minute, .weekday], from: now)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let isWeekday = (2...6).contains(parts.weekday ?? 1)
        if newYork.isDate(asOf, inSameDayAs: now), isWeekday, minutes < 16 * 60 + 15 {
            return "During \(weekday)’s trading"
        }
        return "At \(weekday)’s close"
    }

    /// "+1.31%", "−0.27%" with a true minus sign
    static func percent(_ change: Double) -> String {
        let value = abs(change) < 0.005 ? 0 : change
        return String(format: "%@%.2f%%", value > 0 ? "+" : value < 0 ? "−" : "", abs(value))
    }

    static func price(_ price: Double) -> String { String(format: "$%.2f", price) }

    /// "$3.6 trillion", "$480 billion"
    static func marketCap(_ cap: Double) -> String {
        if cap >= 1e12 { return String(format: "$%.1f trillion", cap / 1e12) }
        return String(format: "$%.0f billion", cap / 1e9)
    }
}
