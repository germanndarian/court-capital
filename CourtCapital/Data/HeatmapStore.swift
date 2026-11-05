import Foundation
import Observation

/// The Markets tab's figures: the last good fetch from the device, then fresh ones from Yahoo.
@MainActor
@Observable
final class HeatmapStore {
    let universe: HeatmapUniverse
    private(set) var snapshot: HeatmapSnapshot?
    private(set) var isRefreshing = false
    /// Set when the last attempt failed
    private(set) var problem: String?

    /// How long figures count as fresh when the tab opens.
    private let freshFor: TimeInterval = 5 * 60

    init(universe: HeatmapUniverse? = nil, snapshot: HeatmapSnapshot? = nil) {
        self.universe = universe ?? HeatmapUniverse.bundled() ?? .empty
        self.snapshot = snapshot ?? HeatmapFeed.cached()
    }

    /// "At Wednesday’s close"
    var caption: String? {
        snapshot.map { HeatmapFeed.caption(asOf: $0.asOf, now: .now) }
    }

    func refresh(force: Bool = false) async {
        guard !isRefreshing, !universe.stocks.isEmpty else { return }
        if !force, let snapshot, Date.now.timeIntervalSince(snapshot.fetched) < freshFor { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = await HeatmapFeed.fetch(symbols: universe.symbols, previous: snapshot) {
            snapshot = fresh
            problem = nil
            HeatmapFeed.store(fresh)
        } else {
            problem = snapshot == nil
                ? "The prices couldn’t be loaded. Pull down to try again."
                : "Couldn’t update just now. These are the last figures we have."
        }
    }
}
