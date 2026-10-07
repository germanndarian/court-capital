// Renders the README artwork into docs/readme from simulator screenshots.
//
//   swift Tools/render-readme-art.swift <screenshots-dir>
//
// The screenshots directory holds 1206 × 2622 iPhone 17 Pro captures named
// today-, story-, story2-, archive-, settings- and home- with a -day or -night suffix
// (home- is the Home Screen with the medium and small widgets in the top-left corner).
// Every piece comes out twice, Day and Night, for GitHub's light and dark themes.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count > 1 else {
    print("usage: swift Tools/render-readme-art.swift <screenshots-dir>")
    exit(1)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let shots = URL(fileURLWithPath: CommandLine.arguments[1])
let output = root.appendingPathComponent("docs/readme")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for name in ["PlayfairDisplay-Variable", "PlayfairDisplay-Italic-Variable", "Newsreader-Variable", "Newsreader-Italic-Variable"] {
    CTFontManagerRegisterFontsForURL(root.appendingPathComponent("Shared/Fonts/\(name).ttf") as CFURL, .process, nil)
}

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: sRGB, components: [
        CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha,
    ])!
}

// MARK: - Looks

struct Look {
    let name: String
    let dark: Bool
    let paper: UInt32
    let paperInset: UInt32
    let ink: UInt32
    let muted: UInt32
    let rule: CGColor
    let ruleStrong: UInt32
    let brass: UInt32
    let brassText: UInt32
    let canvas: UInt32
    let grain: (r: Double, g: Double, b: Double, a: Double)
    let widgetBackdrop: (UInt32, UInt32)
}

let day = Look(
    name: "day", dark: false, paper: 0xF4EEE1, paperInset: 0xEAE2D1, ink: 0x16202F, muted: 0x5E584C,
    rule: color(0x16202F, 0.2), ruleStrong: 0x16202F, brass: 0xA27D3A, brassText: 0x80602A,
    canvas: 0xE4DED1, grain: (0.36, 0.28, 0.16, 0.09), widgetBackdrop: (0xCFC2A8, 0xA8956F)
)
let night = Look(
    name: "night", dark: true, paper: 0x0E1B15, paperInset: 0x15271F, ink: 0xECE3CD, muted: 0xADA48C,
    rule: color(0xCDAE6E, 0.26), ruleStrong: 0xB8995C, brass: 0xC4A262, brassText: 0xCDAE6E,
    canvas: 0x0B1510, grain: (0.93, 0.86, 0.70, 0.05), widgetBackdrop: (0x1F3328, 0x0B1510)
)

// MARK: - Fonts

enum Face {
    case playfair, playfairItalic, newsreader, newsreaderItalic, mono

    var postScriptName: String {
        switch self {
        case .playfair: "PlayfairDisplay-Regular"
        case .playfairItalic: "PlayfairDisplay-Italic"
        case .newsreader: "Newsreader16pt-Regular"
        case .newsreaderItalic: "Newsreader16pt-Italic"
        case .mono: "Menlo-Regular"
        }
    }
}

/// `size` is in pixels; `points` is the design size, which picks Newsreader's optical size.
func font(_ face: Face, _ size: CGFloat, weight: CGFloat = 400, points: CGFloat? = nil) -> CTFont {
    var attributes: [CFString: Any] = [kCTFontNameAttribute: face.postScriptName]
    if face != .mono {
        var variation: [Int: CGFloat] = [0x7767_6874: weight]
        if face == .newsreader || face == .newsreaderItalic {
            variation[0x6F70_737A] = min(max(points ?? size, 6), 72)
        }
        attributes[kCTFontVariationAttribute] = variation
    }
    return CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes(attributes as CFDictionary), size, nil)
}

// MARK: - Paper grain

