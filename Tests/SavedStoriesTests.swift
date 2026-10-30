import Foundation
import SwiftData
import Testing

// MARK: - Made-up editions

/// Editions and stories made up for these tests. Ids are positional, as the app works them out
/// from the edition JSON:
///
///     I. Corporate Law   1-1 court, 1-2 merger, 1-3 mexico
///     II. Finance        2-1 rally, 2-2 swiss
///     III. AI            3-1 mistral
private enum Made {
    typealias StoryDocument = EditionDocument.StoryDocument

    static func story(
        _ headline: String, region: String = "US", whosWho: String? = nil, body: String? = nil,
        why: String? = nil, plain: [String]? = nil, sources: [Source]? = nil
    ) -> StoryDocument {
        StoryDocument(
            headline: headline, region: region, whosWho: whosWho, body: body ?? "The body of “\(headline)”.",
            whyItMatters: why, inPlainWords: plain, sources: sources
        )
    }

    static let court = story(
        "Supreme Court appears ready to side with Intel",
        whosWho: "Intel = US chipmaker · ERISA = US law on workplace pensions",
        body: "The justices sounded sceptical of the workers’ claim.",
        why: "Pension plans may invest more freely.",
        plain: ["Workers lost a pension fight."],
        sources: [Source(outlet: "Reuters", url: "https://example.com/court")]
    )
    static let merger = story("Paramount closes Warner takeover")
    /// Every kind of content a story can hold, and a region the app doesn't know.
    static let mexico = story(
        "Mexico seizes the rig", region: "Mexico",
        whosWho: "Pemex = Mexican state oil company · Rate = 5% = the new policy rate · Bare name · Fed = US central bank",
        body: "Officials took the rig *(a floating drilling platform)* on Monday.\n\nA *second* paragraph follows.",
        why: "Energy prices could move.",
        plain: ["Mexico took a rig.", "Oil firms are watching."],
        sources: [Source(outlet: "FT", url: "https://example.com/rig"), Source(outlet: "AP", url: "https://example.com/rig-ap")]
    )
    static let rally = story("S&P 500 tops 7,800", whosWho: "S&P 500 = index of 500 large US companies", body: "Stocks closed at a record.")
    static let swiss = story("UBS hands fund administration to Northern Trust", region: "CH")
    static let mistral = story("Mistral launches Large 4", region: "EU")

    /// An edition with the three sections; a test changes one by passing its stories.
    static func week(
        date: String = "2026-11-03",
        law: [StoryDocument] = [Made.court, Made.merger, Made.mexico],
        finance: [StoryDocument] = [Made.rally, Made.swiss],
        ai: [StoryDocument] = [Made.mistral]
    ) -> Edition {
        let sections = [("I", "Corporate Law", law), ("II", "Finance", finance), ("III", "AI", ai)]
        return Edition(document: EditionDocument(
            date: date,
            bigStory: law[0].headline,
            sections: sections.map { .init(numeral: $0.0, title: $0.1, stories: $0.2) }
        ))
    }

    /// The first story with this headline, as saved from this edition.
    static func saved(_ headline: String, in edition: Edition, at seconds: TimeInterval = 1_793_000_000) throws -> SavedStory {
        let story = try #require(edition.stories.first { $0.headline == headline })
        return try saved(id: story.id, in: edition, at: seconds)
    }

    /// The story with this id, as saved from this edition.
    static func saved(id: Story.ID, in edition: Edition, at seconds: TimeInterval = 1_793_000_000) throws -> SavedStory {
        let story = try #require(edition.story(id: id))
        let section = try #require(edition.section(containing: id))
        return SavedStory(story, editionDate: edition.date, sectionKicker: section.kicker, savedAt: Date(timeIntervalSince1970: seconds))
    }
}

// MARK: - The shelf, and finding a story again

/// Bookmarked stories, kept on the iPhone. A story's id is only its position in the edition and
/// moves when the Notion page is edited, so a saved story is the edition's date plus its
/// headline, and must never open as another story.
@MainActor
@Suite("Saved stories")
struct SavedStoriesTests {
    private let week = Made.week()
    private let oct07 = Edition(document: try! EditionDocument.decode(Fixture.edition("2026-10-07")))
    private let oct08 = Edition(document: try! EditionDocument.decode(Fixture.edition("2026-10-08")))

    // MARK: Saving

    @Test("Saving puts a story first, found again by edition date and headline")
    func saving() throws {
        let shelf = SavedStore(url: nil)
        #expect(shelf.stories.isEmpty && shelf.count == 0)

        let rally = try Made.saved(Made.rally.headline, in: week)
        shelf.save(rally)

        #expect(shelf.stories == [rally])
        #expect(shelf.count == 1)
        let live = try #require(week.story(id: "2-1"))
        let other = try #require(week.story(id: "2-2"))
        #expect(shelf.isSaved(live, on: week.date))
        #expect(shelf.isSaved(editionDate: week.date, headline: Made.rally.headline))
        #expect(!shelf.isSaved(other, on: week.date))
        // The same headline on another day is another story.
        #expect(!shelf.isSaved(live, on: "2026-11-04"))
    }

    @Test("Saving a story twice changes nothing: it isn't duplicated or moved")
    func savingTwice() throws {
        let shelf = SavedStore(url: nil)
        let rally = try Made.saved(Made.rally.headline, in: week, at: 1_000)
        let court = try Made.saved(Made.court.headline, in: week, at: 2_000)
        shelf.save(rally)
        shelf.save(court)
        #expect(shelf.stories == [court, rally])

        // Again, later, with another id as its hint: the headline decides, and the first copy stays.
        var again = try Made.saved(Made.rally.headline, in: week, at: 3_000)
        again.storyID = "9-9"
        shelf.save(again)
        shelf.save(rally)

        #expect(shelf.stories == [court, rally])
        #expect(shelf.count == 2)
        let kept = try #require(shelf.stories.last)
        #expect(kept.savedAt == Date(timeIntervalSince1970: 1_000))
        #expect(kept.storyID == "2-1")
    }

