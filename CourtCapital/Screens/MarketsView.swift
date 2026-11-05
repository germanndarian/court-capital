import SwiftUI

/// The Markets tab: a heatmap of the biggest US stocks, grouped by sector. Block area is market
/// cap; colour is the day's change.
struct MarketsView: View {
    @Environment(AppModel.self) private var model
    @State private var store = HeatmapStore()
    @State private var focus: String?
    @State private var selected: String?

    private var isVisible: Bool { model.tab == .markets }

    var body: some View {
        Group {
            if let snapshot = store.snapshot {
                ScrollView {
                    page(snapshot)
                }
                .scrollIndicators(.hidden)
            } else {
                ScrollView {
                    if store.isRefreshing {
                        NoticeView(title: "Fetching the markets", message: nil, showsProgress: true)
                            .containerRelativeFrame(.vertical)
                    } else {
                        NoticeView(title: "Markets unavailable", message: store.problem ?? "Pull down to load the prices.")
                            .containerRelativeFrame(.vertical)
                    }
                }
            }
        }
        .refreshable { await store.refresh(force: true) }
        .paperScreen()
        .task(id: isVisible) {
            if isVisible { await store.refresh() }
        }
    }

    private func page(_ snapshot: HeatmapSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeading(kicker: "Wall Street", title: "Markets")
                .padding(.top, 20)
            Text(store.caption ?? "")
                .typeStyle(.text(14, italic: true, relativeTo: .subheadline))
                .foregroundStyle(Theme.inkMuted)
                .padding(.top, 6)
            if let problem = store.problem {
                Text(problem)
                    .typeStyle(.text(13, italic: true, relativeTo: .footnote))
                    .foregroundStyle(Theme.burgundy)
                    .padding(.top, 4)
            }
            DoubleRule()
                .padding(.top, 14)

            HeatmapDetail(
                stock: selected.flatMap { ticker in store.universe.stocks.first { $0.ticker == ticker } },
                quote: selected.flatMap { snapshot.quotes[$0] },
                focus: $focus
            )
            .padding(.vertical, 10)

            HeatmapView(universe: store.universe, quotes: snapshot.quotes, focus: $focus, selected: $selected)

            HeatmapLegend()
                .padding(.top, 14)
            Text("Area is market value. Colour is the change on the day.")
                .typeStyle(.text(12, italic: true, relativeTo: .caption))
                .foregroundStyle(Theme.inkMuted)
                .padding(.top, 8)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 40)
        .animation(.snappy, value: focus)
    }
}
