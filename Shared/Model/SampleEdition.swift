import Foundation

/// The two example editions bundled with the app (Shared/Fixtures), in the same JSON format
/// the scheduled task writes to Notion. The app shows them until a Notion token is set up,
/// and the widgets use them as placeholders.
enum SampleEdition {
    static let dates = ["2026-10-08", "2026-10-07"]

    /// Newest first.
    static let documents: [EditionDocument] = dates.compactMap { date in
        guard let url = Bundle.main.url(forResource: "edition-\(date)", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? EditionDocument.decode(data)
    }

    static let editions: [Edition] = documents.map(Edition.init(document:))

    /// For placeholders and previews.
    static var edition: Edition { editions[0] }
}