/// Tileable value noise, the same grain the app draws (feTurbulence 0.8, three octaves).
func grainTile(_ look: Look, pixelsPerPoint: CGFloat) -> CGImage {
    let size = Int(180 * pixelsPerPoint)
    let base = 144
    let octaves: [(cells: Int, amplitude: Double)] = [(base, 1), (base * 2, 0.5), (base * 4, 0.25)]
    var state: UInt64 = 0xC0C0A
    func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
    let lattices = octaves.map { o in (0..<(o.cells * o.cells)).map { _ in next() * 2 - 1 } }
    func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    for y in 0..<size {
        for x in 0..<size {
            var sum = 0.0
            for (i, o) in octaves.enumerated() {
                let fx = Double(x) / Double(size) * Double(o.cells), fy = Double(y) / Double(size) * Double(o.cells)
                let x0 = Int(fx), y0 = Int(fy)
                let tx = smooth(fx - Double(x0)), ty = smooth(fy - Double(y0))
                func v(_ a: Int, _ b: Int) -> Double { lattices[i][(b % o.cells) * o.cells + (a % o.cells)] }
                let top = v(x0, y0) + (v(x0 + 1, y0) - v(x0, y0)) * tx
                let bottom = v(x0, y0 + 1) + (v(x0 + 1, y0 + 1) - v(x0, y0 + 1)) * tx
                sum += o.amplitude * (top + (bottom - top) * ty)
            }
            let alpha = look.grain.a * min(max(0.5 + sum * 0.3, 0), 1)
            let offset = (y * size + x) * 4
            pixels[offset] = UInt8(look.grain.r * alpha * 255)
            pixels[offset + 1] = UInt8(look.grain.g * alpha * 255)
            pixels[offset + 2] = UInt8(look.grain.b * alpha * 255)
            pixels[offset + 3] = UInt8(alpha * 255)
        }
    }
    let context = CGContext(data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return context.makeImage()!
}

let grain = [day.name: grainTile(day, pixelsPerPoint: 2), night.name: grainTile(night, pixelsPerPoint: 2)]

// MARK: - Canvas

enum Align { case left, center, right }

struct Run {
    let text: String
    let font: CTFont
    let color: CGColor
}

/// A bitmap with a top-left origin, like the screen.
final class Canvas {
    let context: CGContext
    let width: CGFloat
    let height: CGFloat

    init(_ width: Int, _ height: Int) {
        self.width = CGFloat(width)
        self.height = CGFloat(height)
        context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.translateBy(x: 0, y: self.height)
        context.scaleBy(x: 1, y: -1)
    }

    var bounds: CGRect { CGRect(x: 0, y: 0, width: width, height: height) }

    func fill(_ rect: CGRect, _ fill: CGColor) {
        context.setFillColor(fill)
        context.fill(rect)
    }

    /// Paper stock with grain, and the brass glow from above at night.
    func paper(_ rect: CGRect, _ look: Look, base: UInt32? = nil, glow: Bool = true) {
        context.saveGState()
        context.clip(to: rect)
        fill(rect, color(base ?? look.paper))
        let tile = grain[look.name]!
        context.draw(tile, in: CGRect(x: 0, y: 0, width: CGFloat(tile.width), height: CGFloat(tile.height)), byTiling: true)
        if look.dark && glow {
            let gradient = CGGradient(colorsSpace: sRGB, colors: [color(0xCDAE6E, 0.08), color(0xCDAE6E, 0)] as CFArray, locations: [0, 1])!
            context.saveGState()
            context.translateBy(x: rect.midX, y: rect.minY)
            context.scaleBy(x: 1, y: 0.7 * rect.height / (1.3 * rect.width))
            context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1.3 * rect.width * 0.65, options: [])
            context.restoreGState()
        }
        context.restoreGState()
    }

    func linearGradient(_ rect: CGRect, from top: UInt32, to bottom: UInt32) {
        let gradient = CGGradient(colorsSpace: sRGB, colors: [color(top), color(bottom)] as CFArray, locations: [0, 1])!
        context.saveGState()
        context.clip(to: rect)
        context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY),
                                   end: CGPoint(x: rect.maxX - rect.width * 0.3, y: rect.maxY),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    }

    func line(from a: CGPoint, to b: CGPoint, _ stroke: CGColor, width: CGFloat) {
        context.setStrokeColor(stroke)
        context.setLineWidth(width)
        context.strokeLineSegments(between: [a, b])
    }

    /// Heavy line, gap, hairline: the masthead double rule.
    func doubleRule(x: CGFloat, y: CGFloat, width: CGFloat, _ stroke: CGColor, scale: CGFloat) {
        fill(CGRect(x: x, y: y, width: width, height: 1.5 * scale), stroke)
        fill(CGRect(x: x, y: y + 3.5 * scale, width: width, height: 0.5 * scale), stroke)
    }

    func lozenge(center: CGPoint, size: CGFloat, _ tint: CGColor) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: .pi / 4)
        fill(CGRect(x: -size / 2, y: -size / 2, width: size, height: size), tint)
        context.restoreGState()
    }

    /// Draws runs on one line with the baseline at `y`; returns the line width.
    @discardableResult
    func text(_ runs: [Run], x: CGFloat, y: CGFloat, align: Align = .left, tracking: CGFloat = 0, uppercase: Bool = false) -> CGFloat {
        let string = NSMutableAttributedString()
        for run in runs {
            string.append(NSAttributedString(string: uppercase ? run.text.uppercased() : run.text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): run.font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): run.color,
                NSAttributedString.Key(kCTKernAttributeName as String): tracking,
            ]))
        }
        let line = CTLineCreateWithAttributedString(string)
        // Letter spacing trails the last glyph; leave it out when centring or right-aligning.
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) - tracking
        let start = switch align {
        case .left: x
        case .center: x - width / 2
        case .right: x - width
        }
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: start, y: y)
        CTLineDraw(line, context)
        context.restoreGState()
        return width
    }

    @discardableResult
    func text(_ string: String, _ font: CTFont, _ fill: CGColor, x: CGFloat, y: CGFloat, align: Align = .left, tracking: CGFloat = 0, uppercase: Bool = false) -> CGFloat {
        text([Run(text: string, font: font, color: fill)], x: x, y: y, align: align, tracking: tracking, uppercase: uppercase)
    }

    /// Letter-spaced Newsreader SemiBold caps.
    @discardableResult
    func label(_ string: String, size: CGFloat, _ fill: CGColor, x: CGFloat, y: CGFloat, align: Align = .left, tracking: CGFloat = 0.22, points: CGFloat = 10) -> CGFloat {
        text(string, font(.newsreader, size, weight: 600, points: points), fill, x: x, y: y, align: align, tracking: tracking * size, uppercase: true)
    }

    func image(_ image: CGImage, in rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    func crest(center: CGPoint, diameter: CGFloat, ring: CGFloat, monogram: CGFloat, _ look: Look) {
        let line = ring / 3
        context.setStrokeColor(color(look.brass))
        context.setLineWidth(line)
        for inset in [line / 2, ring - line / 2] {
            let d = diameter - inset * 2
            context.strokeEllipse(in: CGRect(x: center.x - d / 2, y: center.y - d / 2, width: d, height: d))
        }
        let italic = font(.playfairItalic, monogram)
        let ascent = CTFontGetAscent(italic), descent = CTFontGetDescent(italic)
        text("C&C", italic, color(look.brassText), x: center.x, y: center.y + (ascent - descent) / 2, align: .center, tracking: -0.02 * monogram)
    }

    /// An iPhone 17 Pro: 11 pt bezel at radius 66 around a 402 × 874 screen at radius 55.
    func phone(_ shot: CGImage, x: CGFloat, y: CGFloat, screenWidth: CGFloat, clip: CGPath? = nil, overlay: CGImage? = nil) {
        let s = screenWidth / 402
        let outer = CGRect(x: x, y: y, width: 424 * s, height: 896 * s)
        let screen = outer.insetBy(dx: 11 * s, dy: 11 * s)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -34 * s), blur: 60 * s, color: color(0x1E1405, 0.5))
        context.addPath(CGPath(roundedRect: outer, cornerWidth: 66 * s, cornerHeight: 66 * s, transform: nil))
        context.setFillColor(color(0x111111))
        context.fillPath()
        context.restoreGState()
        context.addPath(CGPath(roundedRect: outer.insetBy(dx: -0.75 * s, dy: -0.75 * s), cornerWidth: 66.75 * s, cornerHeight: 66.75 * s, transform: nil))
        context.setStrokeColor(color(0x2D2D2D))
        context.setLineWidth(1.5 * s)
        context.strokePath()
        context.saveGState()
        context.addPath(CGPath(roundedRect: screen, cornerWidth: 55 * s, cornerHeight: 55 * s, transform: nil))
        context.clip()
        image(shot, in: screen)
        if let overlay, let clip {
            context.addPath(clip)
            context.clip()
            image(overlay, in: screen)
        }
        context.restoreGState()
    }

    func save(_ name: String, quality: CGFloat = 0.9) {
        let url = output.appendingPathComponent(name)
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        CGImageDestinationFinalize(destination)
        print("  \(name)")
    }
}

