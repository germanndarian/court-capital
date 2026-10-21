import Foundation

/// The Notion integration token and the Court & Capital page, set in Config/Secrets.xcconfig
/// and carried into Info.plist at build time. Nil until both are filled in.
struct NotionConfig: Sendable, Hashable {
    let token: String
    /// 32 hex characters, without dashes
    let pageID: String

    static var current: NotionConfig? {
        guard let token = value("NOTION_TOKEN"), let page = value("NOTION_PAGE_ID"),
              let pageID = normalizePageID(page)
        else { return nil }
        return NotionConfig(token: token, pageID: pageID)
    }

    /// Accepts a bare ID with or without dashes, or a full Notion link to the page.
    static func normalizePageID(_ raw: String) -> String? {
        let hex = raw.lowercased().filter(\.isHexDigit)
        guard hex.count >= 32 else { return nil }
        return String(hex.suffix(32))
    }

    private static func value(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let isPlaceholder = trimmed.isEmpty || trimmed.hasPrefix("$(") || trimmed.contains("your_")
        return isPlaceholder ? nil : trimmed
    }
}
