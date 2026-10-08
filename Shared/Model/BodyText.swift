import Foundation

/// A run of body copy. The pipeline marks italics with `*…*`: an italic run in parentheses
/// is an inline explanation (muted), any other italic run is ordinary emphasis such as a
/// case name.
enum BodyRun: Sendable, Hashable {
    case text(String)
    case aside(String)
    case emphasis(String)

    var string: String {
        switch self {
        case .text(let string), .aside(let string), .emphasis(let string): string
        }
    }

    static func parse(_ markdown: String) -> [BodyRun] {
        var runs: [BodyRun] = []
        var current = ""
        var italic = false
        func flush() {
            guard !current.isEmpty else { return }
            if italic {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                runs.append(trimmed.hasPrefix("(") ? .aside(current) : .emphasis(current))
            } else {
                runs.append(.text(current))
            }
            current = ""
        }
        var characters = markdown.makeIterator()
        var pending: Character?
        while let character = pending ?? characters.next() {
            pending = nil
            if character == "\\", let next = characters.next() {
                current.append(next)
            } else if character == "*" {
                // `**` (bold) isn't used by the pipeline; treat it like a single marker.
                if let next = characters.next(), next != "*" { pending = next }
                flush()
                italic.toggle()
            } else {
                current.append(character)
            }
        }
        if italic, !current.isEmpty {
            // Unbalanced marker: keep the text rather than lose it.
            runs.append(.text("*" + current))
        } else {
            flush()
        }
        return runs
    }
}
