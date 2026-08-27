import Foundation

/// A local, deterministic screenplay index for the design phase. It only
/// returns short, bounded evidence excerpts; callers can safely provide the
/// result to an AI design request without attaching an entire screenplay.
struct ScriptKnowledgeIndex: Sendable {
    struct Context: Identifiable, Hashable, Sendable {
        let id: String
        let episodeID: UUID
        let episodeOrder: Int
        let sceneIdentifier: String
        let heading: String
        let excerpt: String
        let truncated: Bool
    }

    private static let maximumContexts = 6
    nonisolated private static let maximumHeadingLength = 150
    private static let maximumExcerptLength = 420
    private static let maximumTotalExcerptLength = 2_000

    private let chunks: [Chunk]

    init(episodes: [ScriptEpisode]) {
        self.chunks = episodes
            .sorted { lhs, rhs in
                lhs.order == rhs.order ? lhs.id.uuidString < rhs.id.uuidString : lhs.order < rhs.order
            }
            .flatMap(Self.sceneChunks(in:))
    }

    /// Searches asset identity and extracted overview fields. Source episodes
    /// constrain the result when available, so a design request stays focused
    /// on the asset's known appearances.
    func contexts(
        for asset: AssetItem,
        optionTerms: [String] = []
    ) -> [Context] {
        let identityTokens = Self.tokens(
            in: [asset.name, asset.summary, asset.evidence].joined(separator: "\n")
        )
        let optionTokens = Self.tokens(in: optionTerms.joined(separator: "\n"))
        guard !identityTokens.isEmpty else { return [] }

        let sourceIDs = Set(asset.sourceEpisodeIDs ?? [])
        let candidates = sourceIDs.isEmpty
            ? chunks
            : chunks.filter { sourceIDs.contains($0.episodeID) }

        let ranked = candidates.compactMap { chunk -> (Chunk, Int)? in
            let score = chunk.score(
                for: identityTokens,
                optionTokens: optionTokens
            )
            return score > 0 ? (chunk, score) : nil
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            if lhs.0.episodeOrder != rhs.0.episodeOrder {
                return lhs.0.episodeOrder < rhs.0.episodeOrder
            }
            if lhs.0.sceneOrder != rhs.0.sceneOrder { return lhs.0.sceneOrder < rhs.0.sceneOrder }
            return lhs.0.id < rhs.0.id
        }

        var result: [Context] = []
        var remaining = Self.maximumTotalExcerptLength
        for (chunk, _) in ranked
            where result.count < Self.maximumContexts && remaining > 0 {
            let bound = min(Self.maximumExcerptLength, remaining)
            let context = Self.boundedContext(
                from: chunk,
                matching: [asset.name, asset.evidence, asset.summary],
                excerptLimit: bound
            )
            guard !context.heading.isEmpty || !context.excerpt.isEmpty else {
                continue
            }
            result.append(Context(
                id: chunk.id,
                episodeID: chunk.episodeID,
                episodeOrder: chunk.episodeOrder,
                sceneIdentifier: chunk.sceneIdentifier,
                heading: context.heading,
                excerpt: context.excerpt,
                truncated: context.truncated
            ))
            remaining -= context.excerpt.count
        }
        return result
    }

    private struct Chunk: Sendable {
        let id: String
        let episodeID: UUID
        let episodeOrder: Int
        let sceneOrder: Int
        let sceneIdentifier: String
        let heading: String
        let body: String
        let tokens: Set<String>

        func score(
            for queryTokens: Set<String>,
            optionTokens: Set<String>
        ) -> Int {
            let overlap = tokens.intersection(queryTokens).count
            let headingOverlap = ScriptKnowledgeIndex.tokens(in: heading)
                .intersection(queryTokens).count
            let identityScore = overlap + headingOverlap * 3
            guard identityScore > 0 else { return 0 }
            // Design controls refine a query but can never outweigh the asset
            // identity/overview that establishes what is being designed.
            let optionOverlap = min(tokens.intersection(optionTokens).count, 3)
            // Heading matches are useful, but this remains a deterministic
            // retrieval score rather than semantic inference.
            return identityScore + optionOverlap
        }
    }

