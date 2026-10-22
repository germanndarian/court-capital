import Foundation
import Testing

@Suite("Notion client")
struct NotionClientTests {
    @Test("Sends the token and the API version, asking for 100 blocks at a time")
    func headers() async throws {
        let fake = FakeNotion()
        fake.setChildren(of: "page", [Block.paragraph("Hello")])

        let blocks = try await fake.client().children(of: "page")

        #expect(blocks.map(\.plainText) == ["Hello"])
        let request = try #require(fake.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(fake.token)")
        #expect(request.value(forHTTPHeaderField: "Notion-Version") == "2026-03-11")
        #expect(request.url?.absoluteString == "https://api.notion.com/v1/blocks/page/children?page_size=100")
    }

    @Test("Follows next_cursor until has_more is false")
    func pagination() async throws {
        let fake = FakeNotion(pageSize: 2)
        fake.setChildren(of: "page", (1...5).map { Block.paragraph("Block \($0)") })

        let blocks = try await fake.client().children(of: "page")

        #expect(blocks.map(\.plainText) == (1...5).map { "Block \($0)" })
        let cursors = fake.requests.map { request in
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "start_cursor" }?.value
        }
        #expect(cursors == [nil, "2", "4"])
    }

    @Test("Spaces requests about a third of a second apart")
    func spacing() async throws {
        let fake = FakeNotion(pageSize: 1)
        fake.setChildren(of: "page", (1...3).map { Block.paragraph("Block \($0)") })
        let clock = FakeClock()

        _ = try await fake.client(pacer: clock.pacer()).children(of: "page")

        #expect(fake.requests.count == 3)
        #expect(clock.sleeps == [.milliseconds(340), .milliseconds(340)])
    }

    @Test("Waits as long as Retry-After says after a 429, then retries")
    func retryAfter() async throws {
        let fake = FakeNotion()
        fake.setChildren(of: "page", [Block.paragraph("Hello")])
        fake.reply(.init(status: 429, headers: ["Retry-After": "2"]))
        fake.reply(.init(status: 429, headers: ["Retry-After": "1"]))
        let clock = FakeClock()

        let blocks = try await fake.client(pacer: clock.pacer()).children(of: "page")

        #expect(blocks.count == 1)
        #expect(fake.requests.count == 3)
        #expect(clock.sleeps == [.seconds(2), .seconds(1)])
    }

    @Test("Backs off 1, 2, 4 seconds when a 429 has no Retry-After")
    func backoffWithoutRetryAfter() async throws {
        let fake = FakeNotion()
        fake.setChildren(of: "page", [Block.paragraph("Hello")])
        fake.reply(.init(status: 429), times: 3)
        let clock = FakeClock()

        _ = try await fake.client(pacer: clock.pacer()).children(of: "page")

        #expect(clock.sleeps == [.seconds(1), .seconds(2), .seconds(4)])
    }

    @Test("A 429 holds back the other requests waiting their turn too")
    func pauseIsShared() async throws {
        let clock = FakeClock()
        let pacer = clock.pacer()
        try await pacer.waitForTurn()
        await pacer.pause(for: .seconds(5))
        try await pacer.waitForTurn()
        #expect(clock.sleeps == [.seconds(5)])
    }

    @Test("Gives up after four retries")
    func givesUp() async throws {
        let fake = FakeNotion()
        fake.setChildren(of: "page", [Block.paragraph("Hello")])
        fake.reply(.init(status: 429, headers: ["Retry-After": "1"]), times: 10)

        await #expect(throws: NotionError.rateLimited) {
            try await fake.client(pacer: FakeClock().pacer()).children(of: "page")
        }
        #expect(fake.requests.count == 5)
    }

    @Test("Reports Notion's error code, such as a page that isn't shared")
    func notionErrors() async throws {
        let fake = FakeNotion()
        await #expect(throws: NotionError.http(status: 404, code: "object_not_found")) {
            try await fake.client().children(of: "not-shared")
        }

        fake.reply(.init(status: 401, body: Data(#"{"object":"error","status":401,"code":"unauthorized","message":"API token is invalid."}"#.utf8)))
        await #expect(throws: NotionError.http(status: 401, code: "unauthorized")) {
            try await fake.client().children(of: "page")
        }
    }

    @Test("A response that isn't Notion's JSON is not a DecodingError, so no page is marked unreadable")
    func unexpectedResponse() async throws {
        let fake = FakeNotion()
        fake.reply(.init(status: 200, body: Data("<html>Gateway</html>".utf8)))

        let error = await #expect(throws: NotionError.self) {
            try await fake.client().children(of: "page")
        }
        #expect(error == .unexpectedResponse)
    }

    @Test("Reads Notion's timestamps, with or without milliseconds")
    func timestamps() throws {
        let json = Data(#"{"id":"a","type":"divider","divider":{},"created_time":"2026-10-21T02:59:00.000Z","last_edited_time":"2026-10-21T03:00:00Z"}"#.utf8)
        let block = try JSONDecoder.notion.decode(NotionBlock.self, from: json)
        #expect(block.createdTime == Date(timeIntervalSince1970: 1_792_551_540))
        #expect(block.lastEditedTime == Date(timeIntervalSince1970: 1_792_551_600))
        #expect(block.hasChildren == false)
        #expect(block.richText.isEmpty)
    }
}
