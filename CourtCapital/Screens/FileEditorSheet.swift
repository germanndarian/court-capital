import SwiftUI

/// Open a file on a story, or edit one: its name, the names it follows, its binding, a date to
/// watch and your notes. A live count shows what the file would hold already.
struct FileEditorSheet: View {
    @State private var draft: FileDraft
    @State private var newWord = ""
    @Environment(AppModel.self) private var model
    @Environment(DocketStore.self) private var docket
    @Environment(\.dismiss) private var dismiss
    @FocusState private var addingWord: Bool

    init(draft: FileDraft) {
        _draft = State(initialValue: draft)
    }

    private var file: TrackedFile { draft.file }

    /// The story's names first, then any you added.
    private var chips: [String] {
        let folded = Set(draft.suggestions.map(DocketMatcher.fold))
        return draft.suggestions + file.keywords.filter { !folded.contains(DocketMatcher.fold($0)) }
    }

    private var suggestedTitle: String { DocketSuggestions.title(for: file.keywords) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(draft.isNew ? "Open a file" : "Edit the file")
                        .typeStyle(.label(10))
                        .foregroundStyle(Theme.brassText)
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .typeStyle(.label(10))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.top, 20)

                if draft.isNew, let origin = file.origin {
                    Text("From “\(origin.headline)”")
                        .typeStyle(.text(13.5, italic: true, lineHeight: 1.35, relativeTo: .footnote))
                        .foregroundStyle(Theme.inkMuted)
                        .lineLimit(2)
                        .padding(.top, 10)
                }

                EditorLabel(title: "Name")
                    .padding(.top, 24)
                TextField("Name", text: $draft.file.title, prompt: Text(suggestedTitle.isEmpty ? "Anthropic IPO" : suggestedTitle).foregroundStyle(Theme.inkMuted.opacity(0.6)))
                    .typeStyle(.display(24, relativeTo: .title2))
                    .foregroundStyle(Theme.ink)
                    .submitLabel(.done)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .overlay(alignment: .bottom) { Hairline(color: Theme.ruleStrong) }

