import Foundation

// MARK: - Words the news uses for the same thing

/// Topics stories put in different words. A file that follows any of them finds the others
/// too: an IPO is also a listing, an S-1 or a roadshow. The first wording is the one shown
/// when the editor suggests the topic from a headline.
enum TopicLexicon {
    static let concepts: [[String]] = [
        ["IPO", "listing", "S-1", "roadshow", "initial public offering", "public offering", "goes public", "go public",
         "going public", "went public", "market debut", "trading debut", "stock market debut", "public debut",
         "Nasdaq debut", "NYSE debut", "direct listing", "F-1", "flotation", "prospectus"],
        ["merger", "merge", "merging", "merged", "takeover", "acquisition", "acquire", "acquires", "acquired",
         "acquiring", "combination", "combine", "combining", "tie-up", "take-private", "deal"],
        ["talks", "negotiations", "negotiating", "discussions"],
        ["lawsuit", "sues", "sued", "suing", "suit", "litigation", "class action"],
        ["court case", "court", "trial", "judge", "ruling", "verdict", "appeal", "appeals court", "hearing"],
        ["antitrust", "monopoly", "competition regulator", "anticompetitive", "anti-competitive", "competition law"],
        ["settlement", "settle", "settles", "settled", "settling"],
        ["fine", "fined", "penalty"],
        ["probe", "investigation", "investigating", "investigates", "inquiry"],
        ["bankruptcy", "bankrupt", "Chapter 11", "insolvency", "insolvent"],
        ["earnings", "results", "quarterly", "revenue", "profit", "guidance"],
        ["layoffs", "job cuts", "cuts jobs", "redundancies", "voluntary buyouts", "headcount"],
        ["interest rates", "rates", "rate", "rate cut", "rate hike", "rate decision"],
        ["funding", "funding round", "fundraising", "raises", "raised", "valuation"],
        ["tariffs", "tariff", "trade war", "duties", "levies"],
        ["sanctions", "sanction", "sanctioned"],
        ["chips", "chip", "chipmaker", "chipmakers", "semiconductor", "semiconductors"],
        ["crypto", "cryptocurrency", "bitcoin", "stablecoin"],
        ["oil", "crude", "Brent", "WTI", "OPEC"],
        ["spin-off", "spinoff", "spin off", "spins off", "demerger", "carve-out", "separation"],
        ["buyback", "share buyback", "buy back", "repurchase"],
        ["dividend", "payout"],
        ["CEO", "chief executive"],
        ["stake", "shareholding"],
        ["strike", "walkout", "industrial action"],
        ["election", "elections", "midterms", "runoff"],
    ]

    /// Names stories use for the same body or company.
    static let names: [[String]] = [
        ["Fed", "Federal Reserve", "FOMC"],
        ["SEC", "Securities and Exchange Commission"],
        ["FTC", "Federal Trade Commission"],
        ["DOJ", "Justice Department", "Department of Justice"],
        ["ECB", "European Central Bank"],
        ["SNB", "Swiss National Bank"],
        ["CFTC", "Commodity Futures Trading Commission"],
        ["CMA", "Competition and Markets Authority"],
        ["European Commission", "EU Commission"],
        ["Google", "Alphabet"],
        ["Meta", "Meta Platforms"],
        ["J&J", "Johnson & Johnson"],
        ["Supreme Court", "SCOTUS"],
        ["Court of Chancery", "Delaware Chancery", "Chancery Court"],
    ]

    /// Words that join a phrase but say nothing about the topic: "SpaceX and Tesla merger".
    static let stopWords: Set<String> = [
        "the", "a", "an", "of", "and", "or", "in", "on", "for", "to", "with", "between", "about", "vs", "versus",
        "at", "by", "from", "its", "their", "&", "+",
    ]

    private static func index(_ groups: [[String]]) -> [String: [String]] {
        var index: [String: [String]] = [:]
        for group in groups {
            for wording in group where index[DocketMatcher.fold(wording)] == nil {
                index[DocketMatcher.fold(wording)] = group
            }
        }
        return index
    }

