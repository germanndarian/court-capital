import CoreGraphics
import Foundation

struct StockBlock: Identifiable, Sendable {
    let stock: HeatStock
    let quote: HeatQuote
    let frame: CGRect
    /// Market cap in US dollars, shares times price
    let cap: Double

    var id: String { stock.ticker }
}

struct SectorBlock: Identifiable, Sendable {
    let name: String
    /// The whole group, name included
    let frame: CGRect
    /// The strip for the sector's name; empty when the group is too small for one
    let header: CGRect
    let stocks: [StockBlock]
    let cap: Double

    var id: String { name }
}

/// Sector groups first, then the stocks inside each: two passes of the squarified treemap.
enum HeatmapLayout {
    static func cap(_ stock: HeatStock, _ quote: HeatQuote) -> Double {
        stock.sharesMillions * 1_000_000 * quote.price
    }

    /// `focus` lays out only that sector across the whole area. Stocks without a quote are left out.
    static func make(
        universe: HeatmapUniverse,
        quotes: [String: HeatQuote],
        in size: CGSize,
        headerHeight: CGFloat,
        focus: String? = nil
    ) -> [SectorBlock] {
        var bySector: [String: [(stock: HeatStock, quote: HeatQuote, cap: Double)]] = [:]
        for stock in universe.stocks {
            guard let quote = quotes[stock.ticker] else { continue }
            let cap = cap(stock, quote)
            guard cap.isFinite, cap > 0, focus == nil || focus == stock.sector else { continue }
            bySector[stock.sector, default: []].append((stock, quote, cap))
        }
        let names = bySector.keys.sorted { lhs, rhs in
            let l = bySector[lhs]!.reduce(0) { $0 + $1.cap }, r = bySector[rhs]!.reduce(0) { $0 + $1.cap }
            return l == r ? lhs < rhs : l > r
        }
        let area = CGRect(origin: .zero, size: size)
        let frames = Treemap.layout(weights: names.map { name in bySector[name]!.reduce(0) { $0 + $1.cap } }, in: area)

        return zip(names, frames).map { name, frame in
            let members = bySector[name]!
            let showsHeader = headerHeight > 0 && frame.width >= 44 && frame.height >= headerHeight * 2.5
            let header = showsHeader
                ? CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: headerHeight)
                : CGRect(x: frame.minX, y: frame.minY, width: 0, height: 0)
            let content = CGRect(x: frame.minX, y: frame.minY + header.height, width: frame.width, height: frame.height - header.height)
            let stockFrames = Treemap.layout(weights: members.map(\.cap), in: content)
            let blocks = zip(members, stockFrames).map {
                StockBlock(stock: $0.stock, quote: $0.quote, frame: $1, cap: $0.cap)
            }
            return SectorBlock(name: name, frame: frame, header: header, stocks: blocks, cap: members.reduce(0) { $0 + $1.cap })
        }
    }
}
