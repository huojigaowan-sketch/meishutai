import CryptoKit
import Foundation

enum EpisodeExtractionStatus: String, Codable, Hashable, Sendable {
    case notExtracted
    case extracting
    case completed
    case completedWithWarnings
    case failed
    case stale

    var title: String {
        switch self {
        case .notExtracted: "未提取"
        case .extracting: "正在提取"
        case .completed: "已完成"
        case .completedWithWarnings: "已完成（需复核）"
        case .failed: "提取失败"
        case .stale: "剧本已修改"
        }
    }

    var systemImage: String {
        switch self {
        case .notExtracted: "circle"
        case .extracting: "arrow.trianglehead.2.clockwise.rotate.90"
        case .completed: "checkmark.circle.fill"
        case .completedWithWarnings: "exclamationmark.triangle.fill"
        case .failed: "xmark.circle.fill"
        case .stale: "pencil.circle.fill"
        }
    }
}

enum EpisodeAnalysisStage: Equatable, Sendable {
    case preparing
    case extractingSegment(current: Int, total: Int)
    case auditingSegment(current: Int, total: Int)
    case repairingSegment(current: Int, total: Int, round: Int, totalRounds: Int)
    case organizing(segmentCount: Int)
    case saving
}

struct EpisodeAnalysisRetry: Equatable, Sendable {
    let attempt: Int
    let maximumAttempts: Int
    let delay: TimeInterval?

    init(
        attempt: Int,
        maximumAttempts: Int,
        delay: TimeInterval?
    ) {
        self.attempt = attempt
        self.maximumAttempts = maximumAttempts
        self.delay = delay
    }
}

struct EpisodeAnalysisProgress: Equatable, Sendable {
    let stage: EpisodeAnalysisStage
    let retry: EpisodeAnalysisRetry?

    init(
        stage: EpisodeAnalysisStage,
        retry: EpisodeAnalysisRetry? = nil
    ) {
        self.stage = stage
        self.retry = retry
    }
}

