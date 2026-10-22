import Foundation
import Testing

@Suite("Notion feed")
struct NotionFeedTests {
    private let monday = Date(timeIntervalSince1970: 1_792_378_800)   // 19 Oct 2026, 03:00 UTC
    private let day: TimeInterval = 86_400

    @Test("Lists the edition pages under Court & Capital, newest first, across several requests")
    func editionPages() async throws {
        let fake = FakeNotion(pageSize: 2)
        fake.setChildren(of: FakeNotion.rootID, [
            Block.paragraph("About this page"),
            Block.divider(),
            Block.heading("Editions", level: 2),
            Block.childPage("Edition — Monday, 19 October 2026", id: "mon", created: monday),
            Block.childPage("Edition — Wednesday, 21 October 2026", id: "wed", created: monday + 2 * day, edited: monday + 2 * day + 120),
            Block.childPage("Reading notes", id: "notes", created: monday + day),
            Block.childPage("Edition — Tuesday, 20 October 2026", id: "tue", created: monday + day),
        ])

        let pages = try await fake.feed().pages()

        #expect(pages.map(\.id) == ["wed", "tue", "mon"])
        #expect(pages.first?.title == "Edition — Wednesday, 21 October 2026")
        #expect(pages.first?.createdTime == monday + 2 * day)
        #expect(pages.first?.lastEditedTime == monday + 2 * day + 120)
        #expect(fake.requests.count == 4)
    }

    @Test("Joins the Data block's text chunks back into the edition's JSON")
    func joinsChunks() async throws {
        let json = Fixture.edition("2026-10-08")
        let chunks = Fixture.chunks(json)
        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { $0.count <= 2000 })

        let fake = FakeNotion()
        fake.setChildren(of: "edition", [
            Block.paragraph("Court & Capital · compiled by Claude from public reporting"),
            Block.heading("Data"),
            Block.code(chunks),
        ])

        let data = try #require(try await fake.feed().documentData(for: page("edition")))

        #expect(data == json)
        #expect(try EditionDocument.decode(data) == EditionDocument.decode(json))
    }

    @Test("Reads every block of a long page, so a Data block past the first 100 is found")
    func longPage() async throws {
        let fake = FakeNotion()
        let story = (1...140).map { Block.paragraph("Paragraph \($0)") }
        fake.setChildren(of: "edition", story + [Block.heading("Data"), Block.code([String(decoding: Fixture.edition("2026-10-07"), as: UTF8.self)])])

        let data = try await fake.feed().documentData(for: page("edition"))

        #expect(data == Fixture.edition("2026-10-07"))
        #expect(fake.requests(for: "edition").count == 2)
    }

    @Test("A page without a Data block has no edition")
    func missingDataBlock() async throws {
        let fake = FakeNotion()
        fake.setChildren(of: "edition", [
            Block.heading("I.  Corporate Law", level: 2),
            Block.heading("Delaware court blocks the share reshuffle", isToggle: true),
            Block.divider(),
            Block.paragraph("Court & Capital · compiled by Claude from public reporting"),
        ])

        #expect(try await fake.feed().documentData(for: page("edition")) == nil)
    }

    @Test("Bad JSON in the Data block comes back as is and fails to decode with a DecodingError")
    func badJSON() async throws {
        let fake = FakeNotion()
        fake.setChildren(of: "edition", [Block.heading("Data"), Block.code([#"{"date": "2026-10-22", "big_story": "#, #"Meta, }"#])])

        let data = try #require(try await fake.feed().documentData(for: page("edition")))

        #expect(String(decoding: data, as: UTF8.self) == #"{"date": "2026-10-22", "big_story": Meta, }"#)
        #expect(throws: DecodingError.self) { try EditionDocument.decode(data) }
    }

    @Test("Takes the code block under the Data heading, not an earlier one")
    func codeUnderDataHeading() async throws {
        let fake = FakeNotion()
        let json = Fixture.edition("2026-10-08")
        fake.setChildren(of: "edition", [
            Block.code(["{\"example\": true}"]),
            Block.heading("Data:", level: 2),
            Block.paragraph(""),
            Block.code(Fixture.chunks(json)),
        ])

        #expect(try await fake.feed().documentData(for: page("edition")) == json)
    }

    @Test("Looks inside the Data heading when it's a toggle")
    func toggleHeading() async throws {
        let fake = FakeNotion()
        let json = Fixture.edition("2026-10-08")
        fake.setChildren(of: "edition", [Block.paragraph("Footer"), Block.heading("Data", id: "data-toggle", isToggle: true)])
        fake.setChildren(of: "data-toggle", [Block.code(Fixture.chunks(json))])

        #expect(try await fake.feed().documentData(for: page("edition")) == json)
    }

    @Test("Without a Data heading, falls back to the page's last JSON code block")
    func fallbackToLastJSONBlock() async throws {
        let fake = FakeNotion()
        let json = Fixture.edition("2026-10-07")
        fake.setChildren(of: "edition", [
            Block.heading("Edition data"),
            Block.code(Fixture.chunks(json)),
            Block.code(["print('not the edition')"], language: "python"),
        ])

        #expect(try await fake.feed().documentData(for: page("edition")) == json)
    }

    private func page(_ id: String) -> EditionPageRef {
        EditionPageRef(id: id, title: "Edition", createdTime: monday, lastEditedTime: monday)
    }
}
