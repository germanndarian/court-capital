import SwiftUI

/// A story from an edition on the iPhone, or the stored copy of a saved one.
struct StoryView: View {
    let placed: PlacedStory
    let backTitle: String
    let back: () -> Void
    @State private var openSource: IdentifiableURL?
    @Environment(AppModel.self) private var model
    @Environment(SavedStore.self) private var saved

    var body: some View {
        let story = placed.story
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StoryTopBar(
                    backTitle: backTitle,
                    editionNumber: placed.number,
                    bookmark: StoryBookmark(isSaved: saved.isSaved(story, on: placed.editionDate)) { model.toggleSaved(placed.saved()) },
                    back: back
                )

                HStack(spacing: 10) {
                    Text(placed.sectionKicker)
                        .typeStyle(.label(10))
                        .foregroundStyle(Theme.brassText)
                    RegionTag(region: story.region)
                }
                .padding(.top, 26)

                Text(story.headline)
                    .typeStyle(.storyHeadline)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 12)
                    .accessibilityAddTraits(.isHeader)

                HStack(alignment: .firstTextBaseline) {
                    Text(EditionFormat.storyDate(placed.day))
                        .typeStyle(.text(13, italic: true, relativeTo: .footnote))
                        .foregroundStyle(Theme.inkMuted)
                    Spacer(minLength: 8)
                    Text(EditionFormat.readTime(story.readingMinutes))
                        .typeStyle(.label(9.5, tracking: 0.2))
                        .foregroundStyle(Theme.inkMuted)
                }
                .padding(.top, 16)
                .padding(.bottom, 12)

                DoubleRule()

                WhosWhoCard(terms: story.whosWho)
                    .padding(.top, 22)
                DropCapParagraph(runs: story.bodyRuns)
                    .padding(.top, 24)
                if let why = story.whyItMatters {
                    WhyItMatters(text: why)
                        .padding(.top, 30)
                }
                PlainWords(text: story.plainWordsText)
                    .padding(.top, 26)
                SourceList(sources: story.sources) { openSource = IdentifiableURL(url: $0) }
                    .padding(.top, 32)
                FollowStoryButton(story: story, editionDate: placed.editionDate, hasEditionID: placed.isLive)
                    .padding(.top, 32)
                ShareStoryButton(text: StoryShare.text(story, on: placed.day))
                    .padding(.top, 14)

                Crest(diameter: 28, monogram: 9)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 56)
        }
        .scrollIndicators(.hidden)
        .paperScreen()
        .sheet(item: $openSource) { source in
            SafariView(url: source.url)
                .ignoresSafeArea()
        }
    }
}

struct IdentifiableURL: Identifiable {
    let url: URL
    var id: URL { url }
}
