import Foundation

/// Editions from Notion: the child pages of Court & Capital whose title starts with
/// "Edition", each ending with a "Data" heading and one JSON code block.
struct NotionFeed: EditionFeed {
    let client: NotionClient
    let pageID: String

    init(config: NotionConfig, session: URLSession = .notion, pacer: RequestPacer = .shared) {
        client = NotionClient(token: config.token, session: session, pacer: pacer)
        pageID = config.pageID
    }

    func pages() async throws -> [EditionPageRef] {
        try await client.children(of: pageID)
            .compactMap { block -> EditionPageRef? in
                guard block.type == "child_page", let title = block.title,
                      title.lowercased().hasPrefix("edition")
                else { return nil }
                return EditionPageRef(id: block.id, title: title, createdTime: block.createdTime, lastEditedTime: block.lastEditedTime)
            }
            .sorted { $0.createdTime > $1.createdTime }
    }

    func documentData(for page: EditionPageRef) async throws -> Data? {
        let blocks = try await client.children(of: page.id)
        if let heading = blocks.lastIndex(where: \.isDataHeading) {
            // The code block right under the heading, or inside it when the heading is a toggle.
            let section = blocks[(heading + 1)...].prefix { !$0.isHeading }
            if let code = section.first(where: \.isCode) {
                return Data(code.plainText.utf8)
            }
            if blocks[heading].hasChildren,
               let code = try await client.children(of: blocks[heading].id).first(where: \.isCode) {
                return Data(code.plainText.utf8)
            }
        }
        // No Data heading: the page's last JSON code block, in case the heading was reworded.
        return blocks.last { $0.isCode && $0.language == "json" }.map { Data($0.plainText.utf8) }
    }
}

private extension NotionBlock {
    var isHeading: Bool { type.hasPrefix("heading_") }
    var isCode: Bool { type == "code" }

    /// "Data", in any case, with or without a colon.
    var isDataHeading: Bool {
        isHeading && plainText.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ":"))).lowercased() == "data"
    }
}