func load(_ name: String) -> CGImage {
    let url = shots.appendingPathComponent("\(name).png")
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("missing screenshot \(url.path)")
    }
    return image
}

// MARK: - Artwork

/// The masthead, set as a banner.
func banner(_ look: Look) {
    let canvas = Canvas(1600, 620)
    let s: CGFloat = 2.6
    canvas.paper(canvas.bounds, look)
    let margin: CGFloat = 130
    let width = canvas.width - margin * 2
    let ink = color(look.ink), muted = color(look.muted), brassText = color(look.brassText)

    canvas.label("Vol. I", size: 9.5 * s, muted, x: margin, y: 128, tracking: 0.22, points: 9.5)
    canvas.label("No. CC", size: 9.5 * s, muted, x: canvas.width - margin, y: 128, align: .right, tracking: 0.22, points: 9.5)
    canvas.crest(center: CGPoint(x: canvas.width / 2, y: 118), diameter: 34 * s, ring: 3 * s, monogram: 11 * s, look)

    let masthead = font(.playfair, 41 * s)
    canvas.text([
        Run(text: "Court ", font: masthead, color: ink),
        Run(text: "&", font: font(.playfairItalic, 41 * s), color: brassText),
        Run(text: " Capital", font: masthead, color: ink),
    ], x: canvas.width / 2, y: 312, align: .center, tracking: -0.012 * 41 * s)

    canvas.doubleRule(x: margin, y: 362, width: width, color(look.ruleStrong), scale: s)
    let dateline = font(.newsreaderItalic, 15 * s, points: 15)
    canvas.text("A weekday briefing on law, finance and AI", dateline, ink, x: margin, y: 428)
    canvas.label("For iPhone", size: 9.5 * s, muted, x: canvas.width - margin, y: 424, align: .right, tracking: 0.2, points: 9.5)
    canvas.fill(CGRect(x: margin, y: 452, width: width, height: 0.5 * s), color(look.ruleStrong))

    let mid = canvas.width / 2
    canvas.lozenge(center: CGPoint(x: mid - 26, y: 520), size: 4 * s, color(look.brass))
    canvas.lozenge(center: CGPoint(x: mid, y: 520), size: 5 * s, color(look.brass))
    canvas.lozenge(center: CGPoint(x: mid + 26, y: 520), size: 4 * s, color(look.brass))
    canvas.save("banner-\(look.name).jpg")
}

