import Foundation

enum AssetSummaryConsolidator {
    /// Segment summaries are independent evidence. Keep every distinct line in
    /// source order: choosing a single "best" candidate silently discards facts
    /// that only appeared in another segment.
    static func consolidate(_ summaries: String...) -> String {
        consolidate(summaries)
    }

    static func consolidate(_ summaries: [String]) -> String {
        let lines = summaries
            .flatMap { $0.components(separatedBy: .newlines) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        var uniqueLines: [String] = []
        uniqueLines.reserveCapacity(lines.count)

        for line in lines {
            let key = canonicalLineKey(line)
            guard seen.insert(key).inserted else { continue }
            uniqueLines.append(line)
        }

        return uniqueLines.joined(separator: "\n")
    }

    private static func canonicalLineKey(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
