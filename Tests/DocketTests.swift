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
        // The parties in the headline, then the first topic it's about.
        #expect(draft.file.keywords == ["SpaceX", "Nvidia", "chips"])
        #expect(draft.suggestions.contains("chips"))
        #expect(DocketSuggestions.title(for: draft.file.keywords) == "SpaceX & Nvidia chips")
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
        #expect(file.note.isEmpty && file.keyDate == nil && !file.isPinned && !file.isClosed && !file.exactWords)
    }
}

/// Reading a file's words as a topic: phrases split into names and topics, other wordings of
/// the same topic, and names the Who's who ties together.
@Suite("Topic matching")
struct TopicMatchingTests {
    private let oct08 = Edition(document: try! EditionDocument.decode(Fixture.edition("2026-10-08")))

    /// An edition with stories made up for the test.
    private func edition(_ date: String, _ stories: [(headline: String, whosWho: String, body: String)]) -> Edition {
        let object: [String: Any] = [
            "date": date,
            "big_story": stories[0].headline,
            "sections": [[
                "numeral": "I", "title": "Corporate Law",
                "stories": stories.map { ["headline": $0.headline, "region": "US", "whos_who": $0.whosWho, "body": $0.body] },
            ]],
        ]
        return Edition(document: try! EditionDocument.decode(JSONSerialization.data(withJSONObject: object)))
    }

    private var anthropicWeek: Edition {
        edition("2026-11-03", [
            ("Anthropic files for Nasdaq IPO", "Anthropic = US AI lab · S-1 = the prospectus filed before an IPO", "Anthropic filed its S-1."),
            ("Claude maker prices its listing at $250 a share", "Claude = Anthropic's AI assistant", "The shares start trading on Nasdaq on Thursday."),
            ("Anthropic releases a new model", "Claude = Anthropic's AI assistant", "The model is faster."),
        ])
    }

    private func read(_ keyword: String, in editions: [Edition], exact: Bool = false) -> TopicQuery {
        TopicQuery.read(keyword, vocabulary: TopicVocabulary(stories: editions.flatMap(\.stories)), exact: exact)
    }

    @Test("Splits a phrase into the names and topics it knows")
    func splitsPhrases() {
        let query = read("anthropic ipo", in: [anthropicWeek])
        #expect(query.parts.map(\.label) == ["Anthropic", "IPO"])
        #expect(query.parts[0].alternatives == ["Claude"])
        #expect(query.parts[1].alternatives.prefix(3) == ["listing", "S-1", "roadshow"])
        #expect(read("SpaceX Tesla merger", in: [oct08]).parts.map(\.label) == ["SpaceX", "Tesla", "merger"])
    }

    @Test("Keeps names it knows, and phrases it doesn't understand, whole")
    func keepsPhrases() {
        #expect(read("State Street", in: [oct08]).parts.map(\.label) == ["State Street"])
        let wallStreet = read("Wall Street", in: [oct08])
        #expect(wallStreet.parts.map(\.label) == ["Wall Street"] && !wallStreet.isUnderstood)
        #expect(read("anthropic ipo", in: [anthropicWeek], exact: true).parts.map(\.label) == ["anthropic ipo"])
    }

    @Test("Finds the same topic in other words, and says which")
    func otherWordings() {
        let query = read("Anthropic IPO", in: [anthropicWeek])
        let listing = DocketMatcher.fold("Claude maker prices its listing at $250 a share")
        #expect(query.matches(listing))
        #expect(query.foundThrough(listing) == ["Claude", "listing"])
        #expect(!query.matches(DocketMatcher.fold("Anthropic releases a new model, Claude 5")))
        #expect(query.foundThrough(DocketMatcher.fold("Anthropic files for Nasdaq IPO")).isEmpty)
    }

    @Test("Learns from the Who's who whose names belong to whom")
    func owners() {
        #expect(TopicVocabulary.owners(in: "Saudi Arabia's state oil company").contains("saudi arabia"))
        #expect(TopicVocabulary.owners(in: "Musk's rocket company, listed since June") == ["musk"])
        #expect(TopicVocabulary.owners(in: "independent body electing most of its board").isEmpty)
        let vocabulary = TopicVocabulary(stories: oct08.stories)
        #expect(vocabulary.owned["openai"] == ["GPT-6 Sol", "Luna"])
    }

    @Test("Spots the topic of a headline and names the file after it")
    func headlineTopics() {
        #expect(TopicLexicon.concepts(in: "Anthropic files for Nasdaq IPO with a share structure") == ["IPO"])
        #expect(TopicLexicon.concepts(in: "PlayPower and BCI Burke drop their merger after the FTC sues to block it") == ["merger", "lawsuit"])
        #expect(DocketSuggestions.title(for: ["Anthropic", "IPO"]) == "Anthropic IPO")
        #expect(DocketSuggestions.title(for: ["SpaceX", "Tesla", "merger"]) == "SpaceX & Tesla merger")
    }

    @MainActor
    @Test("A file on a topic keeps the whole saga, and exact words keep it literal")
    func store() throws {
        let docket = DocketStore(url: nil)
        docket.update(editions: [anthropicWeek])
        let ipo = TrackedFile(title: "Anthropic IPO", keywords: ["anthropic ipo"], openedOn: "2026-11-03", seenThrough: "2026-11-03")
        docket.save(ipo)
        let record = docket.record(for: ipo.id)
        #expect(record.map(\.story.headline) == ["Anthropic files for Nasdaq IPO", "Claude maker prices its listing at $250 a share"])
        // Its Who's who says "Anthropic's", so only the IPO was found in other words.
        #expect(docket.foundThrough(record[1], for: ipo) == ["listing"])

        var exact = ipo
        exact.exactWords = true
        #expect(docket.preview(for: exact).isEmpty)
    }
}
