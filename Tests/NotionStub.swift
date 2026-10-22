import Foundation
import Synchronization

/// A stand-in for the Notion API, so no test reaches the real one. Tests fill it with pages
/// and blocks, and the client reaches it through `StubURLProtocol`. Each fake has its own
/// token, which is how the protocol finds it, so tests can run in parallel.
final class FakeNotion: Sendable {
    static let rootID = "3edbe6d5466d81e99c8bda4528c91f57"

    let token = "test-\(UUID().uuidString)"
    /// At most this many results per request (Notion's cap is 100), to force pagination.
    let pageSize: Int

    struct Reply: Sendable {
        var status: Int
        var headers: [String: String] = [:]
        var body = Data(#"{"object":"error","status":500,"code":"internal_server_error","message":"Stub"}"#.utf8)
    }

    private struct Override: Sendable {
        let blockID: String?
        let reply: Reply
        var remaining: Int
    }

    private struct State: Sendable {
        var children: [String: [Data]] = [:]
        var overrides: [Override] = []
        var requests: [URLRequest] = []
    }

    private let state = Mutex(State())

    init(pageSize: Int = 100) {
        self.pageSize = pageSize
        StubURLProtocol.register(self)
    }

    // MARK: Setting up

    func setChildren(of blockID: String, _ blocks: [Data]) {
        state.withLock { $0.children[blockID] = blocks }
    }

    /// Answers the next `times` requests (for one block's children, or any) with `reply`.
    func reply(_ reply: Reply, for blockID: String? = nil, times: Int = 1) {
        state.withLock { $0.overrides.append(Override(blockID: blockID, reply: reply, remaining: times)) }
    }

    func clearReplies() {
        state.withLock { $0.overrides.removeAll() }
    }

    func feed(pacer: RequestPacer = RequestPacer(interval: .zero)) -> NotionFeed {
        NotionFeed(config: NotionConfig(token: token, pageID: Self.rootID), session: StubURLProtocol.session, pacer: pacer)
    }

    func client(pacer: RequestPacer = RequestPacer(interval: .zero)) -> NotionClient {
        NotionClient(token: token, session: StubURLProtocol.session, pacer: pacer)
    }

    // MARK: Inspecting

    var requests: [URLRequest] { state.withLock { $0.requests } }

    /// Requests for one block's children.
    func requests(for blockID: String) -> [URLRequest] {
        requests.filter { Self.blockID(in: $0) == blockID }
    }

    // MARK: Answering