    @Test("The newest saved story comes first")
    func newestFirst() throws {
        let shelf = SavedStore(url: nil)
        let court = try Made.saved(Made.court.headline, in: week, at: 1_000)
        let rally = try Made.saved(Made.rally.headline, in: week, at: 2_000)
        let mistral = try Made.saved(Made.mistral.headline, in: week, at: 3_000)
        shelf.save(court)
        shelf.save(rally)
        shelf.save(mistral)

        #expect(shelf.stories.map(\.headline) == [Made.mistral.headline, Made.rally.headline, Made.court.headline])
        #expect(shelf.count == 3)
    }

    @Test("A story is its edition date and headline, ignoring spaces around it and the id")
    func identity() throws {
        let rally = try Made.saved(Made.rally.headline, in: week)
        var padded = rally
        padded.story = Made.story("  \(Made.rally.headline) \n", whosWho: Made.rally.whosWho, body: Made.rally.body)
        padded.storyID = "7-7"
        padded.sectionKicker = "Somewhere else"
        padded.savedAt = .distantFuture
        #expect(padded.id == rally.id)

        var otherDay = rally
        otherDay.editionDate = "2026-11-04"
        #expect(otherDay.id != rally.id)
        var otherHeadline = rally
        otherHeadline.story = Made.story("S&P 500 tops 7,900")
        #expect(otherHeadline.id != rally.id)

        let shelf = SavedStore(url: nil)
        shelf.save(rally)
        shelf.save(padded)
        #expect(shelf.count == 1)
        #expect(shelf.isSaved(editionDate: week.date, headline: "  \(Made.rally.headline)\t"))
        #expect(!shelf.isSaved(editionDate: week.date, headline: "S&P 500 tops 7,900"))
    }

    @Test("The same headline on two days can be saved twice")
    func sameHeadlineTwoDays() throws {
        let shelf = SavedStore(url: nil)
        shelf.save(try Made.saved(Made.rally.headline, in: week))
        shelf.save(try Made.saved(Made.rally.headline, in: Made.week(date: "2026-11-04")))
        #expect(shelf.count == 2)
        #expect(Set(shelf.stories.map(\.editionDate)) == ["2026-11-03", "2026-11-04"])
    }

    // MARK: Removing and toggling

    @Test("Removing takes a story off the shelf, by saved story or by edition date and headline")
    func removing() throws {
        let shelf = SavedStore(url: nil)
        let court = try Made.saved(Made.court.headline, in: week, at: 1_000)
        let rally = try Made.saved(Made.rally.headline, in: week, at: 2_000)
        let mistral = try Made.saved(Made.mistral.headline, in: week, at: 3_000)
        [court, rally, mistral].forEach(shelf.save)

        shelf.remove(rally)
        #expect(shelf.stories == [mistral, court])

        // A copy with an old id for a hint is still the same story.
        var staleCourt = court
        staleCourt.storyID = "5-5"
        shelf.remove(staleCourt)
        #expect(shelf.stories == [mistral])
        #expect(!shelf.isSaved(editionDate: week.date, headline: Made.court.headline))

        shelf.remove(editionDate: week.date, headline: "  \(Made.mistral.headline) ")
        #expect(shelf.stories.isEmpty && shelf.count == 0)
    }

    @Test("Removing a story that isn't saved does nothing")
    func removingUnsaved() throws {
        let shelf = SavedStore(url: nil)
        let rally = try Made.saved(Made.rally.headline, in: week)
        shelf.save(rally)

        shelf.remove(try Made.saved(Made.court.headline, in: week))
        shelf.remove(editionDate: "2026-11-04", headline: Made.rally.headline)
        shelf.remove(editionDate: week.date, headline: "S&P 500 tops 7,900")
        #expect(shelf.stories == [rally])

        let empty = SavedStore(url: nil)
        empty.remove(rally)
        #expect(empty.stories.isEmpty)
    }

    @Test("Toggling saves a story, or takes it off, and returns where it ended up")
    func toggling() throws {
        let shelf = SavedStore(url: nil)
        let rally = try Made.saved(Made.rally.headline, in: week)
        let live = try #require(week.story(id: "2-1"))

        #expect(shelf.toggle(rally) == true)
        #expect(shelf.isSaved(live, on: week.date))
        #expect(shelf.count == 1)

        // The page toggles with a copy it just made, which may carry another hint.
        var again = rally
        again.storyID = "2-2"
        again.savedAt = .now
        #expect(shelf.toggle(again) == false)
        #expect(!shelf.isSaved(live, on: week.date))
        #expect(shelf.stories.isEmpty)

        #expect(shelf.toggle(rally) == true)
        #expect(shelf.stories == [rally])
    }

    // MARK: A saved story among stale ids

    @Test("Re-downloaded with the stories reordered, a saved story is still itself, never its neighbour")
    func reordered() throws {
        let rally = try Made.saved(Made.rally.headline, in: week)
        #expect(rally.storyID == "2-1")
        let shelf = SavedStore(url: nil)
        shelf.save(rally)

        // The premise: in the new edition the rally is 2-2 and the swiss story has its old id.
        let after = Made.week(finance: [Made.swiss, Made.rally])
        let neighbour = try #require(after.story(id: "2-1"))
        let moved = try #require(after.story(id: "2-2"))
        #expect(neighbour.headline == Made.swiss.headline)
        #expect(moved.headline == Made.rally.headline)

        #expect(shelf.isSaved(moved, on: after.date))
        #expect(!shelf.isSaved(neighbour, on: after.date))

        let placed = rally.resolve(in: after)
        #expect(placed.story.headline == Made.rally.headline)
        #expect(placed.story.id == "2-2")
        #expect(placed.story == moved)
        #expect(placed.isLive)
        #expect(placed.story.headline != neighbour.headline)
    }

    @Test("A story added above shifts every id, and the saved one is still found")
    func shiftedByANewStory() throws {
        let rally = try Made.saved(Made.rally.headline, in: week)
        let after = Made.week(finance: [Made.story("Fed holds rates"), Made.rally, Made.swiss])
        let placed = rally.resolve(in: after)
        #expect(placed.story.headline == Made.rally.headline)
        #expect(placed.story.id == "2-2")
        #expect(placed.isLive)
    }

