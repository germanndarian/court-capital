import CoreGraphics
import Foundation
import Testing

// Spark answers as Yahoo sends them: symbol -> bars. Never the real network.
private let sparkFixture = Data("""
{"AAPL":{"symbol":"AAPL","timestamp":[1793367000,1793629800,1793716200],"close":[100.0,null,102.5]},
 "MSFT":{"symbol":"MSFT","timestamp":[1793367000,1793629800,1793716200],"close":[200.0,190.0,180.0]},
 "ONE":{"symbol":"ONE","timestamp":[1793367000],"close":[10.0]},
 "BAD":"nonsense",
 "ODD":{"close":"oops"}}
""".utf8)

@Suite("Heatmap data")
struct HeatmapFeedTests {
    @Test("Spark: last close against the one before, missing closes skipped")
    func parseSpark() throws {
        let parsed = HeatmapFeed.parseSpark(sparkFixture)
        let apple = try #require(parsed.quotes["AAPL"])
        #expect(apple.price == 102.5)
        #expect(apple.change == 2.5)
        #expect(parsed.quotes["MSFT"]?.change == -5.26)
        #expect(parsed.asOf == Date(timeIntervalSince1970: 1_793_716_200))
    }

    @Test("Garbage, a lone bar and malformed entries cost only their own stock")
    func garbage() {
        let parsed = HeatmapFeed.parseSpark(sparkFixture)
        #expect(Set(parsed.quotes.keys) == ["AAPL", "MSFT"])
        #expect(HeatmapFeed.parseSpark(Data("not json".utf8)).quotes.isEmpty)
        #expect(HeatmapFeed.parseSpark(Data("[1,2]".utf8)).quotes.isEmpty)
        #expect(HeatmapFeed.parseSpark(Data()).quotes.isEmpty)
        #expect(HeatmapFeed.parseChart(Data("{}".utf8)) == nil)
    }

    @Test("Chart fallback parses one symbol")
    func chart() throws {
        let data = Data("""
        {"chart":{"result":[{"timestamp":[1793629800,1793716200],"indicators":{"quote":[{"close":[50.0,51.0]}]}}]}}
        """.utf8)
        let parsed = try #require(HeatmapFeed.parseChart(data))
        #expect(parsed.quote.price == 51)
        #expect(parsed.quote.change == 2)
    }

    @Test("Symbols go out in batches Yahoo accepts, and a missing symbol is just absent")
    func batches() async throws {
        let symbols = (0..<45).map { "S\($0)" } + ["AAPL"]
        let seen = Seen()
        let snapshot = await HeatmapFeed.fetch(symbols: symbols, now: Date(timeIntervalSince1970: 1_793_800_000)) { url in
            await seen.add(url)
            return url.absoluteString.contains("AAPL") ? sparkFixture : Data("{}".utf8)
        }
        let urls = await seen.urls
        #expect(urls.count == 3)
        #expect(urls.allSatisfy { $0.absoluteString.contains("/v8/finance/spark") })
        let result = try #require(snapshot)
        #expect(result.quotes.keys.contains("AAPL"))
        #expect(!result.quotes.keys.contains("S1"))
    }

    @Test("Falls back to the chart endpoint when spark gives nothing, and gives up cleanly")
    func fallback() async throws {
        let chart = Data("""
        {"chart":{"result":[{"timestamp":[1,2],"indicators":{"quote":[{"close":[10,11]}]}}]}}
        """.utf8)
        let snapshot = await HeatmapFeed.fetch(symbols: ["A", "B"]) { url in
            url.absoluteString.contains("/chart/") ? chart : nil
        }
        #expect(snapshot?.quotes.count == 2)
        let nothing = await HeatmapFeed.fetch(symbols: ["A", "B"]) { _ in nil }
        #expect(nothing == nil)
    }

    @Test("The snapshot survives the device cache")
    func cache() throws {
        let defaults = try #require(UserDefaults(suiteName: "heatmap-tests-\(UUID().uuidString)"))
        #expect(HeatmapFeed.cached(defaults: defaults) == nil)
        let snapshot = HeatmapSnapshot(quotes: ["A": HeatQuote(price: 1, change: 2)], asOf: Date(timeIntervalSince1970: 100), fetched: Date(timeIntervalSince1970: 200))
        HeatmapFeed.store(snapshot, defaults: defaults)
        #expect(HeatmapFeed.cached(defaults: defaults) == snapshot)
    }

    @Test("Words: close or trading, percent, market value")
    func words() {
        // Wednesday 4 November 2026: 15:00 in New York is 20:00 UTC.
        let bar = Date(timeIntervalSince1970: 1_793_820_000)
        let during = Date(timeIntervalSince1970: 1_793_820_000 + 3_600)
        let after = Date(timeIntervalSince1970: 1_793_820_000 + 4 * 3_600)
        #expect(HeatmapFeed.caption(asOf: bar, now: during) == "During Wednesday’s trading")
        #expect(HeatmapFeed.caption(asOf: bar, now: after) == "At Wednesday’s close")
        #expect(HeatmapFeed.caption(asOf: bar, now: bar.addingTimeInterval(86_400)) == "At Wednesday’s close")
        #expect(HeatmapFeed.percent(1.314) == "+1.31%")
        #expect(HeatmapFeed.percent(-0.27) == "−0.27%")
        #expect(HeatmapFeed.percent(0) == "0.00%")
        #expect(HeatmapFeed.marketCap(3.64e12) == "$3.6 trillion")
        #expect(HeatmapFeed.marketCap(4.8e11) == "$480 billion")
    }
}

private actor Seen {
    var urls: [URL] = []
    func add(_ url: URL) { urls.append(url) }
}

