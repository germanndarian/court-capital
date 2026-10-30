import SwiftUI

extension TrackedFile.Cover {
    /// The leather itself, the same in Day and Night, as on the archive shelf.
    var leather: Color {
        switch self {
        case .navy: Theme.Leather.navy
        case .green: Theme.Leather.green
        case .burgundy: Theme.Leather.burgundy
        }
    }

    /// The cover's colour for small marks on the page, lighter by night so it reads.
    var ink: Color {
        switch self {
        case .navy: Theme.tagUS
        case .green: Theme.tagEU
        case .burgundy: Theme.tagCH
        }
    }

    var name: String {
        switch self {
        case .navy: "Navy"
        case .green: "Green"
        case .burgundy: "Burgundy"
        }
    }
}

extension Momentum {
    var color: Color {
        switch self {
        case .latest: Theme.burgundy
        case .developing: Theme.brassText
        case .quiet, .cold, .awaiting: Theme.inkMuted
        }
    }
}

extension TrackedFile {
    /// "SpaceX and Tesla", "SpaceX or Tesla"
    var keywordPhrase: String {
        let words = keywords.map { "“\($0)”" }
        guard let last = words.last else { return "" }
        guard words.count > 1 else { return last }
        return words.dropLast().joined(separator: ", ") + (match == .all ? " and " : " or ") + last
    }
}

// MARK: - Leather and gilt

/// A strip of leather down the edge of a file, tooled with gilt bands top and bottom.
struct CoverSpine: View {
    let cover: TrackedFile.Cover
    var width: CGFloat = 10

    var body: some View {
        Rectangle()
            .fill(
                cover.leather
                    .shadow(.inner(color: .white.opacity(0.08), radius: 0, x: 1.5))
                    .shadow(.inner(color: .black.opacity(0.35), radius: 2, x: -2))
            )
            .frame(width: width)
            .overlay {
                VStack {
                    GiltLines()
                    Spacer(minLength: 0)
                    GiltLines()
                }
                .padding(.vertical, 10)
            }
            .accessibilityHidden(true)
    }
}

private struct GiltLines: View {
    var body: some View {
        VStack(spacing: 2) {
            Rectangle().frame(height: 1)
            Rectangle().frame(height: 1)
        }
        .foregroundStyle(Theme.giltRule)
        .opacity(0.8)
    }
}

// MARK: - Coverage

/// A file's coverage over the last weeks: one mark per weekday, tall where the edition
/// carried several of its stories, a hairline where it carried none, and a dot where there
/// was no edition on the iPhone.
struct HeatStrip: View {
    let marks: [Int?]
    var height: CGFloat = 28
    var color: Color = Theme.brass

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(marks.enumerated()), id: \.offset) { index, count in
                mark(count, isLast: index == marks.count - 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private func mark(_ count: Int?, isLast: Bool) -> some View {
        let barWidth = max(2.5, min(height / 4, 6))
        switch count {
        case nil:
            Circle()
                .fill(Theme.rule)
                .frame(width: 2.5, height: 2.5)
        case 0?:
            Rectangle()
                .fill(isLast ? Theme.ruleStrong : Theme.rule)
                .frame(width: barWidth, height: 1)
        case let stories?:
            Rectangle()
                .fill(color)
                .frame(width: barWidth, height: height * min(1, 0.4 + 0.3 * CGFloat(stories - 1)))
        }
    }

    private var accessibilityText: String {
        let days = marks.count(where: { ($0 ?? 0) > 0 })
        return "In the news on \(days) of the last \(marks.count) weekdays"
    }
}

// MARK: - Words and chips

/// A name or word the file follows, set like a region tag but larger. Filled when chosen.
struct KeywordChip: View {
    let word: String
    var isSelected = true

    var body: some View {
        Text(word)
            .typeStyle(.text(14.5, weight: 500, relativeTo: .subheadline))
            .foregroundStyle(isSelected ? Theme.paper : Theme.ink)
            .lineLimit(1)
            .padding(EdgeInsets(top: 6, leading: 11, bottom: 7, trailing: 11))
            .background(isSelected ? Theme.ink : .clear)
            .overlay(Rectangle().strokeBorder(isSelected ? Theme.ink : Theme.ruleStrong, lineWidth: 0.5))
    }
}

/// Lays its children out in rows, wrapping when the next one doesn't fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, width: width)
        return CGSize(width: proposal.width ?? rows.width, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, width: bounds.width)
        for (subview, frame) in zip(subviews, rows.frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (frames: [CGRect], width: CGFloat, height: CGFloat) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (frames, widest, y + rowHeight)
    }
}