    @Test("A headline edited in Notion opens from the saved copy, not from the story at the old id")
    func headlineEdited() throws {
        let rally = try Made.saved(Made.rally.headline, in: week)
        let edited = Made.story("S&P 500 tops 7,900", body: "A different body.")

        // Edited where it stood, so the old id now holds the edited story; and edited and moved,
        // so the old id holds another story.
        let inPlace = Made.week(finance: [edited, Made.swiss])
        let moved = Made.week(finance: [Made.swiss, edited])
        #expect(inPlace.story(id: "2-1")?.headline == edited.headline)
        #expect(moved.story(id: "2-1")?.headline == Made.swiss.headline)

        for after in [inPlace, moved] {
            let placed = rally.resolve(in: after)
            #expect(!placed.isLive)
            #expect(placed.story.headline == Made.rally.headline)
            #expect(placed.story.body == Made.rally.body)
            #expect(placed.story.whosWho == Story(document: Made.rally, id: "x").whosWho)
            #expect(placed.sectionKicker == "II. Finance")
            #expect(placed.editionDate == week.date)

            let shelf = SavedStore(url: nil)
            shelf.save(rally)
            // The edited story is a different story as far as the shelf knows.
            for story in after.stories {
                #expect(shelf.isSaved(story, on: after.date) == false)
            }
        }
    }

    @Test("A saved story whose edition is gone opens complete from its stored copy")
    func editionGone() throws {
        let original = try #require(week.stories.first { $0.headline == Made.mexico.headline })
        let saved = try Made.saved(Made.mexico.headline, in: week)
        let anotherDay = Made.week(date: "2026-11-04", law: [Made.merger], finance: [Made.mexico])

        for edition in [nil, anotherDay] as [Edition?] {
            let placed = saved.resolve(in: edition)
            #expect(!placed.isLive)
            #expect(placed.editionDate == "2026-11-03")
            #expect(placed.sectionKicker == "I. Corporate Law")

            let story = placed.story
            #expect(story.headline == Made.mexico.headline)
            #expect(story.region == .other("Mexico"))
            #expect(story.whosWho.map(\.name) == ["Pemex", "Rate", "Bare name", "Fed"])
            #expect(story.whosWho.map(\.description) == ["Mexican state oil company", "5% = the new policy rate", "", "US central bank"])
            #expect(story.body == Made.mexico.body)
            #expect(story.whyItMatters == "Energy prices could move.")
            #expect(story.plainWords == ["Mexico took a rig.", "Oil firms are watching."])
            #expect(story.sources == [Source(outlet: "FT", url: "https://example.com/rig"), Source(outlet: "AP", url: "https://example.com/rig-ap")])
            #expect(story.readingMinutes == original.readingMinutes)
            #expect(story == original)
        }
    }

    @Test("A region survives the copy, including one the app doesn't know", arguments: ["US", "CH", "EU", "UK", "Asia", "Global", "Mexico", "Middle East"])
    func region(raw: String) throws {
        let edition = Made.week(law: [Made.story("Region test", region: raw)])
        let live = try #require(edition.story(id: "1-1"))
        let saved = try Made.saved("Region test", in: edition)
        let copy = saved.resolve(in: nil).story
        #expect(copy.region == live.region)
        #expect(copy.region.code == live.region.code)
        if case .other = live.region {
            // What the edition wrote, not an upper-cased version of it.
            #expect(saved.story.region == raw)
        }
    }

    @Test("A story without a Who's who, why it matters, plain words or sources copies without them")
    func sparseStory() throws {
        let bare = Made.story("A short one", whosWho: nil, body: "Just a body.", why: "   ", plain: nil, sources: nil)
        let edition = Made.week(law: [bare])
        let live = try #require(edition.story(id: "1-1"))
        #expect(live.whyItMatters == nil)

        let saved = try Made.saved("A short one", in: edition)
        #expect(saved.story.whosWho == nil)
        let copy = saved.resolve(in: nil).story
        #expect(copy == live)
        #expect(copy.whosWho.isEmpty && copy.whyItMatters == nil && copy.plainWords.isEmpty && copy.sources.isEmpty)
    }

    @Test("Two stories with one headline: the old id tells them apart")
    func sameHeadlineInOneEdition() throws {
        let headline = "Markets wrap"
        let first = Made.story(headline, body: "First wrap.")
        let second = Made.story(headline, body: "Second wrap.")
        let edition = Made.week(law: [Made.court, first], finance: [second, Made.rally])
        #expect(edition.story(id: "1-2")?.body == "First wrap.")
        #expect(edition.story(id: "2-1")?.body == "Second wrap.")

        let savedFirst = try Made.saved(id: "1-2", in: edition)
        let savedSecond = try Made.saved(id: "2-1", in: edition)

        let placedFirst = savedFirst.resolve(in: edition)
        #expect(placedFirst.story.id == "1-2")
        #expect(placedFirst.story.body == "First wrap.")
        #expect(placedFirst.sectionKicker == "I. Corporate Law")
        #expect(placedFirst.isLive)

        let placedSecond = savedSecond.resolve(in: edition)
        #expect(placedSecond.story.id == "2-1")
        #expect(placedSecond.story.body == "Second wrap.")
        #expect(placedSecond.sectionKicker == "II. Finance")
        #expect(placedSecond.isLive)

        // When nothing stands at the old id any more, it's still one of the two, never another story.
        let shifted = Made.week(law: [first, second, Made.court], finance: [Made.rally])
        let found = savedSecond.resolve(in: shifted)
        #expect(found.isLive)
        #expect(found.story.headline == headline)
        #expect(["1-1", "1-2"].contains(found.story.id))
    }

