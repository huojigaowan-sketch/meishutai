import CryptoKit
import Foundation

enum CandidateOrigin: String, Codable, Hashable, Sendable {
    case sceneHeading
    case castList
    case speakerCue
    case actionName
    case namedEntity
    case propLexicon
    case propPattern
    case modelGapScan

    var isLocallyCertain: Bool {
        self == .sceneHeading
    }
}

enum CandidateDisposition: String, Codable, Hashable, Sendable {
    case accepted
    case rejected
    case uncertain
}

struct SourceTextSpan: Codable, Hashable, Sendable {
    let utf16Location: Int
    let utf16Length: Int
    let sha256: String
    let excerpt: String

    init(utf16Location: Int, text: String, excerptLimit: Int = 240) {
        self.utf16Location = max(0, utf16Location)
        utf16Length = text.utf16.count
        sha256 = StableExtractionIdentity.sha256(text)
        excerpt = String(text.prefix(max(0, excerptLimit)))
    }

    func text(in source: String) -> String? {
        let sourceLength = source.utf16.count
        guard utf16Location >= 0,
              utf16Length >= 0,
              utf16Location <= sourceLength,
              utf16Length <= sourceLength - utf16Location,
              let range = Range(
                NSRange(location: utf16Location, length: utf16Length),
                in: source
              )
        else {
            return nil
        }
        let value = String(source[range])
        guard StableExtractionIdentity.sha256(value) == sha256 else { return nil }
        return value
    }

    func contains(utf16Offset: Int) -> Bool {
        utf16Offset >= utf16Location
            && utf16Offset < utf16Location + utf16Length
    }
}

struct ScreenplaySceneUnit: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let episodeID: UUID
    let order: Int
    let sceneIdentifier: String
    let heading: String
    let canonicalLocationName: String
    let locationGroup: String?
    let timeOfDayID: String
    let interiorExterior: String?
    let headingSpan: SourceTextSpan
    let sourceSpan: SourceTextSpan
    let isPreamble: Bool
}

struct StageOneCandidate: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let kind: AssetKind
    let rawName: String
    let normalizedName: String
    let sceneID: String
    let evidence: SourceTextSpan
    let origin: CandidateOrigin
}

struct StageOneCandidateDecision: Codable, Hashable, Sendable {
    let candidateID: String
    var disposition: CandidateDisposition
    var canonicalName: String
    var identityQualifier: String?
    var variantLabel: String?
    var reason: String
    var confidence: Double

    var boundedConfidence: Double {
        min(max(confidence, 0), 1)
    }
}

struct AssetOccurrence: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let episodeID: UUID
    let sceneID: String
    let candidateID: String
    let rawName: String
    let evidence: SourceTextSpan
    let variantLabel: String?
    let timeOfDayID: String?
}

struct ExtractionCoverageReport: Codable, Hashable, Sendable {
    let candidateCount: Int
    let decidedCount: Int
    let acceptedCount: Int
    let rejectedCount: Int
    let uncertainCount: Int
    let invalidEvidenceCount: Int

    var undecidedCount: Int {
        max(0, candidateCount - decidedCount)
    }

    var isComplete: Bool {
        candidateCount == decidedCount
            && uncertainCount == 0
            && invalidEvidenceCount == 0
    }

    var decisionRate: Double {
        guard candidateCount > 0 else { return 1 }
        return Double(decidedCount) / Double(candidateCount)
    }

    var groundingRate: Double {
        guard candidateCount > 0 else { return 1 }
        return Double(candidateCount - invalidEvidenceCount) / Double(candidateCount)
    }

    var summaryLine: String {
        "候选 \(candidateCount) · 采用 \(acceptedCount) · 排除 \(rejectedCount) · 存疑 \(uncertainCount) · 证据有效率 \(groundingRate.formatted(.percent.precision(.fractionLength(0))))"
    }
}

