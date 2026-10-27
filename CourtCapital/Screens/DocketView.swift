import SwiftUI

/// The Docket tab: the stories you follow over weeks, each a file bound in leather.
struct DocketView: View {
    @Environment(AppModel.self) private var model
    @Environment(EditionStore.self) private var store
    @Environment(DocketStore.self) private var docket
    @State private var removing: TrackedFile?

    var body: some View {
        let open = docket.openFiles
        let closed = docket.closedFiles
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(kicker: "Stories you follow", title: "The Docket")
                Text(summary(open: open, closed: closed))
                    .typeStyle(.text(14, italic: true, relativeTo: .subheadline))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.top, 6)

                if open.isEmpty {
                    DocketIntro()
                        .padding(.top, 24)
                } else {
                    VStack(spacing: 14) {
                        ForEach(open) { file in
                            card(file)
                        }
                    }
                    .padding(.top, 22)
                }

                SheetButton(title: open.isEmpty ? "Open your first file" : "Open a new file") {
                    model.newFile()
                }
                .padding(.top, 26)

                if !closed.isEmpty {
                    ClosedCasesHeader(count: closed.count)
                        .padding(.top, 40)
                    ForEach(closed) { file in
                        ClosedFileRow(file: file, stories: docket.record(for: file.id).count) {
                            model.docketPath.append(.file(file.id))
                        }
                        .contextMenu { menu(for: file) }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 36)
            .animation(.snappy, value: docket.files)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.refresh() }
        .paperScreen()
        .confirmationDialog(
            "Remove “\(removing?.title ?? "")” from the Docket?",
            isPresented: Binding { removing != nil } set: { if !$0 { removing = nil } },
            titleVisibility: .visible,
            presenting: removing
        ) { file in
            Button("Remove the file", role: .destructive) { docket.remove(file.id) }
        } message: { _ in
            Text("Its notes and settings go with it. The stories stay in the archive.")
        }
    }

    private func card(_ file: TrackedFile) -> some View {
        let record = docket.record(for: file.id)
        return FileCard(
            file: file,
            latest: record.first,
            stories: record.count,
            newStories: docket.newEntries(for: file).count,
            momentum: docket.momentum(for: file),
            heat: docket.heat(for: file, weekdays: 10)
        ) {
            model.docketPath.append(.file(file.id))
        }
        .contextMenu { menu(for: file) }
    }

    @ViewBuilder private func menu(for file: TrackedFile) -> some View {
        if !file.isClosed {
            Button {
                docket.setPinned(file.id, !file.isPinned)
            } label: {
                Label(file.isPinned ? "Unpin" : "Pin to the Top", systemImage: file.isPinned ? "pin.slash" : "pin")
            }
        }
        Button {
            model.edit(file)
        } label: {
            Label("Edit the File", systemImage: "pencil")
        }
        if file.isClosed {
            Button {
                docket.reopen(file.id)
            } label: {
                Label("Reopen the Case", systemImage: "arrow.uturn.backward")
            }
        } else {
            Button {
                docket.close(file.id)
                model.announce("Case closed: \(file.title)")
            } label: {
                Label("Close the Case", systemImage: "archivebox")
            }
        }
        Button(role: .destructive) {
            removing = file
        } label: {
            Label("Remove from the Docket", systemImage: "trash")
        }
    }

    /// "Three open files · one with news"
    private func summary(open: [TrackedFile], closed: [TrackedFile]) -> String {
        guard !open.isEmpty else {
            return closed.isEmpty ? "The long-running stories, kept on file" : "No open files · \(EditionFormat.spelled(closed.count)) closed"
        }
        var parts = ["\(EditionFormat.spelledCapitalised(open.count)) open \(open.count == 1 ? "file" : "files")"]
        let withNews = docket.filesWithNews.count
        if withNews > 0 {
            parts.append("\(EditionFormat.spelled(withNews)) with news")
        }
        return parts.joined(separator: " · ")
    }
}