    fileprivate func respond(to request: URLRequest) -> Reply {
        let blockID = Self.blockID(in: request)
        return state.withLock { state in
            state.requests.append(request)
            if let index = state.overrides.firstIndex(where: { $0.remaining > 0 && ($0.blockID == nil || $0.blockID == blockID) }) {
                state.overrides[index].remaining -= 1
                return state.overrides[index].reply
            }
            guard let blockID, let blocks = state.children[blockID] else {
                return Reply(status: 404, body: Data(#"{"object":"error","status":404,"code":"object_not_found","message":"Stub"}"#.utf8))
            }
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let start = items.first { $0.name == "start_cursor" }.flatMap { Int($0.value ?? "") } ?? 0
            let requested = items.first { $0.name == "page_size" }.flatMap { Int($0.value ?? "") } ?? 100
            let end = min(blocks.count, start + min(requested, pageSize))
            let hasMore = end < blocks.count
            var body = Data(#"{"object":"list","results":["#.utf8)
            body += Data(blocks[start..<end].map { String(decoding: $0, as: UTF8.self) }.joined(separator: ",").utf8)
            body += Data(#"],"next_cursor":\#(hasMore ? "\"\(end)\"" : "null"),"has_more":\#(hasMore),"type":"block","block":{}}"#.utf8)
            return Reply(status: 200, body: body)
        }
    }

    /// The id in /v1/blocks/{id}/children.
    private static func blockID(in request: URLRequest) -> String? {
        guard let parts = request.url?.pathComponents, parts.count == 5, parts[2] == "blocks", parts[4] == "children" else { return nil }
        return parts[3]
    }
}

/// Sends every request to the `FakeNotion` whose token it carries.
final class StubURLProtocol: URLProtocol {
    private static let fakes = Mutex<[String: FakeNotion]>([:])

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }()

    static func register(_ fake: FakeNotion) {
        fakes.withLock { $0[fake.token] = fake }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let token = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
        guard let token, let fake = Self.fakes.withLock({ $0[token] }), let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.userAuthenticationRequired))
            return
        }
        let reply = fake.respond(to: request)
        let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// A clock that only moves when the pacer sleeps, and remembers each sleep.
final class FakeClock: Sendable {
    private let state = Mutex((now: ContinuousClock.now, sleeps: [Duration]()))

    var sleeps: [Duration] { state.withLock { $0.sleeps } }

    func pacer(interval: Duration = .milliseconds(340)) -> RequestPacer {
        RequestPacer(
            interval: interval,
            now: { self.state.withLock { $0.now } },
            sleep: { duration in
                self.state.withLock { state in
                    state.now += duration
                    state.sleeps.append(duration)
                }
            }
        )
    }
}

// MARK: - Blocks as the Notion API returns them

enum Block {
    static func childPage(_ title: String, id: String = newID(), created: Date, edited: Date? = nil) -> Data {
        block(id: id, type: "child_page", content: ["title": title], hasChildren: true, created: created, edited: edited)
    }

    static func heading(_ text: String, level: Int = 3, id: String = newID(), isToggle: Bool = false) -> Data {
        block(id: id, type: "heading_\(level)", content: ["rich_text": richText([text]), "is_toggleable": isToggle, "color": "default"], hasChildren: isToggle)
    }

    static func paragraph(_ text: String) -> Data {
        block(type: "paragraph", content: ["rich_text": richText([text]), "color": "default"])
    }

    static func divider() -> Data {
        block(type: "divider", content: [:])
    }

    /// `chunks` become separate rich_text items, as Notion splits long text.
    static func code(_ chunks: [String], language: String = "json") -> Data {
        block(type: "code", content: ["rich_text": richText(chunks), "language": language, "caption": [Any]()])
    }

    static func newID() -> String { UUID().uuidString.lowercased() }

    static func timestamp(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    private static func richText(_ chunks: [String]) -> [[String: Any]] {
        chunks.map { chunk in
            [
                "type": "text",
                "text": ["content": chunk, "link": NSNull()],
                "annotations": ["bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"],
                "plain_text": chunk,
                "href": NSNull(),
            ]
        }
    }

    private static func block(
        id: String = newID(), type: String, content: [String: Any], hasChildren: Bool = false,
        created: Date = Date(timeIntervalSince1970: 1_792_544_400), edited: Date? = nil
    ) -> Data {
        let object: [String: Any] = [
            "object": "block",
            "id": id,
            "created_time": timestamp(created),
            "last_edited_time": timestamp(edited ?? created),
            "has_children": hasChildren,
            "in_trash": false,
            "type": type,
            type: content,
        ]
        return try! JSONSerialization.data(withJSONObject: object)
    }
}

// MARK: - Fixtures

enum Fixture {
    /// A bundled sample edition, as the JSON the scheduled task writes.
    static func edition(_ date: String) -> Data {
        let url = Bundle(for: FakeNotion.self).url(forResource: "edition-\(date)", withExtension: "json")!
        return try! Data(contentsOf: url)
    }

    /// A sample edition with its date changed, for a third or fourth distinct edition.
    static func edition(_ date: String, redatedTo newDate: String) -> Data {
        var object = try! JSONSerialization.jsonObject(with: edition(date)) as! [String: Any]
        object["date"] = newDate
        return try! JSONSerialization.data(withJSONObject: object)
    }

    /// Splits text into Notion-sized chunks of at most 2,000 characters.
    static func chunks(_ data: Data, size: Int = 2000) -> [String] {
        let text = String(decoding: data, as: UTF8.self)
        var chunks: [String] = []
        var rest = Substring(text)
        while !rest.isEmpty {
            chunks.append(String(rest.prefix(size)))
            rest = rest.dropFirst(size)
        }
        return chunks
    }
}
