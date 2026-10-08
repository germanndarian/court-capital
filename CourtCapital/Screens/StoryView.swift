import SwiftUI

struct StoryView: View {
    let edition: Edition
    let story: Story
    let backTitle: String
    let back: () -> Void
    @State private var openSource: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StoryTopBar(backTitle: backTitle, editionNumber: edition.number, back: back)

                HStack(spacing: 10) {
                    Text(edition.section(containing: story.id)?.kicker ?? "")
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
                    Text(EditionFormat.storyDate(edition.day))
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
                ShareStoryButton(text: StoryShare.text(story, in: edition))
                    .padding(.top, 28)

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