/// What the Docket does, before the first file.
private struct DocketIntro: View {
    private let steps = [
        "Tap Follow this story at the end of any story, or long-press a headline in Today.",
        "Choose what to follow, like “SpaceX Tesla merger”. Every edition that covers it joins the file’s record, earlier ones too, even when a story puts it in other words.",
        "Add a date to watch, a hearing or a listing, and your own notes. New stories get a burgundy mark.",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nothing on the docket yet")
                .typeStyle(.display(24, italic: true, relativeTo: .title2))
                .foregroundStyle(Theme.ink)
            Text("Some stories take weeks: a merger in talks, an IPO, a case on its way to the Supreme Court. Keep a file on them here.")
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

private struct ClosedCasesHeader: View {
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Closed cases")
                    .typeStyle(.display(20, italic: true, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(EditionFormat.spelledCapitalised(count))
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

private struct ClosedFileRow: View {
    let file: TrackedFile
    let stories: Int
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Lozenge(size: 5, color: file.cover.ink)
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.title)
                        .typeStyle(.rowHeadline)
                        .foregroundStyle(Theme.ink)
                        .strikethrough(color: Theme.inkMuted.opacity(0.5))
                    if let closed = file.closedOn.flatMap(EditionCalendar.date(from:)) {
                        Text("Closed \(EditionFormat.storyDate(closed)) · \(EditionFormat.storyCount(stories).lowercased())")
                            .typeStyle(.text(12.5, italic: true, relativeTo: .caption))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron()
            }
            .padding(EdgeInsets(top: 13, leading: 10, bottom: 13, trailing: 10))
            .contentShape(Rectangle())
            .opacity(0.75)
        }
        .buttonStyle(PressedRowStyle())
        .overlay(alignment: .bottom) { Hairline() }
        .padding(.horizontal, -10)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the closed file")
    }
}

// MARK: - The file

/// One file: how it's doing in the news, what it follows, your date and notes, and the
/// record of every story, newest first.
struct DocketFileView: View {
    let fileID: TrackedFile.ID
    @Environment(AppModel.self) private var model
    @Environment(DocketStore.self) private var docket
    /// Stories that were new when you opened the file. They keep their mark for this visit.
    @State private var newIDs: Set<DocketEntry.ID> = []
    @State private var hasAppeared = false
    @State private var confirmingRemoval = false

    var body: some View {
        Group {
            if let file = docket.file(fileID) {
                page(file)
            } else {
                VStack(spacing: 0) {
                    StoryTopBar(backTitle: "Docket", trailing: "") { back() }
                        .padding(.horizontal, 24)
                    NoticeView(title: "File removed", message: "It’s no longer on your Docket.")
                }
            }
        }
        .paperScreen()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !hasAppeared, let file = docket.file(fileID) else { return }
            hasAppeared = true
            newIDs = Set(docket.newEntries(for: file).map(\.id))
            docket.markSeen(fileID)
        }
    }

    private func back() {
        if !model.docketPath.isEmpty { model.docketPath.removeLast() }
    }

    private func page(_ file: TrackedFile) -> some View {
        let record = docket.record(for: file.id)
        let momentum = docket.momentum(for: file)
        let day = max(1, EditionFormat.daysBetween(file.openedOn, EditionCalendar.iso(.now)) + 1)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StoryTopBar(backTitle: "Docket", trailing: "Day \(Roman.numeral(day))") { back() }

                FileTitle(file: file)
                    .padding(.top, 24)

                DoubleRule()
                    .padding(.top, 16)

                CoveragePanel(
                    heat: docket.heat(for: file),
                    momentum: momentum,
                    record: record
                )
                .padding(.top, 20)

                FollowingPanel(file: file, queries: docket.queries(for: file))
                    .padding(.top, 26)

                if let key = file.keyDate {
                    KeyDateCard(key: key)
                        .padding(.top, 26)
                }

                if !file.note.isEmpty {
                    NotesCard(note: file.note)
                        .padding(.top, 26)
                }

                RecordHeader(count: record.count)
                    .padding(.top, 36)
                if record.isEmpty {
                    Text("No edition has mentioned \(file.keywordPhrase) yet. New stories join the record as soon as the edition arrives.")
                        .typeStyle(.text(15, italic: true, lineHeight: 1.45, relativeTo: .body))
                        .foregroundStyle(Theme.inkMuted)
                        .padding(.top, 16)
                } else {
                    Timeline(
                        entries: record,
                        newIDs: newIDs,
                        origin: file.origin,
                        foundThrough: { docket.foundThrough($0, for: file) }
                    ) { entry in
                        model.docketPath.append(.story(StoryRoute(editionDate: entry.editionDate, storyID: entry.story.id)))
                    }
                    .padding(.top, 18)
                }

                FileActions(
                    file: file,
                    edit: { model.edit(file) },
                    pin: { docket.setPinned(file.id, !file.isPinned) },
                    close: {
                        if file.isClosed {
                            docket.reopen(file.id)
                            model.announce("Case reopened")
                        } else {
                            docket.close(file.id)
                            model.announce("Case closed: \(file.title)")
                        }
                    },
                    remove: { confirmingRemoval = true }
                )
                .padding(.top, 40)

                Crest(diameter: 28, monogram: 9)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 56)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog("Remove “\(file.title)” from the Docket?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
            Button("Remove the file", role: .destructive) {
                back()
                docket.remove(file.id)
            }
        } message: {
            Text("Its notes and settings go with it. The stories stay in the archive.")
        }
    }
}

