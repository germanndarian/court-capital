import Foundation

/// One stock on the heatmap. The list lives in `heatmap-universe.json` and is kept by hand.
struct HeatStock: Codable, Hashable, Identifiable, Sendable {
    /// Yahoo Finance symbol, e.g. "BRK-B"
    let ticker: String
    let name: String
    let sector: String
    /// Shares outstanding in millions (approximate). Block area is this times the price.
    let sharesMillions: Double

    var id: String { ticker }
}

/// The stocks the heatmap draws: roughly the 100 biggest of the S&P 500.
struct HeatmapUniverse: Codable, Sendable {
    /// When the list was last checked by hand, e.g. "2026-11"
    let updated: String
    let stocks: [HeatStock]

    static let empty = HeatmapUniverse(updated: "", stocks: [])

    var symbols: [String] { stocks.map(\.ticker) }

    /// Reads the bundled list. Entries without a ticker, sector or a positive share count are dropped.
    static func decode(_ data: Data) -> HeatmapUniverse? {
        guard let universe = try? JSONDecoder().decode(HeatmapUniverse.self, from: data) else { return nil }
        let valid = universe.stocks.filter {
            !$0.ticker.isEmpty && !$0.sector.isEmpty && $0.sharesMillions.isFinite && $0.sharesMillions > 0
        }
        return HeatmapUniverse(updated: universe.updated, stocks: valid)
    }

    static func bundled(in bundle: Bundle = .main) -> HeatmapUniverse? {
        guard let url = bundle.url(forResource: "heatmap-universe", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return decode(data)
    }
}
