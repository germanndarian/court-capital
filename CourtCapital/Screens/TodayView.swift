import SwiftUI

/// The Today tab: the newest edition, or a quiet notice while there isn't one.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(EditionStore.self) private var store

    var body: some View {
        Group {
            if let edition = store.latest {
                EditionPage(
                    edition: edition,
                    isToday: true,
                    note: store.lateNote ?? store.refreshProblem,
                    anchor: model.pendingAnchor,
                    openStory: { model.openToday(story: $0) },
                    anchorHandled: { model.pendingAnchor = nil }
                )
                .refreshable { await store.refresh() }
            } else if !store.hasLoadedOnce || store.isRefreshing {
                NoticeView(title: "Fetching the edition", message: nil, showsProgress: true)
            } else {
                ScrollView {
                    NoticeView(
                        title: "No edition yet",
                        message: store.refreshProblem ?? "The first edition arrives on the next weekday at 5:00 a.m."
                    )
                    .containerRelativeFrame(.vertical)
                }
                .refreshable { await store.refresh() }
            }
        }
        .paperScreen()
    }
}

/// One edition, laid out like the front page. Used by Today and by the Archive.
struct EditionPage: View {
    let edition: Edition
    let isToday: Bool
    var note: String?
    var anchor: TodayAnchor?
    let openStory: (Story.ID) -> Void
    var anchorHandled: () -> Void = {}

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    MastheadView(edition: edition)

                    if let note {
                        Text(note)
                            .typeStyle(.text(13, italic: true, lineHeight: 1.35, relativeTo: .footnote))
                            .foregroundStyle(Theme.burgundy)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    }

                    RuledLabel(title: "The Big Story")
                        .padding(.top, 28)
                    Button {
                        if let id = edition.bigStory.storyId { openStory(id) }
                    } label: {
                        Text(edition.bigStory.text)
                            .typeStyle(.bigStory)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(edition.bigStory.storyId == nil)
                    .padding(.top, 14)
                    .accessibilityHint(edition.bigStory.storyId == nil ? "" : "Opens the story")

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
                    MarketsStrip(quotes: edition.markets.quotes)
                        .padding(.top, 8)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Text(EditionFormat.storyCount(edition.storyCount))
                            Lozenge()
                            Text(EditionFormat.readTime(edition.readingMinutes))
                        }
                        .fixedSize()
                        VStack(spacing: 8) {
                            Text(EditionFormat.storyCount(edition.storyCount))
                            Lozenge()
                            Text(EditionFormat.readTime(edition.readingMinutes))
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
                                title: section.title,
                                count: EditionFormat.storyCount(section.stories.count)
                            )
                            ForEach(section.stories) { story in
                                StoryRow(story: story, edition: edition) { openStory(story.id) }
                            }
                        }
                        .padding(.top, 30)
                    }

                    EditionFooter(edition: edition, isToday: isToday)
                        .padding(.top, 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .onChange(of: anchor, initial: true) { _, anchor in
                guard let anchor else { return }
                withAnimation { proxy.scrollTo(anchor, anchor: .top) }
                anchorHandled()
            }
        }
    }
}

private struct EditionFooter: View {
    let edition: Edition
    let isToday: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Lozenge(size: 4)
                Lozenge(size: 5)
                Lozenge(size: 4)
            }
            Text(isToday ? "End of today’s edition" : "End of the edition")
                .typeStyle(.text(14, italic: true))
                .foregroundStyle(Theme.ink)
            if isToday {
                let next = EditionCalendar.nextReady(after: edition.day.addingTimeInterval(12 * 3600))
                Text("Next: \(EditionFormat.weekday(next)) at \(EditionFormat.time(minutesAfterMidnight: EditionCalendar.readyHour * 60 + EditionCalendar.readyMinute))")
                    .typeStyle(.label(9.5, tracking: 0.2))
                    .foregroundStyle(Theme.inkMuted)
            }
            Text("Court & Capital · \(edition.footer)")
                .typeStyle(.text(12, italic: true, lineHeight: 1.4, relativeTo: .caption))
                .foregroundStyle(Theme.inkMuted)
                .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A centred crest with a short message, for loading, empty and error states.
struct NoticeView: View {
    let title: String
    let message: String?
    var showsProgress = false

    var body: some View {
        VStack(spacing: 14) {
            Crest(diameter: 46, monogram: 14)
            Text(title)
                .typeStyle(.display(24, italic: true, relativeTo: .title2))
                .foregroundStyle(Theme.ink)
            if showsProgress {
                ProgressView()
                    .tint(Theme.brass)
            }
            if let message {
                Text(message)
                    .typeStyle(.text(15, italic: true, lineHeight: 1.45, relativeTo: .body))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