/// "Case file · Pinned", the title on a leather spine, and when it was opened.
private struct FileTitle: View {
    let file: TrackedFile

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            CoverSpine(cover: file.cover, width: 8)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(file.isClosed ? "Closed case" : "Case file")
                        .typeStyle(.label(10))
                        .foregroundStyle(Theme.brassText)
                    if file.isPinned {
                        Lozenge(size: 4)
                        Text("Pinned")
                            .typeStyle(.label(10))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                Text(file.title)
                    .typeStyle(.storyHeadline)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 10)
                    .accessibilityAddTraits(.isHeader)
                Text(opened)
                    .typeStyle(.text(13, italic: true, relativeTo: .footnote))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.top, 10)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var opened: String {
        guard let day = EditionCalendar.date(from: file.openedOn) else { return "" }
        var text = "Opened \(EditionFormat.storyDate(day))"
        if let closed = file.closedOn.flatMap(EditionCalendar.date(from:)) {
            text += " · closed \(EditionFormat.storyDate(closed))"
        }
        return text
    }
}

/// How the file is doing in the news, with four weeks of coverage.
private struct CoveragePanel: View {
    let heat: [Int?]
    let momentum: Momentum
    let record: [DocketEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Coverage")
                    .typeStyle(.label(9.5))
                    .foregroundStyle(Theme.inkMuted)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                HStack(spacing: 7) {
                    if momentum == .latest {
                        Circle().fill(Theme.burgundy).frame(width: 6, height: 6)
                    }
                    Text(momentum.title)
                        .typeStyle(.label(9.5))
                        .foregroundStyle(momentum.color)
                }
            }
            HeatStrip(marks: heat, height: 30)
                .padding(.top, 14)
            Hairline(color: Theme.ruleStrong)
            HStack {
                Text("Four weeks ago")
                Spacer()
                Text("Today")
            }
            .typeStyle(.label(8.5, tracking: 0.18))
            .foregroundStyle(Theme.inkMuted)
            .padding(.top, 6)
            .accessibilityHidden(true)
            Text(summary)
                .typeStyle(.text(14, italic: true, lineHeight: 1.4, relativeTo: .subheadline))
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)
        }
    }

    /// "Last in the news Tuesday, 20 October · five stories in three editions"
    private var summary: String {
        guard let latest = record.first else { return "Not in any edition on your iPhone yet." }
        let editions = Set(record.map(\.editionDate)).count
        let count = "\(EditionFormat.storyCount(record.count).lowercased()) in \(EditionFormat.spelled(editions)) \(editions == 1 ? "edition" : "editions")"
        return "Last in the news \(EditionFormat.storyDate(latest.day)) · \(count)"
    }
}