    nonisolated private static func sceneChunks(
        in episode: ScriptEpisode
    ) -> [Chunk] {
        let lines = episode.scriptText.components(separatedBy: .newlines)
        var parsed: [(identifier: String, heading: String, lines: [String])] = []
        var currentIdentifier: String?
        var currentHeading = ""
        var currentLines: [String] = []

        func appendCurrent() {
            guard let currentIdentifier else { return }
            parsed.append((currentIdentifier, currentHeading, currentLines))
        }

        for line in lines {
            if let identifier = sceneIdentifier(
                in: line,
                episodeOrder: episode.order,
                fallbackSceneOrder: parsed.count + 1
            ) {
                appendCurrent()
                currentIdentifier = identifier
                currentHeading = line.trimmingCharacters(in: .whitespacesAndNewlines)
                currentLines = []
            } else if currentIdentifier != nil {
                currentLines.append(line)
            }
        }
        appendCurrent()

        if parsed.isEmpty {
            let body = episode.scriptText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return [] }
            return [
                makeChunk(
                    episode: episode,
                    sceneOrder: 0,
                    sceneIdentifier: "\(episode.order)-未标场次",
                    heading: "",
                    body: body
                )
            ]
        }

        return parsed.enumerated().map { offset, block in
            makeChunk(
                episode: episode,
                sceneOrder: offset,
                sceneIdentifier: block.identifier,
                heading: block.heading,
                body: block.lines.joined(separator: "\n")
            )
        }
    }

    nonisolated private static func makeChunk(
        episode: ScriptEpisode,
        sceneOrder: Int,
        sceneIdentifier: String,
        heading: String,
        body: String
    ) -> Chunk {
        // The opaque ID deliberately excludes screenplay-derived heading text.
        let id = "script-context-\(episode.id.uuidString.lowercased())-\(sceneOrder)"
        return Chunk(
            id: id,
            episodeID: episode.id,
            episodeOrder: episode.order,
            sceneOrder: sceneOrder,
            sceneIdentifier: sceneIdentifier,
            heading: heading,
            body: body,
            tokens: tokens(in: "\(heading)\n\(body)")
        )
    }

    nonisolated private static func sceneIdentifier(
        in line: String,
        episodeOrder: Int,
        fallbackSceneOrder: Int
    ) -> String? {
        let pattern = #"^\s*(?:>\s*)?(?:[-+]\s+)?(?:#{1,6}\s*)?(?:\*{1,3}|_{1,3})?\s*([0-9０-９]{1,4})\s*[-—–－]\s*([0-9０-９]{1,3}[A-Za-z]?)(?=[^0-9０-９A-Za-z]|$)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        if let match = expression.firstMatch(in: line, range: range),
           let episodeRange = Range(match.range(at: 1), in: line),
           let sceneRange = Range(match.range(at: 2), in: line) {
            let raw = "\(line[episodeRange])-\(line[sceneRange])"
            let halfwidth = raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw
            return halfwidth
                .replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "－", with: "-")
                .replacingOccurrences(of: " ", with: "")
                .lowercased()
        }

        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let uppercased = trimmed.uppercased()
        let hasScreenplayPrefix = ["INT.", "EXT.", "INT ", "EXT ", "I/E."]
            .contains(where: uppercased.hasPrefix)
        let otherHeadingPatterns = [
            #"^\s*[0-9０-９]{1,4}\s*[\.、]\s*\S+"#,
            #"^\s*第?[0-9０-９一二三四五六七八九十百零〇两]+[場场幕]\s*\S*"#,
            #"^\s*(?:场|場|SCENE)\s*[0-9０-９一二三四五六七八九十百零〇两]+"#
        ]
        guard hasScreenplayPrefix || otherHeadingPatterns.contains(where: {
            trimmed.range(of: $0, options: .regularExpression) != nil
        }) else {
            return nil
        }

        if let numberRange = trimmed.range(
            of: #"^[0-9０-９]{1,4}"#,
            options: .regularExpression
        ) {
            let rawNumber = String(trimmed[numberRange])
            let number = rawNumber.applyingTransform(
                .fullwidthToHalfwidth,
                reverse: false
            ) ?? rawNumber
            return "\(episodeOrder)-\(number)"
        }
        return "\(episodeOrder)-\(fallbackSceneOrder)"
    }

    nonisolated private static func tokens(in text: String) -> Set<String> {
        let folded = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "zh_Hans")
        )
        let scalars = Array(folded.unicodeScalars)
        var result = Set<String>()
        var hanRun: [UnicodeScalar] = []
        var latinRun = ""

        func appendHanBigrams() {
            guard hanRun.count >= 2 else {
                hanRun.removeAll(keepingCapacity: true)
                return
            }
            for index in 0..<(hanRun.count - 1) {
                result.insert(String(String.UnicodeScalarView([hanRun[index], hanRun[index + 1]])))
            }
            hanRun.removeAll(keepingCapacity: true)
        }
        func appendLatinToken() {
            if !latinRun.isEmpty { result.insert(latinRun) }
            latinRun = ""
        }

        for scalar in scalars {
            if (0x4E00...0x9FFF).contains(scalar.value) {
                appendLatinToken()
                hanRun.append(scalar)
            } else if CharacterSet.alphanumerics.contains(scalar), scalar.value < 128 {
                appendHanBigrams()
                latinRun.unicodeScalars.append(scalar)
            } else {
                appendHanBigrams()
                appendLatinToken()
            }
        }
        appendHanBigrams()
        appendLatinToken()
        return result
    }

    nonisolated private static func boundedExcerpt(
        from body: String,
        matching terms: [String],
        limit: Int
    ) -> (text: String, truncated: Bool) {
        let normalized = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, limit > 0 else { return ("", false) }
        // Never expose a complete short scene. For every selectable scene the
        // returned body is at most 75% of its original length.
        let omittedForPrivacy = max(
            1,
            Int(ceil(Double(normalized.count) * 0.25))
        )
        let privacyLimit = max(0, normalized.count - omittedForPrivacy)
        guard privacyLimit > 0 else { return ("", true) }
        let count = min(limit, privacyLimit)
        let text = boundedWindow(
            in: normalized,
            matching: terms,
            count: count
        )
        return (text, count < normalized.count)
    }

    /// Applies a privacy cap to heading and body together. A malformed import
    /// whose entire screenplay sits on a single scene-heading line therefore
    /// yields no evidence context instead of leaking that line as metadata.
    nonisolated private static func boundedContext(
        from chunk: Chunk,
        matching terms: [String],
        excerptLimit: Int
    ) -> (heading: String, excerpt: String, truncated: Bool) {
        let heading = chunk.heading.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let body = chunk.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return ("", "", true) }

        let sourceCount = heading.count + body.count
        let omittedForPrivacy = max(
            1,
            Int(ceil(Double(sourceCount) * 0.25))
        )
        var privacyRemaining = max(0, sourceCount - omittedForPrivacy)

        // sceneIdentifier is also sent to the model, so count it against the
        // same budget even though it is derived rather than copied verbatim.
        privacyRemaining -= min(chunk.sceneIdentifier.count, privacyRemaining)
        let headingCount = min(
            maximumHeadingLength,
            heading.count,
            privacyRemaining
        )
        let boundedHeading = boundedWindow(
            in: heading,
            matching: terms,
            count: headingCount
        )
        privacyRemaining -= boundedHeading.count

        let boundedBody = boundedExcerpt(
            from: body,
            matching: terms,
            limit: min(excerptLimit, privacyRemaining)
        )
        let transmittedSourceCount = boundedHeading.count
            + boundedBody.text.count
        return (
            boundedHeading,
            boundedBody.text,
            boundedBody.truncated || transmittedSourceCount < sourceCount
        )
    }

    nonisolated private static func boundedWindow(
        in normalized: String,
        matching terms: [String],
        count: Int
    ) -> String {
        guard !normalized.isEmpty, count > 0 else { return "" }
        let boundedCount = min(count, normalized.count)
        let meaningfulTerms = terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
        let match = meaningfulTerms.lazy.compactMap { term in
            normalized.range(
                of: term,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
            )
        }.first

        let start: String.Index
        if let match {
            let matchOffset = normalized.distance(
                from: normalized.startIndex,
                to: match.lowerBound
            )
            let desiredOffset = max(0, matchOffset - boundedCount / 3)
            let maximumOffset = max(0, normalized.count - boundedCount)
            start = normalized.index(
                normalized.startIndex,
                offsetBy: min(desiredOffset, maximumOffset)
            )
        } else {
            start = normalized.startIndex
        }
        let end = normalized.index(start, offsetBy: boundedCount)
        return String(normalized[start..<end])
    }
}
