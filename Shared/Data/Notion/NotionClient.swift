import Foundation

/// Reads from the Notion API with the integration token. It only ever sends GET requests.
/// Requests are spaced out to stay under Notion's rate limit, and a 429 is retried after the
/// wait Notion asks for.
struct NotionClient: Sendable {
    /// The API version the app was checked against.
    static let version = "2026-03-11"
    static let baseURL = URL(string: "https://api.notion.com/v1/")!
    /// How often a request that keeps getting a 429 is retried before giving up.
    static let maxRetries = 4

    let token: String
    var session: URLSession = .notion
    var pacer: RequestPacer = .shared

    /// Every child block of a page or block. Notion returns at most 100 at a time, so this
    /// follows `next_cursor` until it has them all.
    func children(of blockID: String) async throws -> [NotionBlock] {
        var blocks: [NotionBlock] = []
        var cursor: String?
        repeat {
            var query = [URLQueryItem(name: "page_size", value: "100")]
            if let cursor { query.append(URLQueryItem(name: "start_cursor", value: cursor)) }
            let list: NotionList<NotionBlock> = try await get("blocks/\(blockID)/children", query: query)
            blocks += list.results
            cursor = list.hasMore ? list.nextCursor : nil
        } while cursor != nil
        return blocks
    }

    private func get<Response: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> Response {
        var components = URLComponents(url: Self.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.version, forHTTPHeaderField: "Notion-Version")

        var retries = 0
        while true {
            try await pacer.waitForTurn()
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw NotionError.unexpectedResponse }
            switch http.statusCode {
            case 200..<300:
                // Never let a DecodingError out: the store reads that as a broken Data block
                // and wouldn't download the page again.
                guard let decoded = try? JSONDecoder.notion.decode(Response.self, from: data) else {
                    throw NotionError.unexpectedResponse
                }
                return decoded
            case 429:
                guard retries < Self.maxRetries else { throw NotionError.rateLimited }
                retries += 1
                await pacer.pause(for: Self.retryAfter(http) ?? .seconds(1 << (retries - 1)))
            default:
                let body = try? JSONDecoder.notion.decode(NotionErrorBody.self, from: data)
                throw NotionError.http(status: http.statusCode, code: body?.code)
            }
        }
    }

    /// Notion sends the wait in whole seconds. Anything over a minute is treated as a minute.
    static func retryAfter(_ response: HTTPURLResponse) -> Duration? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = Double(value.trimmingCharacters(in: .whitespaces)), seconds >= 0
        else { return nil }
        return .milliseconds(Int(min(seconds, 60) * 1000))
    }
}

enum NotionError: Error, Equatable {
    /// Notion answered with an error: 401 for a wrong token, 404 when the page isn't shared
    /// with the integration.
    case http(status: Int, code: String?)
    /// Still rate-limited after every retry.
    case rateLimited
    /// The response wasn't the JSON Notion documents.
    case unexpectedResponse
}

/// Spaces requests out to average at most three a second, Notion's limit for an integration.
/// One pacer is shared by the whole process, so syncs that overlap don't add up.
actor RequestPacer {
    static let shared = RequestPacer(interval: .milliseconds(340))

    private let interval: Duration
    private let now: @Sendable () -> ContinuousClock.Instant
    private let sleep: @Sendable (Duration) async throws -> Void
    private var nextSlot: ContinuousClock.Instant?

    init(
        interval: Duration,
        now: @escaping @Sendable () -> ContinuousClock.Instant = { .now },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.interval = interval
        self.now = now
        self.sleep = sleep
    }

    /// Waits until the next request may go out. The slot is booked before waiting, so
    /// requests that arrive together go out one interval apart.
    func waitForTurn() async throws {
        let now = now()
        let slot = max(now, nextSlot ?? now)
        nextSlot = slot + interval
        if slot > now { try await sleep(slot - now) }
    }

    /// Holds every request back for `delay`, after Notion answers 429.
    func pause(for delay: Duration) {
        let resume = now() + delay
        nextSlot = max(nextSlot ?? resume, resume)
    }
}

// MARK: - Responses

/// One page of a paginated list.
struct NotionList<Item: Decodable & Sendable>: Decodable, Sendable {
    let results: [Item]
    let nextCursor: String?
    let hasMore: Bool

    private enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// A block with just what the app reads. Its content sits under a key named after its type,
/// such as `"heading_3": { "rich_text": [...] }` or `"child_page": { "title": "..." }`.
struct NotionBlock: Decodable, Sendable {
    let id: String
    let type: String
    let hasChildren: Bool
    let createdTime: Date
    let lastEditedTime: Date
    /// A heading's or paragraph's words, or a code block's contents, in chunks.
    let richText: [RichText]
    /// Child pages only
    let title: String?
    /// Code blocks only, such as "json"
    let language: String?

    struct RichText: Decodable, Sendable {
        let plainText: String

        private enum CodingKeys: String, CodingKey {
            case plainText = "plain_text"
        }
    }

    /// Notion splits long text into several chunks; this joins them back together.
    var plainText: String { richText.map(\.plainText).joined() }

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.init(stringValue) }
        init?(intValue: Int) { nil }
    }

    private struct Content: Decodable {
        var richText: [RichText]?
        var title: String?
        var language: String?

        private enum CodingKeys: String, CodingKey {
            case richText = "rich_text"
            case title, language
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        id = try container.decode(String.self, forKey: Key("id"))
        type = try container.decode(String.self, forKey: Key("type"))
        hasChildren = try container.decodeIfPresent(Bool.self, forKey: Key("has_children")) ?? false
        createdTime = try container.decode(Date.self, forKey: Key("created_time"))
        lastEditedTime = try container.decode(Date.self, forKey: Key("last_edited_time"))
        let content = try? container.decodeIfPresent(Content.self, forKey: Key(type))
        richText = content?.richText ?? []
        title = content?.title
        language = content?.language
    }
}

private struct NotionErrorBody: Decodable {
    let code: String?
}

extension JSONDecoder {
    /// Notion's timestamps look like 2026-10-21T03:00:00.000Z.
    static let notion: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            return try Date(text, strategy: .iso8601)
        }
        return decoder
    }()
}

extension URLSession {
    /// No HTTP cache: an edition page can change between two syncs a minute apart.
    static let notion: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }()
}
