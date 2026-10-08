import SwiftUI

/// Crest flanked by volume and edition number, the title, a double rule and the dateline.
struct MastheadView: View {
    let edition: Edition

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Vol. \(Roman.numeral(edition.volume))")
                    .frame(width: 90, alignment: .leading)
                Spacer(minLength: 0)
                Crest()
                Spacer(minLength: 0)
                Text("No. \(Roman.numeral(edition.number))")
                    .frame(width: 90, alignment: .trailing)
            }
            .typeStyle(.label(9.5))
            .foregroundStyle(Theme.inkMuted)

            Wordmark(style: .masthead)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.top, 10)
                .accessibilityAddTraits(.isHeader)

            DoubleRule()
                .padding(.top, 12)

            HStack(alignment: .firstTextBaseline) {
                Text(EditionFormat.dateline(edition.day))
                    .typeStyle(.dateline)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("Weekday Edition")
                    .typeStyle(.label(9.5, tracking: 0.2))
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(.top, 8)
            .padding(.bottom, 7)

            Hairline(color: Theme.ruleStrong)
        }
    }
}

/// A centred label between two brass hairlines.
struct RuledLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.brass).frame(height: 0.5)
            Text(title)
                .typeStyle(.label(10, tracking: 0.24))
                .foregroundStyle(Theme.brassText)
                .fixedSize()
            Rectangle().fill(Theme.brass).frame(height: 0.5)
        }
    }
}

/// Three-column market figures with hairline gutters.
struct MarketsStrip: View {
    let quotes: [Quote]

    var body: some View {
        VStack(spacing: 0) {
            DoubleRule()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0.5), count: 3), spacing: 0.5) {
                ForEach(quotes) { quote in
                    MarketCell(quote: quote)
                }
            }
            .background(Theme.rule)
            Hairline(color: Theme.ruleStrong)
        }
    }
}

private struct MarketCell: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(quote.name)
                .typeStyle(.label(9, tracking: 0.18))
                .foregroundStyle(Theme.inkMuted)
            Text(quote.levelLabel)
                .typeStyle(.figure)
                .foregroundStyle(Theme.ink)
                .padding(.top, 4)
            Text(quote.changeWithArrow)
                .typeStyle(TypeStyle(face: .newsreader, size: 11.5, weight: 500, tabularFigures: true, relativeTo: .caption))
                .foregroundStyle(quote.direction.color)
                .padding(.top, 2)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 11, trailing: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PaperBackground())
        .accessibilityElement(children: .combine)
    }
}

/// "I. Corporate Law ……… Four stories" over a heavy rule.
struct SectionHeader: View {
    let numeral: String
    let title: String
    let count: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(numeral).")
                    .typeStyle(.sectionNumeral)
                    .foregroundStyle(Theme.brassText)
                Text(title)
                    .typeStyle(.sectionTitle)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                Text(count)
                    .typeStyle(.text(12.5, italic: true, relativeTo: .caption))
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Hairline(color: Theme.ruleStrong, thickness: 1.5)
        }
    }
}

/// A headline with its region tag and chevron. Pressing fills the row with paper inset.
struct StoryRow: View {
    let story: Story
    let edition: Edition
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Text(story.headline)
                    .typeStyle(.rowHeadline)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 9) {
                    RegionTag(region: story.region)
                    Chevron()
                }
                .padding(.top, 3)
            }
            .padding(EdgeInsets(top: 14, leading: 10, bottom: 15, trailing: 10))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressedRowStyle())
        .contextMenu {
            ShareLink(item: StoryShare.text(story, in: edition)) {
                Label("Share Story", systemImage: "square.and.arrow.up")
            }
        }
        .overlay(alignment: .bottom) { Hairline() }
        .padding(.horizontal, -10)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the story")
    }
}

/// What a shared story looks like in Messages or Mail.
enum StoryShare {
    static func text(_ story: Story, in edition: Edition) -> String {
        var lines = [story.headline, "", story.plainWordsText]
        if let source = story.sources.first {
            lines += ["", "\(source.outlet): \(source.url)"]
        }
        lines += ["", "Court & Capital · \(EditionFormat.dateline(edition.day))"]
        return lines.joined(separator: "\n")
    }
}

struct Chevron: View {
    var body: some View {
        Text("›")
            .typeStyle(.text(20, relativeTo: .body))
            .foregroundStyle(Theme.inkMuted)
            .frame(height: 12)
            .accessibilityHidden(true)
    }
}

/// Rows highlight with `paperInset` while pressed.
struct PressedRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.paperInset : .clear)
    }
}

/// Small-caps page heading used by Archive and Settings: kicker over a Playfair title.
struct ScreenHeading: View {
    let kicker: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kicker)
                .typeStyle(.label(10))
                .foregroundStyle(Theme.brassText)
            Text(title)
                .typeStyle(.screenTitle)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
