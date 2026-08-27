import Foundation

struct DetectedScriptEpisode: Hashable, Sendable {
    let episodeNumber: String?
    let title: String
    let scriptText: String

    init(
        episodeNumber: String? = nil,
        title: String,
        scriptText: String
    ) {
        self.episodeNumber = episodeNumber
        self.title = title
        self.scriptText = scriptText
    }
}

struct EpisodeSplitDiagnostic: Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case duplicateEpisodeNumber
        case episodeNumberRegression
    }

    enum Evidence: String, Hashable, Sendable {
        case episodeHeader
        case sceneHeading
    }

    let kind: Kind
    let evidence: Evidence
    let lineNumber: Int
    let episodeNumber: String
    let message: String
}

struct EpisodeScriptSplitResult: Hashable, Sendable {
    let episodes: [DetectedScriptEpisode]
    let diagnostics: [EpisodeSplitDiagnostic]
}

enum EpisodeScriptSplitter {
    private static let chineseEpisodeHeaderPattern =
        #"^\s*(?:>\s*)?(?:[-+]\s+)?(?:#{1,6}\s*)?(?:\*{1,3}|_{1,3})?\s*(?:[0-9０-９]{1,3}\s*[.．、]\s*)?第\s*([0-9０-９零〇一二三四五六七八九十百千万两]+)\s*[集话回](?=$|\s|[*_:：\-—–_、.．·（(])"#
    private static let englishEpisodeHeaderPattern =
        #"^\s*(?:>\s*)?(?:[-+]\s+)?(?:#{1,6}\s*)?(?:\*{1,3}|_{1,3})?\s*(?:EPISODE|EP\.?|E)\s*([0-9０-９]{1,4})(?=$|\s|[*_:：\-—–_、.．·（(])"#
    private static let explicitSceneHeadingPattern =
        #"^\s*(?:第\s*[0-9０-９零〇一二三四五六七八九十百千万两]+\s*[集话回]\s*[:：\-—–_、.．·（(]*\s*)?([0-9０-９]{1,4})\s*[-—–－]\s*([0-9０-９]{1,3}[A-Za-z]?)(?=[^0-9０-９A-Za-z]|$)"#
    private static let numberedSceneHeadingPatterns = [
        #"^\s*[0-9０-９]{1,3}\s*[.．、]\s*(?:(?:日|夜|晨|午|昏|黄昏|清晨|傍晚)\s*[/／·|｜-]?\s*)?(?:内景|外景|内|外)(?=[\s/／·|｜-]|$)"#,
        #"^\s*(?:场景|场|SCENE)\s*[0-9０-９]{1,3}(?=[^0-9０-９]|$)"#
    ]
    private static let unnumberedSceneHeadingPattern =
        #"^\s*(?:(?:日|夜|晨|午|昏|黄昏|清晨|傍晚)\s*[/／·|｜-]\s*(?:内景|外景|内|外)|(?:内景|外景|内|外)\s*[/／·|｜-]\s*(?:日|夜|晨|午|昏|黄昏|清晨|傍晚))(?=[\s/／·|｜-]|$)"#

    static func split(_ script: String) -> [DetectedScriptEpisode] {
        splitWithDiagnostics(script).episodes
    }

    static func splitWithDiagnostics(_ script: String) -> EpisodeScriptSplitResult {
        let lines = sourceLines(in: script)
        let episodeHeaders = detectedEpisodeHeaders(in: lines)
        let sceneMarkers = detectedExplicitSceneMarkers(in: lines)
        let sceneEpisodeStarts = consecutiveSceneEpisodeStarts(sceneMarkers)

        // A scene number such as 11-3 is the strongest available episode
        // boundary. It remains reliable when Markdown or OCR noise damages the
        // surrounding "第 N 集" line.
        if sceneEpisodeStarts.count >= 2 {
            let sceneDiagnostics = episodeSequenceDiagnostics(
                sceneEpisodeStarts,
                evidence: .sceneHeading
            )
            guard sceneDiagnostics.isEmpty else {
                return unsplitResult(script, diagnostics: sceneDiagnostics)
            }

            let boundaries = boundariesUsingSceneEpisodeStarts(
                sceneStarts: sceneEpisodeStarts,
                episodeHeaders: episodeHeaders
            )
            return EpisodeScriptSplitResult(
                episodes: episodes(from: script, boundaries: boundaries),
                diagnostics: []
            )
        }

        if episodeHeaders.count >= 2 {
            let diagnostics = episodeSequenceDiagnostics(
                episodeHeaders,
                evidence: .episodeHeader
            )
            guard diagnostics.isEmpty else {
                return unsplitResult(script, diagnostics: diagnostics)
            }

            let boundaries = episodeHeaders.map {
                EpisodeBoundary(
                    sourceOffset: $0.sourceOffset,
                    lineIndex: $0.lineIndex,
                    episodeNumber: $0.episodeNumber
                )
            }
            return EpisodeScriptSplitResult(
                episodes: episodes(from: script, boundaries: boundaries),
                diagnostics: []
            )
        }

        let episodeNumber = sceneEpisodeStarts.first?.episodeNumber
            ?? episodeHeaders.first?.episodeNumber
        return unsplitResult(script, episodeNumber: episodeNumber)
    }

