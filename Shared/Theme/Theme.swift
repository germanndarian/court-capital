import SwiftUI
import UIKit

/// Colour tokens from the Design Tokens page. Every token resolves per appearance:
/// Day is ivory stock with navy ink, Night is the library (racing-green leather, cream type, brass).
enum Palette {
    static let paper = UIColor(day: 0xF4EEE1, night: 0x0E1B15)
    static let paperInset = UIColor(day: 0xEAE2D1, night: 0x15271F)
    static let ink = UIColor(day: 0x16202F, night: 0xECE3CD)
    static let inkMuted = UIColor(day: 0x5E584C, night: 0xADA48C)
    static let rule = UIColor(day: UIColor(hex: 0x16202F, alpha: 0.20), night: UIColor(hex: 0xCDAE6E, alpha: 0.26))
    static let ruleStrong = UIColor(day: 0x16202F, night: 0xB8995C)
    static let brass = UIColor(day: 0xA27D3A, night: 0xC4A262)
    static let brassText = UIColor(day: 0x80602A, night: 0xCDAE6E)
    static let burgundy = UIColor(day: 0x6F1F2C, night: 0xDE9AA2)
    static let up = UIColor(day: 0x2A5A3E, night: 0x9CC5A6)
    static let down = UIColor(day: 0x8A2433, night: 0xE39EA6)
    static let plainBg = UIColor(day: 0x1E3A2C, night: 0x17243B)
    static let plainEdge = UIColor(day: .clear, night: UIColor(hex: 0xCDAE6E, alpha: 0.45))
    static let plainInk = UIColor(day: 0xF1E8D4, night: 0xECE3CD)
    static let plainLabel = UIColor(day: 0xD2B272, night: 0xCDAE6E)
    static let tagUS = UIColor(day: 0x1D2A45, night: 0xAEBBD8)
    static let tagCH = UIColor(day: 0x6F1F2C, night: 0xDEA2A9)
    static let tagEU = UIColor(day: 0x1E3A2C, night: 0xA4CAAD)
    static let toggleOn = UIColor(day: 0x1E3A2C, night: 0xA8884C)

    /// The heatmap's seven steps, deep red through grey to deep green (see `HeatScale`).
    static let heat: [UIColor] = [
        UIColor(day: 0x7E1F2E, night: 0xA03447),
        UIColor(day: 0xA9444F, night: 0x7C2B3A),
        UIColor(day: 0xD2A0A2, night: 0x4A2A30),
        UIColor(day: 0xC4BDAB, night: 0x38403A),
        UIColor(day: 0xA3C4AC, night: 0x28483A),
        UIColor(day: 0x3E7A58, night: 0x2F6B4A),
        UIColor(day: 0x2A5A3E, night: 0x3E8A5E),
    ]
    /// Type on the heatmap's blocks: light on the deep steps by day, always cream by night.
    static let heatLightText = UIColor(day: 0xF6EFDD, night: 0xECE3CD)
}

/// SwiftUI face of `Palette`, plus the mode-independent materials of the archive shelf.
enum Theme {
    static let paper = Color(uiColor: Palette.paper)
    static let paperInset = Color(uiColor: Palette.paperInset)
    static let ink = Color(uiColor: Palette.ink)
    static let inkMuted = Color(uiColor: Palette.inkMuted)
    static let rule = Color(uiColor: Palette.rule)
    static let ruleStrong = Color(uiColor: Palette.ruleStrong)
    static let brass = Color(uiColor: Palette.brass)
    static let brassText = Color(uiColor: Palette.brassText)
    static let burgundy = Color(uiColor: Palette.burgundy)
    static let up = Color(uiColor: Palette.up)
    static let down = Color(uiColor: Palette.down)
    static let plainBg = Color(uiColor: Palette.plainBg)
    static let plainEdge = Color(uiColor: Palette.plainEdge)
    static let plainInk = Color(uiColor: Palette.plainInk)
    static let plainLabel = Color(uiColor: Palette.plainLabel)
    static let tagUS = Color(uiColor: Palette.tagUS)
    static let tagCH = Color(uiColor: Palette.tagCH)
    static let tagEU = Color(uiColor: Palette.tagEU)
    static let toggleOn = Color(uiColor: Palette.toggleOn)

    /// Block colour for a heatmap step, 0 (deep red) to 6 (deep green).
    static func heat(_ step: Int) -> Color {
        Color(uiColor: Palette.heat[min(max(step, 0), Palette.heat.count - 1)])
    }

    /// Type that reads on `heat(step)`.
    static func heatText(_ step: Int) -> Color {
        let deep = [0, 1, 5, 6].contains(step)
        return Color(uiColor: deep ? Palette.heatLightText : Palette.ink)
    }

    /// Toggle knob, the same cream in both modes.
    static let knob = Color(hex: 0xFBF7EE)

    enum Wood {
        static let panelTop = Color(hex: 0x3B2618)
        static let panelBottom = Color(hex: 0x2C1B11)
        static let ledgeTop = Color(hex: 0x6A4529)
        static let ledgeBottom = Color(hex: 0x3A2416)
    }

    enum Leather {
        static let navy = Color(hex: 0x1D2A45)
        static let green = Color(hex: 0x1E3A2C)
        static let burgundy = Color(hex: 0x5E1A26)
        static let all = [navy, green, burgundy]
    }

    static let gilt = Color(hex: 0xD6B776)
    static let giltRule = Color(hex: 0xC4A262)
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    convenience init(day: UIColor, night: UIColor) {
        self.init { $0.userInterfaceStyle == .dark ? night : day }
    }

    convenience init(day: UInt32, night: UInt32) {
        self.init(day: UIColor(hex: day), night: UIColor(hex: night))
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: opacity))
    }
}
