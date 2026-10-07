import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let edition = model.edition
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    MastheadView(edition: edition)

                    RuledLabel(title: "The Big Story")
                        .padding(.top, 28)
                    Button {
                        model.open(edition.bigStoryID)
                    } label: {
                        Text(edition.bigStory)
                            .typeStyle(.bigStory)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                    .accessibilityHint("Opens the story")

                    HStack(alignment: .firstTextBaseline) {
                        Text("The Markets")
                            .typeStyle(.label(10))
                            .foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Text(edition.marketsNote)
                            .typeStyle(.text(12.5, italic: true, relativeTo: .caption))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .padding(.top, 30)
                    .id(TodayAnchor.markets)
                    MarketsStrip(markets: edition.markets)
                        .padding(.top, 8)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Text(EditionFormat.storyCount(edition.storyCount))
                            Lozenge()
                            Text(EditionFormat.readTime(edition.readMinutes))
                        }
                        .fixedSize()
                        VStack(spacing: 8) {
                            Text(EditionFormat.storyCount(edition.storyCount))
                            Lozenge()
                            Text(EditionFormat.readTime(edition.readMinutes))
                        }
                    }
                    .typeStyle(.label(10))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.top, 22)
                    .accessibilityElement(children: .combine)

                    ForEach(edition.sections) { section in
                        VStack(spacing: 0) {
                            SectionHeader(
                                numeral: section.numeral,
                                title: section.name,
                                count: EditionFormat.storyCount(section.stories.count)
                            )
                            ForEach(section.stories) { story in
                                StoryRow(story: story) { model.open(story.id) }
                            }
                        }
                        .padding(.top, 30)
                    }

                    EditionFooter(nextDelivery: EditionCalendar.nextDelivery(after: edition.date))
                        .padding(.top, 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.pendingAnchor) { _, anchor in
                guard let anchor else { return }
                withAnimation { proxy.scrollTo(anchor, anchor: .top) }
                model.pendingAnchor = nil
            }
        }
        .paperScreen()
    }
}

private struct EditionFooter: View {
    let nextDelivery: Date

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Lozenge(size: 4)
                Lozenge(size: 5)
                Lozenge(size: 4)
            }
            Text("End of today’s edition")
                .typeStyle(.text(14, italic: true))
                .foregroundStyle(Theme.ink)
            Text("Next: \(EditionFormat.weekday(nextDelivery)) at \(EditionFormat.time(minutesAfterMidnight: EditionCalendar.deliveryHour * 60 + EditionCalendar.deliveryMinute))")
                .typeStyle(.label(9.5, tracking: 0.2))
                .foregroundStyle(Theme.inkMuted)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