struct ScriptEpisode: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var order: Int
    var title: String
    var scriptText: String
    var sourceFileName: String?
    var extractionStatus: EpisodeExtractionStatus
    var extractionWarnings: [String]
    var lastError: String?
    var extractedAssets: [AssetItem]
    /// Durable, source-fingerprint-bound DeepSeek segment results. A failed or
    /// interrupted episode resumes only the missing segments on the next run.
    var extractionCheckpoints: [DeepSeekSegmentCheckpoint]
    /// Source-bound local candidate ledger and model dispositions for audit,
    /// deterministic coverage checks, and focused human review.
    var extractionLedger: EpisodeExtractionLedger?
    var lastExtractedFingerprint: String?
    var updatedAt: Date
    var extractedAt: Date?
    var analysisMetrics: AnalysisMetrics?

    init(
        id: UUID = UUID(),
        order: Int,
        title: String,
        scriptText: String = "",
        sourceFileName: String? = nil,
        extractionStatus: EpisodeExtractionStatus = .notExtracted,
        extractionWarnings: [String] = [],
        lastError: String? = nil,
        extractedAssets: [AssetItem] = [],
        extractionCheckpoints: [DeepSeekSegmentCheckpoint] = [],
        extractionLedger: EpisodeExtractionLedger? = nil,
        lastExtractedFingerprint: String? = nil,
        updatedAt: Date = .now,
        extractedAt: Date? = nil,
        analysisMetrics: AnalysisMetrics? = nil
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.scriptText = scriptText
        self.sourceFileName = sourceFileName
        self.extractionStatus = extractionStatus
        self.extractionWarnings = extractionWarnings
        self.lastError = lastError
        self.extractedAssets = extractedAssets
        self.extractionCheckpoints = extractionCheckpoints
        self.extractionLedger = extractionLedger
        self.lastExtractedFingerprint = lastExtractedFingerprint
        self.updatedAt = updatedAt
        self.extractedAt = extractedAt
        self.analysisMetrics = analysisMetrics
    }

    nonisolated var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "第 \(order) 集" : trimmed
    }

    nonisolated var contentFingerprint: String {
        let digest = SHA256.hash(data: Data(scriptText.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated var effectiveStatus: EpisodeExtractionStatus {
        switch extractionStatus {
        case .completed:
            if let lastExtractedFingerprint,
               lastExtractedFingerprint != contentFingerprint {
                return .stale
            }
            return .completed
        case .completedWithWarnings:
            if let lastExtractedFingerprint,
               lastExtractedFingerprint != contentFingerprint {
                return .stale
            }
            return .completedWithWarnings
        default:
            return extractionStatus
        }
    }
}

/// A deterministic overview of one completed extraction. It is rebuilt from
/// the persisted per-episode asset snapshot, so it cannot drift from the
/// extracted scenes, characters, and props and needs no redundant database blob.
struct EpisodeExtractionOverview: Identifiable, Hashable, Sendable {
    let episodeID: UUID
    let order: Int
    let title: String
    let sourceFingerprint: String
    let generatedAt: Date
    let sceneSummaries: [String]
    let characterSummaries: [String]
    let propSummaries: [String]

    var id: UUID { episodeID }

    var assetCount: Int {
        sceneSummaries.count + characterSummaries.count + propSummaries.count
    }

    var summaryLine: String {
        "\(sceneSummaries.count) 个场景 · \(characterSummaries.count) 个人物 · \(propSummaries.count) 个道具"
    }

    nonisolated static func make(
        from episode: ScriptEpisode
    ) -> EpisodeExtractionOverview? {
        guard episode.lastExtractedFingerprint == episode.contentFingerprint,
              episode.effectiveStatus == .completed
                || episode.effectiveStatus == .completedWithWarnings
        else {
            return nil
        }

        func summaries(for kind: AssetKind) -> [String] {
            episode.extractedAssets
                .filter { $0.kind == kind && $0.reviewState != .ignored }
                .prefix(24)
                .map { asset in
                    let summary = asset.summary
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return summary.isEmpty
                        ? asset.name
                        : "\(asset.name)：\(summary)"
                }
        }

        return EpisodeExtractionOverview(
            episodeID: episode.id,
            order: episode.order,
            title: episode.displayTitle,
            sourceFingerprint: episode.contentFingerprint,
            generatedAt: episode.extractedAt ?? episode.updatedAt,
            sceneSummaries: summaries(for: .scene),
            characterSummaries: summaries(for: .character),
            propSummaries: summaries(for: .prop)
        )
    }
}

struct ProjectExtractionOverview: Hashable, Sendable {
    let generatedAt: Date
    let episodes: [EpisodeExtractionOverview]

    var episodeCount: Int { episodes.count }
    var sceneCount: Int { episodes.reduce(0) { $0 + $1.sceneSummaries.count } }
    var characterCount: Int {
        episodes.reduce(0) { $0 + $1.characterSummaries.count }
    }
    var propCount: Int { episodes.reduce(0) { $0 + $1.propSummaries.count } }

    var summaryLine: String {
        "\(episodeCount) 集 · \(sceneCount) 个场景 · \(characterCount) 个人物 · \(propCount) 个道具"
    }

    nonisolated static func make(
        from episodes: [ScriptEpisode]
    ) -> ProjectExtractionOverview? {
        let overviews = episodes
            .compactMap(EpisodeExtractionOverview.make)
            .sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.episodeID.uuidString < rhs.episodeID.uuidString
            }
        guard !overviews.isEmpty else { return nil }
        return ProjectExtractionOverview(
            generatedAt: overviews.map(\.generatedAt).max() ?? .now,
            episodes: overviews
        )
    }
}

struct EpisodeSceneHeading: Identifiable, Hashable, Sendable {
    let lineNumber: Int
    let text: String
    let episodeNumber: String?
    let sceneNumber: String?

    var id: Int { lineNumber }

    var sceneIdentifier: String? {
        guard let episodeNumber, let sceneNumber else { return nil }
        return "\(episodeNumber)-\(sceneNumber.lowercased())"
    }
}

struct EpisodeAnalysisPreview: Identifiable, Hashable, Sendable {
    let episodeID: UUID
    let order: Int
    let title: String
    let sceneHeadings: [EpisodeSceneHeading]
    let contentFingerprint: String
    let splitDiagnostics: [EpisodeSplitDiagnostic]

    init(
        episodeID: UUID,
        order: Int,
        title: String,
        sceneHeadings: [EpisodeSceneHeading],
        contentFingerprint: String,
        splitDiagnostics: [EpisodeSplitDiagnostic] = []
    ) {
        self.episodeID = episodeID
        self.order = order
        self.title = title
        self.sceneHeadings = sceneHeadings
        self.contentFingerprint = contentFingerprint
        self.splitDiagnostics = splitDiagnostics
    }

    var id: UUID { episodeID }
}

struct EpisodeAnalysisReview: Identifiable, Hashable, Sendable {
    let id: UUID
    let episodes: [EpisodeAnalysisPreview]
    let blockingIssues: [String]

    init(
        id: UUID = UUID(),
        episodes: [EpisodeAnalysisPreview],
        blockingIssues: [String] = []
    ) {
        self.id = id
        self.episodes = episodes
        self.blockingIssues = blockingIssues
    }

    var hasMissingSceneHeadings: Bool {
        episodes.contains { $0.sceneHeadings.isEmpty }
    }

    var canAnalyze: Bool {
        !hasMissingSceneHeadings && blockingIssues.isEmpty
    }
}

enum EpisodeAnalysisIntegrityValidator {
    static func blockingIssues(
        in previews: [EpisodeAnalysisPreview]
    ) -> [String] {
        guard previews.count > 1 else { return [] }

        var issues: [String] = []
        var episodeOwners: [String: (id: UUID, title: String)] = [:]
        var sceneOwners: [String: (id: UUID, title: String)] = [:]

        for preview in previews {
            issues.append(contentsOf: preview.splitDiagnostics.map(\.message))
            let explicitEpisodeNumbers = Set(
                preview.sceneHeadings.compactMap(\.episodeNumber)
            )
            if explicitEpisodeNumbers.isEmpty, !preview.sceneHeadings.isEmpty {
                issues.append("\(preview.title) 的场景标题缺少“集号-场号”，无法验证分集边界。")
            } else if explicitEpisodeNumbers.count > 1 {
                let numbers = explicitEpisodeNumbers.sorted().joined(separator: "、")
                issues.append("\(preview.title) 混入多个集号（\(numbers)），请重新整理分集。")
            } else if let episodeNumber = explicitEpisodeNumbers.first {
                if let existingOwner = episodeOwners[episodeNumber],
                   existingOwner.id != preview.episodeID {
                    issues.append("集号 \(episodeNumber) 同时出现在“\(existingOwner.title)”和“\(preview.title)”。")
                } else {
                    episodeOwners[episodeNumber] = (preview.episodeID, preview.title)
                }
            }

            for heading in preview.sceneHeadings {
                guard let identifier = heading.sceneIdentifier else { continue }
                if let existingOwner = sceneOwners[identifier],
                   existingOwner.id != preview.episodeID {
                    issues.append("场号 \(identifier) 同时出现在“\(existingOwner.title)”和“\(preview.title)”。")
                } else {
                    sceneOwners[identifier] = (preview.episodeID, preview.title)
                }
            }
        }

        var seen = Set<String>()
        return issues.filter { seen.insert($0).inserted }
    }
}

struct AssetProject: Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var episodeCount: Int
    var assetCount: Int
    var createdAt: Date
    var updatedAt: Date
}

struct LoadedWorkspace {
    var episodes: [ScriptEpisode]
    var assets: [AssetItem]
    var generatedImages: [GeneratedAssetImage]
    var selectedEpisodeID: UUID?
    var recoveryWarnings: [String] = []
}
