import Foundation
import Testing

/// Matching stories to files, the records built from the editions, and the docket on disk.
@Suite("The Docket")
struct DocketTests {
    private let oct07 = Edition(document: try! EditionDocument.decode(Fixture.edition("2026-10-07")))
    private let oct08 = Edition(document: try! EditionDocument.decode(Fixture.edition("2026-10-08")))

    private func file(_ keywords: [String], match: TrackedFile.Match = .all, seenThrough: String = "2026-10-08") -> TrackedFile {
        TrackedFile(title: DocketSuggestions.title(for: keywords), keywords: keywords, match: match, openedOn: seenThrough, seenThrough: seenThrough)
    }

    // MARK: Matching

    @Test("Counts whole words only, ignoring case and accents")
    func wholeWords() {
        let text = DocketMatcher.fold("Meta’s metadata rules hit Julius Bär and two IPOs; S&P 500 and 401(k) plans")
        func mentions(_ word: String) -> Bool { DocketMatcher.mentions(text, DocketMatcher.fold(word)) }
        #expect(mentions("Meta"))
        #expect(!mentions("data"))
        #expect(mentions("julius bar"))
        #expect(mentions("IPO"))
        #expect(mentions("S&P 500"))
        #expect(mentions("401(k)"))
        #expect(!mentions("Bä"))
    }

    @Test("Needs every word, or any one")
    func allOrAny() {
        let text = DocketMatcher.fold("SpaceX seeks $40B for Nvidia chips")
        #expect(DocketMatcher.matches(text, keywords: ["SpaceX", "Nvidia"], match: .all))
        #expect(!DocketMatcher.matches(text, keywords: ["SpaceX", "Tesla"], match: .all))
        #expect(DocketMatcher.matches(text, keywords: ["SpaceX", "Tesla"], match: .any))
        #expect(!DocketMatcher.matches(text, keywords: [], match: .any))
    }

    @Test("Offers the story's names and chooses the parties in the headline")
    func suggestions() throws {
        let story = try #require(oct08.stories.first { $0.headline.hasPrefix("SEC won") })
        let names = DocketSuggestions.names(in: story)
        #expect(Array(names.prefix(4)) == ["SEC", "BlackRock", "Vanguard", "State Street"])
        #expect(DocketSuggestions.chosen(from: names, headline: story.headline) == ["SEC", "BlackRock"])
        #expect(DocketSuggestions.title(for: ["SpaceX"]) == "SpaceX")
        #expect(DocketSuggestions.title(for: ["SpaceX", "Tesla"]) == "SpaceX & Tesla")
        #expect(DocketSuggestions.title(for: ["SpaceX", "Tesla", "xAI"]) == "SpaceX, Tesla & xAI")
    }

    @Test("A new file on a story starts with its parties and an empty title")
    func draft() throws {
        let story = try #require(oct08.stories.first { $0.headline.hasPrefix("AI chip debt") })
        let draft = FileDraft.new(from: story, editionDate: oct08.date, seenThrough: oct08.date, today: "2026-10-08")
        #expect(draft.isNew)
        #expect(draft.file.keywords == ["SpaceX", "Nvidia"])
        #expect(draft.file.title.isEmpty)
        #expect(draft.file.origin == TrackedFile.Origin(editionDate: "2026-10-08", headline: story.headline))
    }

    // MARK: Records

    @MainActor
    @Test("A new file fills with earlier coverage, newest first")
    func record() {
        let docket = DocketStore(url: nil)
        docket.update(editions: [oct08, oct07])
        let nvidia = file(["Nvidia"])
        docket.save(nvidia)

        let record = docket.record(for: nvidia.id)
        #expect(record.count == 5)
        #expect(record.map(\.editionDate) == ["2026-10-08", "2026-10-08", "2026-10-07", "2026-10-07", "2026-10-07"])
        #expect(record.first?.sectionKicker == "II. Finance")
        #expect(docket.newEntries(for: nvidia).isEmpty)
        #expect(docket.momentum(for: nvidia) == .latest)
        #expect(docket.movement(in: oct08).map(\.stories) == [2])
    }

    @MainActor
    @Test("Stories that arrive after you last looked are new until you open the file")
    func newStories() throws {
        let docket = DocketStore(url: nil)
        docket.update(editions: [oct07])
        let nvidia = file(["Nvidia"], seenThrough: "2026-10-07")
        docket.save(nvidia)
        #expect(docket.filesWithNews.isEmpty)

        docket.update(editions: [oct08, oct07])
        let saved = try #require(docket.file(nvidia.id))
        #expect(docket.newEntries(for: saved).count == 2)
        #expect(docket.filesWithNews.map(\.id) == [nvidia.id])

        docket.markSeen(nvidia.id)
        #expect(docket.filesWithNews.isEmpty)
        #expect(docket.file(nvidia.id)?.seenThrough == "2026-10-08")
    }

