import CoreText
import SwiftUI
import UIKit

/// The two bundled faces. Both are variable fonts; weight and optical size are set through
/// their axes so small labels get the sturdier small-size cuts, as the browser does with
/// `font-optical-sizing: auto`.
enum Typeface: Sendable {
    case playfair
    case newsreader

    fileprivate func postScriptName(italic: Bool) -> String {
        switch (self, italic) {
        case (.playfair, false): "PlayfairDisplay-Regular"
        case (.playfair, true): "PlayfairDisplay-Italic"
        case (.newsreader, false): "Newsreader16pt-Regular"
        case (.newsreader, true): "Newsreader16pt-Italic"
        }
    }

    fileprivate var hasOpticalSize: Bool { self == .newsreader }
}

/// A type style from the Design Tokens type scale. Sizes are in points at the default
/// Dynamic Type size; `relativeTo` decides how they scale (nil keeps them fixed, for ornaments
/// and widgets).
struct TypeStyle: Sendable {
    var face: Typeface
    var size: CGFloat
    var weight: CGFloat = 400
    var italic = false
    /// Letter spacing in em, as on the design page.
    var tracking: CGFloat = 0
    /// Line height as a multiple of the size; nil keeps the font's natural line height.
    var lineHeight: CGFloat?
    var uppercase = false
    var tabularFigures = false
    var relativeTo: Font.TextStyle? = .body
    /// Never scale below the design size (region tags).
    var fixedMinimum = false
}

extension TypeStyle {
    static let masthead = TypeStyle(face: .playfair, size: 41, tracking: -0.012, lineHeight: 1.05, relativeTo: .largeTitle)
    static let screenTitle = TypeStyle(face: .playfair, size: 36, lineHeight: 1.05, relativeTo: .largeTitle)
    static let storyHeadline = TypeStyle(face: .playfair, size: 30, tracking: -0.005, lineHeight: 1.18, relativeTo: .title)
    static let bigStory = TypeStyle(face: .playfair, size: 24, lineHeight: 1.27, relativeTo: .title2)
    static let sectionNumeral = TypeStyle(face: .playfair, size: 30, italic: true, lineHeight: 1, relativeTo: .title2)
    static let sectionTitle = TypeStyle(face: .playfair, size: 22, lineHeight: 1, relativeTo: .title2)
    static let quote = TypeStyle(face: .playfair, size: 20, italic: true, lineHeight: 1.4, relativeTo: .title3)
    static let body = TypeStyle(face: .newsreader, size: 18, lineHeight: 1.56, relativeTo: .body)
    static let rowHeadline = TypeStyle(face: .newsreader, size: 17, weight: 500, lineHeight: 1.32, relativeTo: .headline)
    static let figure = TypeStyle(face: .newsreader, size: 17.5, weight: 500, tracking: -0.01, tabularFigures: true, relativeTo: .body)
    static let dateline = TypeStyle(face: .newsreader, size: 13.5, italic: true, relativeTo: .footnote)
    static let tag = TypeStyle(face: .newsreader, size: 8.5, weight: 700, tracking: 0.16, uppercase: true, relativeTo: .caption2, fixedMinimum: true)

    /// Letter-spaced small capitals: Newsreader SemiBold, uppercase.
    static func label(_ size: CGFloat = 10, tracking: CGFloat = 0.22, weight: CGFloat = 600) -> TypeStyle {
        TypeStyle(face: .newsreader, size: size, weight: weight, tracking: tracking, uppercase: true, relativeTo: .caption2)
    }

    /// Newsreader text at an arbitrary size, for the one-off sizes in the screens.
    static func text(_ size: CGFloat, weight: CGFloat = 400, italic: Bool = false, lineHeight: CGFloat? = nil, relativeTo: Font.TextStyle = .body) -> TypeStyle {
        TypeStyle(face: .newsreader, size: size, weight: weight, italic: italic, lineHeight: lineHeight, relativeTo: relativeTo)
    }