    private static let conceptIndex = index(concepts)
    private static let nameIndex = index(names)

    /// The topic a folded word belongs to: "listing" → the IPO group.
    static func concept(_ folded: String) -> [String]? { conceptIndex[folded] }

    static func nameGroup(_ folded: String) -> [String]? { nameIndex[folded] }

    /// The topics a headline mentions, in the order it mentions them: ["IPO"]
    static func concepts(in headline: String) -> [String] {
        let text = DocketMatcher.fold(headline)
        let found = concepts.compactMap { group -> (label: String, at: String.Index)? in
            let first = group.compactMap { wording -> String.Index? in
                let folded = DocketMatcher.fold(wording)
                guard DocketMatcher.mentions(text, folded) else { return nil }
                return text.range(of: folded)?.lowerBound
            }.min()
            return first.map { (group[0], $0) }
        }
        return found.sorted { $0.at < $1.at }.map(\.label)
    }
}

// MARK: - What the editions teach

/// What the editions on the iPhone teach the matcher: every name in their Who's who, and
/// which names are described as someone else's ("Copilot = Microsoft's AI assistant"), so a
/// file on Microsoft also finds stories that only mention Copilot.
struct TopicVocabulary: Sendable {
    /// Folded name → as written
    private(set) var names: [String: String] = [:]
    /// Folded owner → the names described as theirs, as written
    private(set) var owned: [String: [String]] = [:]

    init() {}

    init(stories: [Story]) {
        for story in stories {
            for term in story.whosWho {
                let parts = DocketSuggestions.split(term.name)
                for name in parts where names[DocketMatcher.fold(name)] == nil {
                    names[DocketMatcher.fold(name)] = name
                }
                for owner in Self.owners(in: term.description) {
                    for name in parts where DocketMatcher.fold(name) != owner {
                        let known = owned[owner, default: []]
                        if !known.contains(where: { DocketMatcher.fold($0) == DocketMatcher.fold(name) }) {
                            owned[owner] = known + [name]
                        }
                    }
                }
            }
        }
    }

    /// The owners in a Who's who description: "Saudi Arabia's state oil company" →
    /// ["arabia", "saudi arabia"], each folded. Up to three words before the "'s".
    static func owners(in description: String) -> [String] {
        let words = DocketMatcher.fold(description)
            .split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ",;:()\"")) }
        var owners: [String] = []
        for (position, word) in words.enumerated() where word.hasSuffix("'s") && word.count > 2 {
            var phrase = String(word.dropLast(2))
            owners.append(phrase)
            for back in 1...2 where position - back >= 0 {
                phrase = words[position - back] + " " + phrase
                owners.append(phrase)
            }
        }
        return owners
    }

    /// A name or topic as the matcher understands it, or nil for a word it doesn't know.
    func part(_ written: String) -> TopicQuery.Part? {
        var text = written.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:!?\"“”"))
        for suffix in ["'s", "’s"] where text.count > suffix.count + 1 && text.hasSuffix(suffix) {
            text = String(text.dropLast(suffix.count))
        }
        let folded = DocketMatcher.fold(text)
        guard !folded.isEmpty, !TopicLexicon.stopWords.contains(folded) else { return nil }

        if let group = TopicLexicon.concept(folded) {
            let label = group.first { DocketMatcher.fold($0) == folded } ?? text
            return TopicQuery.Part(label: label, kind: .concept, alternatives: group)
        }

        var label: String?
        var alternatives: [String] = []
        if let group = TopicLexicon.nameGroup(folded) {
            label = group.first { DocketMatcher.fold($0) == folded }
            alternatives += group
        }
        if let name = names[folded] {
            label = label ?? name
        }
        if let owned = owned[folded] {
            label = label ?? text
            alternatives += owned
        }
        guard let label else { return nil }
        return TopicQuery.Part(label: label, kind: .name, alternatives: alternatives)
    }
}

// MARK: - A file's words, understood