                EditorLabel(title: "Follow stories that mention")
                    .padding(.top, 28)
                if !chips.isEmpty {
                    FlowLayout {
                        ForEach(chips, id: \.self) { word in
                            Button {
                                toggle(word)
                            } label: {
                                KeywordChip(word: word, isSelected: isChosen(word))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isChosen(word) ? [.isSelected] : [])
                        }
                    }
                    .padding(.top, 12)
                    .animation(.snappy, value: file.keywords)
                }
                HStack(spacing: 10) {
                    TextField("Add", text: $newWord, prompt: Text(draft.suggestions.isEmpty ? "A name or word, such as Anthropic" : "Add a name or word").foregroundStyle(Theme.inkMuted.opacity(0.7)))
                        .typeStyle(.text(16, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                        .focused($addingWord)
                        .submitLabel(.done)
                        .autocorrectionDisabled()
                        .onSubmit(addWord)
                    Button("Add", action: addWord)
                        .typeStyle(.label(10))
                        .foregroundStyle(Theme.brassText)
                        .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(newWord.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Hairline() }
                .padding(.top, 10)

                if file.keywords.count > 1 {
                    MatchPicker(match: $draft.file.match)
                        .padding(.top, 16)
                }

                MatchPreview(entries: docket.preview(keywords: file.keywords, match: file.match), hasWords: !file.keywords.isEmpty)
                    .padding(.top, 14)

                EditorLabel(title: "Binding")
                    .padding(.top, 30)
                HStack(spacing: 18) {
                    ForEach(TrackedFile.Cover.allCases, id: \.self) { cover in
                        CoverSwatch(cover: cover, isSelected: file.cover == cover) {
                            draft.file.cover = cover
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 12)
                .sensoryFeedback(.selection, trigger: file.cover)

                Toggle(isOn: watchesDate) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("A date to watch")
                            .typeStyle(.text(17, weight: 500, relativeTo: .body))
                            .foregroundStyle(Theme.ink)
                        Text("A countdown on the file, and a reminder that morning")
                            .typeStyle(.text(13.5, italic: true, lineHeight: 1.35, relativeTo: .footnote))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                .toggleStyle(BrassToggleStyle())
                .padding(.vertical, 16)
                .overlay(alignment: .bottom) { Hairline() }
                .padding(.top, 22)

                if file.keyDate != nil {
                    DatePicker("Date", selection: keyDay, displayedComponents: .date)
                        .typeStyle(.text(17, weight: 500, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                        .environment(\.calendar, EditionCalendar.calendar)
                        .environment(\.timeZone, EditionCalendar.timeZone)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) { Hairline() }
                    TextField("What happens", text: keyLabel, prompt: Text("What happens: a hearing, the IPO pricing").foregroundStyle(Theme.inkMuted.opacity(0.7)))
                        .typeStyle(.text(16, italic: true, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                        .submitLabel(.done)
                        .padding(.vertical, 14)
                        .overlay(alignment: .bottom) { Hairline() }
                }

                EditorLabel(title: "Your notes")
                    .padding(.top, 28)
                TextField("Notes", text: $draft.file.note, prompt: Text("Why you’re following it, what to look out for").foregroundStyle(Theme.inkMuted.opacity(0.7)), axis: .vertical)
                    .typeStyle(.text(16, italic: true, lineHeight: 1.45, relativeTo: .body))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3...8)
                    .padding(14)
                    .background(Theme.paperInset)
                    .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 0.5))
                    .padding(.top, 10)

                SheetButton(title: draft.isNew ? "Open the file" : "Save the file", action: save)
                    .disabled(file.keywords.isEmpty)
                    .opacity(file.keywords.isEmpty ? 0.4 : 1)
                    .padding(.top, 30)
                if file.keywords.isEmpty {
                    Text("Choose at least one name or word to follow.")
                        .typeStyle(.text(12.5, italic: true, relativeTo: .caption))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
            .animation(.easeOut(duration: 0.2), value: file.keyDate != nil)
            .animation(.easeOut(duration: 0.2), value: file.keywords.count > 1)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .tint(Theme.brass)
        .presentationDetents([.large])
        .presentationBackground { PaperBackground() }
        .sensoryFeedback(.selection, trigger: file.keywords)
    }

    // MARK: Words

    private func isChosen(_ word: String) -> Bool {
        file.keywords.contains { DocketMatcher.fold($0) == DocketMatcher.fold(word) }
    }

    private func toggle(_ word: String) {
        if isChosen(word) {
            draft.file.keywords.removeAll { DocketMatcher.fold($0) == DocketMatcher.fold(word) }
        } else {
            draft.file.keywords.append(word)
        }
    }

    private func addWord() {
        let word = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        newWord = ""
        guard !word.isEmpty, !isChosen(word) else { return }
        draft.file.keywords.append(word)
    }

    // MARK: Date to watch

    private var watchesDate: Binding<Bool> {
        Binding {
            draft.file.keyDate != nil
        } set: { isOn in
            if isOn {
                let week = EditionCalendar.calendar.date(byAdding: .day, value: 7, to: .now) ?? .now
                draft.file.keyDate = TrackedFile.KeyDate(date: EditionCalendar.iso(week), label: "")
            } else {
                draft.file.keyDate = nil
            }
        }
    }

    private var keyDay: Binding<Date> {
        Binding {
            draft.file.keyDate.flatMap { EditionCalendar.date(from: $0.date) } ?? .now
        } set: { day in
            draft.file.keyDate?.date = EditionCalendar.iso(day)
        }
    }

    private var keyLabel: Binding<String> {
        Binding {
            draft.file.keyDate?.label ?? ""
        } set: { label in
            draft.file.keyDate?.label = label
        }
    }

    // MARK: Saving

    private func save() {
        addWord()
        var file = draft.file
        file.title = file.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if file.title.isEmpty { file.title = DocketSuggestions.title(for: file.keywords) }
        file.note = file.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let label = file.keyDate?.label {
            file.keyDate?.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !file.keywords.isEmpty else { return }

        let hadDate = docket.file(file.id)?.keyDate != nil
        docket.save(file)
        if draft.isNew {
            let stories = docket.record(for: file.id).count
            model.announce(stories == 0 ? "On your Docket. Stories gather here as they arrive." : "On your Docket, with \(EditionFormat.storyCount(stories).lowercased()) so far")
        }
        if file.keyDate != nil, !hadDate {
            Task {
                _ = await MorningNotification.requestPermission()
                await DocketReminders.refresh(docket.files)
            }
        }
        dismiss()
    }
}

private struct EditorLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .typeStyle(.label(9.5))
            .foregroundStyle(Theme.inkMuted)
            .accessibilityAddTraits(.isHeader)
    }
}

/// "All of them" or "Any one", each with a line on what it means.
private struct MatchPicker: View {
    @Binding var match: TrackedFile.Match

    var body: some View {
        HStack(spacing: 10) {
            option(.all, title: "All of them", note: "In the same story")
            option(.any, title: "Any one", note: "Wider, more stories")
        }
        .sensoryFeedback(.selection, trigger: match)
    }

    private func option(_ value: TrackedFile.Match, title: String, note: String) -> some View {
        let isSelected = match == value
        return Button {
            match = value
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .typeStyle(.label(10))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.inkMuted)
                Text(note)
                    .typeStyle(.text(12.5, italic: true, relativeTo: .caption))
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.paperInset : .clear)
            .overlay(Rectangle().strokeBorder(isSelected ? Theme.brass : Theme.rule, lineWidth: isSelected ? 1 : 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// What the file would hold right now: "Four stories already, the latest Tuesday, 20 October."
private struct MatchPreview: View {
    let entries: [DocketEntry]
    let hasWords: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Lozenge(size: 5, color: entries.isEmpty ? Theme.rule : Theme.brass)
            Text(text)
                .typeStyle(.text(14, italic: true, lineHeight: 1.4, relativeTo: .subheadline))
                .foregroundStyle(entries.isEmpty ? Theme.inkMuted : Theme.ink)
                .contentTransition(.numericText())
        }
        .animation(.snappy, value: entries.count)
    }

    private var text: String {
        guard hasWords else { return "Choose what to follow to see what’s already on record." }
        guard let latest = entries.first else { return "Nothing in the editions on your iPhone yet. New stories join as they arrive." }
        let count = entries.count == 1 ? "One story" : "\(EditionFormat.spelledCapitalised(entries.count)) stories"
        return "\(count) already on record, the latest \(EditionFormat.storyDate(latest.day))."
    }
}

/// A small leather book in the file's binding.
private struct CoverSwatch: View {
    let cover: TrackedFile.Cover
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 8) {
                CoverSpine(cover: cover, width: 30)
                    .frame(height: 50)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 1.5, topTrailingRadius: 1.5))
                    .overlay {
                        if isSelected {
                            UnevenRoundedRectangle(topLeadingRadius: 1.5, topTrailingRadius: 1.5)
                                .stroke(Theme.gilt, lineWidth: 1)
                        }
                    }
                    .shadow(color: .black.opacity(isSelected ? 0.35 : 0), radius: 4, y: 4)
                    .offset(y: isSelected ? -4 : 0)
                Text(cover.name)
                    .typeStyle(.label(8.5, tracking: 0.18))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.inkMuted)
            }
            .animation(.snappy, value: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cover.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