/// The names the file follows, how they're read, and whether it needs all of them.
private struct FollowingPanel: View {
    let file: TrackedFile
    let queries: [TopicQuery]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Following stories that mention")
                .typeStyle(.label(9.5))
                .foregroundStyle(Theme.inkMuted)
                .accessibilityAddTraits(.isHeader)
            FlowLayout {
                ForEach(file.keywords, id: \.self) { word in
                    KeywordChip(word: word, isSelected: false)
                }
            }
            .padding(.top, 12)
            if !file.exactWords, queries.contains(where: \.isUnderstood) {
                TopicReading(queries: queries)
                    .padding(.top, 12)
            }
            if file.keywords.count > 1 || file.exactWords {
                Text(matchNote)
                    .typeStyle(.text(13, italic: true, relativeTo: .footnote))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.top, 10)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var matchNote: String {
        let match = file.keywords.count > 1 ? (file.match == .all ? "All of them, in the same story." : "Any one of them.") : ""
        return file.exactWords ? (match + " Exactly these words.").trimmingCharacters(in: .whitespaces) : match
    }
}

/// The date to watch and how far off it is.
private struct KeyDateCard: View {
    let key: TrackedFile.KeyDate

    var body: some View {
        let day = EditionCalendar.date(from: key.date) ?? .now
        let countdown = EditionFormat.countdown(to: key.date)
        let isPast = key.date < EditionCalendar.iso(.now)
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Date to watch")
                    .typeStyle(.label(9.5))
                    .foregroundStyle(Theme.brassText)
                Text(EditionFormat.storyDate(day))
                    .typeStyle(.display(20, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                if !key.label.isEmpty {
                    Text(key.label)
                        .typeStyle(.text(14.5, italic: true, relativeTo: .subheadline))
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 2) {
                Text(countdown)
                    .typeStyle(.display(17, italic: true, relativeTo: .headline))
                    .foregroundStyle(isPast ? Theme.inkMuted : Theme.burgundy)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 92, height: 92)
            .overlay(DoubleRing(width: 3, color: isPast ? Theme.rule : Theme.brass))
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        .background(Theme.paperInset)
        .overlay(Rectangle().strokeBorder(Theme.ruleStrong, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
}

/// Your notes, in the margin like the archive ledger.
private struct NotesCard: View {
    let note: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            HStack(spacing: 1) {
                Rectangle().frame(width: 1)
                Rectangle().frame(width: 1)
            }
            .foregroundStyle(Theme.burgundy)
            VStack(alignment: .leading, spacing: 8) {
                Text("Your notes")
                    .typeStyle(.label(9.5))
                    .foregroundStyle(Theme.burgundy)
                Text(note)
                    .typeStyle(.text(16, italic: true, lineHeight: 1.5, relativeTo: .body))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.vertical, 4)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

private struct RecordHeader: View {
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("The record")
                    .typeStyle(.sectionTitle)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                Text(EditionFormat.storyCount(count))
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

// MARK: - Timeline

/// Every story on the file, newest first, on a brass rail. Quiet stretches between stories
/// show as a dotted rail with how long the news went quiet.
private struct Timeline: View {
    let entries: [DocketEntry]
    let newIDs: Set<DocketEntry.ID>
    let origin: TrackedFile.Origin?
    let foundThrough: (DocketEntry) -> [String]
    let open: (DocketEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    let quiet = EditionFormat.daysBetween(entry.editionDate, entries[index - 1].editionDate) - 1
                    if quiet >= 3 {
                        QuietStretch(days: quiet)
                    }
                }
                TimelineEntry(
                    entry: entry,
                    isNew: newIDs.contains(entry.id),
                    isOrigin: origin.map { $0.editionDate == entry.editionDate && $0.headline == entry.story.headline } ?? false,
                    foundThrough: foundThrough(entry),
                    isFirst: index == 0,
                    isLast: index == entries.count - 1
                ) {
                    open(entry)
                }
            }
        }
    }
}

private struct TimelineEntry: View {
    let entry: DocketEntry
    let isNew: Bool
    let isOrigin: Bool
    /// Other wordings the story was found through: ["listing"]
    let foundThrough: [String]
    let isFirst: Bool
    let isLast: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Rail()
                        .frame(height: 7)
                        .opacity(isFirst ? 0 : 1)
                    Lozenge(size: 8, color: isNew ? Theme.burgundy : Theme.brass)
                        .frame(height: 12)
                    Rail()
                        .frame(maxHeight: .infinity)
                        .opacity(isLast ? 0 : 1)
                }
                .frame(width: 14)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(EditionFormat.short(entry.day))
                            .typeStyle(.label(9.5, tracking: 0.18))
                            .foregroundStyle(Theme.ink)
                        Text(entry.sectionKicker)
                            .typeStyle(.label(9, tracking: 0.18))
                            .foregroundStyle(Theme.brassText)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if isNew {
                            NewTag()
                        }
                    }
                    .padding(.top, 8)
                    Text(entry.story.headline)
                        .typeStyle(.rowHeadline)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 7)
                    if let why = entry.story.whyItMatters {
                        Text(why)
                            .typeStyle(.text(14, italic: true, lineHeight: 1.4, relativeTo: .subheadline))
                            .foregroundStyle(Theme.inkMuted)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .padding(.top, 6)
                    }
                    if !foundThrough.isEmpty {
                        Text("Found through \(foundThrough.map { "“\($0)”" }.joined(separator: " and "))")
                            .typeStyle(.text(12.5, italic: true, relativeTo: .caption))
                            .foregroundStyle(Theme.brassText)
                            .padding(.top, 8)
                    }
                    if isOrigin {
                        HStack(spacing: 6) {
                            Crest(diameter: 16, ring: 1.5, monogram: 5)
                            Text("You opened the file here")
                                .typeStyle(.text(12.5, italic: true, relativeTo: .caption))
                                .foregroundStyle(Theme.brassText)
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)
            }
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressedRowStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the story")
    }
}

