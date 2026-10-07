import SafariServices
import SwiftUI

/// "‹ Today · C&C · No. CC" over a hairline.
struct StoryTopBar: View {
    let editionNumber: Int
    let back: () -> Void

    var body: some View {
        HStack {
            Button(action: back) {
                HStack(spacing: 6) {
                    Text("‹")
                        .typeStyle(.text(22, relativeTo: .body))
                        .frame(height: 10)
                        .offset(y: -1.5)
                    Text("Today")
                        .typeStyle(.label(10))
                }
                .foregroundStyle(Theme.brassText)
                .padding(.vertical, 12)
                .frame(minWidth: 80, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Today")

            Spacer(minLength: 0)
            Text("C&C")
                .typeStyle(.display(16, italic: true, relativeTo: nil))
                .foregroundStyle(Theme.ink)
                .accessibilityHidden(true)
            Spacer(minLength: 0)

            Text("No. \(Roman.numeral(editionNumber))")
                .typeStyle(.label(9.5, tracking: 0.2))
                .foregroundStyle(Theme.inkMuted)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .frame(height: 46)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

struct WhosWhoCard: View {
    let terms: [Term]
    @ScaledMetric(relativeTo: .subheadline) private var termWidth: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Who’s who")
                .typeStyle(.label(9.5))
                .foregroundStyle(Theme.brassText)
                .accessibilityAddTraits(.isHeader)
            Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 7) {
                ForEach(terms) { term in
                    GridRow(alignment: .firstTextBaseline) {
                        Text(term.term)
                            .typeStyle(.text(14.5, weight: 600, lineHeight: 1.3, relativeTo: .subheadline))
                            .foregroundStyle(Theme.ink)
                            .frame(width: termWidth, alignment: .leading)
                        Text(term.definition)
                            .typeStyle(.text(14.5, italic: true, lineHeight: 1.3, relativeTo: .subheadline))
                            .foregroundStyle(Theme.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 10)
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperInset)
        .overlay(Rectangle().strokeBorder(Theme.ruleStrong, lineWidth: 0.5))
    }
}

/// Quote block A: an open, centred block between mirrored double rules.
struct WhyItMatters: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            DoubleRule()
            VStack(spacing: 10) {
                Text("Why it matters")
                    .typeStyle(.label(9.5, tracking: 0.24))
                    .foregroundStyle(Theme.burgundy)
                Text(text)
                    .typeStyle(.quote)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
            }
            .padding(EdgeInsets(top: 18, leading: 4, bottom: 20, trailing: 4))
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            DoubleRule(mirrored: true)
        }
        .padding(.vertical, 4)
    }
}

/// Quote block B: racing green by day, navy leather with a brass edge by night.
struct PlainWords: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("In plain words")
                    .typeStyle(.label(9.5, tracking: 0.24))
                    .fixedSize()
                Rectangle().frame(height: 0.5).opacity(0.5)
            }
            .foregroundStyle(Theme.plainLabel)
            Text(text)
                .typeStyle(.text(17, lineHeight: 1.55))
                .foregroundStyle(Theme.plainInk)
        }
        .padding(EdgeInsets(top: 20, leading: 20, bottom: 22, trailing: 20))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.plainBg, in: RoundedRectangle(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.plainEdge, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
}

struct SourceList: View {
    let sources: [Source]
    let open: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sources")
                .typeStyle(.label(9.5))
                .foregroundStyle(Theme.inkMuted)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
            Hairline(color: Theme.ruleStrong, thickness: 1.5)
            ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                Button {
                    open(source.url)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(Roman.numeral(index + 1).lowercased()).")
                            .typeStyle(.display(14, italic: true, relativeTo: .callout))
                            .foregroundStyle(Theme.brassText)
                            .frame(minWidth: 18, alignment: .leading)
                            .accessibilityHidden(true)
                        Text(source.name)
                            .typeStyle(.text(16, relativeTo: .callout))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("↗\u{FE0E}")
                            .typeStyle(.text(13, relativeTo: .callout))
                            .foregroundStyle(Theme.inkMuted)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SourceRowStyle())
                .overlay(alignment: .bottom) { Hairline() }
                .accessibilityHint("Opens the source in Safari")
            }
        }
    }
}

private struct SourceRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Theme.brassText : Theme.ink)
    }
}

/// Where who's who, body, quotes and sources land for stories the feed has not filled yet.
struct FeedPlaceholder: View {
    var body: some View {
        ZStack {
            Canvas { context, size in
                var path = Path()
                var offset: CGFloat = 0
                while offset < size.width + size.height {
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset - size.height, y: size.height))
                    offset += 9.5
                }
                context.stroke(path, with: .color(Theme.rule), lineWidth: 0.5)
            }
            Text("who’s who · body · why it matters\nin plain words · sources\n— from the edition feed —")
                .font(.system(size: 11, design: .monospaced))
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.inkMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.paper)
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(Rectangle().strokeBorder(Theme.ruleStrong, lineWidth: 0.5))
        .accessibilityElement()
        .accessibilityLabel("The full story arrives with the edition feed.")
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = Palette.brassText
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
