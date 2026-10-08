import Foundation
import PostgREST

/// The Supabase project the app and widgets read from, set in Config/Secrets.xcconfig and
/// carried into Info.plist at build time.
enum SupabaseConfig {
    static var host: String? { value("SUPABASE_HOST") }
    static var publishableKey: String? { value("SUPABASE_PUBLISHABLE_KEY") }

    static var isConfigured: Bool { host != nil && publishableKey != nil }

    private static func value(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
    }
}

enum EditionServiceError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Supabase isn’t set up in this build. Add your keys to Config/Secrets.xcconfig."
        }
    }
}

/// Read-only access to the editions table. The publishable key can only SELECT.
struct EditionService: Sendable {
    private let client: PostgrestClient

    init() throws {
        guard let host = SupabaseConfig.host, let key = SupabaseConfig.publishableKey,
              let url = URL(string: "https://\(host)/rest/v1")
        else { throw EditionServiceError.notConfigured }
        client = PostgrestClient(url: url, headers: ["apikey": key])
    }

    private struct ContentRow: Decodable {
        let content: Edition
    }

    /// The most recent editions, newest first, in full.
    func latest(limit: Int = 10) async throws -> [Edition] {
        let response = try await client.from("editions")
            .select("content")
            .order("edition_date", ascending: false)
            .limit(limit)
            .execute()
        return try JSONDecoder.edition.decode([ContentRow].self, from: response.data).map(\.content)
    }

    /// One edition in full, if it exists.
    func edition(on date: String) async throws -> Edition? {
        let response = try await client.from("editions")
            .select("content")
            .eq("edition_date", value: date)
            .limit(1)
            .execute()
        return try JSONDecoder.edition.decode([ContentRow].self, from: response.data).first?.content
    }

    /// Every published edition's date, number and Big Story, newest first.
    func archive() async throws -> [ArchiveItem] {
        let response = try await client.from("editions")
            .select("edition_date,number,big_story,reading_minutes:content->reading_minutes")
            .order("edition_date", ascending: false)
            .limit(1000)
            .execute()
        return try JSONDecoder.edition.decode([ArchiveItem].self, from: response.data)
    }
}