private struct Rail: View {
    var body: some View {
        Rectangle()
            .fill(Theme.brass.opacity(0.7))
            .frame(width: 1)
    }
}

/// "Nine quiet days" on a dotted stretch of rail.
private struct QuietStretch: View {
    let days: Int

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Path { path in
                path.move(to: CGPoint(x: 0.5, y: 0))
                path.addLine(to: CGPoint(x: 0.5, y: 40))
            }
            .stroke(Theme.brass.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            .frame(width: 1, height: 40)
            .frame(width: 14)
            Text("\(EditionFormat.spelledCapitalised(days)) quiet days")
                .typeStyle(.text(12.5, italic: true, relativeTo: .caption))
                .foregroundStyle(Theme.inkMuted)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Edit, pin, close or remove.
private struct FileActions: View {
    let file: TrackedFile
    let edit: () -> Void
    let pin: () -> Void
    let close: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetButton(title: "Edit the file", action: edit)
            if !file.isClosed {
                row(file.isPinned ? "Unpin" : "Pin to the top", action: pin)
            }
            row(file.isClosed ? "Reopen the case" : "Close the case", action: close)
            row("Remove from the Docket", color: Theme.burgundy, action: remove)
        }
    }

    private func row(_ title: String, color: Color = Theme.ink, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .typeStyle(.label(10))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: 46)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedRowStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}
