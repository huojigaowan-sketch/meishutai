import CryptoKit
import Foundation

enum ScreenplayNormalizationMode: String, Codable, Hashable, Sendable {
    case deterministicPassThrough
    case languageModel

    var title: String {
        switch self {
        case .deterministicPassThrough:
            "原文已是标准剧本"
        case .languageModel:
            "大模型标准化"
        }
    }
}

enum FinalDraftParagraphKind: String, CaseIterable, Codable, Hashable, Sendable {
    case sceneHeading
    case action
    case character
    case parenthetical
    case dialogue
    case transition
    case shot
    case general
    case note
    case section
    case synopsis

    var finalDraftType: String {
        switch self {
        case .sceneHeading: "Scene Heading"
        case .action: "Action"
        case .character: "Character"
        case .parenthetical: "Parenthetical"
        case .dialogue: "Dialogue"
        case .transition: "Transition"
        case .shot: "Shot"
        case .general: "General"
        case .note: "General"
        case .section: "General"
        case .synopsis: "General"
        }
    }

    var requiresVerbatimGrounding: Bool {
        switch self {
        case .action, .parenthetical, .dialogue, .shot, .general, .note, .synopsis:
            true
        case .sceneHeading, .character, .transition, .section:
            false
        }
    }
}

struct ScreenplayNormalizationSourceUnit: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let order: Int
    let span: SourceTextSpan

    init(
        id: String,
        order: Int,
        span: SourceTextSpan
    ) {
        self.id = id
        self.order = order
        self.span = span
    }
}

struct NormalizedScreenplayElement: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let order: Int
    let kindRawValue: String
    let text: String
    let sourceUnitIDs: [String]
    let confidence: Double
    let canonicalUTF16Location: Int
    let canonicalUTF16Length: Int

    init(
        id: String,
        order: Int,
        kind: FinalDraftParagraphKind,
        text: String,
        sourceUnitIDs: [String],
        confidence: Double,
        canonicalUTF16Location: Int = 0,
        canonicalUTF16Length: Int = 0
    ) {
        self.id = id
        self.order = order
        kindRawValue = kind.rawValue
        self.text = text
        self.sourceUnitIDs = sourceUnitIDs
        self.confidence = min(max(confidence, 0), 1)
        self.canonicalUTF16Location = max(0, canonicalUTF16Location)
        self.canonicalUTF16Length = max(0, canonicalUTF16Length)
    }

    var kind: FinalDraftParagraphKind {
        FinalDraftParagraphKind(rawValue: kindRawValue) ?? .general
    }

    var canonicalRange: NSRange {
        NSRange(
            location: canonicalUTF16Location,
            length: canonicalUTF16Length
        )
    }
}

struct ScreenplayNormalizationTelemetry: Codable, Hashable, Sendable {
    let providerName: String
    let modelName: String?
    let plannedSegmentCount: Int
    let completedSegmentCount: Int
    let requestCount: Int
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

struct ScreenplayNormalizationRecord: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let sourceFingerprint: String
    let normalizedFingerprint: String
    let modeRawValue: String
    let canonicalFountain: String
    let finalDraftXML: String
    let sourceUnits: [ScreenplayNormalizationSourceUnit]
    let elements: [NormalizedScreenplayElement]
    let overallConfidence: Double
    let warnings: [String]
    let telemetry: ScreenplayNormalizationTelemetry
    let generatedAt: Date

    init(
        schemaVersion: Int = 1,
        sourceFingerprint: String,
        normalizedFingerprint: String,
        mode: ScreenplayNormalizationMode,
        canonicalFountain: String,
        finalDraftXML: String,
        sourceUnits: [ScreenplayNormalizationSourceUnit],
        elements: [NormalizedScreenplayElement],
        overallConfidence: Double,
        warnings: [String],
        telemetry: ScreenplayNormalizationTelemetry,
        generatedAt: Date = .now
    ) {
        self.schemaVersion = schemaVersion
        self.sourceFingerprint = sourceFingerprint
        self.normalizedFingerprint = normalizedFingerprint
        modeRawValue = mode.rawValue
        self.canonicalFountain = canonicalFountain
        self.finalDraftXML = finalDraftXML
        self.sourceUnits = sourceUnits
        self.elements = elements
        self.overallConfidence = min(max(overallConfidence, 0), 1)
        self.warnings = warnings
        self.telemetry = telemetry
        self.generatedAt = generatedAt
    }

    var mode: ScreenplayNormalizationMode {
        ScreenplayNormalizationMode(rawValue: modeRawValue) ?? .languageModel
    }

    func isFresh(for sourceFingerprint: String) -> Bool {
        self.sourceFingerprint == sourceFingerprint
            && !canonicalFountain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && normalizedFingerprint
                == StableExtractionIdentity.sha256(canonicalFountain)
    }

    func originalEvidence(
        for element: NormalizedScreenplayElement,
        in source: String
    ) -> [String] {
        let requestedIDs = Set(element.sourceUnitIDs)
        return sourceUnits
            .filter { requestedIDs.contains($0.id) }
            .sorted { $0.order < $1.order }
            .compactMap { $0.span.text(in: source) }
    }
}

extension ScriptEpisode {
    var freshScreenplayNormalization: ScreenplayNormalizationRecord? {
        guard let screenplayNormalization,
              screenplayNormalization.isFresh(for: contentFingerprint) else {
            return nil
        }
        return screenplayNormalization
    }

    var extractionSourceText: String {
        freshScreenplayNormalization?.canonicalFountain ?? scriptText
    }

    var extractionSourceFingerprint: String {
        freshScreenplayNormalization?.normalizedFingerprint ?? contentFingerprint
    }

    var screenplayNormalizationIsStale: Bool {
        guard let screenplayNormalization else { return false }
        return !screenplayNormalization.isFresh(for: contentFingerprint)
    }

    var screenplayNormalizationSummary: String? {
        guard let record = freshScreenplayNormalization else { return nil }
        let percentage = record.overallConfidence.formatted(
            .percent.precision(.fractionLength(0))
        )
        return "\(record.mode.title) · \(record.elements.count) 个 Final Draft 元素 · 置信度 \(percentage)"
    }
}