/// Three phones on the design-review canvas, the middle one raised.
func showcase(_ look: Look, shots names: [String], captions: [String], file: String) {
    let canvas = Canvas(1800, 1250)
    canvas.paper(canvas.bounds, look, base: look.canvas)
    let screenWidth: CGFloat = 440
    let phoneWidth = 424 * screenWidth / 402
    let gap = (canvas.width - phoneWidth * CGFloat(names.count)) / CGFloat(names.count + 1)
    for (index, name) in names.enumerated() {
        let x = gap + CGFloat(index) * (phoneWidth + gap)
        let raised = names.count == 3 && index == 1
        let y: CGFloat = raised ? 70 : 120
        canvas.phone(load("\(name)-\(look.name)"), x: x, y: y, screenWidth: screenWidth)
        let captionY = y + 896 * screenWidth / 402 + 62
        canvas.label(captions[index], size: 22, color(look.dark ? look.brassText : look.muted), x: x + phoneWidth / 2, y: captionY, align: .center, tracking: 0.24, points: 10)
    }
    canvas.save(file)
}

/// One phone split on the diagonal, Day above and Night below, like the Automatic swatch.
func dayAndNight() {
    let canvas = Canvas(1800, 1300)
    let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2 - 20)
    let reach = center.x + center.y
    // Everything below the 45° line through the phone's centre is Night.
    let triangle = CGMutablePath()
    triangle.move(to: CGPoint(x: reach + 4000, y: -4000))
    triangle.addLine(to: CGPoint(x: reach - 4000, y: 4000))
    triangle.addLine(to: CGPoint(x: reach + 4000, y: 4000))
    triangle.closeSubpath()

    canvas.paper(canvas.bounds, day, base: day.canvas)
    canvas.context.saveGState()
    canvas.context.addPath(triangle)
    canvas.context.clip()
    canvas.paper(canvas.bounds, night, base: night.canvas)
    canvas.context.restoreGState()
    canvas.line(from: CGPoint(x: reach, y: 0), to: CGPoint(x: reach - canvas.height, y: canvas.height), color(0xC4A262, 0.7), width: 1.5)

    let screenWidth: CGFloat = 440
    let phoneWidth = 424 * screenWidth / 402
    let phoneHeight = 896 * screenWidth / 402
    let origin = CGPoint(x: center.x - phoneWidth / 2, y: center.y - phoneHeight / 2)
    canvas.phone(load("today-day"), x: origin.x, y: origin.y, screenWidth: screenWidth, clip: triangle, overlay: load("today-night"))

    canvas.label("Day", size: 26, color(day.brassText), x: 150, y: 210, tracking: 0.24)
    canvas.text("The morning paper:", font(.newsreaderItalic, 36, points: 18), color(day.ink), x: 150, y: 270)
    canvas.text("ivory stock, navy ink.", font(.newsreaderItalic, 36, points: 18), color(day.ink), x: 150, y: 318)

    canvas.label("Night", size: 26, color(night.brassText), x: canvas.width - 150, y: canvas.height - 260, align: .right, tracking: 0.24)
    canvas.text("The library at night: green", font(.newsreaderItalic, 36, points: 18), color(night.ink), x: canvas.width - 150, y: canvas.height - 200, align: .right)
    canvas.text("leather, cream type, brass.", font(.newsreaderItalic, 36, points: 18), color(night.ink), x: canvas.width - 150, y: canvas.height - 152, align: .right)
    canvas.save("day-and-night.jpg")
}