    @MainActor
    @Test("A closed case leaves the edition but keeps its record")
    func closing() throws {
        let docket = DocketStore(url: nil)
        docket.update(editions: [oct08, oct07])
        let spacex = file(["SpaceX", "Nvidia"])
        docket.save(spacex)
        let story = try #require(oct08.stories.first { $0.headline.hasPrefix("AI chip debt") })
        #expect(docket.files(following: story, on: oct08.date).map(\.id) == [spacex.id])

        docket.close(spacex.id, on: "2026-10-09")
        #expect(docket.files(following: story, on: oct08.date).isEmpty)
        #expect(docket.movement(in: oct08).isEmpty)
        #expect(docket.openFiles.isEmpty)
        #expect(docket.closedFiles.map(\.id) == [spacex.id])
        #expect(docket.record(for: spacex.id).count == 1)

        docket.reopen(spacex.id)
        #expect(docket.openFiles.map(\.id) == [spacex.id])
    }

    @MainActor
    @Test("Pinned files come first, then the ones in the news most recently")
    func order() {
        let docket = DocketStore(url: nil)
        docket.update(editions: [oct08, oct07])
        let groq = file(["Groq"])
        let samsung = file(["Samsung Electronics"])
        var mistral = file(["Mistral"])
        docket.save(groq)
        docket.save(samsung)
        docket.save(mistral)
        #expect(docket.openFiles.map(\.title) == ["Samsung Electronics", "Groq", "Mistral"])

        mistral.isPinned = true
        docket.save(mistral)
        #expect(docket.openFiles.map(\.title) == ["Mistral", "Samsung Electronics", "Groq"])

        docket.remove(samsung.id)
        #expect(docket.openFiles.map(\.title) == ["Mistral", "Groq"])
    }

    @Test("Coverage has a mark per weekday, and none where there's no edition")
    func heat() {
        let stories = oct08.stories
        let entries = [
            DocketEntry(editionDate: "2026-10-08", sectionKicker: "", story: stories[0]),
            DocketEntry(editionDate: "2026-10-08", sectionKicker: "", story: stories[1]),
            DocketEntry(editionDate: "2026-10-07", sectionKicker: "", story: stories[2]),
        ]
        // Monday 5 to Friday 9 October, with editions only on the 6th to the 8th.
        let marks = DocketStore.heat(entries: entries, editionDates: ["2026-10-06", "2026-10-07", "2026-10-08"], endingOn: "2026-10-11", weekdays: 5)
        #expect(marks == [nil, 0, 1, 2, nil])
    }

    @Test("How the file is doing follows how recently an edition mentioned it")
    func momentum() {
        let dates = (1...20).map { String(format: "2026-09-%02d", 30 - $0) }
        #expect(Momentum.of(latest: dates[0], editionDates: dates) == .latest)
        #expect(Momentum.of(latest: dates[3], editionDates: dates) == .developing)
        #expect(Momentum.of(latest: dates[8], editionDates: dates) == .quiet)
        #expect(Momentum.of(latest: dates[16], editionDates: dates) == .cold)
        #expect(Momentum.of(latest: nil, editionDates: dates) == .awaiting)
    }

    @Test("Counts down to the date to watch in words")
    func countdown() {
        /// Thursday 22 October 2026, 20:00 in Zürich
        let thursdayEvening = Date(timeIntervalSince1970: 1_792_692_000)
        #expect(EditionFormat.countdown(to: "2026-10-22", from: thursdayEvening) == "Today")
        #expect(EditionFormat.countdown(to: "2026-10-23", from: thursdayEvening) == "Tomorrow")
        #expect(EditionFormat.countdown(to: "2026-10-31", from: thursdayEvening) == "In nine days")
        #expect(EditionFormat.countdown(to: "2026-10-21", from: thursdayEvening) == "Yesterday")
        #expect(EditionFormat.countdown(to: "2026-10-19", from: thursdayEvening) == "Three days ago")
    }

    // MARK: On disk

    @MainActor
    @Test("Keeps the docket on disk")
    func persistence() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "docket-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }

        var ipo = file(["Anthropic", "IPO"])
        ipo.cover = .burgundy
        ipo.note = "Watch the valuation."
        ipo.keyDate = TrackedFile.KeyDate(date: "2026-11-12", label: "Pricing")
        DocketStore(url: url).save(ipo)

        #expect(DocketStore(url: url).files == [ipo])
    }

    @MainActor
    @Test("An unreadable docket is set aside, not overwritten")
    func unreadable() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "docket-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "docket.json")
        try Data("not json".utf8).write(to: url)

        let docket = DocketStore(url: url)
        #expect(docket.files.isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
        #expect(names.count == 1 && names[0].hasPrefix("docket-unreadable-"))
    }

    @Test("A file saved before newer settings existed still opens, with their defaults")
    func olderFile() throws {
        let json = Data("""
        {"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","title":"UBS","keywords":["UBS"],"openedOn":"2026-10-07","seenThrough":"2026-10-07","cover":"brass"}
        """.utf8)
        let file = try JSONDecoder().decode(TrackedFile.self, from: json)
        #expect(file.match == .all)
        #expect(file.cover == .navy)
        #expect(file.note.isEmpty && file.keyDate == nil && !file.isPinned && !file.isClosed)
    }
}