@Suite("Heatmap layout")
struct HeatmapLayoutTests {
    private let bounds = CGRect(x: 10, y: 20, width: 300, height: 400)

    @Test("Areas follow the weights and the blocks tile the bounds")
    func proportional() {
        let weights: [Double] = [50, 30, 10, 5, 3, 2]
        let frames = Treemap.layout(weights: weights, in: bounds)
        let total = weights.reduce(0, +)
        for (weight, frame) in zip(weights, frames) {
            let share = Double(frame.width * frame.height) / Double(bounds.width * bounds.height)
            #expect(abs(share - weight / total) < 1e-6)
        }
        #expect(abs(frames.reduce(0) { $0 + $1.width * $1.height } - bounds.width * bounds.height) < 0.01)
    }

    @Test("No overlap and nothing outside the bounds")
    func tiling() {
        let weights: [Double] = (1...40).map { Double($0 * $0) }
        let frames = Treemap.layout(weights: weights, in: bounds)
        let slack: CGFloat = 0.001
        for frame in frames {
            #expect(frame.minX >= bounds.minX - slack && frame.maxX <= bounds.maxX + slack)
            #expect(frame.minY >= bounds.minY - slack && frame.maxY <= bounds.maxY + slack)
        }
        for i in frames.indices {
            for j in frames.indices where j > i {
                let overlap = frames[i].intersection(frames[j])
                #expect(overlap.isNull || overlap.width * overlap.height < 0.001)
            }
        }
    }

    @Test("Empty input, zero and bad weights, empty bounds")
    func edges() {
        #expect(Treemap.layout(weights: [], in: bounds).isEmpty)
        let frames = Treemap.layout(weights: [0, 10, -3, .nan, 10], in: bounds)
        #expect(frames.count == 5)
        #expect([0, 2, 3].allSatisfy { frames[$0].width == 0 && frames[$0].height == 0 })
        #expect(abs(frames[1].width * frames[1].height - bounds.width * bounds.height / 2) < 0.01)
        #expect(Treemap.layout(weights: [0, 0], in: bounds).allSatisfy { $0.isEmpty })
        #expect(Treemap.layout(weights: [1, 2], in: .zero).allSatisfy { $0.isEmpty })
        #expect(Treemap.layout(weights: [5], in: bounds) == [bounds])
    }

    private let universe = HeatmapUniverse(updated: "test", stocks: [
        HeatStock(ticker: "AA", name: "A", sector: "Tech", sharesMillions: 10),
        HeatStock(ticker: "BB", name: "B", sector: "Tech", sharesMillions: 5),
        HeatStock(ticker: "CC", name: "C", sector: "Health", sharesMillions: 20),
        HeatStock(ticker: "DD", name: "D", sector: "Health", sharesMillions: 1),
    ])

    @Test("Sectors group their stocks, biggest first, and skip stocks without a quote")
    func sectors() {
        let quotes = ["AA": HeatQuote(price: 10, change: 1), "BB": HeatQuote(price: 10, change: -1), "CC": HeatQuote(price: 10, change: 0)]
        let sectors = HeatmapLayout.make(universe: universe, quotes: quotes, in: CGSize(width: 300, height: 400), headerHeight: 16)
        #expect(sectors.map(\.name) == ["Health", "Tech"])
        #expect(sectors.flatMap(\.stocks).count == 3)
        for sector in sectors {
            #expect(sector.header.height == 16)
            for block in sector.stocks { #expect(sector.frame.insetBy(dx: -0.01, dy: -0.01).contains(block.frame)) }
            #expect(sector.stocks.allSatisfy { $0.frame.minY >= sector.header.maxY - 0.01 })
        }
        let focused = HeatmapLayout.make(universe: universe, quotes: quotes, in: CGSize(width: 300, height: 400), headerHeight: 16, focus: "Tech")
        #expect(focused.count == 1 && focused[0].frame.size == CGSize(width: 300, height: 400))
    }

    @Test("No quotes at all draws nothing")
    func noQuotes() {
        #expect(HeatmapLayout.make(universe: universe, quotes: [:], in: CGSize(width: 300, height: 400), headerHeight: 16).isEmpty)
    }
}

@Suite("Heatmap colours and list")
struct HeatScaleTests {
    @Test("Grey near zero, red and green either side")
    func steps() {
        #expect(HeatScale.step(for: 0) == HeatScale.neutral)
        #expect(HeatScale.step(for: 0.3) == HeatScale.neutral)
        #expect(HeatScale.step(for: -0.3) == HeatScale.neutral)
        #expect(HeatScale.step(for: -1.5) == 2)
        #expect(HeatScale.step(for: 1.5) == 4)
        #expect(HeatScale.step(for: -5) == 1)
        #expect(HeatScale.step(for: 5) == 5)
    }

    @Test("Clamps beyond eight percent, and a bad number is grey")
    func clamps() {
        #expect(HeatScale.step(for: -8) == 0)
        #expect(HeatScale.step(for: 8) == 6)
        #expect(HeatScale.step(for: -40) == 0)
        #expect(HeatScale.step(for: 1000) == 6)
        #expect(HeatScale.step(for: .nan) == HeatScale.neutral)
        #expect(HeatScale.step(for: .infinity) == HeatScale.neutral)
    }

    @Test("The bundled list reads, with no repeats and sensible shares")
    func bundledList() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Shared/Heatmap/heatmap-universe.json")
        let universe = try #require(HeatmapUniverse.decode(try Data(contentsOf: url)))
        #expect(universe.stocks.count >= 90)
        #expect(Set(universe.symbols).count == universe.stocks.count)
        #expect(universe.stocks.allSatisfy { $0.sharesMillions > 0 })
        #expect(HeatmapUniverse.decode(Data("nope".utf8)) == nil)
    }
}