    @Test("A live match shows the text as Notion has it now")
    func correctedText() throws {
        let saved = try Made.saved(Made.court.headline, in: week)
        let corrected = Made.story(
            Made.court.headline,
            whosWho: "Intel = US chipmaker (corrected)",
            body: "The body, corrected in Notion.",
            why: "Corrected: why it matters.",
            plain: ["Corrected plain words."],
            sources: [Source(outlet: "AP", url: "https://example.com/corrected")]
        )
        let after = Made.week(law: [corrected, Made.merger, Made.mexico])

        let placed = saved.resolve(in: after)
        #expect(placed.isLive)
        #expect(placed.story == after.story(id: "1-1"))
        #expect(placed.story.body == "The body, corrected in Notion.")
        #expect(placed.story.whyItMatters == "Corrected: why it matters.")
        #expect(placed.story.plainWords == ["Corrected plain words."])
        #expect(placed.story.whosWho.map(\.description) == ["US chipmaker (corrected)"])
        #expect(placed.story.sources.map(\.outlet) == ["AP"])
        // What was saved is still what was saved.
        #expect(saved.story.body == Made.court.body)
    }

    @Test("The section kicker and edition number are the live ones for a live story, the saved ones otherwise")
    func kickerAndNumber() throws {
        let rally = try Made.saved(Made.rally.headline, in: week)
        #expect(rally.sectionKicker == "II. Finance")

        // Where it stands.
        let live = rally.resolve(in: week)
        #expect(live.sectionKicker == "II. Finance")
        #expect(live.number == week.number)
        #expect(live.editionDate == week.date)
        #expect(live.day == week.day)

        // Moved to another section by an edit: the live section wins.
        let moved = Made.week(law: [Made.court, Made.rally], finance: [Made.swiss])
        let placed = rally.resolve(in: moved)
        #expect(placed.isLive)
        #expect(placed.sectionKicker == "I. Corporate Law")
        #expect(placed.story.id == "1-2")

        // The stored copy keeps what it was saved with, and the number of its date.
        let stored = rally.resolve(in: nil)
        #expect(!stored.isLive)
        #expect(stored.sectionKicker == "II. Finance")
        #expect(stored.number == week.number)
        #expect(stored.number == EditionCalendar.editionNumber(for: "2026-11-03"))
        #expect(stored.day == week.day)
        #expect(stored.editionDate == "2026-11-03")
    }

    @Test("Edition numbers come out right for a stored copy, in Roman numerals: 7 October 2026 is No. CC")
    func storedEditionNumber() throws {
        let story = try Made.saved(id: "2-1", in: oct07)
        #expect(oct07.number == 200)

        let live = story.resolve(in: oct07)
        let stored = story.resolve(in: nil)
        #expect(live.number == 200 && stored.number == 200)
        #expect(Roman.numeral(stored.number) == "CC")
        #expect(live.sectionKicker == "II. Finance" && stored.sectionKicker == "II. Finance")
        #expect(story.day == EditionCalendar.date(from: "2026-10-07"))
    }

    @Test("Saving from the story page keeps the text, whether the story is live or a stored copy")
    func savingFromThePage() throws {
        let saved = try Made.saved(Made.mexico.headline, in: week)
        let shelf = SavedStore(url: nil)
        shelf.save(saved)

        // Open from a stored copy (its edition is gone), take it off, put it back.
        let stored = saved.resolve(in: nil)
        #expect(shelf.isSaved(stored.story, on: stored.editionDate))
        #expect(shelf.toggle(stored.saved()) == false)
        #expect(!shelf.isSaved(stored.story, on: stored.editionDate))
        #expect(shelf.toggle(stored.saved()) == true)

        let back = try #require(shelf.stories.first)
        #expect(back.id == saved.id)
        #expect(back.story == saved.story)
        #expect(back.sectionKicker == saved.sectionKicker)
        #expect(back.editionDate == saved.editionDate)
        #expect(back.storyID == saved.storyID)

        // Saved from a live page after a re-download, the copy takes the new text and id.
        let corrected = Made.story(Made.mexico.headline, region: "Mexico", body: "Corrected body.")
        let after = Made.week(law: [corrected])
        let live = saved.resolve(in: after)
        let renewed = live.saved(at: Date(timeIntervalSince1970: 1_794_000_000))
        #expect(live.isLive)
        #expect(renewed.story.body == "Corrected body.")
        #expect(renewed.storyID == "1-1")
        #expect(renewed.id == saved.id)
        #expect(renewed.sectionKicker == "I. Corporate Law")
        #expect(renewed.savedAt == Date(timeIntervalSince1970: 1_794_000_000))
    }

    // MARK: The Docket

    @Test("A stored copy is never live, and a live story is, in every way an edition can change")
    func liveOnlyWhenTheEditionHasIt() throws {
        let rally = try Made.saved(Made.rally.headline, in: week)

        // The story's own edition, unchanged, reordered, or with a new story above it.
        #expect(rally.resolve(in: week).isLive)
        #expect(rally.resolve(in: Made.week(finance: [Made.swiss, Made.rally])).isLive)
        #expect(rally.resolve(in: Made.week(finance: [Made.story("New"), Made.rally, Made.swiss])).isLive)

        // Its edition is gone, another day is there instead, the headline was edited, or the story was dropped.
        #expect(!rally.resolve(in: nil).isLive)
        #expect(!rally.resolve(in: Made.week(date: "2026-11-04")).isLive)
        #expect(!rally.resolve(in: Made.week(finance: [Made.story("S&P 500 tops 7,900"), Made.swiss])).isLive)
        #expect(!rally.resolve(in: Made.week(finance: [Made.swiss])).isLive)
    }