struct EpisodeExtractionLedger: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let episodeID: UUID
    let sourceFingerprint: String
    var scenes: [ScreenplaySceneUnit]
    var candidates: [StageOneCandidate]
    var decisions: [StageOneCandidateDecision]
    var generatedAt: Date

    init(
        schemaVersion: Int = 1,
        episodeID: UUID,
        sourceFingerprint: String,
        scenes: [ScreenplaySceneUnit],
        candidates: [StageOneCandidate],
        decisions: [StageOneCandidateDecision],
        generatedAt: Date = .now
    ) {
        self.schemaVersion = schemaVersion
        self.episodeID = episodeID
        self.sourceFingerprint = sourceFingerprint
        self.scenes = scenes
        self.candidates = candidates
        self.decisions = decisions
        self.generatedAt = generatedAt
    }

    func coverage(in source: String) -> ExtractionCoverageReport {
        let decisionsByCandidateID = Dictionary(
            decisions.map { ($0.candidateID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let validCandidateIDs = Set(candidates.map(\.id))
        let validDecisions = decisionsByCandidateID.filter {
            validCandidateIDs.contains($0.key)
        }
        let invalidEvidence = candidates.count {
            $0.evidence.text(in: source) == nil
        }
        return ExtractionCoverageReport(
            candidateCount: candidates.count,
            decidedCount: validDecisions.count,
            acceptedCount: validDecisions.values.count {
                $0.disposition == .accepted
            },
            rejectedCount: validDecisions.values.count {
                $0.disposition == .rejected
            },
            uncertainCount: validDecisions.values.count {
                $0.disposition == .uncertain
            },
            invalidEvidenceCount: invalidEvidence
        )
    }

    var unresolvedDecisions: [StageOneCandidateDecision] {
        decisions.filter { $0.disposition == .uncertain }
    }
}

struct ExtractionReviewItem: Identifiable, Hashable, Sendable {
    let id: String
    let episodeID: UUID
    let episodeTitle: String
    let candidateID: String
    let kind: AssetKind
    let rawName: String
    let proposedCanonicalName: String
    let evidence: String
    let reason: String
    let confidence: Double

    init(
        episodeID: UUID,
        episodeTitle: String,
        candidate: StageOneCandidate,
        decision: StageOneCandidateDecision
    ) {
        id = "\(episodeID.uuidString.lowercased())|\(candidate.id)"
        self.episodeID = episodeID
        self.episodeTitle = episodeTitle
        candidateID = candidate.id
        kind = candidate.kind
        rawName = candidate.rawName
        proposedCanonicalName = decision.canonicalName
        evidence = candidate.evidence.excerpt
        reason = decision.reason
        confidence = decision.boundedConfidence
    }
}

enum StableExtractionIdentity {
    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func candidateID(
        sourceFingerprint: String,
        kind: AssetKind,
        normalizedName: String,
        sceneID: String,
        utf16Location: Int,
        origin: CandidateOrigin
    ) -> String {
        "candidate-" + sha256(
            [
                "stage-one-candidate-v1",
                sourceFingerprint,
                kind.rawValue,
                normalizedName,
                sceneID,
                String(utf16Location),
                origin.rawValue
            ].joined(separator: "\u{0}")
        )
    }

    static func sceneID(
        sourceFingerprint: String,
        episodeID: UUID,
        utf16Location: Int,
        heading: String
    ) -> String {
        "scene-" + sha256(
            [
                "stage-one-scene-v1",
                sourceFingerprint,
                episodeID.uuidString.lowercased(),
                String(utf16Location),
                heading
            ].joined(separator: "\u{0}")
        )
    }
}

enum CanonicalAssetIdentity {
    static func normalizedName(_ value: String, kind: AssetKind) -> String {
        var normalized = value.precomposedStringWithCanonicalMapping.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "zh_Hans")
        )
        normalized = normalized.replacingOccurrences(
            of: #"^(?:角色|人物|场景|地点|道具)\s*[：:]\s*"#,
            with: "",
            options: .regularExpression
        )
        if kind == .scene {
            normalized = normalized.replacingOccurrences(
                of: #"(?:^|[\s/·\-—–])(?:内|外|日|夜|晨|午|晚|黄昏|清晨|凌晨|INT\.?|EXT\.?)(?=$|[\s/·\-—–])"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return normalized.unicodeScalars
            .filter {
                let value = $0.value
                let isVariationSelector = (0xFE00...0xFE0F).contains(value)
                    || (0xE0100...0xE01EF).contains(value)
                return CharacterSet.alphanumerics.contains($0) && !isVariationSelector
            }
            .map(String.init)
            .joined()
    }

    static func key(
        kind: AssetKind,
        canonicalName: String,
        identityQualifier: String? = nil
    ) -> String {
        let normalized = normalizedName(canonicalName, kind: kind)
        let qualifier = identityQualifier.map {
            normalizedName($0, kind: kind)
        } ?? ""
        return "\(kind.rawValue)|\(normalized)|\(qualifier)"
    }

    static func stableUUID(for canonicalKey: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(canonicalKey.utf8)).prefix(16))
        // RFC 9562-compatible deterministic UUID shape. The payload is a SHA-256
        // digest, so the same canonical entity keeps the same ID across reruns.
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
