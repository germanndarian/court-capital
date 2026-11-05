import CoreGraphics

/// Squarified treemap (Bruls, Huizing and van Wijk): rectangles whose areas follow the weights,
/// kept as close to square as possible so they stay readable.
enum Treemap {
    /// One rectangle per weight, in the order given. A weight that isn't a positive number gets
    /// an empty rectangle. The rectangles tile `rect` without overlapping.
    static func layout(weights: [Double], in rect: CGRect) -> [CGRect] {
        var frames = Array(repeating: CGRect(x: rect.minX, y: rect.minY, width: 0, height: 0), count: weights.count)
        guard rect.width > 0, rect.height > 0 else { return frames }

        let items = weights.enumerated()
            .filter { $0.element.isFinite && $0.element > 0 }
            .sorted { $0.element > $1.element }
        let total = items.reduce(0) { $0 + $1.element }
        guard total > 0 else { return frames }

        let scale = Double(rect.width * rect.height) / total
        var remaining = rect
        var row: [(index: Int, area: Double)] = []

        func worstRatio(_ row: [(index: Int, area: Double)], side: Double) -> Double {
            let sum = row.reduce(0) { $0 + $1.area }
            guard let biggest = row.map(\.area).max(), let smallest = row.map(\.area).min(), sum > 0, smallest > 0 else {
                return .infinity
            }
            let squared = side * side
            return max(squared * biggest / (sum * sum), sum * sum / (squared * smallest))
        }

        func place(_ row: [(index: Int, area: Double)]) {
            let sum = row.reduce(0) { $0 + $1.area }
            guard sum > 0 else { return }
            if remaining.width >= remaining.height {
                // A column down the left edge.
                let width = min(CGFloat(sum) / remaining.height, remaining.width)
                var y = remaining.minY
                for item in row {
                    let height = CGFloat(item.area / sum) * remaining.height
                    frames[item.index] = CGRect(x: remaining.minX, y: y, width: width, height: height)
                    y += height
                }
                remaining = CGRect(x: remaining.minX + width, y: remaining.minY, width: remaining.width - width, height: remaining.height)
            } else {
                // A row along the top edge.
                let height = min(CGFloat(sum) / remaining.width, remaining.height)
                var x = remaining.minX
                for item in row {
                    let width = CGFloat(item.area / sum) * remaining.width
                    frames[item.index] = CGRect(x: x, y: remaining.minY, width: width, height: height)
                    x += width
                }
                remaining = CGRect(x: remaining.minX, y: remaining.minY + height, width: remaining.width, height: remaining.height - height)
            }
        }

        var next = 0
        while next < items.count {
            let item = (index: items[next].offset, area: items[next].element * scale)
            let side = Double(min(remaining.width, remaining.height))
            if row.isEmpty || worstRatio(row + [item], side: side) <= worstRatio(row, side: side) {
                row.append(item)
                next += 1
            } else {
                place(row)
                row = []
            }
        }
        place(row)
        return frames
    }
}