    // The follow button on the story page lives in a SwiftUI view, which the unit-test target
    // doesn't compile. It asks the Docket about a story only when `PlacedStory.isLive` is true
    // (StoryView passes it as `hasEditionID`), so this tests what is testable: that asked by id,
    // the Docket really would mistake a stale copy for its neighbour, and that the copy says it
    // isn't live while a live match carries the id the edition gives it today.
    @Test("The Docket follows by id, so a stale copy would pass for its neighbour: it is not live")
    func docketTrap() throws {
        let rally = try Made.saved(Made.rally.headline, in: week)
        #expect(rally.storyID == "2-1")
        let zorblax = Made.story("Zorblax merges with Quuxcorp", body: "Zorblax and Quuxcorp agreed a merger.")

        // The rally's headline was edited away, and Zorblax now stands at its old id.
        let edited = Made.week(finance: [zorblax, Made.swiss])
        let docket = DocketStore(url: nil)
        docket.update(editions: [edited])
        let file = TrackedFile(title: "Zorblax", keywords: ["Zorblax"], openedOn: edited.date, seenThrough: edited.date)
        docket.save(file)
        let neighbour = try #require(edited.story(id: "2-1"))
        #expect(docket.files(following: neighbour, on: edited.date).map(\.id) == [file.id])

        let stale = rally.resolve(in: edited)
        #expect(stale.story.headline == Made.rally.headline)
        #expect(!stale.isLive)
        // The premise: asked about the stale copy by its old id, the Docket names the neighbour's file.
        #expect(docket.files(following: stale.story, on: stale.editionDate).map(\.id) == [file.id])

        // Reordered instead: the live story has its real id, and the neighbour's file is not its own.
        let reordered = Made.week(finance: [zorblax, Made.rally, Made.swiss])
        docket.update(editions: [reordered])
        let live = rally.resolve(in: reordered)
        #expect(live.isLive)
        #expect(live.story.id == "2-2")
        #expect(docket.files(following: live.story, on: live.editionDate).isEmpty)
        let zorblaxLive = try #require(reordered.story(id: "2-1"))
        #expect(docket.files(following: zorblaxLive, on: reordered.date).map(\.id) == [file.id])
    }

    // MARK: Bundled samples

    @Test("Every sample story survives being copied, and opens from the copy as it was")
    func sampleStoriesCopyCleanly() throws {
        for edition in [oct07, oct08] {
            for story in edition.stories {
                let saved = try Made.saved(id: story.id, in: edition)
                let copy = saved.resolve(in: nil)
                #expect(copy.story == story, "\(edition.date) \(story.id) \(story.headline)")
                #expect(copy.sectionKicker == edition.section(containing: story.id)?.kicker)
                #expect(copy.number == edition.number)
                #expect(!copy.isLive)
                // Live again, once the edition is back.
                let live = saved.resolve(in: edition)
                #expect(live.story == story && live.isLive, "\(edition.date) \(story.id)")
            }
        }
    }

    @Test("A story saved from a sample edition still opens when the real editions have other dates")
    func sampleStoryAmongRealEditions() throws {
        let story = try #require(oct08.stories.first { $0.headline.hasPrefix("Samsung") })
        let saved = try Made.saved(id: story.id, in: oct08)

        // The real editions are other dates, even with the same stories in them.
        let real = try [
            Edition(document: EditionDocument.decode(Fixture.edition("2026-10-08", redatedTo: "2026-10-21"))),
            Edition(document: EditionDocument.decode(Fixture.edition("2026-10-07", redatedTo: "2026-10-22"))),
        ]
        for edition in real {
            let placed = saved.resolve(in: edition)
            #expect(!placed.isLive)
            #expect(placed.editionDate == "2026-10-08")
            #expect(placed.story == story)
            #expect(placed.story.region == .asia)
            #expect(placed.sectionKicker == "II. Finance")
            #expect(placed.number == 201)
        }
        #expect(!SavedStore(url: nil).isSaved(real[0].stories[0], on: "2026-10-21"))
    }
}

// MARK: - On disk

/// `saved.json` in Application Support: apart from the edition cache, readable on the next
/// launch, and never overwritten when it can't be read.
@MainActor
@Suite("Saved stories on disk")
struct SavedStoriesOnDiskTests {
    private let week = Made.week()

