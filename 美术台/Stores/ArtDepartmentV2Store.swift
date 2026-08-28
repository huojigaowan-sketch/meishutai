import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ArtDepartmentV2Store {
    var document: ArtDepartmentWorkspaceDocument = .empty
    var selectedProjectID: UUID?
    var selectedSection: ArtWorkspaceSection = .script
    var selectedAssetID: UUID?
    var selectedAssetKind: ProductionAssetKind = .scene
    var selectedStyleCardIDs: [UUID] = []
    var externalStyleTitle = ""
    var externalStylePrompt = ""
    var externalStyleCategory: StylePromptCategory = .general
    var styleImageDataByPath: [String: Data] = [:]
    var generationMode: ImageGenerationMode = .textToImage
    var generationDirection = ""
    var promptPlan: ArtPromptPlan = .empty
    var generationRecipe: ImageGenerationRecipe = .arkDefault
    var generationReferencePath: String?
    var isWorking = false
    var progress: PipelineProgress = .idle
    var errorMessage: String?
    var noticeMessage: String?
    var showsDiagnostics = false
    var selectedStyleNodeID: UUID?
    var styleSearchText = ""
    var showsArchivedStyles = false
    var activeExternalStyleDraftID: UUID?
    var styleSampleLoadingIDs: Set<UUID> = []
    var styleSampleFailedIDs: Set<UUID> = []
    @ObservationIgnored var externalDraftSaveTask: Task<Void, Never>?

    @ObservationIgnored let persistence = ArtDepartmentPersistence.shared

    var projects: [ArtDepartmentProject] { document.projects }
    var styleCards: [StylePromptCard] { document.styleCards }

    var currentProject: ArtDepartmentProject? {
        guard let selectedProjectID else { return document.projects.first }
        return document.projects.first { $0.id == selectedProjectID }
    }

    /// The production library contains only automatically accepted assets. Low
    /// confidence candidates are retained in diagnostics, never presented as a
    /// task a person must approve.
    var filteredAssets: [ProductionAsset] {
        currentProject?.assets.filter {
            $0.kind == selectedAssetKind && $0.isUsable
        } ?? []
    }

    var diagnosticAssets: [ProductionAsset] {
        currentProject?.assets.filter {
            $0.isQuarantined || $0.reviewDecision == .rejected
        } ?? []
    }

    var selectedAsset: ProductionAsset? {
        guard let selectedAssetID,
              let selected = currentProject?.assets.first(where: {
                  $0.id == selectedAssetID && $0.kind == selectedAssetKind && $0.isUsable
              })
        else { return filteredAssets.first }
        return selected
    }

    var selectedStyleCards: [StylePromptCard] {
        document.styleCards.filter { selectedStyleCardIDs.contains($0.id) && !$0.isArchived }
    }

    var hasExplicitStyleSelection: Bool {
        StyleSelectionPolicy.hasExplicitSelection(
            selectedStyleCardIDs: selectedStyleCardIDs,
            externalPrompt: externalStylePrompt
        )
    }

    func styleImage(for relativePath: String?) -> NSImage? {
        guard let relativePath,
              let data = styleImageDataByPath[relativePath]
        else { return nil }
        return NSImage(data: data)
    }

    var activeEngineStatus: AppleEngineStatusSnapshot? {
        currentProject?.engineStatus
    }

    init() {}

    func load() async {
        do {
            document = try await persistence.load()
            migrateToAutomaticPipeline()
            if document.projects.isEmpty { addProject() }
            selectedProjectID = selectedProjectID.flatMap { id in
                document.projects.contains(where: { $0.id == id }) ? id : nil
            } ?? document.projects.first?.id
            synchronizeSelections()
            await reloadStyleImageCache()
            restoreExternalStyleDraft()
            await refreshEngineStatus()
            await persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addProject() {
        let project = ArtDepartmentProject(title: "美术项目 \(document.projects.count + 1)")
        document.projects.insert(project, at: 0)
        selectedProjectID = project.id
        selectedSection = .script
        selectedAssetID = nil
        promptPlan = .empty
        Task {
            await refreshEngineStatus()
            await persist()
        }
    }

    func deleteCurrentProject() {
        guard let id = currentProject?.id else { return }
        document.projects.removeAll { $0.id == id }
        if document.projects.isEmpty {
            document.projects.append(ArtDepartmentProject(title: "美术项目 1"))
        }
        selectedProjectID = document.projects.first?.id
        synchronizeSelections()
        Task { await persist() }
    }

    func selectProject(_ id: UUID) {
        selectedProjectID = id
        synchronizeSelections()
        promptPlan = .empty
    }

    func updateProjectTitle(_ title: String) {
        mutateProject {
            $0.title = title
            $0.updatedAt = .now
        }
        Task { await persist() }
    }

    func updateSourceText(_ text: String) {
        mutateProject {
            $0.sourceText = text
            $0.sourceFingerprint = SourceUnitBuilder.fingerprint(text)
            $0.pipelineStage = .source
            $0.canonicalScenes = []
            $0.canonicalFountain = ""
            $0.normalizationAudit = nil
            $0.assets = []
            $0.automationSummary = nil
            $0.reliabilityAudit = nil
            $0.updatedAt = .now
        }
        synchronizeSelections()
    }

    func updateCanonicalFountain(_ text: String) {
        mutateProject {
            $0.canonicalFountain = text
            $0.canonicalScenes = CanonicalFountainParser.parse(text)
            $0.pipelineStage = $0.canonicalScenes.isEmpty ? .source : .canonical
            $0.assets = []
            $0.automationSummary = nil
            $0.reliabilityAudit = nil
            $0.updatedAt = .now
        }
        synchronizeSelections()
    }

    func importScript(from url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let text = try await AppleScriptDocumentReader.shared.read(url)
            mutateProject {
                $0.sourceText = text
                $0.sourceFileName = url.lastPathComponent
                $0.sourceFingerprint = SourceUnitBuilder.fingerprint(text)
                $0.pipelineStage = .source
                $0.canonicalScenes = []
                $0.canonicalFountain = ""
                $0.normalizationAudit = nil
                $0.assets = []
                $0.automationSummary = nil
                $0.updatedAt = .now
            }
            noticeMessage = "已通过 Apple 文档读取管线导入 \(url.lastPathComponent)，原文保持不变。"
            await persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runFullPipeline() async {
        guard let project = currentProject else {
            errorMessage = ArtDepartmentV2Error.noProject.localizedDescription
            return
        }
        guard !project.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = ArtDepartmentV2Error.emptySource.localizedDescription
            return
        }
        await runWork {
            let client = remoteClientIfConfigured()
            let configurationName = (try? ArtLLMConfiguration.current().model) ?? ""
            mutateProject { $0.pipelineStage = .normalizing }
            let normalized = try await ArtDepartmentV2Pipeline.normalizeScript(
                sourceText: project.sourceText,
                client: client,
                modelName: configurationName,
                progress: { [weak self] value in
                    self?.progress = value
                }
            )
            mutateProject {
                $0.canonicalScenes = normalized.scenes
                $0.canonicalFountain = normalized.fountain
                $0.normalizationAudit = normalized.audit
                $0.engineStatus = normalized.engineStatus
                $0.pipelineStage = .extracting
                $0.assets = []
                $0.automationSummary = nil
                $0.updatedAt = .now
            }
            let extracted = try await ArtDepartmentV2Pipeline.extractAssets(
                scenes: normalized.scenes,
                client: client,
                progress: { [weak self] value in
                    self?.progress = value
                }
            )
            mutateProject {
                $0.assets = extracted.assets
                $0.automationSummary = extracted.summary
                $0.reliabilityAudit = extracted.audit
                $0.engineStatus = extracted.engineStatus
                $0.pipelineStage = .completed
                $0.updatedAt = .now
            }
            synchronizeSelections()
            selectedSection = .assets
            noticeMessage = automationNotice(extracted.summary)
            await persist()
        }
    }

    func normalizeCurrentScript() async {
        guard let project = currentProject else {
            errorMessage = ArtDepartmentV2Error.noProject.localizedDescription
            return
        }
        guard !project.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = ArtDepartmentV2Error.emptySource.localizedDescription
            return
        }
        await runWork {
            let client = remoteClientIfConfigured()
            let configurationName = (try? ArtLLMConfiguration.current().model) ?? ""
            mutateProject { $0.pipelineStage = .normalizing }
            let result = try await ArtDepartmentV2Pipeline.normalizeScript(
                sourceText: project.sourceText,
                client: client,
                modelName: configurationName,
                progress: { [weak self] value in
                    self?.progress = value
                }
            )
            mutateProject {
                $0.canonicalScenes = result.scenes
                $0.canonicalFountain = result.fountain
                $0.normalizationAudit = result.audit
                $0.engineStatus = result.engineStatus
                $0.pipelineStage = .canonical
                $0.assets = []
                $0.automationSummary = nil
                $0.updatedAt = .now
            }
            noticeMessage = "标准化完成：\(result.scenes.count) 场，证据覆盖 \(result.audit.coveredSourceUnitCount)/\(result.audit.sourceUnitCount)。"
            await persist()
        }
    }

    func extractCurrentAssets() async {
        guard let project = currentProject else {
            errorMessage = ArtDepartmentV2Error.noProject.localizedDescription
            return
        }
        let scenes = project.canonicalScenes.isEmpty
            ? CanonicalFountainParser.parse(project.canonicalFountain)
            : project.canonicalScenes
        guard !scenes.isEmpty else {
            errorMessage = ArtDepartmentV2Error.noCanonicalScenes.localizedDescription
            return
        }
        await runWork {
            let client = remoteClientIfConfigured()
            mutateProject { $0.pipelineStage = .adjudicating }
            let result = try await ArtDepartmentV2Pipeline.extractAssets(
                scenes: scenes,
                client: client,
                progress: { [weak self] value in
                    self?.progress = value
                }
            )
            mutateProject {
                $0.canonicalScenes = scenes
                $0.assets = result.assets
                $0.automationSummary = result.summary
                $0.reliabilityAudit = result.audit
                $0.engineStatus = result.engineStatus
                $0.pipelineStage = .completed
                $0.updatedAt = .now
            }
            synchronizeSelections()
            noticeMessage = automationNotice(result.summary)
            await persist()
        }
    }

    func addStyleCard(
        title: String,
        prompt: String,
        category: StylePromptCategory,
        tags: [String],
        notes: String,
        imageURL: URL?
    ) async {
        let cleanTitle: String
        let cleanPrompt: String
        do {
            cleanTitle = try StyleOnlyPromptPolicy.validatedUserTitle(title)
            cleanPrompt = try StyleOnlyPromptPolicy.validatedUserPrompt(prompt)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        var card = StylePromptCard(
            title: cleanTitle,
            prompt: cleanPrompt,
            category: category,
            tags: tags,
            notes: notes
        )
        do {
            if let imageURL {
                let accessing = imageURL.startAccessingSecurityScopedResource()
                defer { if accessing { imageURL.stopAccessingSecurityScopedResource() } }
                let imageData = try Data(contentsOf: imageURL)
                if let duplicate = try await nearestDuplicateStyle(for: imageData) {
                    selectedStyleCardIDs = [duplicate.id]
                    noticeMessage = "该参考图与“\(duplicate.title)”高度相似，已直接复用现有风格卡。"
                    return
                }
                card.referenceImagePath = try await persistence.importStyleImage(
                    from: imageURL,
                    cardID: card.id
                )
                if let path = card.referenceImagePath {
                    styleImageDataByPath[path] = imageData
                }
                let signature = try? await AppleVisionAnalyzer.shared.signature(for: imageData)
                card.visionFingerprintBase64 = signature?.featurePrintBase64
            }
            document.styleCards.insert(card, at: 0)
            selectedStyleCardIDs = [card.id]
            noticeMessage = "风格卡已保存到 AES-GCM 加密图书馆；参考图由 Apple Vision 建立本地相似度签名。"
            await persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateStyleCard(_ card: StylePromptCard) {
        guard let index = document.styleCards.firstIndex(where: { $0.id == card.id }),
              !document.styleCards[index].isBuiltIn
        else { return }
        do {
            var card = card
            card.title = try StyleOnlyPromptPolicy.validatedUserTitle(card.title)
            card.prompt = try StyleOnlyPromptPolicy.validatedUserPrompt(card.prompt)
            card.updatedAt = .now
            document.styleCards[index] = card
            Task { await persist() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteStyleCard(_ id: UUID) {
        guard let card = document.styleCards.first(where: { $0.id == id }),
              !card.isBuiltIn else { return }
        if let path = card.referenceImagePath {
            styleImageDataByPath.removeValue(forKey: path)
        }
        document.styleCards.removeAll { $0.id == id }
        selectedStyleCardIDs.removeAll { $0 == id }
        Task {
            try? await persistence.deleteStyleImage(at: card.referenceImagePath)
            await persist()
        }
    }

    func toggleStyleSelection(_ id: UUID) {
        if selectedStyleCardIDs.contains(id) {
            selectedStyleCardIDs.removeAll { $0 == id }
        } else {
            selectedStyleCardIDs.append(id)
        }
    }

    func saveExternalStyleToLibrary() {
        promoteExternalStyleDraft()
    }

    func importGenerationReference(_ url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            generationReferencePath = try await persistence.importStyleImage(
                from: url,
                cardID: UUID()
            )
            noticeMessage = "已加密保存本轮参考图。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func planGenerationPrompt() async {
        guard let asset = selectedAsset else {
            errorMessage = ArtDepartmentV2Error.noSelectedAsset.localizedDescription
            return
        }
        await runWork {
            try validateExternalStyleInput()
            let cards = resolveStyleCards()
            guard !cards.isEmpty else { throw ArtDepartmentV2Error.noSelectedStyle }
            let client = remoteClientIfConfigured()
            promptPlan = try await ArtDepartmentV2Pipeline.makePromptPlan(
                asset: asset,
                styleCards: cards,
                mode: generationMode,
                direction: generationDirection,
                client: client
            )
            noticeMessage = "已按“剧本资产设计 + 用户选择的纯视觉风格”生成双层生图计划。"
        }
    }

    func generateImages() async {
        guard let project = currentProject,
              let asset = selectedAsset else {
            errorMessage = ArtDepartmentV2Error.noSelectedAsset.localizedDescription
            return
        }
        await runWork {
            try validateExternalStyleInput()
            let cards = resolveStyleCards()
            guard !cards.isEmpty else { throw ArtDepartmentV2Error.noSelectedStyle }
            if promptPlan.requiresRebuild(
                for: asset,
                styleCards: cards,
                mode: generationMode
            ) {
                promptPlan = try await ArtDepartmentV2Pipeline.makePromptPlan(
                    asset: asset,
                    styleCards: cards,
                    mode: generationMode,
                    direction: generationDirection,
                    client: remoteClientIfConfigured()
                )
                }

            let configuration = try ArkImageConfiguration.current()
            var references: [Data] = []
            // Style samples are preview-only. Sending them as provider references
            // would let a sample's person, place or object contaminate the asset.
            if GenerationReferencePolicy.shouldSendToProvider(.userContentReference),
               let data = try await persistence.data(for: generationReferencePath)
            {
                references.append(data)
            }
            var recipe = generationRecipe
            if recipe.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                recipe.model = configuration.model
            }
            progress = .init(
                title: "Ark 生图",
                detail: "基于自动核验资产与用户明确选择的风格生成",
                current: 0,
                total: max(1, recipe.maxImages)
            )
            let payloads = try await ArkImageGenerationClient(
                configuration: configuration
            ).generate(
                prompt: promptPlan.positivePrompt,
                negativePrompt: promptPlan.negativePrompt,
                recipe: recipe,
                referenceImages: references
            )
            var records: [GeneratedImageRecord] = []
            for (offset, payload) in payloads.enumerated() {
                let id = UUID()
                let path = try await persistence.saveGeneratedImage(
                    payload.data,
                    projectID: project.id,
                    imageID: id,
                    fileExtension: payload.fileExtension
                )
                records.append(GeneratedImageRecord(
                    id: id,
                    projectID: project.id,
                    assetID: asset.id,
                    styleCardIDs: cards.map(\.id),
                    promptPlan: promptPlan,
                    recipe: recipe,
                    localImagePath: path,
                    providerRequestID: payload.requestID
                ))
                progress = .init(
                    title: "Ark 生图",
                    detail: "已保存 \(offset + 1) / \(payloads.count)",
                    current: offset + 1,
                    total: payloads.count
                )
            }
            if let firstPayload = payloads.first {
                await attachGeneratedSampleToActiveExperiment(firstPayload.data)
            }
            mutateProject {
                $0.generatedImages.insert(contentsOf: records, at: 0)
                $0.updatedAt = .now
            }
            noticeMessage = "已生成并本地保存 \(records.count) 张图。"
            await persist()
        }
    }

    func imageURL(for relativePath: String?) -> URL? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
        return support
            .appending(path: "MeishutaiV2", directoryHint: .isDirectory)
            .appending(path: relativePath)
    }

    func fountainExportData() -> Data? {
        currentProject?.canonicalFountain.data(using: .utf8)
    }

    func fdxExportData() -> Data? {
        guard let project = currentProject else { return nil }
        return FinalDraftFDXExporter.data(
            scenes: project.canonicalScenes,
            title: project.title
        )
    }

    func assetJSONExportData() -> Data? {
        guard let project = currentProject else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(project.usableAssets)
    }

    // MARK: - Private

    private func reloadStyleImageCache() async {
        var cache: [String: Data] = [:]
        for card in document.styleCards {
            for sample in card.styleSampleMedia {
                guard let path = sample.encryptedLocalPath,
                      let data = try? await persistence.data(for: path)
                else { continue }
                cache[path] = data
            }
        }
        styleImageDataByPath = cache
    }

    private func refreshEngineStatus() async {
        let status = await AppleStructuredExtractionEngine.shared.status(
            remoteAvailable: remoteClientIfConfigured() != nil
        )
        mutateProject {
            $0.engineStatus = status
            $0.updatedAt = .now
        }
    }

    private func remoteClientIfConfigured() -> ArtChatCompletionClient? {
        guard let configuration = try? ArtLLMConfiguration.current() else { return nil }
        return ArtChatCompletionClient(configuration: configuration)
    }

    private func validateExternalStyleInput() throws {
        let prompt = externalStylePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        _ = try StyleOnlyPromptPolicy.validatedUserPrompt(prompt)
        let title = externalStyleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            _ = try StyleOnlyPromptPolicy.validatedUserTitle(title)
        }
    }

    private func resolveStyleCards() -> [StylePromptCard] {
        var cards = selectedStyleCards.map {
            StylePromptResolver.resolvedCard($0, in: document.styleCards)
        }
        let prompt = externalStylePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty {
            if let draftID = activeExternalStyleDraftID,
               let draft = document.styleCards.first(where: { $0.id == draftID }),
               !cards.contains(where: { $0.id == draftID })
            {
                cards.append(StylePromptResolver.resolvedCard(draft, in: document.styleCards))
            } else if activeExternalStyleDraftID == nil {
                let title = externalStyleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                cards.append(StylePromptCard(
                    id: StyleSelectionPolicy.temporaryCardID,
                    title: title.isEmpty ? "本轮外部风格" : title,
                    prompt: prompt,
                    category: externalStyleCategory,
                    tags: ["持久化准备中", "用户明确选择"],
                    notes: "输入会自动保存为实验分支。",
                    lifecycleRawValue: StylePromptLifecycle.experiment.rawValue,
                    sampleMedia: [],
                    isPromptLocked: false
                ))
            }
        }
        return cards
    }

    private func nearestDuplicateStyle(
        for imageData: Data
    ) async throws -> StylePromptCard? {
        var best: (StylePromptCard, Double)?
        for card in document.styleCards {
            guard let existing = try await persistence.data(for: card.referenceImagePath) else {
                continue
            }
            guard let distance = try? await AppleVisionAnalyzer.shared.distance(
                between: imageData,
                and: existing
            ) else { continue }
            if best == nil || distance < best!.1 { best = (card, distance) }
        }
        guard let best, best.1 < 0.035 else { return nil }
        return best.0
    }

    private func automationNotice(
        _ summary: AssetAutomationSummary
    ) -> String {
        "自动完成：\(summary.sceneCount) 场景、\(summary.characterCount) 人物、\(summary.propCount) 道具。另有 \(summary.quarantinedCount) 项低证据候选已自动隔离，不需要人工处理。"
    }

    private func synchronizeSelections() {
        guard currentProject != nil else {
            selectedAssetID = nil
            return
        }
        if let selectedAssetID,
           filteredAssets.contains(where: { $0.id == selectedAssetID })
        {
            return
        }
        selectedAssetID = filteredAssets.first?.id
    }

    private func mutateProject(
        _ body: (inout ArtDepartmentProject) -> Void
    ) {
        guard let id = currentProject?.id,
              let index = document.projects.firstIndex(where: { $0.id == id })
        else { return }
        body(&document.projects[index])
        document.updatedAt = .now
    }

    private func migrateToAutomaticPipeline() {
        document.schemaVersion = max(6, document.schemaVersion)
        for projectIndex in document.projects.indices {
            if document.projects[projectIndex].pipelineStage == .reviewing {
                document.projects[projectIndex].pipelineStage = .adjudicating
            }
            for assetIndex in document.projects[projectIndex].assets.indices {
                var asset = document.projects[projectIndex].assets[assetIndex]
                if asset.reviewDecision == .pending {
                    let exact = asset.sourceEvidence.contains {
                        !$0.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }
                    asset.reviewDecision = exact && asset.validatedConfidence >= 0.68
                        ? .accepted
                        : .conflict
                    if asset.verificationReport == nil {
                        asset.verificationReport = AssetVerificationReport(
                            engines: ["V2 evidence migration"],
                            consensusCount: 1,
                            exactEvidenceScore: exact ? 1 : 0,
                            schemaCompleteness: asset.validatedConfidence,
                            linguisticSupport: 0,
                            deterministicSupport: asset.modelConfidence >= 0.99,
                            reason: "旧数据按逐字证据和原置信度自动迁移。"
                        )
                    }
                    document.projects[projectIndex].assets[assetIndex] = asset
                }
            }
            if !document.projects[projectIndex].assets.isEmpty {
                document.projects[projectIndex].pipelineStage = .completed
            }
        }
    }

    func persist() async {
        do {
            try await persistence.save(document)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runWork(
        _ operation: () async throws -> Void
    ) async {
        guard !isWorking else { return }
        isWorking = true
        progress = .idle
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await operation()
        } catch {
            mutateProject {
                $0.pipelineStage = .failed
                $0.updatedAt = .now
            }
            errorMessage = error.localizedDescription
            await persist()
        }
    }
}
