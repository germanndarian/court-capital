import SwiftUI

/// The Saved shelf, opened from the Archive: the stories you bookmarked, newest saved first.
/// Each keeps its own copy of the text, so it opens even when its edition is gone.
struct SavedView: View {
    @Environment(AppModel.self) private var model
    @Environment(SavedStore.self) private var saved

    var body: some View {
        let stories = saved.stories
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StoryTopBar(backTitle: "Archive", trailing: "") { back() }

                ScreenHeading(kicker: "Kept on this iPhone", title: "Saved Stories")
                    .padding(.top, 24)
                Text(summary(count: stories.count))
                    .typeStyle(.text(14, italic: true, relativeTo: .subheadline))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.top, 6)

                if stories.isEmpty {
                    SavedIntro()
                        .padding(.top, 24)
                } else {
                    DoubleRule()
                        .padding(.top, 20)
                    ForEach(stories) { story in
                        SavedRow(story: story) {
                            model.archivePath.append(.savedStory(story))
                        } remove: {
                            model.removeSaved(story)
                        }
                    }
                    Crest(diameter: 28, monogram: 9)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 56)
            .animation(.snappy, value: stories)
        }
        .scrollIndicators(.hidden)
        .paperScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func back() {
        if !model.archivePath.isEmpty { model.archivePath.removeLast() }
    }

    /// "Three stories, the newest saved first"
    private func summary(count: Int) -> String {
        switch count {
        case 0: "Stories you bookmark are kept here"
        case 1: "One story, kept on this iPhone"
        default: "\(EditionFormat.storyCount(count)), the newest saved first"
        }
    }
}

/// How to save a story, before the first one.
private struct SavedIntro: View {
    private let steps = [
        "Tap the bookmark at the top of a story.",
        "Or long-press a headline, in Today or in an earlier edition, and choose Save Story.",
        "Press and hold a saved story here to take it off the shelf again.",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nothing saved yet")
                .typeStyle(.display(24, italic: true, relativeTo: .title2))
                .foregroundStyle(Theme.ink)
            Text("Keep the stories you want to come back to. A saved story keeps its own copy on this iPhone, so it stays here even after its edition is replaced.")
                .typeStyle(.text(15.5, lineHeight: 1.45, relativeTo: .body))
                .foregroundStyle(Theme.inkMuted)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(Roman.numeral(index + 1).lowercased()).")
                            .typeStyle(.display(15, italic: true, relativeTo: .callout))
                            .foregroundStyle(Theme.brassText)
                            .frame(minWidth: 20, alignment: .leading)
                        Text(step)
                            .typeStyle(.text(15, lineHeight: 1.4, relativeTo: .callout))
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
            .padding(.top, 18)
        }
        .padding(EdgeInsets(top: 18, leading: 18, bottom: 20, trailing: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperInset)
        .overlay(Rectangle().strokeBorder(Theme.ruleStrong, lineWidth: 0.5))
    }
}

/// The edition's date and section over the headline, with its region tag and a chevron.
private struct SavedRow: View {
    let story: SavedStory
    let open: () -> Void
    let remove: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(EditionFormat.short(story.day))
                            .typeStyle(.label(9.5, tracking: 0.18))
                            .foregroundStyle(Theme.ink)
                        Text(story.sectionKicker)
                            .typeStyle(.label(9, tracking: 0.18))
                            .foregroundStyle(Theme.brassText)
                            .lineLimit(1)
                    }
                    Text(story.headline)
                        .typeStyle(.rowHeadline)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 9) {
                    RegionTag(region: Region(story.story.region))
                    Chevron()
                }
            }
            .padding(EdgeInsets(top: 14, leading: 10, bottom: 15, trailing: 10))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressedRowStyle())
        .contextMenu {
            Button(action: remove) {
                Label("Remove from Saved", systemImage: "bookmark.slash")
            }
        }
        .overlay(alignment: .bottom) { Hairline() }
        .padding(.horizontal, -10)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the story")
        .accessibilityAction(named: "Remove from Saved", remove)
    }
}
