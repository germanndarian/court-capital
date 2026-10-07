import SwiftUI
import UIKit

/// Body copy that opens with a two-line brass drop cap, laid out the way the CSS float does:
/// Playfair 62 at line-height 0.82, 5 pt down, 8 pt clear on the right, 2 pt into the margin.
struct DropCapParagraph: UIViewRepresentable {
    let runs: [BodyRun]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeUIView(context: Context) -> DropCapView {
        DropCapView()
    }

    func updateUIView(_ view: DropCapView, context: Context) {
        view.configure(runs: runs, bodySize: TypeStyle.body.scaledSize(for: dynamicTypeSize))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: DropCapView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: uiView.height(forWidth: width))
    }
}

final class DropCapView: UIView {
    private let storage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let container = NSTextContainer()

    private var capString = NSAttributedString()
    private var capFrame = CGRect.zero
    private var capBaseline: CGFloat = 0
    private var bodySize: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: DropCapView, _: UITraitCollection) in
            view.setNeedsDisplay()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(runs: [BodyRun], bodySize: CGFloat) {
        let fullText = runs.map(\.string).joined()
        guard let first = fullText.first, case .text(let opening) = runs.first else { return }
        self.bodySize = bodySize
        accessibilityLabel = fullText

        let scale = bodySize / TypeStyle.body.size
        let regular = TypeStyle.body.ctFont(size: bodySize) as UIFont
        var italicStyle = TypeStyle.body
        italicStyle.italic = true
        let italic = italicStyle.ctFont(size: bodySize) as UIFont

        // CSS centres glyphs in the line box; TextKit puts the extra leading above them.
        let lineHeight = (bodySize * 1.56).rounded(.toNearestOrAwayFromZero)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        let halfLeading = (lineHeight - regular.lineHeight) / 2

        let body = NSMutableAttributedString()
        for (index, run) in runs.enumerated() {
            var string = run.string
            if index == 0 { string = String(opening.dropFirst()) }
            let isAside: Bool
            if case .aside = run { isAside = true } else { isAside = false }
            body.append(NSAttributedString(string: string, attributes: [
                .font: isAside ? italic : regular,
                .foregroundColor: isAside ? Palette.inkMuted : Palette.ink,
                .paragraphStyle: paragraph,
                .baselineOffset: halfLeading,
            ]))
        }
        storage.setAttributedString(body)

        let capFont = TypeStyle.display(62 * scale, relativeTo: nil).ctFont(size: 62 * scale) as UIFont
        capString = NSAttributedString(string: String(first), attributes: [
            .font: capFont,
            .foregroundColor: Palette.brassText,
        ])
        let capBoxHeight = 62 * scale * 0.82
        let capTop = 5 * scale
        capBaseline = capTop + (capBoxHeight - capFont.lineHeight) / 2 + capFont.ascender
        let capWidth = capString.size().width
        capFrame = CGRect(x: -2 * scale, y: capTop, width: capWidth, height: capBoxHeight)

        // Lines beside the float start after the letter and its 8 pt right margin. A letter
        // that descends below its box (Playfair's J) also pushes aside the line it reaches.
        let line = CTLineCreateWithAttributedString(capString)
        let glyphBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let glyphBottom = capBaseline - glyphBounds.minY + 2 * scale
        let exclusion = CGRect(
            x: 0, y: 0,
            width: max(capFrame.maxX, capFrame.minX + glyphBounds.maxX) + 8 * scale,
            height: max(capFrame.maxY, glyphBottom)
        )
        container.exclusionPaths = [UIBezierPath(rect: exclusion)]

        invalidateIntrinsicContentSize()
        setNeedsLayout()
        setNeedsDisplay()
    }

    func height(forWidth width: CGFloat) -> CGFloat {
        container.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let textHeight = layoutManager.usedRect(for: container).height
        let capBottom = container.exclusionPaths.first?.bounds.maxY ?? capFrame.maxY
        return ceil(max(textHeight, capBottom))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if container.size.width != bounds.width {
            container.size = CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        let glyphs = layoutManager.glyphRange(for: container)
        layoutManager.drawGlyphs(forGlyphRange: glyphs, at: .zero)
        let capFont = capString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let origin = CGPoint(x: capFrame.minX, y: capBaseline - (capFont?.ascender ?? 0))
        capString.draw(at: origin)
    }
}