/// How the matcher reads a file's words, one line per word or phrase it widens:
/// "Anthropic (or Claude) + IPO (or listing, S-1, roadshow…)".
struct TopicReading: View {
    let queries: [TopicQuery]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(queries.filter(\.isUnderstood), id: \.keyword) { query in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Lozenge(size: 4)
                    line(query)
                        .typeStyle(.text(13.5, italic: true, lineHeight: 1.4, relativeTo: .footnote))
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func line(_ query: TopicQuery) -> Text {
        query.parts.enumerated().reduce(Text(verbatim: "")) { text, item in
            let (position, part) = item
            var line = text
            if position > 0 {
                line = line + Text(verbatim: " + ").foregroundStyle(Theme.brassText)
            }
            line = line + Text(verbatim: part.label).foregroundStyle(Theme.ink)
            if !part.alternatives.isEmpty {
                let shown = part.alternatives.prefix(3).joined(separator: ", ")
                let more = part.alternatives.count > 3 ? "…" : ""
                line = line + Text(verbatim: " (or \(shown)\(more))").foregroundStyle(Theme.inkMuted)
            }
            return line
        }
    }
}

/// "New" in burgundy caps, with a count when there's more than one.
struct NewTag: View {
    var count = 1

    var body: some View {
        Text(count > 1 ? "New · \(count)" : "New")
            .typeStyle(.tag)
            .foregroundStyle(Theme.paper)
            .padding(EdgeInsets(top: 2.5, leading: 5.5, bottom: 1.5, trailing: 4))
            .background(Theme.burgundy)
            .accessibilityLabel(count > 1 ? "\(count) new stories" : "New")
    }
}

// MARK: - The file on the Docket

/// A file on the Docket: bound in its leather, with how it's doing in the news, its latest
/// story and its coverage over the last two weeks.
struct FileCard: View {
    let file: TrackedFile
    let latest: DocketEntry?
    let stories: Int
    let newStories: Int
    let momentum: Momentum
    let heat: [Int?]
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 0) {
                CoverSpine(cover: file.cover)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(momentum.title)
                            .typeStyle(.label(9, tracking: 0.2))
                            .foregroundStyle(momentum.color)
                        if file.isPinned {
                            Lozenge(size: 4)
                            Text("Pinned")
                                .typeStyle(.label(9, tracking: 0.2))
                                .foregroundStyle(Theme.inkMuted)
                        }
                        Spacer(minLength: 0)
                        if newStories > 0 {
                            NewTag(count: newStories)
                        }
                    }

