import Foundation

/// A market the app adds itself because the edition's data doesn't carry it.
struct ExtraMarket: Sendable, Hashable {
    /// Short name for the strip and widgets
    let name: String
    let fullName: String
    let listing: String
    /// Yahoo Finance symbol
    let symbol: String
    /// How the market would be named if the edition's own data ever carried it
    let keyword: String

    /// iShares MSCI ACWI UCITS ETF USD (Acc), ISIN IE00B6R52259, priced in US dollars on the
    /// London Stock Exchange (ISAC). The Swiss listing in francs would be SSAC.SW.
    static let acwi = ExtraMarket(
        name: "MSCI ACWI",
        fullName: "iShares MSCI ACWI UCITS ETF",
        listing: "USD (Acc)",
        symbol: "ISAC.L",
        keyword: "ACWI"
    )
}

/// Closing prices for extra markets, from Yahoo Finance's public chart endpoint (no key).
/// Like the edition's own figures, a quote is the last close before the edition's date and
/// its change on that day. Quotes are kept on the device, so they show offline too.
enum MarketQuotes {
    private static let cacheKey = "extraQuotes.v1"
    private static let maxCached = 60

    /// The edition's own figure if your Notion task ever includes the market, else the app's.
    static func quote(_ market: ExtraMarket, in edition: Edition, fetched: Quote?) -> Quote? {
        edition.markets.quotes.first { $0.name.localizedCaseInsensitiveContains(market.keyword) } ?? fetched
    }

    static func cached(_ market: ExtraMarket, for editionDate: String) -> Quote? {
        guard let values = cache()["\(market.symbol)|\(editionDate)"], values.count == 2 else { return nil }
        return Quote(name: market.name, level: values[0], change: values[1])
    }

    /// The close before `editionDate`, from the device if it's been fetched before.
    static func quote(_ market: ExtraMarket, for editionDate: String) async -> Quote? {
        if let cached = cached(market, for: editionDate) { return cached }
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(market.symbol)?range=1mo&interval=1d") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (Court & Capital)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let close = lastClose(in: data, before: editionDate)
        else { return nil }
        store(close, market: market, editionDate: editionDate)
        return Quote(name: market.name, level: close.level, change: close.change)
    }

    /// The last completed close before `editionDate` (in Zürich dates) and its percent change.
    static func lastClose(in chart: Data, before editionDate: String) -> (level: Double, change: Double)? {
        struct Chart: Decodable {
            struct Body: Decodable { let result: [Result]? }
            struct Result: Decodable {
                let timestamp: [Double]?
                let indicators: Indicators
            }
            struct Indicators: Decodable { let quote: [Series] }
            struct Series: Decodable { let close: [Double?]? }
            let chart: Body
        }
        guard let result = try? JSONDecoder().decode(Chart.self, from: chart).chart.result?.first,
              let timestamps = result.timestamp,
              let closes = result.indicators.quote.first?.close
        else { return nil }
        let bars = zip(timestamps, closes).compactMap { timestamp, close -> (date: String, close: Double)? in
            guard let close else { return nil }
            return (EditionCalendar.iso(Date(timeIntervalSince1970: timestamp)), close)
        }
        .filter { $0.date < editionDate }
        guard bars.count >= 2, let last = bars.last else { return nil }
        let previous = bars[bars.count - 2]
        let change = ((last.close / previous.close - 1) * 10_000).rounded() / 100
        return ((last.close * 100).rounded() / 100, change)
    }

    // MARK: Cache

    private static func cache() -> [String: [Double]] {
        UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: [Double]] ?? [:]
    }

    private static func store(_ close: (level: Double, change: Double), market: ExtraMarket, editionDate: String) {
        var cache = cache()
        cache["\(market.symbol)|\(editionDate)"] = [close.level, close.change]
        if cache.count > maxCached {
            for key in cache.keys.sorted().prefix(cache.count - maxCached) { cache[key] = nil }
        }
        UserDefaults.standard.set(cache, forKey: cacheKey)
    }
}
