import SwiftUI

struct StoryView: View {
    let story: Story
    @Environment(AppModel.self) private var model
    @State private var openSource: IdentifiableURL?

    var body: some View {
        let edition = model.edition
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StoryTopBar(editionNumber: edition.number) { model.showToday() }

                HStack(spacing: 10) {
                    Text(edition.section(containing: story.id)?.kicker ?? "")
                        .typeStyle(.label(10))
                        .foregroundStyle(Theme.brassText)
                    RegionTag(region: story.region)
                }
                .padding(.top, 26)

                Text(story.title)
                    .typeStyle(.storyHeadline)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 12)
                    .accessibilityAddTraits(.isHeader)

                HStack(alignment: .firstTextBaseline) {
                    Text(EditionFormat.storyDate(edition.date))
                        .typeStyle(.text(13, italic: true, relativeTo: .footnote))
                        .foregroundStyle(Theme.inkMuted)
                    Spacer(minLength: 8)
                    Text(EditionFormat.readTime(story.readMinutes))
                        .typeStyle(.label(9.5, tracking: 0.2))
                        .foregroundStyle(Theme.inkMuted)
                }
                .padding(.top, 16)
                .padding(.bottom, 12)

                DoubleRule()

                if let content = story.content {
                    WhosWhoCard(terms: content.whosWho)
                        .padding(.top, 22)
                    DropCapParagraph(runs: content.body)
                        .padding(.top, 24)
                    WhyItMatters(text: content.whyItMatters)
                        .padding(.top, 30)
                    PlainWords(text: content.plainWords)
                        .padding(.top, 26)
                    SourceList(sources: content.sources) { openSource = IdentifiableURL(url: $0) }
                        .padding(.top, 32)
                } else {
                    FeedPlaceholder()
                        .padding(.top, 24)
                }

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
