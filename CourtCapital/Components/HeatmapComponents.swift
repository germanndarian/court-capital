import SwiftUI

/// The treemap: sector groups with their names above, a block for each stock.
struct HeatmapView: View {
    let universe: HeatmapUniverse
    let quotes: [String: HeatQuote]
    @Binding var focus: String?
    @Binding var selected: String?

    /// Grows the name strips with Dynamic Type.
    @ScaledMetric(relativeTo: .caption) private var scale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let sectors = HeatmapLayout.make(
                universe: universe,
                quotes: quotes,
                in: proxy.size,
                headerHeight: 17 * min(scale, 1.6),
                focus: focus
            )
            ZStack(alignment: .topLeading) {
                ForEach(sectors) { sector in
                    ForEach(sector.stocks) { block in
                        StockCell(block: block, isSelected: selected == block.id) {
                            selected = selected == block.id ? nil : block.id
                        }
                    }
                    if sector.header.height > 0 {
                        SectorHeader(sector: sector, isFocused: focus == sector.name) {
                            focus = focus == sector.name ? nil : sector.name
                            selected = nil
                        }
                    }
                }
            }
        }
        .aspectRatio(focus == nil ? 1 / 1.65 : 1 / 1.15, contentMode: .fit)
    }
}

private struct SectorHeader: View {
    let sector: SectorBlock
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(sector.name)
                .typeStyle(.label(8.5, tracking: 0.14).fixed)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .padding(.horizontal, 3)
                .frame(width: sector.header.width, height: sector.header.height, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: sector.header.minX, y: sector.header.minY)
        .accessibilityLabel(sector.name)
        .accessibilityHint(isFocused ? "Shows all sectors" : "Shows only this sector")
        .accessibilityAddTraits(.isHeader)
    }
}

private struct StockCell: View {
    let block: StockBlock
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let step = HeatScale.step(for: block.quote.change)
        let frame = block.frame
        let side = min(frame.width, frame.height)
        let tickerSize = min(max(side * 0.24, 8), 26)
        let percentSize = tickerSize * 0.8
        let showsTicker = frame.width >= tickerSize * Double(block.stock.ticker.count) * 0.7 + 4 && frame.height >= tickerSize * 1.5
        let showsPercent = showsTicker && frame.height >= tickerSize * 2.7 && frame.width >= percentSize * 4.4

        Button(action: action) {
            ZStack {
                Rectangle().fill(Theme.heat(step))
                if showsTicker {
                    VStack(spacing: 1) {
                        Text(block.stock.ticker)
                            .typeStyle(TypeStyle(face: .playfair, size: tickerSize, weight: 600, relativeTo: nil))
                        if showsPercent {
                            Text(HeatmapFeed.percent(block.quote.change))
                                .typeStyle(TypeStyle(face: .newsreader, size: percentSize, weight: 500, tabularFigures: true, relativeTo: nil))
                        }
                    }
                    .foregroundStyle(Theme.heatText(step))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(2)
                }
                Rectangle().strokeBorder(Theme.paper, lineWidth: 0.75)
                if isSelected {
                    Rectangle().strokeBorder(Theme.ink, lineWidth: 2)
                }
            }
            .frame(width: frame.width, height: frame.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: frame.minX, y: frame.minY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(block.stock.name), \(block.stock.ticker)")
        .accessibilityValue(spoken(block.quote.change))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func spoken(_ change: Double) -> String {
        let value = String(format: "%.2f", abs(change))
        if abs(change) < 0.005 { return "unchanged" }
        return change > 0 ? "up \(value) percent" : "down \(value) percent"
    }
}

/// What was tapped: name, price, change, market value. Or a hint, and the way back from a sector.
struct HeatmapDetail: View {
    let stock: HeatStock?
    let quote: HeatQuote?
    @Binding var focus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let stock, let quote {
                HStack(alignment: .firstTextBaseline) {
                    Text(stock.name)
                        .typeStyle(.display(20, relativeTo: .title3))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Text(HeatmapFeed.percent(quote.change))
                        .typeStyle(.figure)
                        .foregroundStyle(quote.change < 0 ? Theme.down : quote.change > 0 ? Theme.up : Theme.inkMuted)
                }
                Text("\(stock.ticker) · \(HeatmapFeed.price(quote.price)) · \(HeatmapFeed.marketCap(HeatmapLayout.cap(stock, quote))) · \(stock.sector)")
                    .typeStyle(.text(13, italic: true, relativeTo: .footnote))
                    .foregroundStyle(Theme.inkMuted)
            } else {
                Text(focus.map { "\($0), largest first" } ?? "Tap a block for the price. Tap a sector name to focus on it.")
                    .typeStyle(.text(13, italic: true, relativeTo: .footnote))
                    .foregroundStyle(Theme.inkMuted)
            }
            if focus != nil {
                Button {
                    focus = nil
                } label: {
                    Text("All sectors")
                        .typeStyle(.label(10))
                        .foregroundStyle(Theme.brassText)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The colour scale from −8% to +8%, in the seven steps the blocks use.
struct HeatmapLegend: View {
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(0..<HeatScale.steps, id: \.self) { step in
                    Rectangle().fill(Theme.heat(step)).frame(height: 10)
                }
            }
            HStack(spacing: 2) {
                ForEach(Array(HeatScale.marks.enumerated()), id: \.offset) { _, mark in
                    Text(label(mark))
                        .typeStyle(.text(10.5, weight: 500, relativeTo: .caption2))
                        .foregroundStyle(Theme.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Colour scale")
        .accessibilityValue("Red for falls up to 8 percent or more, grey near no change, green for gains up to 8 percent or more")
    }

    private func label(_ mark: Double) -> String {
        mark == 0 ? "0%" : mark > 0 ? "+\(Int(mark))%" : "−\(Int(-mark))%"
    }
}
