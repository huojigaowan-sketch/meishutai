import Foundation

struct ScreenplayNormalizationSourcePayload: Codable, Hashable, Sendable {
    let segmentID: String
    let segmentIndex: Int
    let segmentTotal: Int
    let previousContext: String
    let nextContext: String
    let sourceUnits: [ScreenplayNormalizationSourceUnitPayload]
}

struct ScreenplayNormalizationSourceUnitPayload: Codable, Hashable, Sendable {
    let id: String
    let order: Int
    let text: String
}

struct ScreenplayNormalizationElementDraft: Codable, Hashable, Sendable {
    let kind: String
    let text: String
    let sourceUnitIDs: [String]
    let confidence: Double
}

struct ScreenplayNormalizationSegmentReceipt: Codable, Hashable, Sendable {
    let segmentID: String
    let coveredSourceUnitIDs: [String]
    let elements: [ScreenplayNormalizationElementDraft]
    let warnings: [String]
}

struct ScreenplayNormalizationSegmentPlan: Hashable, Sendable {
    let id: String
    let index: Int
    let total: Int
    let sourceUnits: [ScreenplayNormalizationSourceUnit]
    let previousContext: String
    let nextContext: String
}

enum ScreenplayNormalizationEngine {
    static let maximumSourceUnitCharacters = 1_200
    static let maximumSegmentCharacters = 8_500

