import Foundation

/// A small edition for widget placeholders and SwiftUI previews. Real editions come from
/// Supabase.
enum SampleEdition {
    static let edition = Edition(
        schemaVersion: 1,
        date: "2026-10-08",
        number: 201,
        volume: 1,
        bigStory: .init(
            text: "Fed minutes show every official backed September’s rate hike and most expect another before year-end.",
            storyId: "fed-minutes"
        ),
        markets: .init(asOf: "2026-10-07", quotes: [
            Quote(name: "S&P 500", level: 7801.77, change: -0.22, changeUnit: "percent", unit: "index"),
            Quote(name: "Nasdaq", level: 27538.69, change: -0.22, changeUnit: "percent", unit: "index"),
            Quote(name: "SMI", level: 13808.42, change: 0.14, changeUnit: "percent", unit: "index"),
            Quote(name: "US 10Y", level: 5.277, change: 0.8, changeUnit: "bp", unit: "yield"),
            Quote(name: "USD/CHF", level: 0.8322, change: 0.13, changeUnit: "percent", unit: "fx"),
            Quote(name: "Brent", level: 100.2, change: -0.38, changeUnit: "percent", unit: "usd"),
        ]),
        sections: [
            EditionSection(key: "corporate_law", numeral: "I", title: "Corporate Law", note: "US focus", stories: [story(
                id: "kalshi-states",
                headline: "39 states and D.C. urge Supreme Court to let states regulate Kalshi’s sports prediction markets",
                whosWho: [Term(name: "Kalshi", description: "US platform for trading bets on real-world events")],
                body: "Ohio, 38 other states and Washington, D.C. filed an amicus brief *(a “friend of the court” filing by someone not party to the case)* supporting New Jersey’s petition in *Flaherty v. KalshiEX*."
            )]),
            EditionSection(key: "finance", numeral: "II", title: "Finance", note: "US & Swiss markets", stories: [story(
                id: "fed-minutes",
                headline: "Fed minutes: all officials backed September’s rate hike, and most expect another by year-end",
                whosWho: [Term(name: "Fed", description: "US central bank, sets interest rates")],
                body: "Minutes of the 15–16 September meeting confirm the FOMC voted 12–0 to raise rates by a quarter point to 3.75%–4%."
            )]),
            EditionSection(key: "ai", numeral: "III", title: "AI", note: "Quick hits", stories: [story(
                id: "gpt-6",
                headline: "OpenAI puts GPT-6 Sol and Luna into ChatGPT for all users",
                whosWho: [Term(name: "OpenAI", description: "maker of ChatGPT")],
                body: "The October models replace GPT-5.6 for free and paid users worldwide."
            )]),
        ],
        readingMinutes: 3,
        footer: "compiled by Claude from public reporting · not financial or legal advice",
        model: "sample",
        generatedAt: "2026-10-08T03:15:00Z"
    )

    private static func story(id: String, headline: String, whosWho: [Term], body: String) -> Story {
        Story(
            id: id,
            headline: headline,
            region: .us,
            whosWho: whosWho,
            body: body,
            whyItMatters: "A short note on why this matters.",
            plainWords: ["One short sentence.", "Another one.", "And a third."],
            sources: [Source(outlet: "Example", url: "https://example.com")],
            readingMinutes: 1
        )
    }
}