/// The bounding box of the warm paper pixels inside `search`.
func paperBox(in image: CGImage, search: CGRect) -> CGRect {
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    var box = CGRect.null
    for y in Int(search.minY)..<Int(search.maxY) {
        for x in Int(search.minX)..<Int(search.maxX) {
            let i = (y * width + x) * 4
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            if r > 215 && g > 205 && b > 185 && r - b > 10 {
                box = box.union(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
    }
    return box
}

/// Home Screen widgets on the design review's backdrop, with the app icon.
func widgets(_ look: Look, medium: CGRect, small: CGRect) {
    let home = load("home-\(look.name)")
    let canvas = Canvas(1800, 900)
    canvas.linearGradient(canvas.bounds, from: look.widgetBackdrop.0, to: look.widgetBackdrop.1)
    let radius: CGFloat = 56
    let top: CGFloat = 150
    let totalWidth = medium.width + 80 + small.width
    var x = (canvas.width - totalWidth) / 2
    for (rect, caption) in [(medium, "Medium · the Big Story and four markets"), (small, "Small · the Big Story")] {
        // Trim the antialiased edge where the wallpaper shows through, then re-round.
        let trimmed = rect.insetBy(dx: 10, dy: 10)
        let crop = home.cropping(to: trimmed)!
        let target = CGRect(x: x, y: top, width: trimmed.width, height: trimmed.height)
        canvas.context.saveGState()
        canvas.context.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: color(0x000000, 0.35))
        canvas.context.addPath(CGPath(roundedRect: target, cornerWidth: radius, cornerHeight: radius, transform: nil))
        canvas.context.setFillColor(color(look.paper))
        canvas.context.fillPath()
        canvas.context.restoreGState()
        canvas.context.saveGState()
        canvas.context.addPath(CGPath(roundedRect: target, cornerWidth: radius, cornerHeight: radius, transform: nil))
        canvas.context.clip()
        canvas.image(crop, in: target)
        canvas.context.restoreGState()
        canvas.label(caption, size: 22, color(look.dark ? look.brassText : 0x3A2A12), x: target.midX, y: target.maxY + 80, align: .center, tracking: 0.2)
        x = target.maxX + 80
    }
    canvas.save("widgets-\(look.name).jpg")
}

/// The colour tokens, Day above Night.
func palette() {
    let tokens: [(String, UInt32, UInt32)] = [
        ("paper", 0xF4EEE1, 0x0E1B15), ("paperInset", 0xEAE2D1, 0x15271F), ("ink", 0x16202F, 0xECE3CD),
        ("inkMuted", 0x5E584C, 0xADA48C), ("brass", 0xA27D3A, 0xC4A262), ("brassText", 0x80602A, 0xCDAE6E),
        ("burgundy", 0x6F1F2C, 0xDE9AA2), ("up", 0x2A5A3E, 0x9CC5A6), ("down", 0x8A2433, 0xE39EA6),
        ("plainBg", 0x1E3A2C, 0x17243B), ("tagUS", 0x1D2A45, 0xAEBBD8), ("tagCH", 0x6F1F2C, 0xDEA2A9),
    ]
    let canvas = Canvas(1800, 1240)
    let half = CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height / 2)
    for (index, look) in [day, night].enumerated() {
        let panel = half.offsetBy(dx: 0, dy: half.height * CGFloat(index))
        canvas.paper(panel, look)
        let margin: CGFloat = 110
        canvas.label(look.dark ? "Night · the library" : "Day · the morning paper", size: 24, color(look.brassText), x: margin, y: panel.minY + 104, tracking: 0.24)
        canvas.fill(CGRect(x: margin, y: panel.minY + 128, width: canvas.width - margin * 2, height: 2), color(look.ruleStrong))
        let columns = 6
        let cell = (canvas.width - margin * 2) / CGFloat(columns)
        for (i, token) in tokens.enumerated() {
            let hex = look.dark ? token.2 : token.1
            let x = margin + CGFloat(i % columns) * cell
            let y = panel.minY + 170 + CGFloat(i / columns) * 225
            let swatch = CGRect(x: x, y: y, width: cell - 36, height: 110)
            canvas.fill(swatch, color(hex))
            canvas.context.setStrokeColor(look.rule)
            canvas.context.setLineWidth(2)
            canvas.context.stroke(swatch.insetBy(dx: 1, dy: 1))
            canvas.text(token.0, font(.newsreader, 27, weight: 600, points: 14), color(look.ink), x: x, y: y + 150)
            canvas.text(String(format: "#%06X", hex), font(.mono, 20), color(look.muted), x: x, y: y + 182)
        }
    }
    canvas.save("palette.jpg")
}

/// The type scale, as on the Design Tokens page.
func typeSpecimen(_ look: Look) {
    let s: CGFloat = 2.1
    let rows: [(name: String, spec: String, runs: [Run], tracking: CGFloat, uppercase: Bool)] = [
        ("masthead", "Playfair Display 41 / 43", [
            Run(text: "Court ", font: font(.playfair, 41 * s), color: color(look.ink)),
            Run(text: "&", font: font(.playfairItalic, 41 * s), color: color(look.brassText)),
            Run(text: " Capital", font: font(.playfair, 41 * s), color: color(look.ink)),
        ], -0.012 * 41 * s, false),
        ("storyHeadline", "Playfair Display 30 / 35", [Run(text: "Supreme Court looks split", font: font(.playfair, 30 * s), color: color(look.ink))], -0.005 * 30 * s, false),
        ("bigStory", "Playfair Display 24 / 30", [Run(text: "Schneider Electric agreed to buy PTC", font: font(.playfair, 24 * s), color: color(look.ink))], 0, false),
        ("quote", "Playfair Display Italic 20 / 28", [Run(text: "A 4–4 tie would let Boulder’s case proceed.", font: font(.playfairItalic, 20 * s), color: color(look.ink))], 0, false),
        ("body", "Newsreader 18 / 28", [
            Run(text: "Justice Alito recused himself ", font: font(.newsreader, 18 * s, points: 18), color: color(look.ink)),
            Run(text: "(stepped aside)", font: font(.newsreaderItalic, 18 * s, points: 18), color: color(look.muted)),
        ], 0, false),
        ("rowHeadline", "Newsreader Medium 17 / 22.5", [Run(text: "Supreme Court refuses Zillow’s bid", font: font(.newsreader, 17 * s, weight: 500, points: 17), color: color(look.ink))], 0, false),
        ("figure", "Newsreader Medium 17.5, tabular", [Run(text: "27,477.31  ▲ +1.05%", font: font(.newsreader, 17.5 * s, weight: 500, points: 17.5), color: color(look.ink))], -0.01 * 17.5 * s, false),
        ("label", "Newsreader SemiBold 10, tracked 0.22 em", [Run(text: "The Big Story", font: font(.newsreader, 10 * s * 1.3, weight: 600, points: 10), color: color(look.brassText))], 0.22 * 13 * s, true),
    ]
    let canvas = Canvas(1800, 1380)
    canvas.paper(canvas.bounds, look)
    let margin: CGFloat = 110
    let sampleX: CGFloat = 610
    var y: CGFloat = 70
    canvas.fill(CGRect(x: margin, y: y, width: canvas.width - margin * 2, height: 3), color(look.ruleStrong))
    for row in rows {
        let height: CGFloat = row.name == "masthead" ? 196 : 152
        let baseline = y + height / 2 + 22
        canvas.text(row.name, font(.mono, 24), color(look.brassText), x: margin, y: baseline - 16)
        canvas.text(row.spec, font(.newsreaderItalic, 22, points: 12), color(look.muted), x: margin, y: baseline + 20)
        canvas.text(row.runs, x: sampleX, y: baseline + (row.name == "masthead" ? 20 : 8), tracking: row.tracking, uppercase: row.uppercase)
        y += height
        canvas.fill(CGRect(x: margin, y: y, width: canvas.width - margin * 2, height: 1), look.rule)
    }
    canvas.save("type-\(look.name).jpg")
}

// MARK: - Render

print("Rendering README art into \(output.path)")
let homeDay = load("home-day")
let medium = paperBox(in: homeDay, search: CGRect(x: 0, y: 180, width: 1206, height: 640))
let small = paperBox(in: homeDay, search: CGRect(x: 0, y: 840, width: 620, height: 560))
for look in [day, night] {
    banner(look)
    showcase(look, shots: ["story", "today", "archive"], captions: ["The story", "Today", "The archive"], file: "showcase-\(look.name).jpg")
    showcase(look, shots: ["story2", "settings"], captions: ["The story, continued", "Settings"], file: "details-\(look.name).jpg")
    widgets(look, medium: medium, small: small)
    typeSpecimen(look)
}
dayAndNight()
palette()