/// One of a file's words or phrases as the matcher reads it: parts that must all appear in a
/// story, each of which can be said several ways. "Anthropic IPO" is the name Anthropic and
/// the topic IPO, anywhere in the same story, even if it says "listing" instead.
struct TopicQuery: Sendable, Hashable {
    struct Part: Sendable, Hashable {
        enum Kind: Sendable, Hashable {
            /// Matched as typed
            case literal
            case concept
            case name
        }

        /// "IPO", "Anthropic"
        let label: String
        let kind: Kind
        /// Other wordings that count, as written: "listing", "S-1"
        let alternatives: [String]
        /// Folded: the label first, then the alternatives
        let wordings: [String]

        init(label: String, kind: Kind, alternatives: [String] = []) {
            self.label = label
            self.kind = kind
            let folded = DocketMatcher.fold(label)
            var seen: Set<String> = [folded]
            // "Google Cloud" adds nothing to "Google": a story that says it already says Google.
            self.alternatives = alternatives.filter {
                seen.insert(DocketMatcher.fold($0)).inserted && !DocketMatcher.mentions(DocketMatcher.fold($0), folded)
            }
            wordings = [DocketMatcher.fold(label)] + self.alternatives.map(DocketMatcher.fold)
        }

        func matches(_ text: String) -> Bool {
            wordings.contains { !$0.isEmpty && DocketMatcher.mentions(text, $0) }
        }
    }

    /// As typed
    let keyword: String
    let parts: [Part]
    /// Parts with the fewest wordings first, so most stories are ruled out quickly.
    private let checkOrder: [Int]

    init(keyword: String, parts: [Part]) {
        self.keyword = keyword
        self.parts = parts
        checkOrder = parts.indices.sorted { parts[$0].wordings.count < parts[$1].wordings.count }
    }

    /// The words as understood, spelled the way the editions spell them: "Anthropic IPO".
    var tidied: String {
        isUnderstood ? parts.map(\.label).joined(separator: " ") : keyword
    }

    /// Whether the matcher reads more into the words than they say literally.
    var isUnderstood: Bool {
        parts.count > 1 || parts.contains { !$0.alternatives.isEmpty }
    }

    func matches(_ text: String) -> Bool {
        !parts.isEmpty && checkOrder.allSatisfy { parts[$0].matches(text) }
    }

    /// The other wordings a story was found through, where it doesn't use the file's own:
    /// ["listing"] for a story about Anthropic's listing on a file that says IPO.
    func foundThrough(_ text: String) -> [String] {
        parts.compactMap { part in
            guard !DocketMatcher.mentions(text, part.wordings[0]) else { return nil }
            return zip(part.alternatives, part.wordings.dropFirst())
                .first { DocketMatcher.mentions(text, $0.1) }?.0
        }
    }

    /// Reads a word or phrase. Names and topics it knows are split out and widened; a phrase
    /// it doesn't understand at all, like "Wall Street", stays a phrase.
    static func read(_ keyword: String, vocabulary: TopicVocabulary, exact: Bool = false) -> TopicQuery {
        let written = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let literal = TopicQuery(keyword: written, parts: [Part(label: written, kind: .literal)])
        guard !exact, !written.isEmpty else { return literal }
        if let whole = vocabulary.part(written) {
            return TopicQuery(keyword: written, parts: [whole])
        }

        let tokens = written.split(whereSeparator: \.isWhitespace).map(String.init)
        var parts: [Part] = []
        var position = 0
        while position < tokens.count {
            var found: (part: Part, length: Int)?
            for length in stride(from: min(4, tokens.count - position), through: 1, by: -1) {
                let phrase = tokens[position..<position + length].joined(separator: " ")
                if let part = vocabulary.part(phrase) {
                    found = (part, length)
                    break
                }
            }
            if let found {
                parts.append(found.part)
                position += found.length
            } else {
                let token = tokens[position]
                if !TopicLexicon.stopWords.contains(DocketMatcher.fold(token)) {
                    parts.append(Part(label: token, kind: .literal))
                }
                position += 1
            }
        }

        var seen = Set<String>()
        parts = parts.filter { seen.insert($0.wordings[0]).inserted }
        guard parts.contains(where: { $0.kind != .literal }) else { return literal }
        return TopicQuery(keyword: written, parts: parts)
    }
}