    /// A fresh "Application Support" folder. It has a space in its name, as on the iPhone, which
    /// is where `URL.path()` percent-encodes it and file system calls stop finding the file.
    private func inAppSupport(createFolder: Bool = true, _ body: (_ folder: URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "saved-\(UUID().uuidString)")
        let folder = root.appending(path: "Application Support")
        defer { try? FileManager.default.removeItem(at: root) }
        if createFolder {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try body(folder)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    private func names(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).sorted()
    }

    private func write(_ json: String, to url: URL) throws {
        try Data(json.utf8).write(to: url)
    }

    @Test("Keeps the shelf on disk, in order, with every field")
    func roundTrip() throws {
        try inAppSupport { folder in
            let url = folder.appending(path: "saved.json")
            #expect(url.path(percentEncoded: false).contains("Application Support"))

            let court = try Made.saved(Made.court.headline, in: week, at: 1_000)
            let mexico = try Made.saved(Made.mexico.headline, in: week, at: 2_000)
            let mistral = try Made.saved(Made.mistral.headline, in: week, at: 3_000)
            let shelf = SavedStore(url: url)
            [court, mexico, mistral].forEach(shelf.save)
            #expect(exists(url))

            // The file exists in a folder with a space in its name, and a new store must find it.
            let reopened = SavedStore(url: url)
            #expect(reopened.stories == [mistral, mexico, court])
            #expect(reopened.stories == shelf.stories)
            #expect(reopened.count == 3)
            #expect(reopened.isSaved(editionDate: week.date, headline: Made.mexico.headline))

            let loaded = try #require(reopened.stories.first { $0.headline == Made.mexico.headline })
            #expect(loaded.editionDate == "2026-11-03")
            #expect(loaded.storyID == "1-3")
            #expect(loaded.sectionKicker == "I. Corporate Law")
            #expect(loaded.savedAt == Date(timeIntervalSince1970: 2_000))
            #expect(loaded.story == mexico.story)

            // Who's who goes through its "Name = what it is · …" line and comes back as the same terms.
            let original = try #require(week.stories.first { $0.headline == Made.mexico.headline })
            let placed = loaded.resolve(in: nil)
            #expect(loaded.story.whosWho == Term.line(original.whosWho))
            #expect(placed.story.whosWho == original.whosWho)
            #expect(placed.story.region == .other("Mexico"))
            #expect(loaded.story.region == "Mexico")
            #expect(placed.story.sources == original.sources)
            #expect(placed.story.plainWords == original.plainWords)
            #expect(placed.story.whyItMatters == original.whyItMatters)
            #expect(placed.story.body == original.body)
            #expect(placed.story == original)
        }
    }

    @Test("Every sample story comes back from disk as it was")
    func sampleStoriesRoundTrip() throws {
        let editions = [
            Edition(document: try EditionDocument.decode(Fixture.edition("2026-10-07"))),
            Edition(document: try EditionDocument.decode(Fixture.edition("2026-10-08"))),
        ]
        try inAppSupport { folder in
            let url = folder.appending(path: "saved.json")
            let shelf = SavedStore(url: url)
            var second = 0
            var originals: [String: Story] = [:]
            for edition in editions {
                for story in edition.stories {
                    second += 1
                    shelf.save(try Made.saved(id: story.id, in: edition, at: 1_793_000_000 + TimeInterval(second)))
                    originals[SavedStory.key(editionDate: edition.date, headline: story.headline)] = story
                }
            }
            // Ten stories in each sample edition.
            #expect(shelf.count == 20)

            let reopened = SavedStore(url: url)
            #expect(reopened.stories == shelf.stories)
            for saved in reopened.stories {
                let original = try #require(originals[saved.id])
                #expect(saved.resolve(in: nil).story == original, "\(saved.id)")
            }
        }
    }

    @Test("Keeps the order the stories were saved in, also when saved in the same moment")
    func order() throws {
        try inAppSupport { folder in
            let url = folder.appending(path: "saved.json")
            let ids = ["1-1", "1-2", "1-3", "2-1"]

            let spread = SavedStore(url: url)
            for (index, id) in ids.enumerated() {
                spread.save(try Made.saved(id: id, in: week, at: 1_000 + TimeInterval(index)))
            }
            #expect(spread.stories.map(\.storyID) == ["2-1", "1-3", "1-2", "1-1"])
            #expect(SavedStore(url: url).stories.map(\.storyID) == ["2-1", "1-3", "1-2", "1-1"])

            let sameMoment = folder.appending(path: "same.json")
            let together = SavedStore(url: sameMoment)
            for id in ids {
                together.save(try Made.saved(id: id, in: week, at: 5_000))
            }
            #expect(together.stories.map(\.storyID) == ["2-1", "1-3", "1-2", "1-1"])
            #expect(SavedStore(url: sameMoment).stories.map(\.storyID) == ["2-1", "1-3", "1-2", "1-1"])
        }
    }

    @Test("Loads a file that's already there, in a folder with a space in its name")
    func existingFileInSpacedFolder() throws {
        try inAppSupport { folder in
            let url = folder.appending(path: "saved.json")
            try write("""
            {"version":1,"stories":[{"editionDate":"2026-10-07","storyID":"2-1","sectionKicker":"II. Finance","savedAt":1793000000,
            "story":{"headline":"Hand-written","region":"US","body":"Body."}}]}
            """, to: url)
            #expect(exists(url))

            let shelf = SavedStore(url: url)
            #expect(shelf.stories.map(\.headline) == ["Hand-written"])
            // Nothing was set aside: the file was read.
            #expect(try names(in: folder) == ["saved.json"])
        }
    }

    @Test("A shelf that was never saved is empty, and loading it writes nothing")
    func noFile() throws {
        try inAppSupport { folder in
            let shelf = SavedStore(url: folder.appending(path: "saved.json"))
            #expect(shelf.stories.isEmpty && shelf.count == 0)
            let left = try names(in: folder)
            #expect(left.isEmpty)
        }
        try inAppSupport(createFolder: false) { folder in
            let url = folder.appending(path: "saved.json")
            let shelf = SavedStore(url: url)
            #expect(shelf.stories.isEmpty)
            #expect(!exists(folder))

            // The first save creates the folder and the file.
            shelf.save(try Made.saved(Made.rally.headline, in: week))
            #expect(exists(url))
            #expect(SavedStore(url: url).count == 1)
        }
    }

    @Test("Removing is kept too, and removing what isn't saved writes nothing")
    func removalIsKept() throws {
        try inAppSupport { folder in
            let url = folder.appending(path: "saved.json")
            let shelf = SavedStore(url: url)
            shelf.remove(try Made.saved(Made.rally.headline, in: week))
            shelf.remove(editionDate: week.date, headline: "Nothing like this")
            #expect(!exists(url))

            let rally = try Made.saved(Made.rally.headline, in: week, at: 1_000)
            let court = try Made.saved(Made.court.headline, in: week, at: 2_000)
            shelf.save(rally)
            shelf.save(court)
            shelf.remove(rally)
            #expect(SavedStore(url: url).stories == [court])

            #expect(shelf.toggle(court) == false)
            #expect(SavedStore(url: url).stories.isEmpty)
            #expect(shelf.toggle(rally) == true)
            #expect(SavedStore(url: url).stories == [rally])
        }
    }

    @Test("The file holds a version and the stories, in the folder the app uses")
    func format() throws {
        try inAppSupport { folder in
            let url = folder.appending(path: "saved.json")
            SavedStore(url: url).save(try Made.saved(Made.court.headline, in: week, at: 1_793_000_000))

            let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            #expect(object["version"] as? Int == 1)
            let stories = try #require(object["stories"] as? [[String: Any]])
            #expect(stories.count == 1)
            let first = try #require(stories.first)
            #expect(first["editionDate"] as? String == "2026-11-03")
            #expect(first["storyID"] as? String == "1-1")
            #expect(first["sectionKicker"] as? String == "I. Corporate Law")
            #expect(first["savedAt"] as? Double == 1_793_000_000)
            let story = try #require(first["story"] as? [String: Any])
            #expect(story["headline"] as? String == Made.court.headline)
        }
        #expect(SavedStore.defaultURL.lastPathComponent == "saved.json")
        #expect(SavedStore.defaultURL.deletingLastPathComponent().standardizedFileURL == URL.applicationSupportDirectory.standardizedFileURL)
    }

    @Test("A file saved before newer fields existed still opens, with their defaults")
    func olderFile() throws {
        try inAppSupport { folder in
            let url = folder.appending(path: "saved.json")
            // No version, and the first story has neither id, kicker nor saved date.
            try write("""
            {"stories":[
              {"editionDate":"2026-10-07","story":{"headline":"Old story","region":"US","body":"Old body."}},
              {"editionDate":"2026-10-08","storyID":"2-1","savedAt":1793000000,"story":{"headline":"Newer story","region":"Asia","body":"Body.","whosWho":"SEC = regulator"}}
            ]}
            """, to: url)

            let shelf = SavedStore(url: url)
            #expect(shelf.stories.map(\.headline) == ["Newer story", "Old story"])
            #expect(try names(in: folder) == ["saved.json"])

            let old = try #require(shelf.stories.first { $0.headline == "Old story" })
            #expect(old.storyID.isEmpty)
            #expect(old.sectionKicker.isEmpty)
            #expect(old.savedAt == .distantPast)
            #expect(old.story.whosWho == nil && old.story.whyItMatters == nil && old.story.inPlainWords == nil && old.story.sources == nil)

            // It still opens from its copy, with nothing made up for the missing kicker.
            let placed = old.resolve(in: nil)
            #expect(placed.story.headline == "Old story")
            #expect(placed.story.body == "Old body.")
            #expect(placed.sectionKicker.isEmpty)
            #expect(placed.number == EditionCalendar.editionNumber(for: "2026-10-07"))

            // And is found again by its headline in a live edition, though the file has no id.
            let edition = Made.week(date: "2026-10-07", law: [Made.story("Old story", body: "Body now.")])
            let found = old.resolve(in: edition)
            #expect(found.isLive && found.story.body == "Body now." && found.sectionKicker == "I. Corporate Law")

            // Saving on top of an older file keeps the older story.
            shelf.save(try Made.saved(Made.rally.headline, in: week, at: 1_794_000_000))
            let reopened = SavedStore(url: url)
            #expect(reopened.stories.map(\.headline) == [Made.rally.headline, "Newer story", "Old story"])
            #expect(reopened.stories.last?.storyID.isEmpty == true)
        }
    }

    @Test("Duplicate entries in the file load once")
    func duplicatesInTheFile() throws {
        try inAppSupport { folder in
            let url = folder.appending(path: "saved.json")
            try write("""
            {"version":1,"stories":[
              {"editionDate":"2026-10-07","storyID":"1-1","sectionKicker":"I. Corporate Law","savedAt":1000,"story":{"headline":"Twice","region":"US","body":"Older."}},
              {"editionDate":"2026-10-08","storyID":"1-1","sectionKicker":"I. Corporate Law","savedAt":3000,"story":{"headline":"Other","region":"US","body":"Body."}},
              {"editionDate":"2026-10-07","storyID":"1-2","sectionKicker":"I. Corporate Law","savedAt":2000,"story":{"headline":" Twice ","region":"US","body":"Newer."}},
              {"editionDate":"2026-10-07","storyID":"1-1","sectionKicker":"I. Corporate Law","savedAt":1000,"story":{"headline":"Twice","region":"US","body":"Older."}}
            ]}
            """, to: url)

            let shelf = SavedStore(url: url)
            #expect(shelf.count == 2)
            #expect(shelf.stories.map { $0.headline.trimmingCharacters(in: .whitespaces) } == ["Other", "Twice"])
            #expect(Set(shelf.stories.map(\.id)).count == 2)
            #expect(shelf.isSaved(editionDate: "2026-10-07", headline: "Twice"))
            shelf.remove(editionDate: "2026-10-07", headline: "Twice")
            #expect(!shelf.isSaved(editionDate: "2026-10-07", headline: "Twice"))
            #expect(shelf.count == 1)
        }
    }

    @Test("An unreadable file is set aside, not overwritten", arguments: [
        "not json",
        "",
        #"{"stories":"oops"}"#,
        #"{"version":1,"stories":[{"editionDate":"2026-10-07"}]}"#,
    ])
    func unreadable(contents: String) throws {
        try inAppSupport { folder in
            let url = folder.appending(path: "saved.json")
            try write(contents, to: url)

            let shelf = SavedStore(url: url)
            #expect(shelf.stories.isEmpty)
            let afterLoad = try names(in: folder)
            #expect(afterLoad.count == 1)
            let aside = try #require(afterLoad.first)
            #expect(aside.hasPrefix("saved-unreadable-") && aside.hasSuffix(".json"))
            #expect(try Data(contentsOf: folder.appending(path: aside)) == Data(contents.utf8))
            #expect(!exists(url))

            // Saving afterwards starts a new file and leaves the set-aside one alone.
            shelf.save(try Made.saved(Made.rally.headline, in: week))
            #expect(try names(in: folder).count == 2)
            #expect(try Data(contentsOf: folder.appending(path: aside)) == Data(contents.utf8))
            #expect(SavedStore(url: url).count == 1)
        }
    }
}

// MARK: - After a sync

/// The shelf next to the edition store syncing from a fake Notion into an in-memory cache:
/// pages come, are edited and download again, or are deleted, and saved stories follow.
@MainActor
@Suite("Saved stories after a sync")
struct SavedStoriesSyncTests {
    private let container = try! ModelContainer(for: StoredEdition.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    private let fake = FakeNotion()
    /// Long enough ago that Notion's minute rounding doesn't come into it.
    private let earlier = Date.now.addingTimeInterval(-3 * 3600)

    private func store() -> EditionStore {
        EditionStore(context: container.mainContext, feed: fake.feed())
    }

    private func page(_ title: String, _ id: String, edited: TimeInterval) -> Data {
        Block.childPage("Edition — \(title)", id: id, created: earlier + 10, edited: earlier + edited)
    }

    private func publish(_ id: String, _ json: Data) {
        fake.setChildren(of: id, [Block.heading("Data"), Block.code(Fixture.chunks(json))])
    }

    /// The sample editions' stand-ins: the bundled fixtures, as Notion pages.
    private func publishSamples() {
        fake.setChildren(of: FakeNotion.rootID, [
            page("Thursday, 8 October 2026", "oct08", edited: 40),
            page("Wednesday, 7 October 2026", "oct07", edited: 30),
        ])
        publish("oct08", Fixture.edition("2026-10-08"))
        publish("oct07", Fixture.edition("2026-10-07"))
    }

    /// An edition's JSON with section II (index 1) changed.
    private func changed(_ json: Data, _ change: (inout [[String: Any]]) -> Void) throws -> Data {
        var object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        var sections = try #require(object["sections"] as? [[String: Any]])
        var stories = try #require(sections[1]["stories"] as? [[String: Any]])
        change(&stories)
        sections[1]["stories"] = stories
        object["sections"] = sections
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func save(_ headlinePrefix: String, from edition: Edition, into shelf: SavedStore) throws -> SavedStory {
        let story = try #require(edition.stories.first { $0.headline.hasPrefix(headlinePrefix) })
        let saved = try Made.saved(id: story.id, in: edition)
        shelf.save(saved)
        return saved
    }

    @Test("A story saved from the sample editions opens once the real editions have replaced them")
    func samplesReplaced() async throws {
        publishSamples()
        let editions = store()
        await editions.refresh()
        let oct08 = try #require(editions.cachedEdition(on: "2026-10-08"))
        let shelf = SavedStore(url: nil)
        let saved = try save("Samsung", from: oct08, into: shelf)
        let original = try #require(oct08.story(id: saved.storyID))

        // The Notion token is set: the real editions are other dates, and the samples are gone.
        fake.setChildren(of: FakeNotion.rootID, [
            page("Thursday, 22 October 2026", "oct22", edited: 60),
            page("Wednesday, 21 October 2026", "oct21", edited: 50),
        ])
        publish("oct22", Fixture.edition("2026-10-08", redatedTo: "2026-10-22"))
        publish("oct21", Fixture.edition("2026-10-07", redatedTo: "2026-10-21"))
        await editions.refresh()
        #expect(editions.editions.map(\.date) == ["2026-10-22", "2026-10-21"])
        #expect(editions.cachedEdition(on: "2026-10-08") == nil)

        let stored = try #require(shelf.stories.first)
        let placed = stored.resolve(in: editions.cachedEdition(on: stored.editionDate))
        #expect(!placed.isLive)
        #expect(placed.story == original)
        #expect(placed.editionDate == "2026-10-08")
        #expect(placed.sectionKicker == "II. Finance")
        #expect(placed.number == 201)
        #expect(shelf.isSaved(editionDate: "2026-10-08", headline: original.headline))
    }

    @Test("A page edited and downloaded again with its stories reordered: the saved story is found by headline")
    func reorderedAndDownloadedAgain() async throws {
        publishSamples()
        let editions = store()
        await editions.refresh()
        let shelf = SavedStore(url: nil)
        let saved = try save("Fed minutes", from: try #require(editions.cachedEdition(on: "2026-10-08")), into: shelf)
        #expect(saved.storyID == "2-1")

        // Section II reversed, so the Fed story is 2-5 and the SMI story has its old id.
        fake.setChildren(of: FakeNotion.rootID, [
            page("Thursday, 8 October 2026", "oct08", edited: 600),
            page("Wednesday, 7 October 2026", "oct07", edited: 30),
        ])
        publish("oct08", try changed(Fixture.edition("2026-10-08")) { $0.reverse() })
        await editions.refresh()

        let after = try #require(editions.cachedEdition(on: "2026-10-08"))
        let neighbour = try #require(after.story(id: "2-1"))
        #expect(neighbour.headline.hasPrefix("SMI"))
        #expect(!shelf.isSaved(neighbour, on: after.date))

        let placed = saved.resolve(in: after)
        #expect(placed.isLive)
        #expect(placed.story.id == "2-5")
        #expect(placed.story.headline == saved.headline)
        #expect(placed.sectionKicker == "II. Finance")
        #expect(shelf.isSaved(placed.story, on: after.date))
    }

    @Test("A page whose story was retitled in Notion: the saved story keeps its own text")
    func retitledAndDownloadedAgain() async throws {
        publishSamples()
        let editions = store()
        await editions.refresh()
        let shelf = SavedStore(url: nil)
        let saved = try save("Fed minutes", from: try #require(editions.cachedEdition(on: "2026-10-08")), into: shelf)

        fake.setChildren(of: FakeNotion.rootID, [
            page("Thursday, 8 October 2026", "oct08", edited: 600),
            page("Wednesday, 7 October 2026", "oct07", edited: 30),
        ])
        publish("oct08", try changed(Fixture.edition("2026-10-08")) { stories in
            stories[0]["headline"] = "Fed minutes: officials split on the next hike"
            stories[0]["body"] = "A different story entirely."
        })
        await editions.refresh()

        let after = try #require(editions.cachedEdition(on: "2026-10-08"))
        #expect(after.story(id: "2-1")?.body == "A different story entirely.")
        let placed = saved.resolve(in: after)
        #expect(!placed.isLive)
        #expect(placed.story.headline == saved.headline)
        #expect(placed.story.body == saved.story.body)
        #expect(placed.story.body != "A different story entirely.")
    }

    @Test("A page deleted in Notion leaves the archive, and the saved story stays")
    func pageDeleted() async throws {
        publishSamples()
        let editions = store()
        await editions.refresh()
        let shelf = SavedStore(url: nil)
        let saved = try save("Samsung", from: try #require(editions.cachedEdition(on: "2026-10-08")), into: shelf)

        fake.setChildren(of: FakeNotion.rootID, [page("Wednesday, 7 October 2026", "oct07", edited: 30)])
        await editions.refresh()
        #expect(editions.cachedEdition(on: "2026-10-08") == nil)

        #expect(shelf.stories == [saved])
        let placed = saved.resolve(in: editions.cachedEdition(on: saved.editionDate))
        #expect(!placed.isLive)
        #expect(placed.story.headline == saved.headline)
        #expect(placed.story.region == .asia)
    }
}