    /// Playfair Display at an arbitrary size.
    static func display(_ size: CGFloat, italic: Bool = false, tracking: CGFloat = 0, lineHeight: CGFloat? = nil, relativeTo: Font.TextStyle? = .title3) -> TypeStyle {
        TypeStyle(face: .playfair, size: size, italic: italic, tracking: tracking, lineHeight: lineHeight, relativeTo: relativeTo)
    }

    var fixed: TypeStyle {
        var copy = self
        copy.relativeTo = nil
        return copy
    }

    func scaledSize(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        guard let relativeTo else { return size }
        let traits = UITraitCollection(preferredContentSizeCategory: dynamicTypeSize.contentSizeCategory)
        let scaled = UIFontMetrics(forTextStyle: relativeTo.uiTextStyle).scaledValue(for: size, compatibleWith: traits)
        return fixedMinimum ? max(size, scaled) : scaled
    }

    func ctFont(size: CGFloat) -> CTFont {
        FontStore.shared.font(face, size: size, weight: weight, italic: italic)
    }

    func font(for dynamicTypeSize: DynamicTypeSize) -> Font {
        let font = Font(ctFont(size: scaledSize(for: dynamicTypeSize)))
        return tabularFigures ? font.monospacedDigit() : font
    }
}

/// Builds and caches the variable-font instances.
final class FontStore: @unchecked Sendable {
    static let shared = FontStore()

    private struct Key: Hashable {
        let face: Typeface
        let size: CGFloat
        let weight: CGFloat
        let italic: Bool
    }

    private static let weightAxis = 0x7767_6874 // 'wght'
    private static let opticalSizeAxis = 0x6F70_737A // 'opsz'

    private let lock = NSLock()
    private var cache: [Key: CTFont] = [:]

    func font(_ face: Typeface, size: CGFloat, weight: CGFloat, italic: Bool) -> CTFont {
        let key = Key(face: face, size: size, weight: weight, italic: italic)
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] { return cached }

        var variation: [Int: CGFloat] = [Self.weightAxis: weight]
        if face.hasOpticalSize {
            variation[Self.opticalSizeAxis] = min(max(size, 6), 72)
        }
        let attributes: [CFString: Any] = [
            kCTFontNameAttribute: face.postScriptName(italic: italic),
            kCTFontVariationAttribute: variation,
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        cache[key] = font
        return font
    }
}

extension CTFont {
    /// The font's natural line height: what CSS calls `line-height: normal`.
    var naturalLineHeight: CGFloat {
        CTFontGetAscent(self) + CTFontGetDescent(self) + CTFontGetLeading(self)
    }
}

// MARK: - Applying a style

private struct TypeStyleModifier: ViewModifier {
    let style: TypeStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let size = style.scaledSize(for: dynamicTypeSize)
        let ctFont = style.ctFont(size: size)
        let base = Font(ctFont)
        content
            .font(style.tabularFigures ? base.monospacedDigit() : base)
            .tracking(style.tracking * size)
            .modifier(UppercaseModifier(enabled: style.uppercase))
            .modifier(LineHeightModifier(points: style.lineHeight.map { $0 * size }, natural: ctFont.naturalLineHeight))
    }
}

/// Only ever sets uppercase, so a `textCase` applied around the style still takes effect.
private struct UppercaseModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.textCase(.uppercase)
        } else {
            content
        }
    }
}

/// CSS line heights. iOS 26 sets them exactly, except well below the font's natural height
/// (single-line display type at line-height 1), where an exact height clips descenders.
/// Otherwise: line spacing plus half-leading padding, negative when the CSS line is tighter.
private struct LineHeightModifier: ViewModifier {
    let points: CGFloat?
    let natural: CGFloat

    func body(content: Content) -> some View {
        if let points {
            if #available(iOS 26.0, *), points >= natural * 0.85 {
                content.lineHeight(.exact(points: points))
            } else {
                content
                    .lineSpacing(max(0, points - natural))
                    .padding(.vertical, min(0, points - natural) / 2)
            }
        } else {
            content
        }
    }
}

extension View {
    func typeStyle(_ style: TypeStyle) -> some View {
        modifier(TypeStyleModifier(style: style))
    }
}

// MARK: - Dynamic Type bridging

extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}

extension DynamicTypeSize {
    var contentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}
