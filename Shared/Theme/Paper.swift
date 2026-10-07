import SwiftUI
import UIKit

/// Paper grain: fractal noise tinted with the paper's ink, 9% by day and 5% by night,
/// tiled every 180 pt. Generated once in code so nothing large ships in the bundle.
enum PaperGrain {
    static let day = makeTile(red: 0.36, green: 0.28, blue: 0.16, opacity: 0.09)
    static let night = makeTile(red: 0.93, green: 0.86, blue: 0.70, opacity: 0.05)

    private static let tilePoints = 180
    private static let scale = 2

    /// Three octaves of periodic value noise at 0.8 cycles per point, the browser's
    /// `feTurbulence baseFrequency="0.8" numOctaves="3" stitchTiles="stitch"`.
    private static func makeTile(red: Double, green: Double, blue: Double, opacity: Double) -> UIImage {
        let size = tilePoints * scale
        let baseCells = Int(Double(tilePoints) * 0.8)
        let octaves: [(cells: Int, amplitude: Double)] = [(baseCells, 1), (baseCells * 2, 0.5), (baseCells * 4, 0.25)]
        var generator = SplitMix64(seed: 0xC0C0A)
        let lattices = octaves.map { octave in
            (0..<(octave.cells * octave.cells)).map { _ in generator.nextUnit() * 2 - 1 }
        }

        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                var sum = 0.0
                for (index, octave) in octaves.enumerated() {
                    sum += octave.amplitude * sample(lattices[index], cells: octave.cells, x: x, y: y, size: size)
                }
                let value = min(max(0.5 + sum * 0.3, 0), 1)
                let alpha = opacity * value
                let offset = (y * size + x) * 4
                pixels[offset] = UInt8(red * alpha * 255)
                pixels[offset + 1] = UInt8(green * alpha * 255)
                pixels[offset + 2] = UInt8(blue * alpha * 255)
                pixels[offset + 3] = UInt8(alpha * 255)
            }
        }

        let context = CGContext(
            data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return UIImage(cgImage: context.makeImage()!, scale: CGFloat(scale), orientation: .up)
    }

    private static func sample(_ lattice: [Double], cells: Int, x: Int, y: Int, size: Int) -> Double {
        let fx = Double(x) / Double(size) * Double(cells)
        let fy = Double(y) / Double(size) * Double(cells)
        let x0 = Int(fx), y0 = Int(fy)
        let tx = smooth(fx - Double(x0)), ty = smooth(fy - Double(y0))
        func value(_ i: Int, _ j: Int) -> Double { lattice[(j % cells) * cells + (i % cells)] }
        let top = value(x0, y0) + (value(x0 + 1, y0) - value(x0, y0)) * tx
        let bottom = value(x0, y0 + 1) + (value(x0 + 1, y0 + 1) - value(x0, y0 + 1)) * tx
        return top + (bottom - top) * ty
    }

    private static func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
}

private struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// Paper stock with grain. By night the page also catches a faint brass glow from above.
struct PaperBackground: View {
    var glow = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Theme.paper
            .overlay {
                Image(uiImage: colorScheme == .dark ? PaperGrain.night : PaperGrain.day)
                    .resizable(resizingMode: .tile)
            }
            .overlay {
                if glow && colorScheme == .dark {
                    NightGlow()
                }
            }
    }
}

/// `radial-gradient(130% 70% at 50% 0%, rgba(205,174,110,.07), transparent 65%)`
private struct NightGlow: View {
    var body: some View {
        GeometryReader { proxy in
            let radiusX = proxy.size.width * 1.3
            let radiusY = proxy.size.height * 0.7
            Rectangle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(hex: 0xCDAE6E, opacity: 0.07), location: 0),
                            .init(color: Color(hex: 0xCDAE6E, opacity: 0), location: 0.65),
                        ],
                        center: .top, startRadius: 0, endRadius: radiusX
                    )
                )
                .frame(width: proxy.size.width, height: radiusX)
                .scaleEffect(x: 1, y: radiusY / radiusX, anchor: .top)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .allowsHitTesting(false)
    }
}
