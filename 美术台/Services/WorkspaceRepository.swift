import Foundation
import SwiftData

@Model
final class PersistedWorkspace {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var assetsData: Data
    var selectedEpisodeID: UUID?
    var schemaVersion: Int
    var updatedAt: Date
    var projectTitle: String?
    var episodeCount: Int?
    var assetCount: Int?
    var createdAt: Date?

    init(
        id: UUID = UUID(),
        assetsData: Data = Data(),
        selectedEpisodeID: UUID? = nil,
        schemaVersion: Int = 5,
        updatedAt: Date = .now,
        projectTitle: String? = nil,
        episodeCount: Int? = nil,
        assetCount: Int? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.assetsData = assetsData
        self.selectedEpisodeID = selectedEpisodeID
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.projectTitle = projectTitle
        self.episodeCount = episodeCount
        self.assetCount = assetCount
        self.createdAt = createdAt
    }
}

@Model
final class PersistedEpisode {
    @Attribute(.unique) var id: UUID
    var workspaceID: UUID
    var orderIndex: Int
    var title: String
    var scriptText: String
    var sourceFileName: String?
    var extractionStatusRaw: String
    @Attribute(.externalStorage) var warningsData: Data
    var lastError: String?
    @Attribute(.externalStorage) var extractedAssetsData: Data
    @Attribute(.externalStorage) var extractionCheckpointsData: Data?
    @Attribute(.externalStorage) var extractionLedgerData: Data?
    var lastExtractedFingerprint: String?
    var updatedAt: Date
    var extractedAt: Date?
    var analysisRouteRaw: String?
    var analysisSourceCharacterCount: Int?
    var analysisRemoteCharacterCount: Int?
    var analysisSegmentCount: Int?

    init(
        id: UUID,
        workspaceID: UUID,
        orderIndex: Int,
        title: String,
        scriptText: String,
        sourceFileName: String?,
        extractionStatusRaw: String,
        warningsData: Data,
        lastError: String?,
        extractedAssetsData: Data,
        extractionCheckpointsData: Data? = nil,
        extractionLedgerData: Data? = nil,
        lastExtractedFingerprint: String?,
        updatedAt: Date,
        extractedAt: Date?,
        analysisRouteRaw: String? = nil,
        analysisSourceCharacterCount: Int? = nil,
        analysisRemoteCharacterCount: Int? = nil,
        analysisSegmentCount: Int? = nil
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.orderIndex = orderIndex
        self.title = title
        self.scriptText = scriptText
        self.sourceFileName = sourceFileName
        self.extractionStatusRaw = extractionStatusRaw
        self.warningsData = warningsData
        self.lastError = lastError
        self.extractedAssetsData = extractedAssetsData
        self.extractionCheckpointsData = extractionCheckpointsData
        self.extractionLedgerData = extractionLedgerData
        self.lastExtractedFingerprint = lastExtractedFingerprint
        self.updatedAt = updatedAt
        self.extractedAt = extractedAt
        self.analysisRouteRaw = analysisRouteRaw
        self.analysisSourceCharacterCount = analysisSourceCharacterCount
        self.analysisRemoteCharacterCount = analysisRemoteCharacterCount
        self.analysisSegmentCount = analysisSegmentCount
    }
}

@Model
final class PersistedGeneratedImage {
    @Attribute(.unique) var id: UUID
    var workspaceID: UUID
    var assetID: UUID
    @Attribute(.externalStorage) var imageData: Data
    var promptSnapshot: String
    var styleIdentifier: String
    var generationVariantID: String?
    var generationVariantTitle: String?
    var createdAt: Date
    var isPrimary: Bool

    init(
        id: UUID = UUID(),
        workspaceID: UUID,
        assetID: UUID,
        imageData: Data,
        promptSnapshot: String,
        styleIdentifier: String,
        generationVariantID: String? = nil,
        generationVariantTitle: String? = nil,
        createdAt: Date = .now,
        isPrimary: Bool = true
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.assetID = assetID
        self.imageData = imageData
        self.promptSnapshot = promptSnapshot
        self.styleIdentifier = styleIdentifier
        self.generationVariantID = generationVariantID
        self.generationVariantTitle = generationVariantTitle
        self.createdAt = createdAt
        self.isPrimary = isPrimary
    }
}

