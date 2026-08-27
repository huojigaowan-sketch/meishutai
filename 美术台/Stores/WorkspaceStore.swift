import Foundation
import Observation

/// Stage-one identity must depend only on the entity, never on generated
/// descriptions, prompts, weather, time or other occurrence-specific fields.
enum AssetMergeIdentity {
    private static let locale = Locale(identifier: "en_US_POSIX")

    static func key(for asset: AssetItem) -> String {
        if let canonicalKey = asset.canonicalKey?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !canonicalKey.isEmpty {
            return canonicalKey
        }
        return CanonicalAssetIdentity.key(
            kind: asset.kind,
            canonicalName: asset.name
        )
    }

    static func compositeKey(_ components: [String?]) -> String {
        components.map { component in
            guard let component else { return "n;" }
            let normalized = normalizedKey(component)
            return "v\(normalized.utf8.count):\(normalized);"
        }
        .joined()
    }

    static func normalizedKey(_ value: String) -> String {
        let folded = value.precomposedStringWithCanonicalMapping.folding(
            options: [.caseInsensitive],
            locale: locale
        )
        return folded
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

@MainActor
@Observable
final class WorkspaceStore {
    var selectedSection: WorkspaceSection = .script {
        didSet { rebuildAssetLibraryContent() }
    }
    var selectedAssetID: AssetItem.ID?
    var searchText = "" {
        didSet { rebuildAssetLibraryContent() }
    }
    var projects: [AssetProject] = []
    var selectedProjectID: UUID?
    var episodes: [ScriptEpisode] = []
    var selectedEpisodeID: UUID?
    var assets: [AssetItem] = [] {
        didSet { rebuildAssetLibraryContent() }
    }
    var generatedImages: [GeneratedAssetImage] = []
    private(set) var filteredAssets: [AssetItem] = []
    private(set) var assetLibraryItems: [AssetLibraryItem] = []
    private(set) var assetLibraryFolders: [AssetLibraryFolder] = []
    var seriesDesignBlueprint: SeriesDesignBlueprint?
    var isAnalyzing = false
    var currentAnalyzingEpisodeID: UUID?
    var analysisCompletedEpisodeCount = 0
    var analysisTotalEpisodeCount = 0
    private(set) var analysisCurrentEpisodeIndex = 0
    private(set) var currentAnalyzingEpisodeTitle: String?
    private(set) var analysisProgress: EpisodeAnalysisProgress?
    private(set) var analysisStartedAt: Date?
    private(set) var isCancellingAnalysis = false
    private(set) var analysisProviderName: String?
    var analysisNotice: String?
    var designingAssetID: UUID?
    var designNotice: String?
    var designNoticeAssetID: UUID?
    var storageNotice: String?
    var errorMessage: String?

    @ObservationIgnored private var repository: WorkspaceRepository?
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private let legacySnapshotURL: URL
    @ObservationIgnored private let selectedProjectDefaultsKey =
        "assetdesk.selectedProjectID"

    init(
        repository injectedRepository: WorkspaceRepository? = nil,
        legacySnapshotURL injectedLegacySnapshotURL: URL? = nil
    ) {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let defaultLegacySnapshotURL = applicationSupport
            .appendingPathComponent("AssetDesk", isDirectory: true)
            .appendingPathComponent("workspace.json")
        legacySnapshotURL = injectedLegacySnapshotURL ?? defaultLegacySnapshotURL

        do {
            let repository: WorkspaceRepository
            if let injectedRepository {
                repository = injectedRepository
            } else {
                repository = try WorkspaceRepository()
            }
            self.repository = repository

            var availableProjects = try repository.listProjects()
            let shouldMigrateLegacyWorkspace = availableProjects.isEmpty
            if availableProjects.isEmpty {
                let project = try repository.createProject(title: "我的资产项目")
                availableProjects = [project]
            }
            projects = availableProjects

            let storedProjectID = UserDefaults.standard
                .string(forKey: selectedProjectDefaultsKey)
                .flatMap(UUID.init(uuidString:))
            let initialProjectID = projects.contains(where: { $0.id == storedProjectID })
                ? storedProjectID
                : projects.first?.id

            guard let initialProjectID else {
                throw WorkspaceRepositoryError.projectNotFound
            }
            selectedProjectID = initialProjectID
            try loadProject(
                id: initialProjectID,
                migrateLegacyWorkspace: shouldMigrateLegacyWorkspace
            )
            try refreshProjects()
        } catch {
            let fallbackProject = AssetProject(
                id: UUID(),
                title: "未保存的项目",
                episodeCount: 1,
                assetCount: 0,
                createdAt: .now,
                updatedAt: .now
            )
            projects = [fallbackProject]
            selectedProjectID = fallbackProject.id
            episodes = [Self.emptyEpisode(order: 1)]
            selectedEpisodeID = episodes.first?.id
            storageNotice = "SwiftData 项目库无法载入，本次仍可编辑，但数据可能无法持久保存：\(error.localizedDescription)"
        }

        rebuildAssetLibraryContent()
    }

    var currentProject: AssetProject? {
        guard let selectedProjectID else { return projects.first }
        return projects.first(where: { $0.id == selectedProjectID })
            ?? projects.first
    }

    var currentEpisode: ScriptEpisode? {
        guard let selectedEpisodeID else { return episodes.first }
        return episodes.first(where: { $0.id == selectedEpisodeID }) ?? episodes.first
    }

    var currentExtractionReviewItems: [ExtractionReviewItem] {
        guard let currentEpisode else { return [] }
        return extractionReviewItems(for: currentEpisode)
    }

    var currentExtractionCoverage: ExtractionCoverageReport? {
        guard let currentEpisode,
              let ledger = currentEpisode.extractionLedger,
              ledger.sourceFingerprint == currentEpisode.contentFingerprint else {
            return nil
        }
        return ledger.coverage(in: currentEpisode.scriptText)
    }

    var projectExtractionReviewItems: [ExtractionReviewItem] {
        episodes.sorted(using: KeyPathComparator(\.order)).flatMap {
            extractionReviewItems(for: $0)
        }
    }

    private func extractionReviewItems(
        for episode: ScriptEpisode
    ) -> [ExtractionReviewItem] {
        guard let ledger = episode.extractionLedger else { return [] }
        let decisions = Dictionary(
            ledger.decisions.map { ($0.candidateID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return ledger.candidates.compactMap { candidate in
            guard let decision = decisions[candidate.id],
                  decision.disposition == .uncertain else {
                return nil
            }
            return ExtractionReviewItem(
                episodeID: episode.id,
                episodeTitle: episode.displayTitle,
                candidate: candidate,
                decision: decision
            )
        }
        .sorted {
            if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
            if $0.rawName != $1.rawName { return $0.rawName < $1.rawName }
            return $0.candidateID < $1.candidateID
        }
    }

    func resolveExtractionCandidate(
        episodeID: UUID,
        candidateID: String,
        disposition: CandidateDisposition,
        canonicalName: String
    ) {
        guard disposition != .uncertain,
              let episodeIndex = episodes.firstIndex(where: { $0.id == episodeID }),
              var ledger = episodes[episodeIndex].extractionLedger,
              let decisionIndex = ledger.decisions.firstIndex(
                where: { $0.candidateID == candidateID }
              ),
              let candidate = ledger.candidates.first(where: { $0.id == candidateID })
        else {
            return
        }

        let resolvedName = canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard disposition == .rejected || !resolvedName.isEmpty else { return }
        ledger.decisions[decisionIndex].disposition = disposition
        ledger.decisions[decisionIndex].canonicalName = disposition == .accepted
            ? resolvedName
            : candidate.rawName
        ledger.decisions[decisionIndex].reason = disposition == .accepted
            ? "人工复核确认"
            : "人工复核排除"
        ledger.decisions[decisionIndex].confidence = 1
        ledger.generatedAt = .now

        episodes[episodeIndex].extractionLedger = ledger
        rebuildEpisodeAssets(at: episodeIndex, from: ledger)
        let coverage = ledger.coverage(in: episodes[episodeIndex].scriptText)
        var warnings = episodes[episodeIndex].extractionWarnings.filter {
            !$0.contains("人工复核")
                && !$0.contains("语义歧义")
                && !$0.contains("候选需要")
        }
        if coverage.uncertainCount > 0 {
            warnings.append("仍有 \(coverage.uncertainCount) 项候选需要人工复核。")
        }
        episodes[episodeIndex].extractionWarnings = warnings
        episodes[episodeIndex].extractionStatus = warnings.isEmpty
            ? .completed
            : .completedWithWarnings
        episodes[episodeIndex].updatedAt = .now
        rebuildGlobalAssets()
        persistAll()
        let remaining = projectExtractionReviewItems.count
        analysisNotice = remaining == 0
            ? "项目中的存疑候选已全部复核，正式资产库已同步更新。"
            : "复核决定已保存；项目仍有 \(remaining) 项候选等待确认。"
    }

    func mergeExtractionCandidates(
        _ items: [ExtractionReviewItem],
        canonicalName: String
    ) {
        let resolvedName = canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard items.count >= 2, !resolvedName.isEmpty else { return }
        let grouped = Dictionary(grouping: items, by: \.episodeID)

        for (episodeID, episodeItems) in grouped {
            guard let episodeIndex = episodes.firstIndex(where: { $0.id == episodeID }),
                  var ledger = episodes[episodeIndex].extractionLedger else {
                continue
            }
            let candidateIDs = Set(episodeItems.map(\.candidateID))
            for decisionIndex in ledger.decisions.indices
                where candidateIDs.contains(ledger.decisions[decisionIndex].candidateID) {
                ledger.decisions[decisionIndex].disposition = .accepted
                ledger.decisions[decisionIndex].canonicalName = resolvedName
                ledger.decisions[decisionIndex].reason = "人工复核合并为同一规范资产"
                ledger.decisions[decisionIndex].confidence = 1
            }
            ledger.generatedAt = .now
            episodes[episodeIndex].extractionLedger = ledger
            rebuildEpisodeAssets(at: episodeIndex, from: ledger)
            episodes[episodeIndex].updatedAt = .now
        }

        rebuildGlobalAssets()
        persistAll()
        analysisNotice = "已将 \(items.count) 项候选合并为“\(resolvedName)”，来源证据全部保留。"
    }

    var projectExtractionOverview: ProjectExtractionOverview? {
        ProjectExtractionOverview.make(from: episodes)
    }

    var isAIJobRunning: Bool {
        isAnalyzing
    }

    @discardableResult
    func addProject() -> UUID? {
        guard !isAnalyzing, let repository else { return nil }

        do {
            try saveCurrentProjectSnapshot()
            let title = nextProjectTitle()
            let project = try repository.createProject(title: title)
            selectedProjectID = project.id

            let episode = Self.emptyEpisode(order: 1)
            episodes = [episode]
            selectedEpisodeID = episode.id
            assets = []
            generatedImages = []
            seriesDesignBlueprint = nil
            selectedAssetID = nil
            selectedSection = .script
            searchText = ""
            analysisNotice = "已创建“\(project.title)”。可以直接粘贴第一集剧本。"
            try saveCurrentProjectSnapshot()
            try refreshProjects()
            rememberSelectedProject()
            storageNotice = nil
            return project.id
        } catch {
            reportStorageFailure(error)
            return nil
        }
    }

    func selectProject(_ id: UUID) {
        guard !isAnalyzing,
              id != selectedProjectID,
              projects.contains(where: { $0.id == id })
        else {
            return
        }

        do {
            try saveCurrentProjectSnapshot()
            selectedProjectID = id
            try loadProject(id: id, migrateLegacyWorkspace: false)
            try refreshProjects()
            rememberSelectedProject()
        } catch {
            reportStorageFailure(error)
        }
    }

    func renameProject(id: UUID, title: String) {
        guard !isAnalyzing, let repository else { return }
        do {
            try repository.renameProject(id: id, title: title)
            try refreshProjects()
            storageNotice = nil
        } catch {
            reportStorageFailure(error)
        }
    }

    func deleteProject(id: UUID) {
        guard !isAnalyzing, let repository else { return }

        do {
            let deletesCurrentProject = id == selectedProjectID
            try repository.deleteProject(id: id)
            try refreshProjects()

            if projects.isEmpty {
                let replacement = try repository.createProject(title: "我的资产项目")
                projects = [replacement]
            }

            if deletesCurrentProject {
                guard let nextProjectID = projects.first?.id else {
                    throw WorkspaceRepositoryError.projectNotFound
                }
                selectedProjectID = nextProjectID
                try loadProject(
                    id: nextProjectID,
                    migrateLegacyWorkspace: false
                )
                rememberSelectedProject()
            }
            try refreshProjects()
            storageNotice = nil
        } catch {
            reportStorageFailure(error)
        }
    }

    var scriptText: String {
        get { currentEpisode?.scriptText ?? "" }
        set {
            guard let index = currentEpisodeIndex else { return }
            episodes[index].scriptText = newValue
            episodes[index].extractionCheckpoints = []
            episodes[index].extractionLedger = nil
            episodes[index].analysisMetrics = nil
            seriesDesignBlueprint = nil
            episodes[index].updatedAt = .now
        }
    }

    var currentEpisodeTitle: String {
        get { currentEpisode?.title ?? "" }
        set {
            guard let index = currentEpisodeIndex else { return }
            episodes[index].title = newValue
            seriesDesignBlueprint = nil
            episodes[index].updatedAt = .now
        }
    }

    var sourceFileName: String? {
        currentEpisode?.sourceFileName
    }

    var selectedAsset: AssetItem? {
        guard let selectedAssetID else { return nil }
        return assets.first(where: { $0.id == selectedAssetID })
    }

    func generatedImages(for assetID: UUID) -> [GeneratedAssetImage] {
        generatedImages
            .filter { $0.assetID == assetID }
            .sorted {
                if $0.isPrimary != $1.isPrimary {
                    return $0.isPrimary
                }
                return $0.createdAt > $1.createdAt
            }
    }

    var pendingEpisodeCount: Int {
        episodes.count(where: episodeNeedsExtraction)
    }

    private func rebuildAssetLibraryContent() {
        let organization = AssetLibraryOrganizer.organize(
            assets: assets,
            section: selectedSection,
            searchText: searchText
        )
        filteredAssets = organization.filteredAssets
        assetLibraryItems = organization.items
        assetLibraryFolders = organization.folders
    }

    func count(for section: WorkspaceSection) -> Int {
        let active = assets.filter { $0.reviewState != .ignored }
        switch section {
        case .script:
            return episodes.count
        case .allAssets:
            return active.count
        case .scenes:
            return active.count(where: { $0.kind == .scene })
        case .characters:
            return active.count(where: { $0.kind == .character })
        case .props:
            return active.count(where: { $0.kind == .prop })
        }
    }

    func selectEpisode(_ id: UUID) {
        guard episodes.contains(where: { $0.id == id }) else { return }
        selectedEpisodeID = id
        selectedSection = .script
        persist()
    }

    func addEpisode() {
        let nextOrder = (episodes.map(\.order).max() ?? 0) + 1
        let episode = Self.emptyEpisode(order: nextOrder)
        episodes.append(episode)
        seriesDesignBlueprint = nil
        selectedEpisodeID = episode.id
        selectedSection = .script
        persistAll()
    }

    func deleteCurrentEpisode() {
        guard episodes.count > 1, let selectedEpisodeID else { return }
        episodes.removeAll(where: { $0.id == selectedEpisodeID })
        seriesDesignBlueprint = nil
        for index in episodes.indices {
            episodes[index].order = index + 1
            episodes[index].updatedAt = .now
        }
        self.selectedEpisodeID = episodes.first?.id
        rebuildGlobalAssets()
        selectedAssetID = validSelectedAssetID(selectedAssetID)
        persistAll()
    }

    func importScript(from url: URL) throws {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let maximumImportBytes = 128_000_000
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = resourceValues.fileSize,
           fileSize > maximumImportBytes {
            throw WorkspaceError.fileTooLarge
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= maximumImportBytes else {
            throw WorkspaceError.fileTooLarge
        }

        let decoded = try ScriptTextDecoder.decode(data)
        let importedText = decoded.text

        guard let index = currentEpisodeIndex else { return }
        episodes[index].scriptText = importedText
        episodes[index].extractionCheckpoints = []
        episodes[index].extractionLedger = nil
        episodes[index].analysisMetrics = nil
        seriesDesignBlueprint = nil
        episodes[index].sourceFileName = url.lastPathComponent
        if episodes[index].title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            episodes[index].title = url.deletingPathExtension().lastPathComponent
        }
        episodes[index].updatedAt = .now
        selectedSection = .script
        persistCurrentEpisode()
        analysisNotice = "已按 \(decoded.encodingName) 无损导入 \(data.count.formatted()) 字节；原文未做清洗或替换。"
    }

    func loadExampleScript() {
        guard let index = currentEpisodeIndex else { return }
        episodes[index].scriptText = """
        1. 内景 / 废弃剧院大厅 / 冬夜

        暴雨敲打着彩色玻璃。舞台上只亮着一盏老式钨丝灯，红色天鹅绒幕布已被烧去一角。
        女主角林默，32岁，身形高挑精瘦，穿适合寒冬的深色旧风衣和磨损皮靴，拎着一只银色手提箱穿过积水的观众席。
        她在第一排停下，从衣领里取出一枚黄铜钥匙。钥匙柄刻着一只飞蛾。

        林默
        你迟到了。

        二楼包厢的阴影里，主要反派——戴白瓷面具的男人缓慢起身。他的左手握着一根黑木手杖。
        """
        episodes[index].sourceFileName = nil
        episodes[index].extractionCheckpoints = []
        episodes[index].extractionLedger = nil
        episodes[index].analysisMetrics = nil
        seriesDesignBlueprint = nil
        episodes[index].updatedAt = .now
        selectedSection = .script
        persistCurrentEpisode()
    }

    func prepareCurrentEpisodeAnalysis() -> EpisodeAnalysisReview? {
        guard !isAIJobRunning, let episodeID = currentEpisode?.id else {
            if designingAssetID != nil {
                analysisNotice = "当前资产设计完成后，才能启动分集提取。"
            }
            return nil
        }

        let normalizedScript = currentEpisode?.scriptText
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalizedScript.isEmpty else {
            errorMessage = WorkspaceError.emptyScript.localizedDescription
            return nil
        }

        return prepareEpisodeAnalysis(candidateIDs: [episodeID])
    }

    func preparePendingEpisodeAnalysis() -> EpisodeAnalysisReview? {
        guard !isAIJobRunning else {
            if designingAssetID != nil {
                analysisNotice = "当前资产设计完成后，才能启动分集提取。"
            }
            return nil
        }

        let pendingIDs = episodes
            .filter(episodeNeedsExtraction)
            .filter { !$0.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.id)

        guard !pendingIDs.isEmpty else {
            analysisNotice = "没有需要提取的分集。已完成且剧本未修改的分集会被自动跳过。"
            return nil
        }

        return prepareEpisodeAnalysis(candidateIDs: Set(pendingIDs))
    }

    func prepareFailedEpisodeAnalysis() -> EpisodeAnalysisReview? {
        guard !isAIJobRunning else { return nil }
        let failedIDs = episodes
            .filter { $0.effectiveStatus == .failed }
            .filter { !$0.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.id)
        guard !failedIDs.isEmpty else {
            analysisNotice = "当前没有失败分集需要重试。"
            return nil
        }
        return prepareEpisodeAnalysis(candidateIDs: Set(failedIDs))
    }

    func analyzeConfirmedEpisodes(_ review: EpisodeAnalysisReview) async {
        guard !isAIJobRunning, !review.episodes.isEmpty else {
            if designingAssetID != nil {
                errorMessage = "正在设计其他资产。为了让模型一次只做一件事，请完成后再启动第一阶段。"
            }
            return
        }
        guard review.canAnalyze else {
            errorMessage = review.blockingIssues.first
                ?? "有分集没有识别到场景标题行。请返回剧本补齐或修正场号后再确认。"
            return
        }

        let targetIDs = review.episodes.map(\.episodeID)
        let uniqueTargetIDs = Set(targetIDs)
        guard uniqueTargetIDs.count == targetIDs.count else {
            errorMessage = WorkspaceError.analysisTargetMismatch(
                expected: targetIDs.count,
                actual: uniqueTargetIDs.count
            ).localizedDescription
            return
        }

        let sourceIsUnchanged = review.episodes.allSatisfy { preview in
            episodes.first(where: { $0.id == preview.episodeID })?.contentFingerprint
                == preview.contentFingerprint
        }
        guard sourceIsUnchanged else {
            errorMessage = "确认期间剧本内容已经变化，请重新核对分集和场景标题。"
            return
        }

        let currentTargetCount = episodes.count { episode in
            uniqueTargetIDs.contains(episode.id)
                && !episode.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard currentTargetCount == targetIDs.count else {
            errorMessage = WorkspaceError.analysisTargetMismatch(
                expected: targetIDs.count,
                actual: currentTargetCount
            ).localizedDescription
            return
        }

        guard let client = configuredClient() else { return }

        isAnalyzing = true
        analysisStartedAt = .now
        analysisProgress = EpisodeAnalysisProgress(stage: .preparing)
        isCancellingAnalysis = false
        analysisNotice = nil
        errorMessage = nil
        defer { resetAnalysisProgress() }

        currentAnalyzingEpisodeID = targetIDs.count == 1 ? targetIDs.first : nil

        do {
            let summary = try await performEpisodeAnalysis(
                ids: targetIDs,
                using: client
            )
            finishEpisodeAnalysis(summary)
        } catch {
            if Task.isCancelled || error is CancellationError {
                finishCancelledEpisodeAnalysis()
            } else {
                errorMessage = error.localizedDescription
                analysisNotice = "分集提取流程未能启动：\(error.localizedDescription)"
            }
        }
    }

    func startConfirmedEpisodeAnalysis(_ review: EpisodeAnalysisReview) {
        guard analysisTask == nil, !isAIJobRunning else { return }

        analysisTask = Task { [weak self] in
            guard let self else { return }
            await self.analyzeConfirmedEpisodes(review)
            self.analysisTask = nil
        }
    }

    func cancelAnalysis() {
        guard isAnalyzing, !isCancellingAnalysis else { return }
        isCancellingAnalysis = true
        analysisNotice = "正在取消当前请求；已经保存的分段不会丢失。"
        analysisTask?.cancel()
    }

    func setReviewState(_ state: AssetReviewState, for id: AssetItem.ID) {
        guard let index = assets.firstIndex(where: { $0.id == id }) else { return }
        assets[index].reviewState = state
        assets[index].updatedAt = .now

        if state == .ignored, selectedAssetID == id {
            selectedAssetID = filteredAssets.first?.id
        }
        persist()
    }

    func deleteAsset(id: AssetItem.ID) {
        guard let target = assets.first(where: { $0.id == id }) else { return }
        let targetKey = mergeKey(for: target)

        for episodeIndex in episodes.indices {
            episodes[episodeIndex].extractedAssets.removeAll {
                return mergeKey(for: $0) == targetKey
            }
            episodes[episodeIndex].updatedAt = .now
        }

        if let repository, let selectedProjectID {
            do {
                try repository.deleteGeneratedImages(
                    assetID: id,
                    projectID: selectedProjectID
                )
                generatedImages.removeAll(where: { $0.assetID == id })
            } catch {
                reportStorageFailure(error)
            }
        }

        assets.removeAll(where: { $0.id == id })
        rebuildGlobalAssets()
        if selectedAssetID == id {
            selectedAssetID = filteredAssets.first?.id
        }
        persistAll()
    }

    func rebuildAssetIndex() {
        rebuildGlobalAssets()
        persistAll()
    }

    func persist() {
        guard let repository, let selectedProjectID else { return }
        do {
            try repository.saveWorkspace(
                projectID: selectedProjectID,
                assets: assets,
                selectedEpisodeID: selectedEpisodeID,
                seriesDesignBlueprint: seriesDesignBlueprint
            )
            touchCurrentProjectSummary()
            storageNotice = nil
        } catch {
            reportStorageFailure(error)
        }
    }

    func persistCurrentEpisode() {
        guard let repository,
              let selectedProjectID,
              let currentEpisode
        else {
            return
        }

        do {
            try repository.saveEpisode(
                projectID: selectedProjectID,
                episode: currentEpisode
            )
            touchCurrentProjectSummary()
            storageNotice = nil
        } catch {
            reportStorageFailure(error)
        }
    }

    func persistAll() {
        do {
            try saveCurrentProjectSnapshot()
            touchCurrentProjectSummary()
            storageNotice = nil
        } catch {
            reportStorageFailure(error)
        }
    }

    private func loadProject(
        id: UUID,
        migrateLegacyWorkspace: Bool
    ) throws {
        guard let repository else {
            throw WorkspaceRepositoryError.projectNotFound
        }

        let loaded = try repository.load(projectID: id)
        let persistedEpisodes = loaded.episodes.sorted(
            using: KeyPathComparator(\.order)
        )
        let persistedAssets = loaded.assets
        let persistedSelectedEpisodeID = loaded.selectedEpisodeID
        let persistedSeriesDesignBlueprint = loaded.seriesDesignBlueprint

        episodes = persistedEpisodes.map(normalizingExtractedAssetSummaries)
        assets = persistedAssets
            .map(normalizingAssetSummary)
        generatedImages = loaded.generatedImages
        seriesDesignBlueprint = nil
        selectedEpisodeID = persistedSelectedEpisodeID
        selectedAssetID = nil
        selectedSection = .script
        searchText = ""
        analysisNotice = nil
        if episodes.isEmpty, migrateLegacyWorkspace {
            migrateLegacyWorkspaceIfAvailable()
        } else if episodes.isEmpty {
            let episode = Self.emptyEpisode(order: 1)
            episodes = [episode]
            selectedEpisodeID = episode.id
            assets = []
        } else {
            selectedEpisodeID = validSelectedEpisodeID(selectedEpisodeID)
            rebuildGlobalAssets()
        }

        let repairedPersistedData =
            episodes != persistedEpisodes
            || assets != persistedAssets
            || selectedEpisodeID != persistedSelectedEpisodeID
            || seriesDesignBlueprint != persistedSeriesDesignBlueprint
        if repairedPersistedData {
            try saveCurrentProjectSnapshot()
        }

        if loaded.recoveryWarnings.isEmpty {
            storageNotice = nil
        } else {
            storageNotice = loaded.recoveryWarnings.joined(separator: "\n")
        }
    }

    private func saveCurrentProjectSnapshot() throws {
        guard let repository, let selectedProjectID else {
            throw WorkspaceRepositoryError.projectNotFound
        }
        try repository.saveAll(
            projectID: selectedProjectID,
            episodes: episodes,
            assets: assets,
            selectedEpisodeID: selectedEpisodeID,
            seriesDesignBlueprint: seriesDesignBlueprint
        )
    }

    private func refreshProjects() throws {
        guard let repository else {
            throw WorkspaceRepositoryError.projectNotFound
        }
        projects = try repository.listProjects()
    }

    private func rememberSelectedProject() {
        if let selectedProjectID {
            UserDefaults.standard.set(
                selectedProjectID.uuidString,
                forKey: selectedProjectDefaultsKey
            )
        }
    }

    private func touchCurrentProjectSummary() {
        guard let selectedProjectID,
              let index = projects.firstIndex(where: { $0.id == selectedProjectID })
        else {
            return
        }
        projects[index].episodeCount = episodes.count
        projects[index].assetCount = assets.count
        projects[index].updatedAt = .now
    }

    private func nextProjectTitle() -> String {
        let existingTitles = Set(projects.map(\.title))
        var index = projects.count + 1
        var candidate = "新项目 \(index)"
        while existingTitles.contains(candidate) {
            index += 1
            candidate = "新项目 \(index)"
        }
        return candidate
    }

    private var currentEpisodeIndex: Int? {
        guard let selectedEpisodeID else {
            return episodes.indices.first
        }
        return episodes.firstIndex(where: { $0.id == selectedEpisodeID })
            ?? episodes.indices.first
    }

    func resolveTable2SceneIdentity(
        candidateGroups: [Table2SceneCandidateGroup]
    ) async -> Table2SceneIdentityResolution {
        guard !candidateGroups.isEmpty else {
            return Table2SceneIdentityResolution(
                mergeGroups: [],
                warning: nil
            )
        }

        let previousErrorMessage = errorMessage
        errorMessage = nil
        guard let client = configuredClient() else {
            let configurationProblem = errorMessage
                ?? "没有可用的大模型接口配置。"
            errorMessage = previousErrorMessage
            return Table2SceneIdentityResolution(
                mergeGroups: [],
                warning: "\(configurationProblem) 本次仍会导出，但所有同名场景都会保守地分行保留。"
            )
        }
        errorMessage = previousErrorMessage

        var mergeGroups: [Table2SceneMergeGroup] = []
        var failedGroupCount = 0
        var firstFailure: String?
        for candidateGroup in candidateGroups {
            do {
                mergeGroups.append(
                    contentsOf: try await client.verifyTable2SceneCandidateGroup(
                        candidateGroup
                    )
                )
            } catch {
                failedGroupCount += 1
                if firstFailure == nil {
                    firstFailure = error.localizedDescription
                }
            }
        }

        let warning: String?
        if failedGroupCount > 0 {
            let detail = firstFailure.map { " 首个原因：\($0)" } ?? ""
            warning = "\(client.providerName) 有 \(failedGroupCount) 组同名场景未能完成核验；这些组均已分行保留。\(detail)"
        } else {
            warning = nil
        }
        return Table2SceneIdentityResolution(
            mergeGroups: mergeGroups,
            warning: warning
        )
    }

    func designEvidenceContexts(
        for assetID: UUID
    ) -> [AssetDesignEvidenceContext] {
        guard let asset = assets.first(where: { $0.id == assetID }) else {
            return []
        }
        return makeDesignEvidenceContexts(for: asset)
    }

    func designInputFingerprint(for assetID: UUID) -> String? {
        guard let asset = assets.first(where: { $0.id == assetID }) else {
            return nil
        }
        return makeDesignRequestPayload(for: asset).inputFingerprint
    }

    func prepareDesignStart(
        for assetID: UUID
    ) -> AssetDesignStartReview? {
        guard !isAIJobRunning,
              let asset = assets.first(where: { $0.id == assetID }) else {
            if isAnalyzing {
                designNoticeAssetID = assetID
                designNotice = "请等待第一阶段提取完成，再确认资产开始设计。"
            }
            return nil
        }
        let payload = makeDesignRequestPayload(for: asset)
        return AssetDesignStartReview(
            assetID: asset.id,
            assetName: asset.name,
            assetKind: asset.kind,
            inputFingerprint: payload.inputFingerprint,
            designOptionCount: payload.designOptions.count,
            retrievedContextCount: payload.retrievedContexts.count
        )
    }

    func generateConfirmedDesignDraft(
        _ review: AssetDesignStartReview
    ) async {
        guard !isAIJobRunning,
              let asset = assets.first(where: { $0.id == review.assetID }) else {
            return
        }
        let payload = makeDesignRequestPayload(for: asset)
        guard payload.inputFingerprint == review.inputFingerprint else {
            errorMessage = "确认后，资产概览、剧本或设计选项已经变化。请重新确认当前资产后再开始设计。"
            return
        }
        await generateDesignDraft(
            for: review.assetID,
            confirmedPayload: payload
        )
    }

    private func generateDesignDraft(
        for assetID: UUID,
        confirmedPayload payload: AssetDesignRequestPayload
    ) async {
        guard !isAnalyzing, designingAssetID == nil,
              assets.contains(where: { $0.id == assetID }) else {
            return
        }
        guard let client = configuredClient() else { return }

        designingAssetID = assetID
        designNoticeAssetID = assetID
        designNotice = "正在本地检索相关场次，并由 \(client.providerName) 生成设计草案。"
        errorMessage = nil
        defer { designingAssetID = nil }

        do {
            let response = try await client.generateAssetDesign(from: payload)
            guard let index = assets.firstIndex(where: { $0.id == assetID }) else {
                return
            }
            assets[index].designDraft = AssetDesignDraft(
                inputFingerprint: payload.inputFingerprint,
                createdAt: .now,
                appliedAt: nil,
                designSummary: response.designSummary,
                evidenceDigest: response.evidenceDigest,
                assumptions: response.assumptions,
                usedContextIDs: response.usedContextIDs,
                basePrompt: response.basePrompt,
                searchKeywords: response.searchKeywords
            )
            assets[index].updatedAt = .now
            persist()
            designNotice = payload.retrievedContexts.isEmpty
                ? "设计草案已生成；本地没有检索到可靠剧本片段，草案中的推断已单独标注。"
                : "设计草案已生成，并引用了 \(response.usedContextIDs.count) 条本地检索依据；确认后才会写入正式提示词。"
        } catch {
            errorMessage = error.localizedDescription
            designNotice = "设计草案生成失败；现有设计选项和提示词均未修改。"
        }
    }

    func applyDesignDraft(for assetID: UUID) {
        guard let index = assets.firstIndex(where: { $0.id == assetID }),
              var draft = assets[index].designDraft else {
            return
        }
        let currentPayload = makeDesignRequestPayload(for: assets[index])
        guard currentPayload.inputFingerprint == draft.inputFingerprint else {
            errorMessage = "草案生成后，资产概览、剧本或设计选项已经变化。为避免覆盖新选择，请重新生成设计草案。"
            return
        }

        assets[index].basePrompt = draft.basePrompt
        assets[index].searchKeywords = draft.searchKeywords
        draft.appliedAt = .now
        assets[index].designDraft = draft
        assets[index].updatedAt = .now
        persist()
        designNoticeAssetID = assetID
        designNotice = "已采用设计草案；最终提示词仍会继续叠加当前页面的全部设计选项。"
    }

    func discardDesignDraft(for assetID: UUID) {
        guard let index = assets.firstIndex(where: { $0.id == assetID }) else {
            return
        }
        assets[index].designDraft = nil
        assets[index].updatedAt = .now
        persist()
        designNoticeAssetID = assetID
        designNotice = "已丢弃设计草案，现有正式设计未改变。"
    }

    private func makeDesignRequestPayload(
        for asset: AssetItem
    ) -> AssetDesignRequestPayload {
        let options = PromptCompiler.designOptionSnapshots(for: asset).map {
            DesignOptionSnapshot(
                key: boundedDesignText($0.key, maximumCharacters: 120),
                group: boundedDesignText($0.group, maximumCharacters: 120),
                parameter: boundedDesignText(
                    $0.parameter,
                    maximumCharacters: 120
                ),
                selectedValue: boundedDesignText(
                    $0.selectedValue,
                    maximumCharacters: 160
                ),
                promptToken: boundedDesignText(
                    $0.promptToken,
                    maximumCharacters: 360
                ),
                isDefault: $0.isDefault
            )
        }
        let contexts = makeDesignEvidenceContexts(
            for: asset,
            optionSnapshots: options
        )
        let payloadWithoutFingerprint = AssetDesignRequestPayload(
            assetID: asset.id.uuidString.lowercased(),
            kind: asset.kind.rawValue,
            name: boundedDesignText(asset.name, maximumCharacters: 160),
            extractionOverview: boundedDesignText(
                asset.summary,
                maximumCharacters: 1_200
            ),
            extractedEvidence: boundedDesignText(
                asset.evidence,
                maximumCharacters: 1_200
            ),
            extractedProfile: designProfileSummary(for: asset),
            currentDesignPrompt: boundedDesignText(
                asset.basePrompt,
                maximumCharacters: 2_000
            ),
            currentSearchKeywords: boundedDesignText(
                asset.searchKeywords ?? "",
                maximumCharacters: 1_000
            ),
            designOptions: options,
            retrievedContexts: contexts,
            projectOverview: designProjectOverview(),
            inputFingerprint: ""
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let fingerprintSource = (try? encoder.encode(payloadWithoutFingerprint))
            .map { String(decoding: $0, as: UTF8.self) }
            ?? "\(asset.id.uuidString)|\(asset.updatedAt.timeIntervalSinceReferenceDate)"
        return AssetDesignRequestPayload(
            assetID: payloadWithoutFingerprint.assetID,
            kind: payloadWithoutFingerprint.kind,
            name: payloadWithoutFingerprint.name,
            extractionOverview: payloadWithoutFingerprint.extractionOverview,
            extractedEvidence: payloadWithoutFingerprint.extractedEvidence,
            extractedProfile: payloadWithoutFingerprint.extractedProfile,
            currentDesignPrompt: payloadWithoutFingerprint.currentDesignPrompt,
            currentSearchKeywords: payloadWithoutFingerprint.currentSearchKeywords,
            designOptions: payloadWithoutFingerprint.designOptions,
            retrievedContexts: payloadWithoutFingerprint.retrievedContexts,
            projectOverview: payloadWithoutFingerprint.projectOverview,
            inputFingerprint: Self.fingerprint(for: fingerprintSource)
        )
    }

    private func makeDesignEvidenceContexts(
        for asset: AssetItem,
        optionSnapshots: [DesignOptionSnapshot]? = nil
    ) -> [AssetDesignEvidenceContext] {
        let snapshots = optionSnapshots
            ?? PromptCompiler.designOptionSnapshots(for: asset)
        let optionTerms = snapshots
            .filter { !$0.isDefault }
            .map(\.selectedValue)
        return ScriptKnowledgeIndex(episodes: episodes)
            .contexts(for: asset, optionTerms: optionTerms)
            .map { context in
                AssetDesignEvidenceContext(
                    id: context.id,
                    episodeOrder: context.episodeOrder,
                    sceneIdentifier: boundedDesignText(
                        context.sceneIdentifier,
                        maximumCharacters: 40
                    ),
                    heading: boundedDesignText(
                        context.heading,
                        maximumCharacters: 150
                    ),
                    excerpt: boundedDesignText(
                        context.excerpt,
                        maximumCharacters: 420
                    ),
                    truncated: context.truncated
                )
            }
    }

    private func designProfileSummary(for asset: AssetItem) -> String {
        let values: [String]
        switch asset.kind {
        case .scene:
            if let profile = asset.sceneProfile {
                values = [
                    "大场景：\(profile.locationGroup ?? "")",
                    "时间：\(profile.timeOfDayID)",
                    "天气：\(profile.weatherID)",
                    "季节：\(profile.season)",
                    "时代：\(profile.period)",
                    "空间类型：\(profile.locationType)",
                    "制作依据：\(profile.productionNotes)"
                ]
            } else {
                values = []
            }
        case .character:
            if let profile = asset.characterProfile {
                let wardrobe = profile.wardrobe.first(
                    where: { $0.id == asset.activeWardrobeID }
                )
                values = [
                    "角色职能：\(profile.narrativeRole.title)",
                    "重要级别：\(profile.importance.title)",
                    "阵营：\(profile.affiliation ?? "")",
                    "年龄：\(profile.ageRange)",
                    "性别呈现：\(profile.genderPresentation)",
                    "脸部提取：\(profile.facePrompt)",
                    "体型提取：\(profile.physiquePrompt)",
                    "妆发提取：\(profile.hairMakeupPrompt)",
                    "辨识特征：\(profile.distinguishingFeaturesPrompt)",
                    "当前服装：\(wardrobe?.title ?? "不指定")",
                    "服装剧情依据：\(wardrobe?.sourceEvidence ?? "")"
                ]
            } else {
                values = []
            }
        case .prop:
            if let profile = asset.propProfile {
                values = [
                    "分类：\(profile.category)",
                    "剧情功能：\(profile.storyFunction)",
                    "材质提取：\(profile.materialPrompt)",
                    "结构提取：\(profile.constructionPrompt)",
                    "状态变化：\(profile.stateChanges)"
                ]
            } else {
                values = []
            }
        }
        return boundedDesignText(
            values.filter { !$0.hasSuffix("：") }.joined(separator: "\n"),
            maximumCharacters: 2_000
        )
    }

    private func designProjectOverview() -> String {
        guard let overview = projectExtractionOverview else { return "" }
        let episodeLines = overview.episodes.prefix(24).map {
            "\($0.order). \($0.title)：\($0.summaryLine)"
        }
        return boundedDesignText(
            ([overview.summaryLine] + episodeLines).joined(separator: "\n"),
            maximumCharacters: 1_200
        )
    }

    private func boundedDesignText(
        _ value: String,
        maximumCharacters: Int
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maximumCharacters else { return trimmed }
        return String(trimmed.prefix(maximumCharacters))
    }

    private func configuredClient() -> DeepSeekClient? {
        let providerRawValue = UserDefaults.standard.string(forKey: "llm.provider")
        let provider = LLMProvider(rawValue: providerRawValue ?? "") ?? .deepSeek

        switch provider {
        case .deepSeek:
            let apiKey = KeychainService.readAPIKey()
            guard !apiKey.isEmpty else {
                errorMessage = WorkspaceError.missingAPIKey.localizedDescription
                return nil
            }

            let modelRawValue = UserDefaults.standard.string(forKey: "deepseek.model")
            let model = DeepSeekModel(rawValue: modelRawValue ?? "") ?? .pro
            return DeepSeekClient(apiKey: apiKey, model: model)

        case .openAICompatible:
            let apiKey = KeychainService.readOpenAICompatibleAPIKey()
            guard !apiKey.isEmpty else {
                errorMessage = WorkspaceError.missingCompatibleAPIKey.localizedDescription
                return nil
            }

            let defaults = UserDefaults.standard
            let endpointRawValue = defaults.string(forKey: "openaiCompatible.url") ?? ""
            guard let endpoint = OpenAICompatibleEndpoint.resolve(endpointRawValue) else {
                errorMessage = WorkspaceError.invalidCompatibleURL.localizedDescription
                return nil
            }

            let modelID = defaults.string(forKey: "openaiCompatible.model")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !modelID.isEmpty else {
                errorMessage = WorkspaceError.missingCompatibleModel.localizedDescription
                return nil
            }
            return DeepSeekClient(apiKey: apiKey, endpoint: endpoint, modelID: modelID)
        }
    }

    private func prepareEpisodeAnalysis(
        candidateIDs: Set<UUID>
    ) -> EpisodeAnalysisReview? {
        errorMessage = nil
        let originalEpisodes = episodes
        let originalAssets = assets
        let originalSelectedEpisodeID = selectedEpisodeID
        let originalSelectedAssetID = selectedAssetID
        let originalBlueprint = seriesDesignBlueprint
        let targetIDs: [UUID]
        do {
            targetIDs = try splitEpisodesIfNeeded(candidateIDs: candidateIDs)
        } catch {
            episodes = originalEpisodes
            assets = originalAssets
            selectedEpisodeID = originalSelectedEpisodeID
            selectedAssetID = originalSelectedAssetID
            seriesDesignBlueprint = originalBlueprint
            if let workspaceError = error as? WorkspaceError {
                errorMessage = workspaceError.localizedDescription
            } else {
                reportStorageFailure(error)
                errorMessage = "分集结果无法安全保存，已回滚本次整理。请检查存储空间后重试。"
            }
            return nil
        }

        let uniqueTargetIDs = Set(targetIDs)
        guard uniqueTargetIDs.count == targetIDs.count else {
            errorMessage = WorkspaceError.analysisTargetMismatch(
                expected: targetIDs.count,
                actual: uniqueTargetIDs.count
            ).localizedDescription
            return nil
        }

        let idSet = Set(targetIDs)
        let previews = episodes
            .filter { idSet.contains($0.id) }
            .sorted(using: KeyPathComparator(\.order))
            .map { episode in
                let splitInspection = EpisodeScriptSplitter.splitWithDiagnostics(
                    episode.scriptText
                )
                return EpisodeAnalysisPreview(
                    episodeID: episode.id,
                    order: episode.order,
                    title: episode.displayTitle,
                    sceneHeadings: EpisodeScriptSplitter.sceneHeadings(
                        in: episode.scriptText
                    ),
                    contentFingerprint: episode.contentFingerprint,
                    splitDiagnostics: splitInspection.diagnostics
                )
            }
        guard !previews.isEmpty else {
            errorMessage = WorkspaceError.emptyScript.localizedDescription
            return nil
        }
        guard previews.count == targetIDs.count else {
            errorMessage = WorkspaceError.analysisTargetMismatch(
                expected: targetIDs.count,
                actual: previews.count
            ).localizedDescription
            return nil
        }

        let blockingIssues = EpisodeAnalysisIntegrityValidator.blockingIssues(in: previews)
        let review = EpisodeAnalysisReview(
            episodes: previews,
            blockingIssues: blockingIssues
        )
        if review.hasMissingSceneHeadings {
            let missingCount = previews.count(where: { $0.sceneHeadings.isEmpty })
            analysisNotice = "已按集整理；其中 \(missingCount) 集没有识别到场景标题，修正前不会开始提取。"
        } else if !blockingIssues.isEmpty {
            analysisNotice = "已按集整理，但发现 \(blockingIssues.count) 项结构异常；修正前不会启动模型。"
        } else {
            let sceneCount = previews.reduce(0) { $0 + $1.sceneHeadings.count }
            analysisNotice = "已按集整理出 \(previews.count) 集、\(sceneCount) 场。请核对场景标题并一次确认全部。"
        }
        return review
    }

    private func performEpisodeAnalysis(
        ids: [UUID],
        using client: DeepSeekClient
    ) async throws -> AnalysisBatchSummary {
        let idSet = Set(ids)
        guard idSet.count == ids.count else {
            throw WorkspaceError.analysisTargetMismatch(
                expected: ids.count,
                actual: idSet.count
            )
        }
        let targets = episodes
            .filter { idSet.contains($0.id) }
            .filter { !$0.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted(using: KeyPathComparator(\.order))
        guard targets.count == ids.count else {
            throw WorkspaceError.analysisTargetMismatch(
                expected: ids.count,
                actual: targets.count
            )
        }

        analysisCompletedEpisodeCount = 0
        analysisTotalEpisodeCount = targets.count
        analysisProviderName = client.providerName
        currentAnalyzingEpisodeID = targets.count == 1 ? targets.first?.id : nil
        analysisNotice = targets.count == 1
            ? "\(client.providerName) 正在独立提取本集；完成后立即保存。"
            : "已在本地拆成 \(targets.count) 集；\(client.providerName) 将逐集提取，每集完成后立即保存。"

        let jobs = targets.map { target in
            let canResume = target.extractionStatus == .failed
                || target.extractionStatus == .extracting
            return EpisodeAnalysisJob(
                episodeID: target.id,
                script: target.scriptText,
                sourceFingerprint: target.contentFingerprint,
                existingCheckpoints: canResume ? target.extractionCheckpoints : []
            )
        }

        var successCount = 0
        var failureCount = 0
        var unresolvedEpisodeIDs = idSet
        for (index, job) in jobs.enumerated() {
            try Task.checkCancellation()
            currentAnalyzingEpisodeID = job.episodeID
            analysisCurrentEpisodeIndex = index + 1
            currentAnalyzingEpisodeTitle = targets[index].displayTitle
            analysisProgress = EpisodeAnalysisProgress(stage: .preparing)
            try beginAnalysisJob(job)

            let outcome = try await job.run(
                using: client,
                existingCatalog: catalogSummary(excluding: unresolvedEpisodeIDs),
                checkpointHandler: { checkpoint in
                    try await self.persistCheckpoint(checkpoint, for: job.episodeID)
                },
                progressHandler: { progress in
                    self.analysisProgress = progress
                }
            )
            try Task.checkCancellation()
            analysisProgress = EpisodeAnalysisProgress(stage: .saving)
            let committed = commitAnalysisResult(
                outcome,
                baselineEpisode: targets[index],
                unresolvedEpisodeIDs: &unresolvedEpisodeIDs
            )
            successCount += committed ? 1 : 0
            failureCount += committed ? 0 : 1
        }

        return AnalysisBatchSummary(
            successCount: successCount,
            failureCount: failureCount
        )
    }

    private func commitAnalysisResult(
        _ outcome: EpisodeAnalysisOutcome,
        baselineEpisode: ScriptEpisode,
        unresolvedEpisodeIDs: inout Set<UUID>
    ) -> Bool {
        let modelSucceeded = applyAnalysisOutcome(outcome)

        analysisCompletedEpisodeCount += 1
        rebuildGlobalAssets()
        do {
            try persistAnalysisCheckpoint(for: outcome.episodeID)
            if modelSucceeded {
                unresolvedEpisodeIDs.remove(outcome.episodeID)
            }
            analysisNotice = "已按顺序保存 \(analysisCompletedEpisodeCount) / \(analysisTotalEpisodeCount) 集。"
            return modelSucceeded
        } catch {
            if modelSucceeded,
               let index = episodes.firstIndex(where: { $0.id == outcome.episodeID }) {
                let retainedCheckpoints = episodes[index].extractionCheckpoints
                episodes[index] = baselineEpisode
                episodes[index].extractionCheckpoints = retainedCheckpoints
                episodes[index].extractionStatus = .failed
                episodes[index].lastError = "提取已完成，但最终快照未能安全落盘：\(error.localizedDescription)"
                episodes[index].updatedAt = .now
                rebuildGlobalAssets()
            }
            reportStorageFailure(error)
            analysisNotice = "第 \(analysisCompletedEpisodeCount) / \(analysisTotalEpisodeCount) 集的最终快照保存失败；已完成的分段 checkpoint 仍可用于重试。"
            return false
        }
    }

    private func applyAnalysisOutcome(_ outcome: EpisodeAnalysisOutcome) -> Bool {
        switch outcome {
        case .success(let episodeID, let sourceCharacterCount, let result):
            guard let index = episodes.firstIndex(where: { $0.id == episodeID }) else {
                return false
            }

            let route: AnalysisRoute
            if result.usedLocalInventoryPrimary {
                route = .hybrid
            } else {
                route = result.segmentCount > 1
                    ? .deepSeekChunked
                    : .deepSeekOnly
            }

            if let ledger = result.ledger {
                episodes[index].extractionLedger = ledger
                rebuildEpisodeAssets(at: index, from: ledger)
            } else {
                let extracted = result.assets
                let episodeAssets =
                    extracted.scenes.map { makeScene($0, episodeID: episodeID) }
                    + extracted.characters.map { makeCharacter($0, episodeID: episodeID) }
                    + extracted.props.map { makeProp($0, episodeID: episodeID) }
                episodes[index].extractedAssets = deduplicated(episodeAssets)
            }
            let warnings = result.warnings
            episodes[index].extractionCheckpoints = result.checkpoints
            episodes[index].extractionWarnings = warnings
            episodes[index].extractionStatus = warnings.isEmpty
                ? .completed
                : .completedWithWarnings
            episodes[index].lastError = nil
            episodes[index].lastExtractedFingerprint = episodes[index].contentFingerprint
            episodes[index].extractedAt = .now
            episodes[index].updatedAt = .now
            episodes[index].analysisMetrics = AnalysisMetrics(
                route: route,
                sourceCharacterCount: sourceCharacterCount,
                remoteCharacterCount: sourceCharacterCount,
                segmentCount: result.segmentCount,
                requestCount: result.telemetry.networkAttemptCount,
                promptTokens: result.telemetry.promptTokens,
                completionTokens: result.telemetry.completionTokens,
                totalTokens: result.telemetry.totalTokens,
                estimatedCostUSD: estimatedExtractionCostUSD(
                    promptTokens: result.telemetry.promptTokens,
                    completionTokens: result.telemetry.completionTokens
                )
            )
            return true

        case .failure(let episodeID, let message):
            guard let index = episodes.firstIndex(where: { $0.id == episodeID }) else {
                return false
            }
            episodes[index].extractionStatus = .failed
            episodes[index].lastError = message
            episodes[index].updatedAt = .now
            episodes[index].analysisMetrics = nil
            return false
        }
    }

    private func estimatedExtractionCostUSD(
        promptTokens: Int,
        completionTokens: Int
    ) -> Double? {
        let defaults = UserDefaults.standard
        let inputRate = defaults.double(forKey: "llm.inputPricePerMillionTokensUSD")
        let outputRate = defaults.double(forKey: "llm.outputPricePerMillionTokensUSD")
        guard inputRate > 0 || outputRate > 0 else { return nil }
        return (Double(promptTokens) * inputRate + Double(completionTokens) * outputRate) / 1_000_000
    }

    private func rebuildEpisodeAssets(
        at episodeIndex: Int,
        from ledger: EpisodeExtractionLedger
    ) {
        let episodeID = episodes[episodeIndex].id
        let source = episodes[episodeIndex].scriptText
        let extracted = StageOneAssetAssembler.extractedAssets(
            from: ledger,
            source: source
        )
        let occurrences = StageOneAssetAssembler.occurrences(
            from: ledger,
            source: source
        )
        var items =
            extracted.scenes.map { makeScene($0, episodeID: episodeID) }
            + extracted.characters.map { makeCharacter($0, episodeID: episodeID) }
            + extracted.props.map { makeProp($0, episodeID: episodeID) }

        for index in items.indices {
            let identityQualifier: String?
            if items[index].kind == .prop,
               let category = items[index].propProfile?.category,
               !["", "未分类", "未知", "unspecified"].contains(
                    category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
               ) {
                identityQualifier = category
            } else {
                identityQualifier = nil
            }
            let canonicalKey = CanonicalAssetIdentity.key(
                kind: items[index].kind,
                canonicalName: items[index].name,
                identityQualifier: identityQualifier
            )
            items[index].canonicalKey = canonicalKey
            items[index].id = CanonicalAssetIdentity.stableUUID(for: canonicalKey)
            items[index].occurrences = occurrences[canonicalKey] ?? []
        }
        episodes[episodeIndex].extractedAssets = deduplicated(items)
    }

    private func persistCheckpoint(
        _ checkpoint: DeepSeekSegmentCheckpoint,
        for episodeID: UUID
    ) throws {
        guard let repository,
              let selectedProjectID,
              let index = episodes.firstIndex(where: { $0.id == episodeID })
        else {
            throw WorkspaceRepositoryError.projectNotFound
        }
        guard episodes[index].contentFingerprint == checkpoint.sourceFingerprint else {
            throw WorkspaceError.scriptIntegrityViolation
        }

        if let existingIndex = episodes[index].extractionCheckpoints.firstIndex(
            where: { $0.segmentID == checkpoint.segmentID }
        ) {
            episodes[index].extractionCheckpoints[existingIndex] = checkpoint
        } else {
            episodes[index].extractionCheckpoints.append(checkpoint)
        }
        episodes[index].extractionCheckpoints.sort {
            $0.segmentIndex < $1.segmentIndex
        }
        episodes[index].updatedAt = .now
        try repository.saveEpisode(
            projectID: selectedProjectID,
            episode: episodes[index]
        )
    }

    private func beginAnalysisJob(_ job: EpisodeAnalysisJob) throws {
        guard let repository,
              let selectedProjectID,
              let index = episodes.firstIndex(where: { $0.id == job.episodeID })
        else {
            throw WorkspaceRepositoryError.projectNotFound
        }
        let original = episodes[index]
        if original.extractionStatus != .failed,
           original.extractionStatus != .extracting {
            episodes[index].extractionCheckpoints = []
            episodes[index].extractionLedger = nil
        }
        episodes[index].extractionStatus = .extracting
        episodes[index].extractionWarnings = []
        episodes[index].lastError = nil
        episodes[index].updatedAt = .now

        do {
            try repository.saveEpisode(
                projectID: selectedProjectID,
                episode: episodes[index]
            )
        } catch {
            episodes[index] = original
            throw error
        }
    }

    private func finishEpisodeAnalysis(_ summary: AnalysisBatchSummary) {
        let reviewCount = projectExtractionReviewItems.count
        selectedSection = summary.successCount > 0 && reviewCount == 0
            ? .allAssets
            : .script
        if summary.successCount > 0, reviewCount == 0 {
            selectedAssetID = validSelectedAssetID(selectedAssetID) ?? filteredAssets.first?.id
        }

        if reviewCount > 0 {
            analysisNotice = "提取已保存；有 \(reviewCount) 项场景、人物或道具的两次判定不一致，确认前不会进入正式资产。请在上方逐项复核。"
        } else if summary.failureCount == 0 {
            analysisNotice = summary.successCount == 1
                ? "本集提取完成，资产与分集概览已立即保存。"
                : "已按剧情顺序完成 \(summary.successCount) 集提取；资产与项目概览均已更新。"
        } else {
            analysisNotice = "分集提取完成：\(summary.successCount) 集成功，\(summary.failureCount) 集失败。成功分集已进入项目概览；失败分集可单独重试。"
        }
    }

    private func resetAnalysisProgress() {
        isAnalyzing = false
        currentAnalyzingEpisodeID = nil
        analysisCompletedEpisodeCount = 0
        analysisTotalEpisodeCount = 0
        analysisCurrentEpisodeIndex = 0
        currentAnalyzingEpisodeTitle = nil
        analysisProgress = nil
        analysisStartedAt = nil
        isCancellingAnalysis = false
        analysisProviderName = nil
    }

    private func finishCancelledEpisodeAnalysis() {
        let completedCount = analysisCompletedEpisodeCount
        if let episodeID = currentAnalyzingEpisodeID {
            if let index = episodes.firstIndex(where: { $0.id == episodeID }),
               episodes[index].extractionStatus == .extracting {
                episodes[index].extractionStatus = .failed
                episodes[index].lastError = "提取已取消；已经保存的分段会在重新提取时继续使用。"
                episodes[index].updatedAt = .now
                do {
                    try persistAnalysisCheckpoint(for: episodeID)
                } catch {
                    reportStorageFailure(error)
                }
            }
        }

        errorMessage = nil
        analysisNotice = completedCount > 0
            ? "已取消提取；此前完成并保存了 \(completedCount) 集，当前批次的分段 checkpoint 也已保留。"
            : "已取消提取；当前批次已经保存的分段 checkpoint 会在重新提取时继续使用。"
    }

    private func splitEpisodesIfNeeded(candidateIDs: Set<UUID>) throws -> [UUID] {
        let ordered = episodes.sorted(using: KeyPathComparator(\.order))
        var expanded: [ScriptEpisode] = []
        var targetIDs: [UUID] = []
        var splitEpisodeCount = 0

        for episode in ordered {
            guard candidateIDs.contains(episode.id) else {
                expanded.append(episode)
                continue
            }

            let splitResult = EpisodeScriptSplitter.splitWithDiagnostics(
                episode.scriptText
            )
            guard splitResult.diagnostics.isEmpty else {
                throw WorkspaceError.ambiguousEpisodeSplit(
                    splitResult.diagnostics.map(\.message)
                )
            }
            let detected = splitResult.episodes
            guard detected.map(\.scriptText).joined() == episode.scriptText else {
                throw WorkspaceError.scriptIntegrityViolation
            }
            guard detected.count > 1 else {
                expanded.append(episode)
                targetIDs.append(episode.id)
                continue
            }

            guard episode.extractedAssets.isEmpty else {
                throw WorkspaceError.extractedEpisodeRequiresManualRepartition(
                    episode.displayTitle
                )
            }

            splitEpisodeCount += detected.count
            for (offset, part) in detected.enumerated() {
                let partID = offset == 0 ? episode.id : UUID()
                let trimmedTitle = part.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let partTitle = trimmedTitle.isEmpty
                    ? "第 \(expanded.count + 1) 集"
                    : trimmedTitle
                let splitEpisode = ScriptEpisode(
                    id: partID,
                    order: expanded.count + 1,
                    title: partTitle,
                    scriptText: part.scriptText,
                    sourceFileName: episode.sourceFileName
                )
                expanded.append(splitEpisode)
                targetIDs.append(partID)
            }
        }

        guard splitEpisodeCount > 0 else {
            return targetIDs
        }

        for index in expanded.indices {
            expanded[index].order = index + 1
        }
        episodes = expanded
        selectedEpisodeID = validSelectedEpisodeID(selectedEpisodeID)
        seriesDesignBlueprint = nil
        rebuildGlobalAssets()
        try persistPreparedEpisodeSplit()
        analysisNotice = "已用本地规则识别并保存为 \(splitEpisodeCount) 集；请先逐集核对场景标题。"
        return targetIDs
    }

    private func persistPreparedEpisodeSplit() throws {
        try saveCurrentProjectSnapshot()
        touchCurrentProjectSummary()
        storageNotice = nil
    }

    private func persistAnalysisCheckpoint(for episodeID: UUID) throws {
        guard let repository,
              let selectedProjectID,
              let episode = episodes.first(where: { $0.id == episodeID })
        else {
            throw WorkspaceRepositoryError.projectNotFound
        }

        try repository.saveAnalysisCheckpoint(
            projectID: selectedProjectID,
            episode: episode,
            assets: assets,
            selectedEpisodeID: selectedEpisodeID,
            seriesDesignBlueprint: seriesDesignBlueprint
        )
        touchCurrentProjectSummary()
        storageNotice = nil
    }

    private var seriesSourceFingerprint: String {
        let source = episodes
            .sorted(using: KeyPathComparator(\.order))
            .map { "\($0.order)|\($0.title)|\($0.contentFingerprint)" }
            .joined(separator: "\n")
        return Self.fingerprint(for: source)
    }

    private func episodeNeedsExtraction(_ episode: ScriptEpisode) -> Bool {
        switch episode.effectiveStatus {
        case .completed, .completedWithWarnings:
            return false
        case .notExtracted, .extracting, .failed, .stale:
            return true
        }
    }

    private func catalogSummary(excluding episodeIDs: Set<UUID> = []) -> String {
        assets
            .filter { $0.reviewState != .ignored }
            .filter { asset in
                let sourceIDs = asset.sourceEpisodeIDs ?? []
                return sourceIDs.isEmpty
                    || sourceIDs.contains(where: { !episodeIDs.contains($0) })
            }
            .sorted {
                let left = "\($0.kind.rawValue)\u{0}\($0.name)\u{0}\($0.id.uuidString)"
                let right = "\($1.kind.rawValue)\u{0}\($1.name)\u{0}\($1.id.uuidString)"
                return left < right
            }
            .map { asset in
                if let profile = asset.sceneProfile {
                    let group = profile.locationGroup ?? ""
                    return "[SCENE] \(asset.name) | locationGroup \(group) | time \(profile.timeOfDayID)"
                }
                if let profile = asset.characterProfile {
                    let affiliation = profile.affiliation ?? ""
                    return "[CHARACTER] \(asset.name) | tier \(profile.importance.rawValue) | role \(profile.narrativeRole.rawValue) | affiliation \(affiliation)"
                }
                return "[\(asset.kind.rawValue.uppercased())] \(asset.name)"
            }
            .joined(separator: "\n")
    }

    private func migrateLegacyWorkspaceIfAvailable() {
        if let snapshot = loadLegacySnapshot() {
            let episodeID = UUID()
            let migratedAssets = snapshot.assets.map { asset in
                var migrated = normalizingAssetSummary(asset)
                migrated.sourceEpisodeIDs = [episodeID]
                return migrated
            }
            let hasAssets = !migratedAssets.isEmpty
            let episode = ScriptEpisode(
                id: episodeID,
                order: 1,
                title: snapshot.sourceFileName
                    .map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
                    ?? "第 1 集",
                scriptText: snapshot.scriptText,
                sourceFileName: snapshot.sourceFileName,
                extractionStatus: hasAssets ? .completed : .notExtracted,
                extractedAssets: migratedAssets,
                lastExtractedFingerprint: hasAssets
                    ? Self.fingerprint(for: snapshot.scriptText)
                    : nil,
                updatedAt: snapshot.updatedAt,
                extractedAt: hasAssets ? snapshot.updatedAt : nil
            )
            episodes = [episode]
            assets = migratedAssets
            selectedEpisodeID = episodeID
        } else {
            let episode = Self.emptyEpisode(order: 1)
            episodes = [episode]
            selectedEpisodeID = episode.id
            assets = []
        }
        persistAll()
    }

    private func loadLegacySnapshot() -> WorkspaceSnapshot? {
        guard let data = try? Data(contentsOf: legacySnapshotURL) else {
            return nil
        }
        return try? JSONDecoder.workspaceDecoder.decode(
            WorkspaceSnapshot.self,
            from: data
        )
    }

    private func normalizingExtractedAssetSummaries(
        _ episode: ScriptEpisode
    ) -> ScriptEpisode {
        var normalized = episode
        normalized.extractedAssets = episode.extractedAssets.map(
            normalizingAssetSummary
        )
        return normalized
    }

    private func normalizingAssetSummary(_ asset: AssetItem) -> AssetItem {
        var normalized = asset
        normalized.summary = AssetSummaryConsolidator.consolidate(asset.summary)
        normalized = purifyForExtraction(normalized)
        return normalized
    }

    private func rebuildingAssetsFromEpisodes() -> [AssetItem] {
        var orderedKeys: [String] = []
        var mergedByKey: [String: AssetItem] = [:]

        for episode in episodes.sorted(using: KeyPathComparator(\.order)) {
            for episodeAsset in episode.extractedAssets {
                var sourcedAsset = normalizingAssetSummary(episodeAsset)
                sourcedAsset.sourceEpisodeIDs = union(
                    sourcedAsset.sourceEpisodeIDs ?? [],
                    [episode.id]
                )
                let key = mergeKey(for: sourcedAsset)
                if let existing = mergedByKey[key] {
                    mergedByKey[key] = mergeAsset(existing, with: sourcedAsset)
                } else {
                    orderedKeys.append(key)
                    mergedByKey[key] = sourcedAsset
                }
            }
        }

        return orderedKeys.compactMap { mergedByKey[$0] }
    }

    private func rebuildGlobalAssets() {
        repairDuplicateSceneIDs()
        let curatedAssets = assets
        var rebuilt = rebuildingAssetsFromEpisodes()

        for index in rebuilt.indices {
            let key = mergeKey(for: rebuilt[index])
            let curated = curatedAssets.first(where: { mergeKey(for: $0) == key })
            if let curated {
                rebuilt[index] = applyingCuratedState(curated, to: rebuilt[index])
            }
        }

        let rebuiltKeys = Set(rebuilt.map(mergeKey))
        let manualAssets = curatedAssets.filter {
            guard $0.sourceEpisodeIDs?.isEmpty ?? true else { return false }
            return !rebuiltKeys.contains(mergeKey(for: $0))
        }
        assets = rebuilt + manualAssets
        selectedAssetID = validSelectedAssetID(selectedAssetID)
    }

    private func repairDuplicateSceneIDs() {
        var sceneKeyByID: [UUID: String] = [:]
        let orderedEpisodeIndices = episodes.indices.sorted { lhs, rhs in
            if episodes[lhs].order != episodes[rhs].order {
                return episodes[lhs].order < episodes[rhs].order
            }
            return lhs < rhs
        }

        for episodeIndex in orderedEpisodeIndices {
            for assetIndex in episodes[episodeIndex].extractedAssets.indices
                where episodes[episodeIndex].extractedAssets[assetIndex].kind == .scene {
                let existingID = episodes[episodeIndex].extractedAssets[assetIndex].id
                let key = mergeKey(for: episodes[episodeIndex].extractedAssets[assetIndex])
                if sceneKeyByID[existingID] == nil {
                    sceneKeyByID[existingID] = key
                    continue
                }
                guard sceneKeyByID[existingID] != key else { continue }

                var replacementID = UUID()
                while sceneKeyByID[replacementID] != nil {
                    replacementID = UUID()
                }
                sceneKeyByID[replacementID] = key
                episodes[episodeIndex].extractedAssets[assetIndex].id = replacementID
                episodes[episodeIndex].extractedAssets[assetIndex].updatedAt = .now
                episodes[episodeIndex].updatedAt = .now
            }
        }

        // Manual scenes have no episode row that can disambiguate a duplicate
        // UUID. Preserve the first unique ID and repair any later collision so
        // selection and deletion always address exactly one scene.
        for assetIndex in assets.indices
            where assets[assetIndex].kind == .scene
                && (assets[assetIndex].sourceEpisodeIDs?.isEmpty ?? true) {
                let existingID = assets[assetIndex].id
                let key = mergeKey(for: assets[assetIndex])
                if sceneKeyByID[existingID] == nil {
                    sceneKeyByID[existingID] = key
                    continue
                }
                guard sceneKeyByID[existingID] != key else { continue }

                var replacementID = UUID()
                while sceneKeyByID[replacementID] != nil {
                    replacementID = UUID()
                }
                sceneKeyByID[replacementID] = key
                assets[assetIndex].id = replacementID
                assets[assetIndex].updatedAt = .now
            }
    }

    private func deduplicated(_ items: [AssetItem]) -> [AssetItem] {
        var keys: [String] = []
        var values: [String: AssetItem] = [:]
        for originalItem in items {
            let item = normalizingAssetSummary(originalItem)
            let key = mergeKey(for: item)
            if let existing = values[key] {
                values[key] = mergeAsset(existing, with: item)
            } else {
                keys.append(key)
                values[key] = item
            }
        }
        return keys.compactMap { values[$0] }
    }

    private func mergeAsset(_ existing: AssetItem, with incoming: AssetItem) -> AssetItem {
        var merged = existing
        merged.summary = AssetSummaryConsolidator.consolidate(
            existing.summary,
            incoming.summary
        )
        merged.evidence = combinedText(existing.evidence, incoming.evidence)
        merged.sourceEpisodeIDs = union(
            existing.sourceEpisodeIDs ?? [],
            incoming.sourceEpisodeIDs ?? []
        )
        if merged.canonicalKey?.isEmpty ?? true {
            merged.canonicalKey = incoming.canonicalKey
        }
        let mergedOccurrences = Dictionary(
            ((existing.occurrences ?? []) + (incoming.occurrences ?? [])).map {
                ($0.id, $0)
            },
            uniquingKeysWith: { first, _ in first }
        ).values.sorted {
            if $0.evidence.utf16Location != $1.evidence.utf16Location {
                return $0.evidence.utf16Location < $1.evidence.utf16Location
            }
            return $0.id < $1.id
        }
        merged.occurrences = mergedOccurrences.isEmpty ? nil : mergedOccurrences
        merged.characterProfile = mergedCharacterProfile(
            existing.characterProfile,
            incoming.characterProfile
        )
        merged.sceneProfile = mergedSceneProfile(
            existing.sceneProfile,
            incoming.sceneProfile
        )
        merged.propProfile = mergedPropProfile(
            existing.propProfile,
            incoming.propProfile
        )
        merged.activeWardrobeID = restoredActiveWardrobeID(
            previous: existing,
            replacement: merged
        )
        merged.basePrompt = ""
        merged.searchKeywords = nil
        merged.parameterSelections = [:]
        merged.designDraft = nil
        merged.updatedAt = max(existing.updatedAt, incoming.updatedAt)
        return purifyForExtraction(merged)
    }

    private func applyingCuratedState(
        _ curated: AssetItem,
        to extracted: AssetItem
    ) -> AssetItem {
        let extractedAppearanceCount = extracted.characterProfile?.appearanceCount
        var merged = mergeAsset(extracted, with: curated)
        merged.characterProfile?.appearanceCount = extractedAppearanceCount
        if let affiliation = curated.characterProfile?.affiliation,
           !affiliation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.characterProfile?.affiliation = affiliation
        }
        if let locationGroup = curated.sceneProfile?.locationGroup,
           !locationGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.sceneProfile?.locationGroup = locationGroup
        }
        merged.id = curated.id
        merged.name = curated.name
        merged.reviewState = curated.reviewState
        merged.parameterSelections = [:]
        merged.activeWardrobeID = restoredActiveWardrobeID(
            previous: curated,
            replacement: merged
        )
        return purifyForExtraction(merged)
    }

    private func mergedCharacterProfile(
        _ existing: CharacterProfile?,
        _ incoming: CharacterProfile?
    ) -> CharacterProfile? {
        guard var existing else { return incoming }
        guard let incoming else { return existing }

        let incomingIsMoreImportant = importanceRank(incoming.importance)
            < importanceRank(existing.importance)
        if incomingIsMoreImportant {
            existing.importance = incoming.importance
            existing.narrativeRole = incoming.narrativeRole
        }

        if existing.affiliation?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty ?? true {
            existing.affiliation = incoming.affiliation
        }
        if existing.appearanceCount != nil || incoming.appearanceCount != nil {
            existing.appearanceCount =
                max(existing.appearanceCount ?? 0, 0)
                + max(incoming.appearanceCount ?? 0, 0)
        }

        existing.genderPresentation = preferredDetail(
            existing.genderPresentation,
            incoming.genderPresentation
        )
        existing.ageRange = preferredDetail(existing.ageRange, incoming.ageRange)
        existing.facePrompt = preferredDetail(existing.facePrompt, incoming.facePrompt)
        existing.faceSearchKeywords = preferredSearchKeywords(
            existing.faceSearchKeywords,
            incoming.faceSearchKeywords
        )
        existing.physiquePrompt = preferredDetail(
            existing.physiquePrompt,
            incoming.physiquePrompt
        )
        existing.physiqueSearchKeywords = preferredSearchKeywords(
            existing.physiqueSearchKeywords,
            incoming.physiqueSearchKeywords
        )
        existing.hairMakeupPrompt = preferredDetail(
            existing.hairMakeupPrompt,
            incoming.hairMakeupPrompt
        )
        existing.hairMakeupSearchKeywords = preferredSearchKeywords(
            existing.hairMakeupSearchKeywords,
            incoming.hairMakeupSearchKeywords
        )
        existing.distinguishingFeaturesPrompt = preferredDetail(
            existing.distinguishingFeaturesPrompt,
            incoming.distinguishingFeaturesPrompt
        )
        existing.distinguishingFeaturesSearchKeywords = preferredSearchKeywords(
            existing.distinguishingFeaturesSearchKeywords,
            incoming.distinguishingFeaturesSearchKeywords
        )
        existing.wardrobe = mergedWardrobe(existing.wardrobe, incoming.wardrobe)
        return existing
    }

    private func mergedWardrobe(
        _ existing: [WardrobeLook],
        _ incoming: [WardrobeLook]
    ) -> [WardrobeLook] {
        var result = existing
        for look in incoming {
            let key = wardrobeKey(look)
            if let index = result.firstIndex(where: { wardrobeKey($0) == key }) {
                result[index].storyBeat = combinedText(
                    result[index].storyBeat,
                    look.storyBeat
                )
                result[index].sourceEvidence = combinedText(
                    result[index].sourceEvidence,
                    look.sourceEvidence
                )
                result[index].visualPrompt = preferredDetail(
                    result[index].visualPrompt,
                    look.visualPrompt
                )
                result[index].searchKeywords = preferredSearchKeywords(
                    result[index].searchKeywords,
                    look.searchKeywords
                )
            } else {
                result.append(look)
            }
        }
        return result
    }

    private func mergedSceneProfile(
        _ existing: SceneProfile?,
        _ incoming: SceneProfile?
    ) -> SceneProfile? {
        guard var existing else { return incoming }
        guard let incoming else { return existing }
        if existing.locationGroup?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty ?? true {
            existing.locationGroup = incoming.locationGroup
        }
        existing.timeOfDayID = preferredDetail(existing.timeOfDayID, incoming.timeOfDayID)
        existing.weatherID = preferredDetail(existing.weatherID, incoming.weatherID)
        existing.season = preferredDetail(existing.season, incoming.season)
        existing.period = preferredDetail(existing.period, incoming.period)
        existing.locationType = preferredDetail(existing.locationType, incoming.locationType)
        existing.productionNotes = combinedText(
            existing.productionNotes,
            incoming.productionNotes
        )
        return existing
    }

    private func mergedPropProfile(
        _ existing: PropProfile?,
        _ incoming: PropProfile?
    ) -> PropProfile? {
        guard var existing else { return incoming }
        guard let incoming else { return existing }
        existing.category = preferredDetail(existing.category, incoming.category)
        existing.storyFunction = combinedText(
            existing.storyFunction,
            incoming.storyFunction
        )
        existing.materialPrompt = preferredDetail(
            existing.materialPrompt,
            incoming.materialPrompt
        )
        existing.materialSearchKeywords = preferredSearchKeywords(
            existing.materialSearchKeywords,
            incoming.materialSearchKeywords
        )
        existing.constructionPrompt = preferredDetail(
            existing.constructionPrompt,
            incoming.constructionPrompt
        )
        existing.constructionSearchKeywords = preferredSearchKeywords(
            existing.constructionSearchKeywords,
            incoming.constructionSearchKeywords
        )
        existing.stateChanges = combinedText(
            existing.stateChanges,
            incoming.stateChanges
        )
        return existing
    }

    private func makeScene(
        _ extracted: ExtractedScene,
        episodeID: UUID
    ) -> AssetItem {
        let timeID = validatedOptionID(
            extracted.timeOfDayID,
            parameter: .timeOfDay,
            kind: .scene
        )
        let weatherID = validatedOptionID(
            extracted.weatherID,
            parameter: .weatherAtmosphere,
            kind: .scene
        )
        let locationGroup = cleaned(extracted.locationGroup)

        return AssetItem(
            kind: .scene,
            name: cleanedName(extracted.name, kind: .scene),
            summary: cleaned(extracted.description),
            evidence: cleaned(extracted.evidence),
            basePrompt: "",
            searchKeywords: nil,
            sceneProfile: SceneProfile(
                locationGroup: locationGroup.isEmpty ? nil : locationGroup,
                timeOfDayID: timeID,
                weatherID: weatherID,
                season: cleaned(extracted.season, fallback: "未标明"),
                period: cleaned(extracted.period, fallback: "未标明"),
                locationType: cleaned(extracted.locationType, fallback: "未标明"),
                productionNotes: cleaned(extracted.productionNotes)
            ),
            sourceEpisodeIDs: [episodeID]
        )
    }

    private func makeCharacter(
        _ extracted: ExtractedCharacter,
        episodeID: UUID
    ) -> AssetItem {
        let affiliation = cleaned(extracted.affiliation)
        let wardrobe = (extracted.wardrobes ?? []).enumerated().map { index, look in
            WardrobeLook(
                title: cleaned(look.title, fallback: "服装方案 \(index + 1)"),
                season: cleaned(look.season, fallback: "unspecified"),
                occasion: cleaned(look.occasion, fallback: "unspecified"),
                storyBeat: cleaned(look.storyBeat),
                sourceEvidence: cleaned(look.sourceEvidence),
                visualPrompt: "",
                searchKeywords: nil
            )
        }

        let profile = CharacterProfile(
            importance: extracted.resolvedImportance,
            narrativeRole: extracted.resolvedRole,
            affiliation: affiliation.isEmpty ? nil : affiliation,
            appearanceCount: max(extracted.appearanceCount ?? 1, 1),
            genderPresentation: "未提取",
            ageRange: "未提取",
            facePrompt: "",
            faceSearchKeywords: nil,
            physiquePrompt: "",
            physiqueSearchKeywords: nil,
            hairMakeupPrompt: "",
            hairMakeupSearchKeywords: nil,
            distinguishingFeaturesPrompt: "",
            distinguishingFeaturesSearchKeywords: nil,
            wardrobe: wardrobe
        )

        return AssetItem(
            kind: .character,
            name: cleanedName(extracted.name, kind: .character),
            summary: cleaned(extracted.description),
            evidence: cleaned(extracted.evidence),
            basePrompt: "",
            searchKeywords: nil,
            characterProfile: profile,
            activeWardrobeID: wardrobe.first?.id,
            sourceEpisodeIDs: [episodeID]
        )
    }

    private func makeProp(
        _ extracted: ExtractedProp,
        episodeID: UUID
    ) -> AssetItem {
        AssetItem(
            kind: .prop,
            name: cleanedName(extracted.name, kind: .prop),
            summary: cleaned(extracted.description),
            evidence: cleaned(extracted.evidence),
            basePrompt: "",
            searchKeywords: nil,
            propProfile: PropProfile(
                category: cleaned(extracted.category, fallback: "未分类"),
                storyFunction: cleaned(extracted.storyFunction),
                productionPriority: PropProductionPolicy.priority(
                    name: extracted.name,
                    storyFunction: extracted.storyFunction ?? ""
                ),
                materialPrompt: "",
                materialSearchKeywords: cleaned(extracted.materialSearchKeywords),
                constructionPrompt: "",
                constructionSearchKeywords: cleaned(extracted.constructionSearchKeywords),
                stateChanges: cleaned(extracted.stateChanges)
            ),
            sourceEpisodeIDs: [episodeID]
        )
    }

    private func restoredActiveWardrobeID(
        previous: AssetItem,
        replacement: AssetItem
    ) -> UUID? {
        guard let previousProfile = previous.characterProfile,
              let replacementProfile = replacement.characterProfile
        else {
            return replacement.activeWardrobeID
        }

        let previousLook = previousProfile.wardrobe
            .first(where: { $0.id == previous.activeWardrobeID })
        if let previousLook {
            let key = wardrobeKey(previousLook)
            if let matching = replacementProfile.wardrobe.first(
                where: { wardrobeKey($0) == key }
            ) {
                return matching.id
            }
        }
        return replacementProfile.wardrobe.first?.id
    }

    private func validatedOptionID(
        _ candidate: String?,
        parameter: PromptParameter,
        kind: AssetKind
    ) -> String {
        let available = parameter.options(for: kind).map(\.id)
        if let candidate, available.contains(candidate) {
            return candidate
        }
        return parameter.defaultOptionID(for: kind)
    }

    private func purifyForExtraction(_ asset: AssetItem) -> AssetItem {
        var purified = asset
        purified.basePrompt = ""
        purified.searchKeywords = nil
        purified.designDraft = nil
        purified.parameterSelections = [:]

        if var characterProfile = purified.characterProfile {
            characterProfile.facePrompt = ""
            characterProfile.faceSearchKeywords = nil
            characterProfile.physiquePrompt = ""
            characterProfile.physiqueSearchKeywords = nil
            characterProfile.hairMakeupPrompt = ""
            characterProfile.hairMakeupSearchKeywords = nil
            characterProfile.distinguishingFeaturesPrompt = ""
            characterProfile.distinguishingFeaturesSearchKeywords = nil
            characterProfile.designOptionSelections = nil
            characterProfile.wardrobe = characterProfile.wardrobe.map { look in
                var cleanedLook = look
                cleanedLook.visualPrompt = ""
                cleanedLook.searchKeywords = nil
                return cleanedLook
            }
            purified.characterProfile = characterProfile
        }

        if var propProfile = purified.propProfile {
            propProfile.materialPrompt = ""
            propProfile.materialSearchKeywords = nil
            propProfile.constructionPrompt = ""
            propProfile.constructionSearchKeywords = nil
            purified.propProfile = propProfile
        }

        return purified
    }

    private func validSelectedEpisodeID(_ candidate: UUID?) -> UUID? {
        if let candidate, episodes.contains(where: { $0.id == candidate }) {
            return candidate
        }
        return episodes.first?.id
    }

    private func validSelectedAssetID(_ candidate: UUID?) -> UUID? {
        if let candidate, assets.contains(where: { $0.id == candidate }) {
            return candidate
        }
        return nil
    }

    private func persistCurrentOrEpisode(id: UUID) {
        guard let repository,
              let selectedProjectID,
              let episode = episodes.first(where: { $0.id == id })
        else {
            return
        }

        do {
            try repository.saveEpisode(
                projectID: selectedProjectID,
                episode: episode
            )
            touchCurrentProjectSummary()
            storageNotice = nil
        } catch {
            reportStorageFailure(error)
        }
    }

    private func reportStorageFailure(_ error: Error) {
        storageNotice = "本地自动保存失败。当前内存中的内容仍然保留：\(error.localizedDescription)"
    }

    private func cleanedName(_ value: String, kind: AssetKind) -> String {
        cleaned(value, fallback: "未命名\(kind.title)")
    }

    private func cleaned(_ value: String?, fallback: String = "") -> String {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return result.isEmpty ? fallback : result
    }

    private func englishPrompt(_ value: String?, fallback: String = "") -> String {
        let result = cleaned(value)
        guard PromptCompiler.english(result) else {
            return fallback
        }
        return result.isEmpty ? fallback : result
    }

    private func preferredSearchKeywords(
        _ existing: String?,
        _ incoming: String?
    ) -> String? {
        let current = cleaned(existing)
        let replacement = cleaned(incoming)
        if !replacement.isEmpty {
            return replacement
        }
        return current.isEmpty ? nil : current
    }

    private func preferredDetail(_ existing: String, _ incoming: String) -> String {
        let placeholders = ["", "unspecified", "未标明", "未分类", "none", "script"]
        let normalized = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return placeholders.contains(normalized) ? incoming : existing
    }

    private func combinedText(_ existing: String, _ incoming: String) -> String {
        let first = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let second = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !second.isEmpty else { return first }
        guard !first.isEmpty else { return second }
        guard !first.localizedStandardContains(second) else { return first }
        guard !second.localizedStandardContains(first) else { return second }

        var seen = Set<String>()
        return (first + "\n" + second)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                let key = normalizedKey(line)
                return key.isEmpty || seen.insert(key).inserted
            }
            .joined(separator: "\n")
    }

    private func mergeKey(for asset: AssetItem) -> String {
        AssetMergeIdentity.key(for: asset)
    }

    private func wardrobeKey(_ look: WardrobeLook) -> String {
        AssetMergeIdentity.compositeKey([
            look.title,
            look.season,
            look.occasion,
            look.storyBeat,
            look.visualPrompt
        ])
    }

    private func normalizedKey(_ value: String) -> String {
        AssetMergeIdentity.normalizedKey(value)
    }

    private func importanceRank(_ importance: CharacterImportance) -> Int {
        switch importance {
        case .s: 0
        case .a: 1
        case .b: 2
        case .c: 3
        case .d: 4
        }
    }

    private func union<T: Hashable>(_ first: [T], _ second: [T]) -> [T] {
        var seen = Set<T>()
        return (first + second).filter { seen.insert($0).inserted }
    }

    private static func emptyEpisode(order: Int) -> ScriptEpisode {
        ScriptEpisode(order: order, title: "第 \(order) 集")
    }

    private static func fingerprint(for script: String) -> String {
        ScriptEpisode(order: 0, title: "", scriptText: script).contentFingerprint
    }
}

private struct AnalysisBatchSummary {
    let successCount: Int
    let failureCount: Int
}

private struct EpisodeAnalysisJob: Sendable {
    let episodeID: UUID
    let script: String
    let sourceFingerprint: String
    let existingCheckpoints: [DeepSeekSegmentCheckpoint]

    func run(
        using client: DeepSeekClient,
        existingCatalog: String,
        checkpointHandler: @escaping @Sendable (
            DeepSeekSegmentCheckpoint
        ) async throws -> Void,
        progressHandler: @escaping @MainActor @Sendable (
            EpisodeAnalysisProgress
        ) -> Void
    ) async throws -> EpisodeAnalysisOutcome {
        try Task.checkCancellation()
        do {
            let result = try await client.extractVerifiedInventory(
                from: script,
                episodeID: episodeID,
                sourceFingerprint: sourceFingerprint,
                existingCatalog: existingCatalog,
                existingCheckpoints: existingCheckpoints,
                checkpointHandler: checkpointHandler,
                progress: progressHandler
            )
            try Task.checkCancellation()
            return .success(
                episodeID: episodeID,
                sourceCharacterCount: script.count,
                result: result
            )
        } catch {
            try Task.checkCancellation()
            return .failure(
                episodeID: episodeID,
                message: error.localizedDescription
            )
        }
    }
}

private enum EpisodeAnalysisOutcome: Sendable {
    case success(
        episodeID: UUID,
        sourceCharacterCount: Int,
        result: DeepSeekExtractionResult
    )
    case failure(
        episodeID: UUID,
        message: String
    )

    var episodeID: UUID {
        switch self {
        case .success(let episodeID, _, _), .failure(let episodeID, _):
            episodeID
        }
    }
}

private extension JSONDecoder {
    static var workspaceDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum WorkspaceError: LocalizedError {
    case emptyScript
    case analysisTargetMismatch(expected: Int, actual: Int)
    case missingAPIKey
    case missingCompatibleAPIKey
    case invalidCompatibleURL
    case missingCompatibleModel
    case fileTooLarge
    case unsupportedEncoding
    case ambiguousEpisodeSplit([String])
    case scriptIntegrityViolation
    case extractedEpisodeRequiresManualRepartition(String)

    var errorDescription: String? {
        switch self {
        case .emptyScript:
            "请先粘贴或导入当前分集的剧本文本。"
        case .analysisTargetMismatch(let expected, let actual):
            "安全校验失败：已确认 \(expected) 集，但只能生成 \(actual) 个分析任务。模型调用已阻止，请重新分集确认。"
        case .missingAPIKey:
            "请先在“设置”中保存 DeepSeek API Key。"
        case .missingCompatibleAPIKey:
            "请先在“设置”中保存 OpenAI 兼容接口的 API Key。"
        case .invalidCompatibleURL:
            "请先在“设置”中填写有效的 OpenAI 兼容接口 URL。"
        case .missingCompatibleModel:
            "请先在“设置”中填写 OpenAI 兼容接口的模型 ID。"
        case .fileTooLarge:
            "剧本文件超过 128 MB。为避免应用内存不足，请先拆成多个原始文件；应用不会截断或部分导入。"
        case .unsupportedEncoding:
            "无法读取此文本编码，请将文件另存为 UTF-8 后重试。"
        case .ambiguousEpisodeSplit(let diagnostics):
            "检测到可能重复或回跳的分集边界，已保留原文且没有拆分：\(diagnostics.joined(separator: "；"))"
        case .scriptIntegrityViolation:
            "分集守恒校验失败：拆分片段无法逐字符还原原剧本。已中止并保留原始数据。"
        case .extractedEpisodeRequiresManualRepartition(let title):
            "“\(title)”已有提取快照。为避免自动分集时错误迁移或删除资产，已保留原数据；请新建空白分集或项目后导入整部剧本。"
        }
    }
}