    static func sourceUnits(
        in source: String,
        sourceFingerprint: String
    ) throws -> [ScreenplayNormalizationSourceUnit] {
        let sourceNSString = source as NSString
        guard sourceNSString.length > 0 else {
            throw ScreenplayNormalizationError.emptyInput
        }

        var result: [ScreenplayNormalizationSourceUnit] = []
        var lineLocation = 0
        var order = 0

        while lineLocation < sourceNSString.length {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            sourceNSString.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: lineLocation, length: 0)
            )
            let lineLength = max(0, contentsEnd - lineStart)
            let line = sourceNSString.substring(
                with: NSRange(location: lineStart, length: lineLength)
            )
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let lineNSString = line as NSString
                var localLocation = 0
                while localLocation < lineNSString.length {
                    let requestedLength = min(
                        maximumSourceUnitCharacters,
                        lineNSString.length - localLocation
                    )
                    let composed = lineNSString.rangeOfComposedCharacterSequences(
                        for: NSRange(
                            location: localLocation,
                            length: requestedLength
                        )
                    )
                    let safeRange = NSRange(
                        location: localLocation,
                        length: min(
                            max(composed.location + composed.length - localLocation, 1),
                            lineNSString.length - localLocation
                        )
                    )
                    let chunk = lineNSString.substring(with: safeRange)
                    let absoluteLocation = lineStart + safeRange.location
                    let unitID = "normalization-unit-" + StableExtractionIdentity.sha256(
                        [
                            "screenplay-normalization-unit-v1",
                            sourceFingerprint,
                            String(order),
                            String(absoluteLocation),
                            chunk,
                        ].joined(separator: "\u{0}")
                    )
                    result.append(
                        ScreenplayNormalizationSourceUnit(
                            id: unitID,
                            order: order,
                            span: SourceTextSpan(
                                utf16Location: absoluteLocation,
                                text: chunk,
                                excerptLimit: 360
                            )
                        )
                    )
                    order += 1
                    localLocation += safeRange.length
                }
            }
            guard lineEnd > lineLocation else { break }
            lineLocation = lineEnd
        }

        guard !result.isEmpty else {
            throw ScreenplayNormalizationError.emptyInput
        }
        return result
    }

    static func segmentPlans(
        sourceUnits: [ScreenplayNormalizationSourceUnit],
        source: String,
        sourceFingerprint: String
    ) throws -> [ScreenplayNormalizationSegmentPlan] {
        guard !sourceUnits.isEmpty else {
            throw ScreenplayNormalizationError.emptyInput
        }
        let unitsWithText = try sourceUnits.map { unit -> (ScreenplayNormalizationSourceUnit, String) in
            guard let text = unit.span.text(in: source) else {
                throw ScreenplayNormalizationError.invalidSourceSpan(unit.id)
            }
            return (unit, text)
        }

        var groups: [[(ScreenplayNormalizationSourceUnit, String)]] = []
        var current: [(ScreenplayNormalizationSourceUnit, String)] = []
        var currentCharacters = 0

        for pair in unitsWithText {
            let projected = currentCharacters + pair.1.count
            if !current.isEmpty, projected > maximumSegmentCharacters {
                groups.append(current)
                current = []
                currentCharacters = 0
            }
            current.append(pair)
            currentCharacters += pair.1.count
        }
        if !current.isEmpty {
            groups.append(current)
        }

        return groups.enumerated().map { index, group in
            let firstID = group.first?.0.id ?? "empty"
            let lastID = group.last?.0.id ?? firstID
            let segmentID = "normalization-segment-" + StableExtractionIdentity.sha256(
                [
                    "screenplay-normalization-segment-v1",
                    sourceFingerprint,
                    String(index),
                    firstID,
                    lastID,
                ].joined(separator: "\u{0}")
            )
            let previousContext = index > 0
                ? groups[index - 1].suffix(2).map(\.1).joined(separator: "\n")
                : ""
            let nextContext = index + 1 < groups.count
                ? groups[index + 1].prefix(2).map(\.1).joined(separator: "\n")
                : ""
            return ScreenplayNormalizationSegmentPlan(
                id: segmentID,
                index: index + 1,
                total: groups.count,
                sourceUnits: group.map(\.0),
                previousContext: String(previousContext.suffix(900)),
                nextContext: String(nextContext.prefix(900))
            )
        }
    }

    static func payload(
        for plan: ScreenplayNormalizationSegmentPlan,
        source: String
    ) throws -> ScreenplayNormalizationSourcePayload {
        let units = try plan.sourceUnits.map { unit in
            guard let text = unit.span.text(in: source) else {
                throw ScreenplayNormalizationError.invalidSourceSpan(unit.id)
            }
            return ScreenplayNormalizationSourceUnitPayload(
                id: unit.id,
                order: unit.order,
                text: text
            )
        }
        return ScreenplayNormalizationSourcePayload(
            segmentID: plan.id,
            segmentIndex: plan.index,
            segmentTotal: plan.total,
            previousContext: plan.previousContext,
            nextContext: plan.nextContext,
            sourceUnits: units
        )
    }

    static func validate(
        receipt: ScreenplayNormalizationSegmentReceipt,
        plan: ScreenplayNormalizationSegmentPlan,
        source: String
    ) throws -> ScreenplayNormalizationSegmentReceipt {
        guard receipt.segmentID == plan.id else {
            throw ScreenplayNormalizationError.invalidReceipt(
                "segmentID 不匹配。"
            )
        }
        let expectedIDs = plan.sourceUnits.map(\.id)
        let expectedSet = Set(expectedIDs)
        let coveredSet = Set(receipt.coveredSourceUnitIDs)
        guard expectedSet.count == expectedIDs.count,
              coveredSet.count == receipt.coveredSourceUnitIDs.count,
              coveredSet == expectedSet else {
            let missing = expectedSet.subtracting(coveredSet).sorted()
            let unknown = coveredSet.subtracting(expectedSet).sorted()
            throw ScreenplayNormalizationError.invalidReceipt(
                "source unit 覆盖不完整；missing=\(missing.joined(separator: ","))；unknown=\(unknown.joined(separator: ","))。"
            )
        }
        guard !receipt.elements.isEmpty else {
            throw ScreenplayNormalizationError.invalidReceipt(
                "当前分段没有返回任何 Final Draft 元素。"
            )
        }

        let unitsByID = Dictionary(
            uniqueKeysWithValues: plan.sourceUnits.map { ($0.id, $0) }
        )
        var referencedIDs = Set<String>()
        for element in receipt.elements {
            guard let kind = FinalDraftParagraphKind(rawValue: element.kind) else {
                throw ScreenplayNormalizationError.invalidReceipt(
                    "未知元素类型：\(element.kind)。"
                )
            }
            let cleanText = element.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanText.isEmpty,
                  element.confidence.isFinite,
                  (0...1).contains(element.confidence) else {
                throw ScreenplayNormalizationError.invalidReceipt(
                    "元素文本为空或置信度越界。"
                )
            }
            let sourceIDSet = Set(element.sourceUnitIDs)
            guard !sourceIDSet.isEmpty,
                  sourceIDSet.count == element.sourceUnitIDs.count,
                  sourceIDSet.isSubset(of: expectedSet) else {
                throw ScreenplayNormalizationError.invalidReceipt(
                    "元素 sourceUnitIDs 含未知或重复 ID。"
                )
            }
            referencedIDs.formUnion(sourceIDSet)

            if kind.requiresVerbatimGrounding {
                let evidence = try element.sourceUnitIDs.compactMap { id -> String? in
                    guard let unit = unitsByID[id] else { return nil }
                    return unit.span.text(in: source)
                }
                guard isGrounded(cleanText, in: evidence) else {
                    throw ScreenplayNormalizationError.ungroundedElement(cleanText)
                }
            }
        }
        guard referencedIDs == expectedSet else {
            let missing = expectedSet.subtracting(referencedIDs).sorted()
            throw ScreenplayNormalizationError.invalidReceipt(
                "有 source unit 被回执覆盖但没有进入任何元素：\(missing.joined(separator: ","))。"
            )
        }
        return receipt
    }

    static func makeRecord(
        source: String,
        sourceFingerprint: String,
        sourceUnits: [ScreenplayNormalizationSourceUnit],
        receipts: [ScreenplayNormalizationSegmentReceipt],
        mode: ScreenplayNormalizationMode,
        telemetry: ScreenplayNormalizationTelemetry
    ) throws -> ScreenplayNormalizationRecord {
        let expectedIDs = Set(sourceUnits.map(\.id))
        let coveredIDs = Set(receipts.flatMap(\.coveredSourceUnitIDs))
        guard expectedIDs == coveredIDs else {
            throw ScreenplayNormalizationError.invalidReceipt(
                "全本标准化没有完整覆盖原文 source units。"
            )
        }

        var warnings = receipts.flatMap(\.warnings)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var elements: [NormalizedScreenplayElement] = []
        for draft in receipts.flatMap(\.elements) {
            guard let kind = FinalDraftParagraphKind(rawValue: draft.kind) else {
                continue
            }
            let normalizedText = normalizedElementText(
                draft.text,
                kind: kind
            )
            guard !normalizedText.isEmpty else { continue }
            let order = elements.count
            let id = "normalized-element-" + StableExtractionIdentity.sha256(
                [
                    "normalized-screenplay-element-v1",
                    sourceFingerprint,
                    String(order),
                    kind.rawValue,
                    normalizedText,
                    draft.sourceUnitIDs.joined(separator: ","),
                ].joined(separator: "\u{0}")
            )
            elements.append(
                NormalizedScreenplayElement(
                    id: id,
                    order: order,
                    kind: kind,
                    text: normalizedText,
                    sourceUnitIDs: draft.sourceUnitIDs,
                    confidence: draft.confidence
                )
            )
        }
        guard !elements.isEmpty else {
            throw ScreenplayNormalizationError.noElements
        }

        if !elements.contains(where: { $0.kind == .sceneHeading }) {
            let firstSourceIDs = elements.first?.sourceUnitIDs
                ?? sourceUnits.prefix(1).map(\.id)
            elements.insert(
                NormalizedScreenplayElement(
                    id: "normalized-element-" + StableExtractionIdentity.sha256(
                        "synthetic-scene-heading\u{0}\(sourceFingerprint)"
                    ),
                    order: 0,
                    kind: .sceneHeading,
                    text: "INT. 未知地点 - DAY",
                    sourceUnitIDs: firstSourceIDs,
                    confidence: 0.25
                ),
                at: 0
            )
            elements = elements.enumerated().map { index, element in
                NormalizedScreenplayElement(
                    id: element.id,
                    order: index,
                    kind: element.kind,
                    text: element.text,
                    sourceUnitIDs: element.sourceUnitIDs,
                    confidence: element.confidence
                )
            }
            warnings.append(
                "原文没有形成可靠场景标题，已创建“未知地点”占位场景；提取结果应人工复核。"
            )
        }

        let rendered = renderFountain(elements)
        guard !EpisodeScriptSplitter.sceneHeadings(
            in: rendered.fountain
        ).isEmpty else {
            throw ScreenplayNormalizationError.invalidFountain
        }
        let lowConfidenceCount = rendered.elements.count {
            $0.confidence < 0.65
        }
        if lowConfidenceCount > 0 {
            warnings.append(
                "有 \(lowConfidenceCount) 个标准剧本元素的分类置信度低于 65%，已保留来源映射供复核。"
            )
        }
        warnings = deduplicated(warnings)
        let confidence = rendered.elements.isEmpty
            ? 0
            : rendered.elements.reduce(0) { $0 + $1.confidence }
                / Double(rendered.elements.count)
        let normalizedFingerprint = StableExtractionIdentity.sha256(
            rendered.fountain
        )
        let finalDraftXML = renderFinalDraftXML(rendered.elements)

        let record = ScreenplayNormalizationRecord(
            sourceFingerprint: sourceFingerprint,
            normalizedFingerprint: normalizedFingerprint,
            mode: mode,
            canonicalFountain: rendered.fountain,
            finalDraftXML: finalDraftXML,
            sourceUnits: sourceUnits,
            elements: rendered.elements,
            overallConfidence: confidence,
            warnings: warnings,
            telemetry: telemetry
        )
        try validate(record: record, source: source)
        return record
    }

    static func deterministicPassThroughRecord(
        source: String,
        sourceFingerprint: String
    ) throws -> ScreenplayNormalizationRecord? {
        guard isClearlyCanonicalFountain(source) else { return nil }
        let units = try sourceUnits(
            in: source,
            sourceFingerprint: sourceFingerprint
        )
        let unitsWithText = try units.map { unit -> (ScreenplayNormalizationSourceUnit, String) in
            guard let text = unit.span.text(in: source) else {
                throw ScreenplayNormalizationError.invalidSourceSpan(unit.id)
            }
            return (unit, text)
        }

        var elements: [ScreenplayNormalizationElementDraft] = []
        var previousKind: FinalDraftParagraphKind?
        for (unit, rawLine) in unitsWithText {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let kind: FinalDraftParagraphKind
            let text: String
            if isSceneHeading(line) {
                kind = .sceneHeading
                text = normalizedSceneHeading(line)
            } else if line.hasPrefix("@") {
                kind = .character
                text = normalizedCharacter(line)
            } else if isParenthetical(line),
                      previousKind == .character || previousKind == .parenthetical {
                kind = .parenthetical
                text = normalizedParenthetical(line)
            } else if previousKind == .character || previousKind == .parenthetical {
                kind = .dialogue
                text = line
            } else if isTransition(line) {
                kind = .transition
                text = normalizedTransition(line)
            } else if line.hasPrefix("#") {
                kind = .section
                text = line.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            } else if line.hasPrefix("=") {
                kind = .synopsis
                text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("[["), line.hasSuffix("]]"), line.count > 4 {
                kind = .note
                text = String(line.dropFirst(2).dropLast(2))
            } else {
                kind = .action
                text = line
            }
            elements.append(
                ScreenplayNormalizationElementDraft(
                    kind: kind.rawValue,
                    text: text,
                    sourceUnitIDs: [unit.id],
                    confidence: 1
                )
            )
            previousKind = kind
        }
        guard !elements.isEmpty else { return nil }
        let receipt = ScreenplayNormalizationSegmentReceipt(
            segmentID: "local-pass-through",
            coveredSourceUnitIDs: units.map(\.id),
            elements: elements,
            warnings: []
        )
        return try makeRecord(
            source: source,
            sourceFingerprint: sourceFingerprint,
            sourceUnits: units,
            receipts: [receipt],
            mode: .deterministicPassThrough,
            telemetry: ScreenplayNormalizationTelemetry(
                providerName: "本地确定性解析器",
                modelName: nil,
                plannedSegmentCount: 1,
                completedSegmentCount: 1,
                requestCount: 0,
                promptTokens: 0,
                completionTokens: 0,
                totalTokens: 0
            )
        )
    }

    static func validate(
        record: ScreenplayNormalizationRecord,
        source: String
    ) throws {
        guard record.sourceFingerprint
                == StableExtractionIdentity.sha256(source) else {
            throw ScreenplayNormalizationError.sourceFingerprintMismatch
        }
        guard record.normalizedFingerprint
                == StableExtractionIdentity.sha256(record.canonicalFountain),
              !record.canonicalFountain.isEmpty,
              !record.elements.isEmpty else {
            throw ScreenplayNormalizationError.invalidFountain
        }
        let sourceUnitIDs = Set(record.sourceUnits.map(\.id))
        guard sourceUnitIDs.count == record.sourceUnits.count else {
            throw ScreenplayNormalizationError.invalidReceipt(
                "标准化 source unit ID 重复。"
            )
        }
        for unit in record.sourceUnits {
            guard unit.span.text(in: source) != nil else {
                throw ScreenplayNormalizationError.invalidSourceSpan(unit.id)
            }
        }
        let referenced = Set(record.elements.flatMap(\.sourceUnitIDs))
        guard referenced == sourceUnitIDs else {
            throw ScreenplayNormalizationError.invalidReceipt(
                "标准化元素没有完整映射回原文。"
            )
        }
        let canonicalLength = record.canonicalFountain.utf16.count
        for element in record.elements {
            guard element.canonicalUTF16Location >= 0,
                  element.canonicalUTF16Length > 0,
                  element.canonicalUTF16Location <= canonicalLength,
                  element.canonicalUTF16Length
                    <= canonicalLength - element.canonicalUTF16Location else {
                throw ScreenplayNormalizationError.invalidFountain
            }
        }
    }

    static func isClearlyCanonicalFountain(_ source: String) -> Bool {
        let headings = EpisodeScriptSplitter.sceneHeadings(in: source)
        guard !headings.isEmpty else { return false }
        let meaningfulLines = source
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !meaningfulLines.isEmpty else { return false }
        let typedLines = meaningfulLines.count { line in
            isSceneHeading(line)
                || line.hasPrefix("@")
                || isParenthetical(line)
                || isTransition(line)
                || line.hasPrefix("#")
                || line.hasPrefix("=")
                || line.hasPrefix("[[")
        }
        return Double(typedLines) / Double(meaningfulLines.count) >= 0.12
            || meaningfulLines.contains(where: { $0.hasPrefix("@") })
    }

    private static func renderFountain(
        _ elements: [NormalizedScreenplayElement]
    ) -> (fountain: String, elements: [NormalizedScreenplayElement]) {
        var output = ""
        var renderedElements: [NormalizedScreenplayElement] = []
        var previousKind: FinalDraftParagraphKind?

        for element in elements.sorted(by: { $0.order < $1.order }) {
            let rendered = fountainText(for: element)
            guard !rendered.isEmpty else { continue }
            let inline = (element.kind == .dialogue || element.kind == .parenthetical)
                && (previousKind == .character
                    || previousKind == .parenthetical
                    || previousKind == .dialogue)
            if !output.isEmpty {
                output += inline ? "\n" : "\n\n"
            }
            let location = output.utf16.count
            output += rendered
            renderedElements.append(
                NormalizedScreenplayElement(
                    id: element.id,
                    order: renderedElements.count,
                    kind: element.kind,
                    text: element.text,
                    sourceUnitIDs: element.sourceUnitIDs,
                    confidence: element.confidence,
                    canonicalUTF16Location: location,
                    canonicalUTF16Length: rendered.utf16.count
                )
            )
            previousKind = element.kind
        }
        if !output.hasSuffix("\n") {
            output += "\n"
        }
        return (output, renderedElements)
    }

    private static func fountainText(
        for element: NormalizedScreenplayElement
    ) -> String {
        switch element.kind {
        case .sceneHeading:
            normalizedSceneHeading(element.text)
        case .action, .dialogue, .shot, .general:
            element.text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .character:
            "@" + normalizedCharacter(element.text)
        case .parenthetical:
            normalizedParenthetical(element.text)
        case .transition:
            "> " + normalizedTransition(element.text)
        case .note:
            "[[" + element.text.trimmingCharacters(in: .whitespacesAndNewlines) + "]]"
        case .section:
            "# " + element.text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .synopsis:
            "= " + element.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func renderFinalDraftXML(
        _ elements: [NormalizedScreenplayElement]
    ) -> String {
        let paragraphs = elements.sorted(by: { $0.order < $1.order }).map { element in
            let text: String
            switch element.kind {
            case .character:
                text = normalizedCharacter(element.text)
            case .parenthetical:
                text = normalizedParenthetical(element.text)
            case .transition:
                text = normalizedTransition(element.text)
            default:
                text = element.text
            }
            return "    <Paragraph Type=\"\(element.kind.finalDraftType)\"><Text>\(xmlEscaped(text))</Text></Paragraph>"
        }
        .joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <FinalDraft DocumentType="Script" Template="No" Version="1">
          <Content>
        \(paragraphs)
          </Content>
        </FinalDraft>
        """
    }

    private static func normalizedElementText(
        _ value: String,
        kind: FinalDraftParagraphKind
    ) -> String {
        let clean = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .sceneHeading:
            normalizedSceneHeading(clean)
        case .character:
            normalizedCharacter(clean)
        case .parenthetical:
            normalizedParenthetical(clean)
        case .transition:
            normalizedTransition(clean)
        default:
            clean
        }
    }

    private static func normalizedSceneHeading(_ value: String) -> String {
        var clean = value
            .replacingOccurrences(
                of: #"^\s*(?:#{1,6}\s*)?(?:场景|场|SCENE)?\s*[0-9０-９一二三四五六七八九十百零〇两]*\s*[.、:：\-—–－]?\s*"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = clean.uppercased()
        let prefix: String
        if upper.contains("INT./EXT") || upper.contains("I/E")
            || clean.contains("内外") || clean.contains("内/外") {
            prefix = "INT./EXT."
        } else if upper.contains("EXT") || clean.contains("外景")
                    || clean.range(of: #"^外(?:\s|[./／·|｜\-—–])"#, options: .regularExpression) != nil {
            prefix = "EXT."
        } else {
            prefix = "INT."
        }

        let time: String
        if clean.range(
            of: "夜|晚|午夜|凌晨|NIGHT|MIDNIGHT",
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            time = "NIGHT"
        } else if clean.range(
            of: "黄昏|傍晚|DUSK|SUNSET",
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            time = "DUSK"
        } else if clean.range(
            of: "清晨|黎明|拂晓|DAWN",
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            time = "DAWN"
        } else {
            time = "DAY"
        }

        clean = clean
            .replacingOccurrences(
                of: #"\b(?:INT\.?/EXT\.?|INT\.?|EXT\.?|I/E\.?)\b"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"(?:内景|外景|内外景|内/外|内|外)"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?:DAY|NIGHT|DAWN|DUSK|MIDNIGHT|SUNSET|日|夜|晚|白天|清晨|黎明|拂晓|黄昏|傍晚|午夜|凌晨)"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"^[\s./／·|｜\-—–－]+|[\s./／·|｜\-—–－]+$"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let location = clean.isEmpty ? "未知地点" : clean
        return "\(prefix) \(location) - \(time)"
    }

    private static func normalizedCharacter(_ value: String) -> String {
        let clean = value
            .replacingOccurrences(
                of: #"^\s*@|\s*[：:]\s*$|\s*[（(][^）)]{0,30}[）)]\s*$|\s+(?:O\.S\.|V\.O\.|OS|VO|OFF)\s*$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let containsHan = clean.unicodeScalars.contains {
            (0x4E00...0x9FFF).contains($0.value)
        }
        return containsHan ? clean : clean.uppercased()
    }

    private static func normalizedParenthetical(_ value: String) -> String {
        let clean = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "()（）"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "(" + clean + ")"
    }

    private static func normalizedTransition(_ value: String) -> String {
        var clean = value
            .replacingOccurrences(of: #"^\s*>\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasSuffix(":") && !clean.hasSuffix("：") {
            clean += ":"
        }
        let containsHan = clean.unicodeScalars.contains {
            (0x4E00...0x9FFF).contains($0.value)
        }
        return containsHan ? clean : clean.uppercased()
    }

    private static func isSceneHeading(_ value: String) -> Bool {
        value.range(
            of: #"^\s*(?:INT\.?/EXT\.?|INT\.?|EXT\.?|I/E\.?)\s+.+?(?:\s+-\s+(?:DAY|NIGHT|DAWN|DUSK|MIDNIGHT|CONTINUOUS))?\s*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func isTransition(_ value: String) -> Bool {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.hasPrefix(">")
            || clean.range(
                of: #"^(?:CUT TO|FADE IN|FADE OUT|DISSOLVE TO|MATCH CUT TO|SMASH CUT TO)\s*:?$"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
    }

    private static func isParenthetical(_ value: String) -> Bool {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return (clean.hasPrefix("(") && clean.hasSuffix(")"))
            || (clean.hasPrefix("（") && clean.hasSuffix("）"))
    }

    private static func isGrounded(
        _ text: String,
        in evidence: [String]
    ) -> Bool {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let joined = evidence.joined(separator: "\n")
        if joined.contains(cleanText) {
            return true
        }
        let textKey = semanticComparable(cleanText)
        let evidenceKey = semanticComparable(joined)
        guard !textKey.isEmpty else { return false }
        if textKey.count <= 3 {
            return evidence.contains { $0.contains(cleanText) }
        }
        return evidenceKey.contains(textKey)
            || textKey.contains(evidenceKey)
    }

    private static func semanticComparable(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "zh_Hans")
            )
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func xmlEscaped(_ value: String) -> String {
        var legal = ""
        for scalar in value.unicodeScalars {
            let code = scalar.value
            if code == 0x9 || code == 0xA || code == 0xD
                || (0x20...0xD7FF).contains(code)
                || (0xE000...0xFFFD).contains(code)
                || (0x10000...0x10FFFF).contains(code) {
                legal.unicodeScalars.append(scalar)
            }
        }
        return legal
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

enum ScreenplayNormalizationError: LocalizedError {
    case emptyInput
    case sourceFingerprintMismatch
    case invalidSourceSpan(String)
    case invalidReceipt(String)
    case ungroundedElement(String)
    case noElements
    case invalidFountain
    case unavailableWithoutAPI

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            "剧本文本为空，无法建立 Final Draft 标准稿。"
        case .sourceFingerprintMismatch:
            "标准化开始前原剧本已经变化，请重新确认后再运行。"
        case .invalidSourceSpan(let id):
            "原文映射失效（\(id)）；为避免错位，标准化已中止。"
        case .invalidReceipt(let message):
            "Final Draft 标准化回执未通过完整性校验：\(message)"
        case .ungroundedElement(let text):
            "模型返回了无法在原文中逐字核对的内容：“\(String(text.prefix(80)))”。原文未被修改。"
        case .noElements:
            "模型没有返回可用的 Final Draft 元素。"
        case .invalidFountain:
            "标准化结果不是可解析的完整 Fountain / Final Draft 剧本。"
        case .unavailableWithoutAPI:
            "当前文本还不是标准剧本格式，需要先配置大模型 API 完成 Final Draft 标准化。"
        }
    }
}