@MainActor
final class WorkspaceRepository {
    private let container: ModelContainer
    private let context: ModelContext

    init(isStoredInMemoryOnly: Bool = false) throws {
        let schema = Schema([
            PersistedWorkspace.self,
            PersistedEpisode.self,
            PersistedGeneratedImage.self
        ])
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func listProjects() throws -> [AssetProject] {
        let workspaces = try context.fetch(FetchDescriptor<PersistedWorkspace>())

        return try workspaces
            .map { workspace in
                let resolvedEpisodeCount: Int
                if let episodeCount = workspace.episodeCount {
                    resolvedEpisodeCount = episodeCount
                } else {
                    let workspaceID = workspace.id
                    let descriptor = FetchDescriptor<PersistedEpisode>(
                        predicate: #Predicate { $0.workspaceID == workspaceID }
                    )
                    resolvedEpisodeCount = try context.fetchCount(descriptor)
                }

                let resolvedAssetCount: Int
                if let assetCount = workspace.assetCount {
                    resolvedAssetCount = assetCount
                } else {
                    resolvedAssetCount = (
                        try? decode(
                            [AssetItem].self,
                            from: workspace.assetsData,
                            defaultValue: []
                        ).count
                    ) ?? 0
                }

                return AssetProject(
                    id: workspace.id,
                    title: resolvedTitle(
                        workspace.projectTitle,
                        fallbackIndex: 1
                    ),
                    episodeCount: resolvedEpisodeCount,
                    assetCount: resolvedAssetCount,
                    createdAt: workspace.createdAt ?? workspace.updatedAt,
                    updatedAt: workspace.updatedAt
                )
            }
            .sorted {
                if $0.updatedAt == $1.updatedAt {
                    return $0.title.localizedStandardCompare($1.title)
                        == .orderedAscending
                }
                return $0.updatedAt > $1.updatedAt
            }
    }

    func createProject(title: String) throws -> AssetProject {
        let now = Date.now
        let workspace = PersistedWorkspace(
            schemaVersion: 6,
            updatedAt: now,
            projectTitle: normalizedProjectTitle(title),
            episodeCount: 0,
            assetCount: 0,
            createdAt: now
        )
        context.insert(workspace)
        try context.save()

        return AssetProject(
            id: workspace.id,
            title: workspace.projectTitle ?? "未命名项目",
            episodeCount: 0,
            assetCount: 0,
            createdAt: now,
            updatedAt: now
        )
    }

    func renameProject(id: UUID, title: String) throws {
        let workspace = try workspace(id: id)
        workspace.projectTitle = normalizedProjectTitle(title)
        workspace.updatedAt = .now
        try context.save()
    }

    func deleteProject(id: UUID) throws {
        let workspace = try workspace(id: id)
        for episode in try episodeRecords(workspaceID: id) {
            context.delete(episode)
        }
        for image in try imageRecords(workspaceID: id) {
            context.delete(image)
        }
        context.delete(workspace)
        try context.save()
    }

    func load(projectID: UUID) throws -> LoadedWorkspace {
        let workspace = try workspace(id: projectID)
        var recoveryWarnings: [String] = []
        let assets: [AssetItem]
        do {
            assets = try decode(
                [AssetItem].self,
                from: workspace.assetsData,
                defaultValue: []
            )
        } catch {
            assets = []
            recoveryWarnings.append(
                "全局资产索引无法解码，已从各分集快照重新构建。"
            )
        }

        let records = try episodeRecords(workspaceID: projectID)
            .sorted(using: KeyPathComparator(\.orderIndex))

        var episodes: [ScriptEpisode] = []
        for record in records {
            var status = EpisodeExtractionStatus(
                rawValue: record.extractionStatusRaw
            ) ?? .notExtracted
            var lastError = record.lastError
            let extractionWarnings: [String]
            do {
                extractionWarnings = try decode(
                    [String].self,
                    from: record.warningsData,
                    defaultValue: []
                )
            } catch {
                extractionWarnings = [
                    "本地提取警告记录无法解码；提取状态和剧本文本已保留。"
                ]
                recoveryWarnings.append(
                    "\(record.title) 的提取警告记录损坏；提取状态和剧本文本已保留。"
                )
            }
            let extractedAssets: [AssetItem]
            do {
                extractedAssets = try decode(
                    [AssetItem].self,
                    from: record.extractedAssetsData,
                    defaultValue: []
                )
            } catch {
                extractedAssets = []
                status = .failed
                lastError = "本地提取快照损坏；剧本文本仍完整，可重新提取本集。"
                recoveryWarnings.append(
                    "\(record.title) 的资产快照损坏；剧本文本已保留。"
                )
            }
            let extractionCheckpoints: [DeepSeekSegmentCheckpoint]
            if let data = record.extractionCheckpointsData, !data.isEmpty {
                do {
                    extractionCheckpoints = try Self.decoder.decode(
                        [DeepSeekSegmentCheckpoint].self,
                        from: data
                    )
                } catch {
                    extractionCheckpoints = []
                    recoveryWarnings.append(
                        "\(record.title) 的分段续传记录损坏，已忽略；剧本和已提取资产不受影响。"
                    )
                }
            } else {
                extractionCheckpoints = []
            }
            let extractionLedger: EpisodeExtractionLedger?
            if let data = record.extractionLedgerData, !data.isEmpty {
                do {
                    extractionLedger = try Self.decoder.decode(
                        EpisodeExtractionLedger.self,
                        from: data
                    )
                } catch {
                    extractionLedger = nil
                    recoveryWarnings.append(
                        "\(record.title) 的候选证据账本无法解码，已忽略；可重新提取本集重建。"
                    )
                }
            } else {
                extractionLedger = nil
            }

            episodes.append(
                ScriptEpisode(
                    id: record.id,
                    order: record.orderIndex,
                    title: record.title,
                    scriptText: record.scriptText,
                    sourceFileName: record.sourceFileName,
                    extractionStatus: status,
                    extractionWarnings: extractionWarnings,
                    lastError: lastError,
                    extractedAssets: extractedAssets,
                    extractionCheckpoints: extractionCheckpoints,
                    extractionLedger: extractionLedger,
                    lastExtractedFingerprint: record.lastExtractedFingerprint,
                    updatedAt: record.updatedAt,
                    extractedAt: record.extractedAt,
                    analysisMetrics: Self.analysisMetrics(from: record)
                )
            )
        }

        let generatedImages = try imageRecords(workspaceID: projectID)
            .map(Self.generatedImage)
            .sorted { $0.createdAt > $1.createdAt }

        return LoadedWorkspace(
            episodes: episodes,
            assets: assets,
            generatedImages: generatedImages,
            selectedEpisodeID: workspace.selectedEpisodeID,
            recoveryWarnings: recoveryWarnings
        )
    }

    func saveWorkspace(
        projectID: UUID,
        assets: [AssetItem],
        selectedEpisodeID: UUID?
    ) throws {
        let workspace = try workspace(id: projectID)
        workspace.assetsData = try Self.encoder.encode(assets)
        workspace.selectedEpisodeID = selectedEpisodeID
        workspace.assetCount = assets.count
        workspace.schemaVersion = 6
        workspace.updatedAt = .now
        try context.save()
    }

    func saveEpisode(
        projectID: UUID,
        episode: ScriptEpisode
    ) throws {
        let workspace = try workspace(id: projectID)
        let record = try episodeRecord(
            id: episode.id,
            workspaceID: projectID
        )
        try update(record, from: episode)
        workspace.updatedAt = .now
        try context.save()
    }

    func saveAnalysisCheckpoint(
        projectID: UUID,
        episode: ScriptEpisode,
        assets: [AssetItem],
        selectedEpisodeID: UUID?
    ) throws {
        let workspace = try workspace(id: projectID)
        let record = try episodeRecord(
            id: episode.id,
            workspaceID: projectID
        )
        try update(record, from: episode)
        workspace.assetsData = try Self.encoder.encode(assets)
        workspace.selectedEpisodeID = selectedEpisodeID
        workspace.assetCount = assets.count
        workspace.schemaVersion = 6
        workspace.updatedAt = .now
        try context.save()
    }

    func saveAll(
        projectID: UUID,
        episodes: [ScriptEpisode],
        assets: [AssetItem],
        selectedEpisodeID: UUID?
    ) throws {
        let workspace = try workspace(id: projectID)
        let existing = try episodeRecords(workspaceID: projectID)
        let validIDs = Set(episodes.map(\.id))

        for record in existing where !validIDs.contains(record.id) {
            context.delete(record)
        }

        for episode in episodes {
            let record: PersistedEpisode
            if let existingRecord = existing.first(where: { $0.id == episode.id }) {
                record = existingRecord
            } else {
                record = try makeEpisodeRecord(
                    from: episode,
                    workspaceID: projectID
                )
            }
            try update(record, from: episode)
        }

        workspace.assetsData = try Self.encoder.encode(assets)
        workspace.selectedEpisodeID = selectedEpisodeID
        workspace.episodeCount = episodes.count
        workspace.assetCount = assets.count
        workspace.schemaVersion = 6
        workspace.updatedAt = .now
        if workspace.projectTitle == nil {
            workspace.projectTitle = "我的资产项目"
        }
        if workspace.createdAt == nil {
            workspace.createdAt = workspace.updatedAt
        }
        try context.save()
    }

    func deleteGeneratedImages(
        assetID: UUID,
        projectID: UUID
    ) throws {
        for record in try imageRecords(workspaceID: projectID)
            where record.assetID == assetID {
            context.delete(record)
        }
        try context.save()
    }

    private func workspace(id: UUID) throws -> PersistedWorkspace {
        var descriptor = FetchDescriptor<PersistedWorkspace>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let workspace = try context.fetch(descriptor).first else {
            throw WorkspaceRepositoryError.projectNotFound
        }
        return workspace
    }

    private func episodeRecord(
        id: UUID,
        workspaceID: UUID
    ) throws -> PersistedEpisode {
        if let existing = try episodeRecords(workspaceID: workspaceID)
            .first(where: { $0.id == id }) {
            return existing
        }

        let placeholder = PersistedEpisode(
            id: id,
            workspaceID: workspaceID,
            orderIndex: 0,
            title: "",
            scriptText: "",
            sourceFileName: nil,
            extractionStatusRaw: EpisodeExtractionStatus.notExtracted.rawValue,
            warningsData: Data(),
            lastError: nil,
            extractedAssetsData: Data(),
            extractionCheckpointsData: nil,
            extractionLedgerData: nil,
            lastExtractedFingerprint: nil,
            updatedAt: .now,
            extractedAt: nil
        )
        context.insert(placeholder)
        return placeholder
    }

    private func episodeRecords(
        workspaceID: UUID
    ) throws -> [PersistedEpisode] {
        let descriptor = FetchDescriptor<PersistedEpisode>(
            predicate: #Predicate { $0.workspaceID == workspaceID }
        )
        return try context.fetch(descriptor)
    }

    private func imageRecords(
        workspaceID: UUID
    ) throws -> [PersistedGeneratedImage] {
        let descriptor = FetchDescriptor<PersistedGeneratedImage>(
            predicate: #Predicate { $0.workspaceID == workspaceID }
        )
        return try context.fetch(descriptor)
    }

    private func makeEpisodeRecord(
        from episode: ScriptEpisode,
        workspaceID: UUID
    ) throws -> PersistedEpisode {
        let record = PersistedEpisode(
            id: episode.id,
            workspaceID: workspaceID,
            orderIndex: episode.order,
            title: episode.title,
            scriptText: episode.scriptText,
            sourceFileName: episode.sourceFileName,
            extractionStatusRaw: episode.extractionStatus.rawValue,
            warningsData: Data(),
            lastError: episode.lastError,
            extractedAssetsData: Data(),
            extractionCheckpointsData: try Self.encoder.encode(
                episode.extractionCheckpoints
            ),
            extractionLedgerData: try episode.extractionLedger.map {
                try Self.encoder.encode($0)
            },
            lastExtractedFingerprint: episode.lastExtractedFingerprint,
            updatedAt: episode.updatedAt,
            extractedAt: episode.extractedAt,
            analysisRouteRaw: episode.analysisMetrics?.route.rawValue,
            analysisSourceCharacterCount: episode.analysisMetrics?.sourceCharacterCount,
            analysisRemoteCharacterCount: episode.analysisMetrics?.remoteCharacterCount,
            analysisSegmentCount: episode.analysisMetrics?.segmentCount
        )
        context.insert(record)
        return record
    }

    private func update(
        _ record: PersistedEpisode,
        from episode: ScriptEpisode
    ) throws {
        record.orderIndex = episode.order
        record.title = episode.title
        record.scriptText = episode.scriptText
        record.sourceFileName = episode.sourceFileName
        record.extractionStatusRaw = episode.extractionStatus.rawValue
        record.warningsData = try Self.encoder.encode(
            episode.extractionWarnings
        )
        record.lastError = episode.lastError
        record.extractedAssetsData = try Self.encoder.encode(
            episode.extractedAssets
        )
        record.extractionCheckpointsData = try Self.encoder.encode(
            episode.extractionCheckpoints
        )
        record.extractionLedgerData = try episode.extractionLedger.map {
            try Self.encoder.encode($0)
        }
        record.lastExtractedFingerprint = episode.lastExtractedFingerprint
        record.updatedAt = episode.updatedAt
        record.extractedAt = episode.extractedAt
        record.analysisRouteRaw = episode.analysisMetrics?.route.rawValue
        record.analysisSourceCharacterCount = episode.analysisMetrics?.sourceCharacterCount
        record.analysisRemoteCharacterCount = episode.analysisMetrics?.remoteCharacterCount
        record.analysisSegmentCount = episode.analysisMetrics?.segmentCount
    }

    private static func generatedImage(
        _ record: PersistedGeneratedImage
    ) -> GeneratedAssetImage {
        GeneratedAssetImage(
            id: record.id,
            workspaceID: record.workspaceID,
            assetID: record.assetID,
            imageData: record.imageData,
            promptSnapshot: record.promptSnapshot,
            styleIdentifier: record.styleIdentifier,
            generationVariantID: record.generationVariantID,
            generationVariantTitle: record.generationVariantTitle,
            createdAt: record.createdAt,
            isPrimary: record.isPrimary
        )
    }

    private static func analysisMetrics(
        from record: PersistedEpisode
    ) -> AnalysisMetrics? {
        guard let routeRaw = record.analysisRouteRaw,
              let route = AnalysisRoute(rawValue: routeRaw),
              let sourceCharacterCount = record.analysisSourceCharacterCount,
              let remoteCharacterCount = record.analysisRemoteCharacterCount
        else {
            return nil
        }
        return AnalysisMetrics(
            route: route,
            sourceCharacterCount: sourceCharacterCount,
            remoteCharacterCount: remoteCharacterCount,
            segmentCount: record.analysisSegmentCount
        )
    }

    private func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        defaultValue: T
    ) throws -> T {
        guard !data.isEmpty else {
            return defaultValue
        }
        return try Self.decoder.decode(type, from: data)
    }

    private func normalizedProjectTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名项目" : trimmed
    }

    private func resolvedTitle(
        _ title: String?,
        fallbackIndex: Int
    ) -> String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "我的资产项目 \(fallbackIndex)" : trimmed
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum WorkspaceRepositoryError: LocalizedError {
    case projectNotFound
    case imageNotFound

    var errorDescription: String? {
        switch self {
        case .projectNotFound:
            "找不到这个项目，它可能已被删除。"
        case .imageNotFound:
            "找不到这张生成图，它可能已经被删除。"
        }
    }
}
