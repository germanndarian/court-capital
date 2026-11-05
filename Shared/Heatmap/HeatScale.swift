import Foundation

/// Maps a day's percent change to one of seven colour steps, from deep red (0) through grey (3)
/// to deep green (6). The legend's marks sit at the steps' centres.
enum HeatScale {
    /// Changes beyond this many percent, either way, all take the strongest colour.
    static let limit = 8.0
    static let steps = 7
    static let neutral = 3
    /// The percent change each step's legend mark stands for.
    static let marks: [Double] = [-8, -5, -2, 0, 2, 5, 8]

    static func step(for change: Double) -> Int {
        guard change.isFinite else { return neutral }
        switch change {
        case ..<(-6.5): return 0
        case ..<(-3.5): return 1
        case ..<(-0.5): return 2
        case ...0.5: return 3
        case ...3.5: return 4
        case ...6.5: return 5
        default: return 6
        }
    }
}
