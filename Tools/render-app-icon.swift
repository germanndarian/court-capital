// Renders the 1024 × 1024 app icon masters from the design spec (Section VI of the design review).
// Run from the repository root:  swift Tools/render-app-icon.swift
//
// Default is racing green, Dark is near-black green, Tinted is a grayscale source the system
// tints. No corner mask is baked in; iOS applies its own.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let fontURL = root.appendingPathComponent("Shared/Fonts/PlayfairDisplay-Italic-Variable.ttf")
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
let output = root.appendingPathComponent("CourtCapital/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

struct Look {
    let name: String
    let appearance: String?
    let background: [(UInt32, CGFloat)]
    let ring: UInt32
    let outlineAlpha: CGFloat
    let monogram: UInt32
}

let looks = [
    Look(name: "default", appearance: nil, background: [(0x2E5242, 0), (0x1A3626, 0.55), (0x10241A, 1)], ring: 0xC4A262, outlineAlpha: 0.45, monogram: 0xD6B776),
    Look(name: "dark", appearance: "dark", background: [(0x15231C, 0), (0x070D0A, 1)], ring: 0xC4A262, outlineAlpha: 0.4, monogram: 0xD6B776),
    Look(name: "tinted", appearance: "tinted", background: [(0x161616, 0), (0x161616, 1)], ring: 0xE6E6E6, outlineAlpha: 0.4, monogram: 0xEDEDED),
]

let size = 1024
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: sRGB,
        components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha]
    )!
}

func strokeCircle(_ context: CGContext, center: CGPoint, diameter: CGFloat) {
    context.strokeEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter))
}

/// Proportions follow the 180 pt drawing: ring 128 with a 6 double border, a 1 pt outline
/// 7 pt outside it, and the monogram at 46.
func render(_ look: Look) -> CGImage {
    let s = CGFloat(size)
    let unit = s / 180
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!

    // radial-gradient(circle at 34% 24%, …): an ellipse sized to the farthest corner.
    let gradient = CGGradient(
        colorsSpace: sRGB,
        colors: look.background.map { color($0.0) } as CFArray,
        locations: look.background.map(\.1)
    )!
    let radiusX = 0.9332 * s, radiusY = 1.0751 * s
    context.saveGState()
    context.translateBy(x: 0.34 * s, y: s - 0.24 * s)
    context.scaleBy(x: radiusX / radiusY, y: 1)
    context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radiusY, options: [.drawsAfterEndLocation])
    context.restoreGState()

    let center = CGPoint(x: s / 2, y: s / 2)
    let diameter = 128 * unit

    // A CSS double border: two lines a third of the border width each.
    let border = 6 * unit
    let line = border / 3
    context.setStrokeColor(color(look.ring))
    context.setLineWidth(line)
    strokeCircle(context, center: center, diameter: diameter - line)
    strokeCircle(context, center: center, diameter: diameter - 2 * border + line)

    context.setStrokeColor(color(look.ring, look.outlineAlpha))
    context.setLineWidth(unit)
    strokeCircle(context, center: center, diameter: diameter + 14 * unit + unit)

    let fontSize = 46 * unit
    let font = CTFontCreateWithName("PlayfairDisplay-Italic" as CFString, fontSize, nil)
    let text = NSAttributedString(string: "C&C", attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(look.monogram),
        NSAttributedString.Key(kCTKernAttributeName as String): -0.03 * fontSize,
    ])
    let ctLine = CTLineCreateWithAttributedString(text)
    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading))
    context.textPosition = CGPoint(x: (s - width) / 2, y: s / 2 - (ascent - descent) / 2)
    CTLineDraw(ctLine, context)
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

var images: [[String: Any]] = []
for look in looks {
    let filename = "icon-\(look.name).png"
    write(render(look), to: output.appendingPathComponent(filename))
    var entry: [String: Any] = ["filename": filename, "idiom": "universal", "platform": "ios", "size": "1024x1024"]
    if let appearance = look.appearance {
        entry["appearances"] = [["appearance": "luminosity", "value": appearance]]
    }
    images.append(entry)
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(output.path)")
