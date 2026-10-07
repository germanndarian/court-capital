import SwiftUI
import WidgetKit

@main
struct CourtCapitalWidgets: WidgetBundle {
    var body: some Widget {
        EditionWidget()
        EditionNumberWidget()
    }
}

// MARK: - Timeline

struct EditionEntry: TimelineEntry {
    let date: Date
    let edition: Edition
}

/// One entry per edition; the next timeline is requested when the 6:30 a.m. edition lands.
struct EditionProvider: TimelineProvider {
    func placeholder(in context: Context) -> EditionEntry {
        EditionEntry(date: .now, edition: SampleEdition.edition)
    }

    func getSnapshot(in context: Context, completion: @escaping (EditionEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EditionEntry>) -> Void) {
        let entry = EditionEntry(date: .now, edition: SampleEdition.edition)
        let refresh = EditionCalendar.nextDelivery(after: .now)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

enum WidgetLink {
    static let today = URL(string: "courtcapital://today")!
    static let markets = URL(string: "courtcapital://today/markets")!
}

// MARK: - Widgets

struct EditionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EditionWidget", provider: EditionProvider()) { entry in
            EditionWidgetView(entry: entry)
        }
        .configurationDisplayName("Today’s Edition")
        .description("The Big Story, the markets and how long the edition takes to read.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct EditionNumberWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EditionNumberWidget", provider: EditionProvider()) { entry in
            CircularFigure(big: Roman.numeral(entry.edition.number), small: "No.")
                .widgetURL(WidgetLink.today)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        }
        .configurationDisplayName("Edition Number")
        .description("Today’s edition number in Roman numerals.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct EditionWidgetView: View {
    let entry: EditionEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let edition = entry.edition
        Group {
            switch family {
            case .systemMedium:
                MediumEditionView(edition: edition)
            case .accessoryRectangular:
                RectangularEditionView(edition: edition)
            case .accessoryCircular:
                CircularFigure(big: "\(edition.readMinutes)", small: "Min")
            case .accessoryInline:
                Text("\(Image(systemName: "diamond.fill")) Court & Capital · \(edition.readMinutes) min")
            default:
                SmallEditionView(edition: edition)
            }
        }
        .widgetURL(WidgetLink.today)
        .containerBackground(for: .widget) {
            if family.isAccessory {
                AccessoryWidgetBackground()
            } else {
                PaperBackground(glow: true)
            }
        }
    }
}

private extension WidgetFamily {
    var isAccessory: Bool {
        self == .accessoryRectangular || self == .accessoryCircular || self == .accessoryInline
    }
}

// MARK: - Home Screen

/// 170 × 170: crest, Big Story in four lines, date and reading time.
struct SmallEditionView: View {
    let edition: Edition

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Crest(diameter: 22, ring: 2, monogram: 7)
                Spacer()
                Text("No. \(Roman.numeral(edition.number))")
                    .typeStyle(.label(8, tracking: 0.2).fixed)
                    .foregroundStyle(Theme.inkMuted)
            }
            Text("The Big Story")
                .typeStyle(.label(7.5).fixed)
                .foregroundStyle(Theme.brassText)
                .padding(.top, 10)
            Text(edition.bigStory)
                .typeStyle(.display(14.5, lineHeight: 1.24, relativeTo: nil))
                .foregroundStyle(Theme.ink)
                .lineLimit(4)
                .padding(.top, 4)
            Spacer(minLength: 0)
            HStack {
                Text(EditionFormat.short(edition.date))
                Spacer()
                Text("\(edition.readMinutes) min")
            }
            .typeStyle(.label(7.5, tracking: 0.18).fixed)
            .foregroundStyle(Theme.inkMuted)
            .padding(.top, 6)
            .overlay(alignment: .top) { Hairline(color: Theme.ruleStrong) }
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14))
    }
}

/// 364 × 170: wordmark, Big Story at 1.5 : 1 with four markets.
struct MediumEditionView: View {
    let edition: Edition

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Wordmark(style: .display(16, relativeTo: nil))
                Spacer()
                Text("\(EditionFormat.short(edition.date)) · No. \(Roman.numeral(edition.number))")
                    .typeStyle(.label(8, tracking: 0.2).fixed)
                    .foregroundStyle(Theme.inkMuted)
            }
            DoubleRule(heavy: 1)
                .padding(.top, 6)
            GeometryReader { proxy in
                let gap: CGFloat = 14
                let storyWidth = (proxy.size.width - gap) * 0.6
                HStack(alignment: .top, spacing: gap) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("The Big Story")
                            .typeStyle(.label(7.5).fixed)
                            .foregroundStyle(Theme.brassText)
                        Text(edition.bigStory)
                            .typeStyle(.display(14.5, lineHeight: 1.24, relativeTo: nil))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(4)
                            .padding(.top, 4)
                        Spacer(minLength: 0)
                        Text("\(EditionFormat.storyCount(edition.storyCount)) · \(edition.readMinutes) min")
                            .typeStyle(.label(7.5, tracking: 0.18).fixed)
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .frame(width: storyWidth, alignment: .leading)

                    Link(destination: WidgetLink.markets) {
                        VStack(spacing: 0) {
                            ForEach(edition.widgetMarkets) { market in
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(market.name)
                                        .typeStyle(.label(7.5, tracking: 0.16).fixed)
                                        .foregroundStyle(Theme.inkMuted)
                                    Spacer(minLength: 0)
                                    Text(market.changeLabel)
                                        .typeStyle(TypeStyle(face: .newsreader, size: 11, weight: 500, tabularFigures: true, relativeTo: nil))
                                        .foregroundStyle(market.direction.color)
                                }
                                .lineLimit(1)
                                .padding(.bottom, 4)
                                .overlay(alignment: .bottom) { Hairline() }
                                if market.id != edition.widgetMarkets.last?.id { Spacer(minLength: 0) }
                            }
                        }
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Theme.ruleStrong).frame(width: 0.5)
                        }
                    }
                }
            }
            .padding(.top, 9)
        }
        .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
    }
}

// MARK: - Lock Screen

struct RectangularEditionView: View {
    let edition: Edition

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("C&C · The Big Story")
                .typeStyle(.label(8, tracking: 0.2, weight: 700).fixed)
                .opacity(0.75)
            Text(edition.bigStory)
                .typeStyle(.display(13.5, lineHeight: 1.2, relativeTo: nil))
                .lineLimit(2)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A large figure over a small caption inside a ring: reading time or edition number.
struct CircularFigure: View {
    let big: String
    let small: String

    var body: some View {
        ZStack {
            Circle()
                .inset(by: 0.75)
                .stroke(.white.opacity(0.35), lineWidth: 1.5)
                .widgetAccentable()
            VStack(spacing: 2) {
                Text(big)
                    .typeStyle(.display(26, lineHeight: 1, relativeTo: nil))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(small)
                    .typeStyle(.label(7.5, tracking: 0.18, weight: 700).fixed)
                    .opacity(0.8)
            }
            .padding(.horizontal, 6)
        }
    }
}