    static func sanitizeNovelChapterMarkers(in text: String) -> String {
        // Kept as an API compatibility point for import and export callers.
        // Source text must never be normalized destructively; chapter-marker
        // cleanup used by recognition lives only in `detectionOnlyLine`.
        text
    }

    static func sceneHeadings(in script: String) -> [EpisodeSceneHeading] {
        sourceLines(in: script).compactMap { line in
            guard let scene = sceneHeading(
                from: line.text,
                lineIndex: line.lineIndex
            ) else {
                return nil
            }
            return EpisodeSceneHeading(
                lineNumber: line.lineIndex + 1,
                text: scene.displayText,
                episodeNumber: scene.episodeNumber,
                sceneNumber: scene.sceneNumber
            )
        }
    }

    private static func detectedEpisodeHeaders(
        in lines: [SourceLine]
    ) -> [EpisodeHeaderMarker] {
        lines.compactMap { line in
            guard let episodeNumber = episodeNumber(fromHeaderLine: line.text) else {
                return nil
            }
            return EpisodeHeaderMarker(
                sourceOffset: line.sourceOffset,
                lineIndex: line.lineIndex,
                episodeNumber: episodeNumber
            )
        }
    }

    private static func detectedExplicitSceneMarkers(
        in lines: [SourceLine]
    ) -> [SceneMarker] {
        lines.compactMap { line in
            guard let scene = sceneHeading(from: line.text, lineIndex: line.lineIndex),
                  let episodeNumber = scene.episodeNumber,
                  let sceneNumber = scene.sceneNumber
            else {
                return nil
            }
            return SceneMarker(
                sourceOffset: line.sourceOffset,
                lineIndex: line.lineIndex,
                episodeNumber: episodeNumber,
                sceneNumber: sceneNumber
            )
        }
    }

    private static func consecutiveSceneEpisodeStarts(
        _ markers: [SceneMarker]
    ) -> [SceneMarker] {
        var starts: [SceneMarker] = []
        for marker in markers where starts.last?.episodeNumber != marker.episodeNumber {
            starts.append(marker)
        }
        return starts
    }

    private static func boundariesUsingSceneEpisodeStarts(
        sceneStarts: [SceneMarker],
        episodeHeaders: [EpisodeHeaderMarker]
    ) -> [EpisodeBoundary] {
        var boundaries: [EpisodeBoundary] = []
        var previousSceneStartLine = -1
        for sceneStart in sceneStarts {
            let matchingHeader = episodeHeaders.last { header in
                header.episodeNumber == sceneStart.episodeNumber
                    && header.lineIndex > previousSceneStartLine
                    && header.lineIndex <= sceneStart.lineIndex
            }
            let boundarySourceOffset = matchingHeader?.sourceOffset
                ?? sceneStart.sourceOffset
            let boundaryLineIndex = matchingHeader?.lineIndex
                ?? sceneStart.lineIndex
            boundaries.append(
                EpisodeBoundary(
                    sourceOffset: boundarySourceOffset,
                    lineIndex: boundaryLineIndex,
                    episodeNumber: sceneStart.episodeNumber
                )
            )
            previousSceneStartLine = sceneStart.lineIndex
        }
        return boundaries
    }

    private static func episodes(
        from script: String,
        boundaries: [EpisodeBoundary]
    ) -> [DetectedScriptEpisode] {
        guard !boundaries.isEmpty else {
            return unsplitResult(script).episodes
        }

        let sourceLength = (script as NSString).length
        var detectedEpisodes: [DetectedScriptEpisode] = []
        for (offset, boundary) in boundaries.enumerated() {
            let lowerOffset = offset == 0 ? 0 : boundary.sourceOffset
            let upperOffset = offset + 1 < boundaries.count
                ? boundaries[offset + 1].sourceOffset
                : sourceLength
            guard lowerOffset <= upperOffset,
                  let sourceRange = Range(
                      NSRange(
                          location: lowerOffset,
                          length: upperOffset - lowerOffset
                      ),
                      in: script
                  )
            else {
                return unsplitResult(script).episodes
            }
            detectedEpisodes.append(
                DetectedScriptEpisode(
                    episodeNumber: boundary.episodeNumber,
                    title: standardTitle(boundary.episodeNumber),
                    scriptText: String(script[sourceRange])
                )
            )
        }
        return detectedEpisodes
    }

