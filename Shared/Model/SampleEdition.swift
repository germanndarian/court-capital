import Foundation

/// Wednesday's edition from the design review, until the edition feed is wired up.
enum SampleEdition {
    static let date = EditionCalendar.calendar.date(from: DateComponents(year: 2026, month: 10, day: 7))!

    static let boulder = StoryContent(
        whosWho: [
            Term(term: "Supreme Court", definition: "highest US court"),
            Term(term: "Suncor", definition: "Canadian oil company"),
            Term(term: "ExxonMobil", definition: "biggest US oil company"),
            Term(term: "Boulder County", definition: "Colorado local government suing them"),
        ],
        body: [
            .text("Justices Sotomayor and Jackson appeared to back Boulder, while Kavanaugh clearly favoured the oil companies. Justice Alito recused himself "),
            .aside("(stepped aside from the case)"),
            .text(", so only eight justices will decide it."),
        ],
        whyItMatters: "The ruling decides whether dozens of similar climate suits can go to trial. A 4–4 tie would let Boulder’s case proceed.",
        plainWords: "The judges heard the big climate case and seemed divided. One judge stepped aside, so a tie is possible. A tie would let the county keep suing.",
        sources: [
            Source(name: "Legal Planet", url: URL(string: "https://legal-planet.org")!),
            Source(name: "Common Dreams", url: URL(string: "https://www.commondreams.org")!),
        ]
    )

    static let edition = Edition(
        date: date,
        bigStory: "Schneider Electric agreed to buy US industrial-software maker PTC for $22.6 billion in cash, the biggest deal in its history.",
        bigStoryID: "ptc",
        marketsNote: "At \(EditionFormat.weekday(EditionCalendar.previousWeekday(before: date)))’s close",
        markets: [
            Market(name: "S&P 500", value: "7,773.99", change: "+0.66%", direction: .up),
            Market(name: "Nasdaq", value: "27,477.31", change: "+1.05%", direction: .up),
            Market(name: "SMI", value: "13,703.53", change: "+0.31%", direction: .up),
            Market(name: "US 10Y", value: "5.32%", change: "Yield", direction: .flat),
            Market(name: "USD/CHF", value: "0.8308", change: "+0.29%", direction: .up),
            Market(name: "Brent", value: "$100.32", change: "−1.9%", direction: .down),
        ],
        widgetMarketNames: ["S&P 500", "Nasdaq", "SMI", "Brent"],
        sections: [
            EditionSection(numeral: "I", name: "Corporate Law", stories: [
                Story(id: "boulder", title: "Supreme Court looks split on Boulder’s climate suit against Big Oil; Alito sits out", region: .us, readMinutes: 3, content: boulder),
                Story(id: "zillow", title: "Supreme Court refuses Zillow’s bid to escape investor class action", region: .us, readMinutes: 2),
                Story(id: "antitrust", title: "Supreme Court asks US government’s view on insulin, hard-drive and allergy antitrust appeals", region: .us, readMinutes: 2),
                Story(id: "charters", title: "Community banks sue to block crypto firms from getting national trust charters", region: .us, readMinutes: 2),
            ]),
            EditionSection(numeral: "II", name: "Finance", stories: [
                Story(id: "ptc", title: "Schneider Electric agrees record $22.6B cash takeover of PTC", region: .eu, readMinutes: 2),
                Story(id: "nasdaq", title: "Nasdaq gains 1.05% even as 10-year Treasury yield hits a 24-year high", region: .us, readMinutes: 2),
                Story(id: "rxo", title: "C.H. Robinson agrees $5.8B deal for rival freight broker RXO", region: .us, readMinutes: 2),
                Story(id: "pension", title: "Swiss pension funds lose 0.3% in September as Swiss stocks slide", region: .ch, readMinutes: 2),
            ]),
            EditionSection(numeral: "III", name: "AI", stories: [
                Story(id: "sif", title: "Trump creates “Super Intelligence Force” to steer US AI policy", region: .us, readMinutes: 2),
                Story(id: "nyc", title: "Ex-AI lab researchers warn NYC Council under oath about losing control of AI", region: .us, readMinutes: 2),
            ]),
        ],
        readMinutes: 11
    )

    /// Stand-in Big Story headlines for earlier editions in the archive.
    static let pastHeadlines = [
        "Delaware court narrows the business-judgment shield for controller buyouts",
        "Swiss franc firms as investors seek safety after weak euro-area data",
        "EU publishes compliance guidance for general-purpose AI models",
        "Regional lender agrees all-share merger to build a mid-sized US bank",
        "Appeals court revives securities suit over missed revenue guidance",
        "Bond yields climb as traders price fewer rate cuts this year",
        "Zurich insurer completes sale of its legacy life book",
        "State lawmakers advance disclosure rules for AI-generated political ads",
        "Private-credit fund marks down loans to software borrowers",
        "Shareholders reject pay package after proxy advisers object",
        "Antitrust enforcers clear chip-equipment deal with conditions",
        "Geneva trading house raises a fresh revolving credit facility",
    ]
}
