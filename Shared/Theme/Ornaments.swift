import SwiftUI

/// 0.5 pt rule between rows and cells.
struct Hairline: View {
    var color: Color = Theme.rule
    var thickness: CGFloat = 0.5

    var body: some View {
        Rectangle().fill(color).frame(height: thickness)
    }
}

/// The newspaper double rule: heavy line, 2 pt gap, hairline. `mirrored` flips it for the
/// bottom of a quote block; the widget masthead uses a lighter 1 pt top line.
struct DoubleRule: View {
    var color: Color = Theme.ruleStrong
    var heavy: CGFloat = 1.5
    var light: CGFloat = 0.5
    var mirrored = false

    var body: some View {
        VStack(spacing: 2) {
            Rectangle().fill(color).frame(height: mirrored ? light : heavy)
            Rectangle().fill(color).frame(height: mirrored ? heavy : light)
        }
    }
}

/// A CSS `double` border drawn as a circle: two lines a third of the width each.
struct DoubleRing: View {
    var width: CGFloat
    var color: Color

    var body: some View {
        let line = width / 3
        ZStack {
            Circle().inset(by: line / 2).stroke(color, lineWidth: line)
            Circle().inset(by: width - line / 2).stroke(color, lineWidth: line)
        }
    }
}

/// The C&C crest: a brass double ring around an italic monogram.
struct Crest: View {
    var diameter: CGFloat = 34
    var ring: CGFloat = 3
    var monogram: CGFloat = 11

    var body: some View {
        ZStack {
            DoubleRing(width: ring, color: Theme.brass)
            Text("C&C")
                .typeStyle(.display(monogram, italic: true, tracking: -0.02, relativeTo: nil))
                .foregroundStyle(Theme.brassText)
                .fixedSize()
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

/// A small brass diamond.
struct Lozenge: View {
    var size: CGFloat = 5
    var color: Color = Theme.brass

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(45))
            .accessibilityHidden(true)
    }
}

/// "Court & Capital" with the ampersand in brass italic.
struct Wordmark: View {
    var style: TypeStyle
    var brassAmpersand = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        var italic = style
        italic.italic = true
        let ampersand = Text("&")
            .font(italic.font(for: dynamicTypeSize))
            .foregroundStyle(brassAmpersand ? Theme.brassText : Theme.ink)
        return Text("Court \(ampersand) Capital")
            .typeStyle(style)
            .foregroundStyle(Theme.ink)
            .accessibilityLabel("Court and Capital")
    }
}

enum TagStyle {
    case outline
    case filled
}

/// Region tag: 8.5 pt bold caps in a 0.5 pt box, coloured by region.
struct RegionTag: View {
    let region: Region
    var style: TagStyle = .outline

    var body: some View {
        let color = region.color
        Text(region.rawValue)
            .typeStyle(.tag)
            .foregroundStyle(style == .filled ? Theme.paper : color)
            .padding(EdgeInsets(top: 2.5, leading: 5.5, bottom: 1.5, trailing: 4))
            .background(style == .filled ? color : .clear)
            .overlay(Rectangle().strokeBorder(color, lineWidth: 0.5))
            .accessibilityLabel(region.spokenName)
    }
}

extension Region {
    var color: Color {
        switch self {
        case .us: Theme.tagUS
        case .ch: Theme.tagCH
        case .eu: Theme.tagEU
        }
    }

    var spokenName: String {
        switch self {
        case .us: "United States"
        case .ch: "Switzerland"
        case .eu: "Europe"
        }
    }
}

extension Market.Direction {
    var color: Color {
        switch self {
        case .up: Theme.up
        case .down: Theme.down
        case .flat: Theme.inkMuted
        }
    }
}