    private static func unsplitResult(
        _ script: String,
        episodeNumber: String? = nil,
        diagnostics: [EpisodeSplitDiagnostic] = []
    ) -> EpisodeScriptSplitResult {
        EpisodeScriptSplitResult(
            episodes: [
                DetectedScriptEpisode(
                    episodeNumber: episodeNumber,
                    title: episodeNumber.map { standardTitle($0) } ?? "",
                    scriptText: script
                )
            ],
            diagnostics: diagnostics
        )
    }

    private static func sourceLines(in script: String) -> [SourceLine] {
        let source = script as NSString
        guard source.length > 0 else { return [] }

        var lines: [SourceLine] = []
        func appendLine(_ contentRange: NSRange) -> Bool {
            guard let stringRange = Range(contentRange, in: script) else {
                return false
            }
            lines.append(
                SourceLine(
                    sourceOffset: contentRange.location,
                    lineIndex: lines.count,
                    text: String(script[stringRange])
                )
            )
            return true
        }

        var lineStart = 0
        var cursor = 0
        while cursor < source.length {
            let codeUnit = source.character(at: cursor)
            let isLineBreak: Bool
            switch codeUnit {
            case 0x000A, 0x000B, 0x000C, 0x000D, 0x0085, 0x2028, 0x2029:
                isLineBreak = true
            default:
                isLineBreak = false
            }
            guard isLineBreak else {
                cursor += 1
                continue
            }

            guard appendLine(
                NSRange(location: lineStart, length: cursor - lineStart)
            ) else {
                // Detection failure must never affect the original payload.
                return []
            }

            if codeUnit == 0x000D,
               cursor + 1 < source.length,
               source.character(at: cursor + 1) == 0x000A {
                cursor += 2
            } else {
                cursor += 1
            }
            lineStart = cursor
        }

        if lineStart < source.length,
           !appendLine(
               NSRange(location: lineStart, length: source.length - lineStart)
           ) {
            return []
        }
        return lines
    }

    private static func episodeSequenceDiagnostics(
        _ markers: [SceneMarker],
        evidence: EpisodeSplitDiagnostic.Evidence
    ) -> [EpisodeSplitDiagnostic] {
        episodeSequenceDiagnostics(
            markers.map {
                NumberedMarker(
                    lineIndex: $0.lineIndex,
                    episodeNumber: $0.episodeNumber
                )
            },
            evidence: evidence
        )
    }

    private static func episodeSequenceDiagnostics(
        _ markers: [EpisodeHeaderMarker],
        evidence: EpisodeSplitDiagnostic.Evidence
    ) -> [EpisodeSplitDiagnostic] {
        episodeSequenceDiagnostics(
            markers.map {
                NumberedMarker(
                    lineIndex: $0.lineIndex,
                    episodeNumber: $0.episodeNumber
                )
            },
            evidence: evidence
        )
    }

    private static func episodeSequenceDiagnostics(
        _ markers: [NumberedMarker],
        evidence: EpisodeSplitDiagnostic.Evidence
    ) -> [EpisodeSplitDiagnostic] {
        var diagnostics: [EpisodeSplitDiagnostic] = []
        var seenNumbers = Set<String>()
        var previousNumber: Int?

        for marker in markers {
            let evidenceName = evidence == .sceneHeading ? "场号" : "集标题"
            if seenNumbers.contains(marker.episodeNumber) {
                diagnostics.append(
                    EpisodeSplitDiagnostic(
                        kind: .duplicateEpisodeNumber,
                        evidence: evidence,
                        lineNumber: marker.lineIndex + 1,
                        episodeNumber: marker.episodeNumber,
                        message: "第 \(marker.lineIndex + 1) 行的\(evidenceName)重复出现集号 \(marker.episodeNumber)，该证据序列存在歧义。"
                    )
                )
            } else if let number = Int(marker.episodeNumber),
                      let previousNumber,
                      number < previousNumber {
                diagnostics.append(
                    EpisodeSplitDiagnostic(
                        kind: .episodeNumberRegression,
                        evidence: evidence,
                        lineNumber: marker.lineIndex + 1,
                        episodeNumber: marker.episodeNumber,
                        message: "第 \(marker.lineIndex + 1) 行的\(evidenceName)集号从 \(previousNumber) 回跳到 \(marker.episodeNumber)，该证据序列存在歧义。"
                    )
                )
            }

            seenNumbers.insert(marker.episodeNumber)
            previousNumber = Int(marker.episodeNumber) ?? previousNumber
        }
        return diagnostics
    }

    private static func detectionOnlyLine(_ line: String) -> String {
        let chapterPattern = #"(?:第\s*)?[0-9０-９零〇一二三四五六七八九十百千万两]+\s*章"#
        return line.replacingOccurrences(
            of: chapterPattern,
            with: "",
            options: .regularExpression
        )
    }