                    Text(file.title)
                        .typeStyle(.display(22, lineHeight: 1.18, relativeTo: .title3))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 8)

                    Text(latest?.story.headline ?? "Waiting for an edition that mentions \(file.keywordPhrase).")
                        .typeStyle(.text(14.5, italic: latest == nil, lineHeight: 1.35, relativeTo: .subheadline))
                        .foregroundStyle(latest == nil ? Theme.inkMuted : Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 6)

                    HStack(alignment: .bottom, spacing: 14) {
                        HeatStrip(marks: heat, height: 16)
                            .frame(maxWidth: 110)
                        Spacer(minLength: 0)
                        Text(footnote)
                            .typeStyle(.text(12.5, italic: true, relativeTo: .caption))
                            .foregroundStyle(file.keyDate == nil ? Theme.inkMuted : Theme.brassText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.top, 14)
                }
                .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
            }
            .background(Theme.paperInset)
            .overlay(Rectangle().strokeBorder(Theme.ruleStrong, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(CardPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the file")
    }

    /// "Hearing in nine days", or "Five stories"
    private var footnote: String {
        if let key = file.keyDate {
            let label = key.label.isEmpty ? "Date to watch" : key.label
            return "\(label) · \(EditionFormat.countdown(to: key.date).lowercased())"
        }
        return stories == 0 ? "No stories yet" : EditionFormat.storyCount(stories)
    }
}

/// Cards sink a little while pressed.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - On the edition's pages

/// The file's name under a headline in the edition: this story is on your Docket.
struct DocketMarker: View {
    let file: TrackedFile

    var body: some View {
        HStack(spacing: 6) {
            Lozenge(size: 4.5, color: file.cover.ink)
            Text(file.title)
                .typeStyle(.label(8.5, tracking: 0.18))
                .foregroundStyle(Theme.brassText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("On your Docket: \(file.title)")
    }
}

/// At the end of a story: follow it on the Docket, or, once it's there, go to its file.
struct FollowStoryButton: View {
    let story: Story
    let editionDate: String
    /// False for the stored copy of a saved story that isn't in its edition any more. Its id is
    /// only where the story stood when it was saved, and the Docket follows stories by edition
    /// date and id, so asking would show another story's file. Such a story reads as not
    /// followed, and can still open a new file from its own text.
    var hasEditionID = true
    @Environment(AppModel.self) private var model
    @Environment(DocketStore.self) private var docket

    var body: some View {
        if hasEditionID, let file = docket.files(following: story, on: editionDate).first {
            Button {
                model.openFile(file.id)
            } label: {
                HStack(spacing: 0) {
                    CoverSpine(cover: file.cover, width: 8)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("On your Docket")
                            .typeStyle(.label(9.5))
                            .foregroundStyle(Theme.brassText)
                        Text(file.title)
                            .typeStyle(.display(19, italic: true, relativeTo: .title3))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Text(EditionFormat.storyCount(docket.record(for: file.id).count) + " on the file")
                            .typeStyle(.text(13, italic: true, relativeTo: .footnote))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Chevron()
                        .padding(.trailing, 14)
                }
                .background(Theme.paperInset)
                .overlay(Rectangle().strokeBorder(Theme.ruleStrong, lineWidth: 0.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(CardPressStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the file on the Docket")
        } else {
            Button {
                model.follow(story, editionDate: editionDate)
            } label: {
                VStack(spacing: 0) {
                    DoubleRule(color: Theme.brass)
                    HStack(spacing: 10) {
                        Lozenge()
                        Text("Follow this story")
                            .typeStyle(.label(11))
                            .foregroundStyle(Theme.ink)
                        Lozenge()
                    }
                    .padding(.vertical, 13)
                    DoubleRule(color: Theme.brass, mirrored: true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressedRowStyle())
            .accessibilityHint("Adds it to the Docket, which keeps its record across editions")
        }
    }
}

/// On Today: the files that moved in this edition.
struct DocketBriefing: View {
    let items: [(file: TrackedFile, stories: Int)]
    let open: (TrackedFile.ID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            RuledLabel(title: "On your Docket")
            VStack(spacing: 0) {
                ForEach(items, id: \.file.id) { item in
                    Button {
                        open(item.file.id)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Lozenge(size: 6, color: item.file.cover.ink)
                                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                            Text(item.file.title)
                                .typeStyle(.display(18, italic: true, relativeTo: .headline))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(EditionFormat.storyCount(item.stories)) today")
                                .typeStyle(.text(12.5, italic: true, relativeTo: .caption))
                                .foregroundStyle(Theme.inkMuted)
                                .fixedSize()
                            Chevron()
                        }
                        .padding(EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressedRowStyle())
                    .overlay(alignment: .bottom) { Hairline() }
                    .padding(.horizontal, -10)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens the file")
                }
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - Toast

/// A slip of paper that drops in from the top for a moment.
struct Toast: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Lozenge(size: 5)
            Text(text)
                .typeStyle(.text(14, italic: true, relativeTo: .subheadline))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Lozenge(size: 5)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(PaperBackground())
        .overlay(Rectangle().strokeBorder(Theme.ruleStrong, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