    private static func episodeNumber(fromHeaderLine line: String) -> String? {
        let candidate = detectionOnlyLine(line)
        let patterns = [chineseEpisodeHeaderPattern, englishEpisodeHeaderPattern]
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }
            let range = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
            guard let match = expression.firstMatch(in: candidate, range: range),
                  let numberRange = Range(match.range(at: 1), in: candidate)
            else {
                continue
            }
            return normalizedNumber(String(candidate[numberRange]))
        }
        return nil
    }

    private static func sceneHeading(
        from line: String,
        lineIndex: Int
    ) -> ParsedSceneHeading? {
        let candidate = cleanedSceneLine(detectionOnlyLine(line))
        guard !candidate.isEmpty else { return nil }

        if let expression = try? NSRegularExpression(
            pattern: explicitSceneHeadingPattern,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
            if let match = expression.firstMatch(in: candidate, range: range),
               let episodeRange = Range(match.range(at: 1), in: candidate),
               let sceneRange = Range(match.range(at: 2), in: candidate) {
                let episodeNumber = normalizedNumber(String(candidate[episodeRange]))
                let sceneNumber = normalizedSceneNumber(String(candidate[sceneRange]))
                let displayText = compactWhitespace(
                    String(candidate[episodeRange.lowerBound...])
                )
                return ParsedSceneHeading(
                    lineIndex: lineIndex,
                    displayText: displayText,
                    episodeNumber: episodeNumber,
                    sceneNumber: sceneNumber
                )
            }
        }

        for pattern in numberedSceneHeadingPatterns where candidate.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return ParsedSceneHeading(
                lineIndex: lineIndex,
                displayText: compactWhitespace(candidate),
                episodeNumber: nil,
                sceneNumber: nil
            )
        }
        if candidate.range(
            of: unnumberedSceneHeadingPattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return ParsedSceneHeading(
                lineIndex: lineIndex,
                displayText: compactWhitespace(candidate),
                episodeNumber: nil,
                sceneNumber: nil
            )
        }
        return nil
    }

    private static func cleanedSceneLine(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"^\s*(?:>\s*)?(?:[-+]\s+)?(?:#{1,6}\s*)?(?:\*{1,3}|_{1,3})?\s*"#,
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: #"(?:\*{1,3}|_{1,3})\s*$"#,
            with: "",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedNumber(_ value: String) -> String {
        let halfwidth = value.applyingTransform(.fullwidthToHalfwidth, reverse: false)
            ?? value
        if let number = Int(halfwidth) {
            return String(number)
        }
        if let number = chineseNumber(halfwidth) {
            return String(number)
        }
        return halfwidth
    }

    private static func normalizedSceneNumber(_ value: String) -> String {
        let halfwidth = value.applyingTransform(.fullwidthToHalfwidth, reverse: false)
            ?? value
        let digits = halfwidth.prefix(while: \.isNumber)
        let suffix = halfwidth.dropFirst(digits.count).lowercased()
        let normalizedDigits = Int(digits).map(String.init) ?? String(digits)
        return normalizedDigits + suffix
    }

    private static func chineseNumber(_ value: String) -> Int? {
        let digits: [Character: Int] = [
            "零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3,
            "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]
        let units: [Character: Int] = ["十": 10, "百": 100, "千": 1_000, "万": 10_000]
        guard value.allSatisfy({ digits[$0] != nil || units[$0] != nil }) else {
            return nil
        }

        var total = 0
        var section = 0
        var pendingDigit = 0
        for character in value {
            if let digit = digits[character] {
                pendingDigit = digit
                continue
            }
            guard let unit = units[character] else { return nil }
            if unit == 10_000 {
                section += pendingDigit
                total += max(section, 1) * unit
                section = 0
                pendingDigit = 0
            } else {
                section += max(pendingDigit, 1) * unit
                pendingDigit = 0
            }
        }
        return total + section + pendingDigit
    }

    private static func standardTitle(_ episodeNumber: String) -> String {
        "第 \(episodeNumber) 集"
    }

    private static func compactWhitespace(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension EpisodeScriptSplitter {
    struct SourceLine {
        let sourceOffset: Int
        let lineIndex: Int
        let text: String
    }

    struct EpisodeHeaderMarker {
        let sourceOffset: Int
        let lineIndex: Int
        let episodeNumber: String
    }

    struct SceneMarker {
        let sourceOffset: Int
        let lineIndex: Int
        let episodeNumber: String
        let sceneNumber: String
    }

    struct EpisodeBoundary {
        let sourceOffset: Int
        let lineIndex: Int
        let episodeNumber: String
    }

    struct NumberedMarker {
        let lineIndex: Int
        let episodeNumber: String
    }

    struct ParsedSceneHeading {
        let lineIndex: Int
        let displayText: String
        let episodeNumber: String?
        let sceneNumber: String?
    }
}
