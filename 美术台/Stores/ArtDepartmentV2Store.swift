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
    var generationMode: ImageGenerationMode = .textToImage
    var generationDirection = ""
    var promptPlan: ArtPromptPlan = .empty
    var generationRecipe: ImageGenerationRecipe = .arkDefault
    var generationReferencePath: String?
    var isWorking = false
    var progress: PipelineProgress = .idle
    var errorMessage: String?
    var noticeMessage: String?

    @ObservationIgnored private let persistence = ArtDepartmentPersistence.shared

    var projects: [ArtDepartmentProject] { document.projects }
    var styleCards: [StylePromptCard] { document.styleCards }

    var currentProject: ArtDepartmentProject? {
        guard let selectedProjectID else { return document.projects.first }
        return document.projects.first { $0.id == selectedProjectID }
    }

    var filteredAssets: [ProductionAsset] {
        currentProject?.assets.filter { $0.kind == selectedAssetKind && $0.reviewDecision != .rejected } ?? []
    }

    var selectedAsset: ProductionAsset? {
        guard let selectedAssetID,
              let selected = currentProject?.assets.first(where: {
                  $0.id == selectedAssetID
                    && $0.kind == selectedAssetKind
                    && $0.reviewDecision != .rejected
              }) else {
            return filteredAssets.first
        }
        return selected
    }

    var selectedStyleCards: [StylePromptCard] {
        document.styleCards.filter { selectedStyleCardIDs.contains($0.id) }
    }

    init() {}

    func load() async {
        do {
            document = try await persistence.load()
            if document.projects.isEmpty { addProject() }
            selectedProjectID = selectedProjectID.flatMap { id in document.projects.contains(where: { $0.id == id }) ? id : nil }
                ?? document.projects.first?.id
            synchronizeSelections()
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
        Task { await persist() }
    }

    func deleteCurrentProject() {
        guard let id = currentProject?.id else { return }
        document.projects.removeAll { $0.id == id }
        if document.projects.isEmpty { document.projects.append(ArtDepartmentProject(title: "美术项目 1")) }
        selectedProjectID = document.projects.first?.id
        synchronizeSelections()
        Task { await persist() }
    }

    func selectProject(_ id: UUID) {
        selectedProjectID = id
        synchronizeSelections()
    }

    func updateProjectTitle(_ title: String) {
        mutateProject { $0.title = title; $0.updatedAt = .now }
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
            $0.updatedAt = .now
        }
    }

    func updateCanonicalFountain(_ text: String) {
        mutateProject {
            $0.canonicalFountain = text
            $0.canonicalScenes = CanonicalFountainParser.parse(text)
            $0.pipelineStage = $0.canonicalScenes.isEmpty ? .source : .canonical
            $0.assets = []
            $0.updatedAt = .now
        }
    }

    func importScript(from url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let text = try ScriptFileReader.read(url)
            mutateProject {
                $0.sourceText = text
                $0.sourceFileName = url.lastPathComponent
                $0.sourceFingerprint = SourceUnitBuilder.fingerprint(text)
                $0.pipelineStage = .source
                $0.canonicalScenes = []
                $0.canonicalFountain = ""
                $0.normalizationAudit = nil
                $0.assets = []
                $0.updatedAt = .now
            }
            noticeMessage = "已导入 \(url.lastPathComponent)，原文保持不变。"
            await persist()
        } catch { errorMessage = error.localizedDescription }
    }

    func normalizeCurrentScript() async {
        guard let project = currentProject else { errorMessage = ArtDepartmentV2Error.noProject.localizedDescription; return }
        let source = project.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { errorMessage = ArtDepartmentV2Error.emptySource.localizedDescription; return }
        await runWork {
            let configuration = try ArtLLMConfiguration.current()
            mutateProject { $0.pipelineStage = .normalizing }
            let result = try await ArtDepartmentV2Pipeline.normalizeScript(
                sourceText: project.sourceText,
                client: ArtChatCompletionClient(configuration: configuration),
                modelName: configuration.model,
                progress: { [weak self] value in await MainActor.run { self?.progress = value } }
            )
            mutateProject {
                $0.canonicalScenes = result.scenes
                $0.canonicalFountain = result.fountain
                $0.normalizationAudit = result.audit
                $0.pipelineStage = .canonical
                $0.assets = []
                $0.updatedAt = .now
            }
            noticeMessage = "标准化完成：\(result.scenes.count) 场，原文证据覆盖 \(result.audit.coveredSourceUnitCount)/\(result.audit.sourceUnitCount)。"
            await persist()
        }
    }

    func extractCurrentAssets() async {
        guard let project = currentProject else { errorMessage = ArtDepartmentV2Error.noProject.localizedDescription; return }
        let scenes = project.canonicalScenes.isEmpty ? CanonicalFountainParser.parse(project.canonicalFountain) : project.canonicalScenes
        guard !scenes.isEmpty else { errorMessage = ArtDepartmentV2Error.noCanonicalScenes.localizedDescription; return }
        await runWork {
            let configuration = try ArtLLMConfiguration.current()
            mutateProject { $0.pipelineStage = .extracting }
            let assets = try await ArtDepartmentV2Pipeline.extractAssets(
                scenes: scenes,
                client: ArtChatCompletionClient(configuration: configuration),
                progress: { [weak self] value in await MainActor.run { self?.progress = value } }
            )
            mutateProject {
                $0.canonicalScenes = scenes
                $0.assets = assets
                $0.pipelineStage = .reviewing
                $0.updatedAt = .now
            }
            synchronizeSelections()
            noticeMessage = "提取完成：\(assets.filter { $0.kind == .scene }.count) 场景、\(assets.filter { $0.kind == .character }.count) 人物、\(assets.filter { $0.kind == .prop }.count) 道具。"
            await persist()
        }
    }

    func setAssetDecision(_ decision: AssetReviewDecision, assetID: UUID) {
        mutateProject { project in
            guard let index = project.assets.firstIndex(where: { $0.id == assetID }) else { return }
            project.assets[index].reviewDecision = decision
            project.updatedAt = .now
            let remaining = project.assets.contains { $0.reviewDecision == .pending || $0.reviewDecision == .conflict }
            if !remaining { project.pipelineStage = .completed }
        }
        Task { await persist() }
    }

    func updateAsset(_ updated: ProductionAsset) {
        mutateProject { project in
            guard let index = project.assets.firstIndex(where: { $0.id == updated.id }) else { return }
            project.assets[index] = updated
            project.updatedAt = .now
        }
        Task { await persist() }
    }

    func addStyleCard(title: String, prompt: String, category: StylePromptCategory, tags: [String], notes: String, imageURL: URL?) async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanPrompt.isEmpty else { return }
        var card = StylePromptCard(title: cleanTitle, prompt: cleanPrompt, category: category, tags: tags, notes: notes)
        do {
            if let imageURL {
                let accessing = imageURL.startAccessingSecurityScopedResource()
                defer { if accessing { imageURL.stopAccessingSecurityScopedResource() } }
                card.referenceImagePath = try await persistence.importStyleImage(from: imageURL, cardID: card.id)
            }
            document.styleCards.insert(card, at: 0)
            selectedStyleCardIDs = [card.id]
            await persist()
        } catch { errorMessage = error.localizedDescription }
    }

    func updateStyleCard(_ card: StylePromptCard) {
        guard let index = document.styleCards.firstIndex(where: { $0.id == card.id }) else { return }
        var card = card
        card.updatedAt = .now
        document.styleCards[index] = card
        Task { await persist() }
    }

    func deleteStyleCard(_ id: UUID) {
        guard let card = document.styleCards.first(where: { $0.id == id }), !card.isBuiltIn else { return }
        document.styleCards.removeAll { $0.id == id }
        selectedStyleCardIDs.removeAll { $0 == id }
        Task { await persist() }
    }

    func toggleStyleSelection(_ id: UUID) {
        if selectedStyleCardIDs.contains(id) { selectedStyleCardIDs.removeAll { $0 == id } }
        else { selectedStyleCardIDs.append(id) }
    }

    func importGenerationReference(_ url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            generationReferencePath = try await persistence.importStyleImage(from: url, cardID: UUID())
        } catch { errorMessage = error.localizedDescription }
    }

    func planGenerationPrompt() async {
        guard let asset = selectedAsset else { errorMessage = ArtDepartmentV2Error.noSelectedAsset.localizedDescription; return }
        let cards = selectedStyleCards
        guard !cards.isEmpty else { errorMessage = ArtDepartmentV2Error.noSelectedStyle.localizedDescription; return }
        await runWork {
            let client: ArtChatCompletionClient?
            if let configuration = try? ArtLLMConfiguration.current() { client = ArtChatCompletionClient(configuration: configuration) }
            else { client = nil }
            promptPlan = try await ArtDepartmentV2Pipeline.makePromptPlan(asset: asset, styleCards: cards, mode: generationMode, direction: generationDirection, client: client)
            noticeMessage = "生图提示词已生成。请审阅材质、构图、元素和锁定事实后再调用 Ark。"
        }
    }

    func generateImages() async {
        guard let project = currentProject, let asset = selectedAsset else { errorMessage = ArtDepartmentV2Error.noSelectedAsset.localizedDescription; return }
        guard !promptPlan.positivePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = "请先生成或填写生图提示词。"; return }
        await runWork {
            let configuration = try ArkImageConfiguration.current()
            var references: [Data] = []
            for card in selectedStyleCards {
                if let data = try await persistence.data(for: card.referenceImagePath) { references.append(data) }
            }
            if let data = try await persistence.data(for: generationReferencePath) { references.append(data) }
            var recipe = generationRecipe
            if recipe.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { recipe.model = configuration.model }
            progress = .init(title: "Ark 生图", detail: "正在根据已审阅提示词生成", current: 0, total: max(1, recipe.maxImages))
            let payloads = try await ArkImageGenerationClient(configuration: configuration).generate(
                prompt: promptPlan.positivePrompt,
                negativePrompt: promptPlan.negativePrompt,
                recipe: recipe,
                referenceImages: references
            )
            var records: [GeneratedImageRecord] = []
            for (offset, payload) in payloads.enumerated() {
                let id = UUID()
                let path = try await persistence.saveGeneratedImage(payload.data, projectID: project.id, imageID: id, fileExtension: payload.fileExtension)
                records.append(GeneratedImageRecord(id: id, projectID: project.id, assetID: asset.id, styleCardIDs: selectedStyleCardIDs, promptPlan: promptPlan, recipe: recipe, localImagePath: path, providerRequestID: payload.requestID))
                progress = .init(title: "Ark 生图", detail: "已保存 \(offset + 1) / \(payloads.count)", current: offset + 1, total: payloads.count)
            }
            mutateProject { $0.generatedImages.insert(contentsOf: records, at: 0); $0.updatedAt = .now }
            noticeMessage = "已生成并本地保存 \(records.count) 张图。"
            await persist()
        }
    }

    func imageURL(for relativePath: String?) -> URL? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        return support.appending(path: "MeishutaiV2", directoryHint: .isDirectory).appending(path: relativePath)
    }

    func fountainExportData() -> Data? { currentProject?.canonicalFountain.data(using: .utf8) }
    func fdxExportData() -> Data? {
        guard let project = currentProject else { return nil }
        return FinalDraftFDXExporter.data(scenes: project.canonicalScenes, title: project.title)
    }
    func assetJSONExportData() -> Data? {
        guard let project = currentProject else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(project.assets.filter { $0.reviewDecision == .accepted })
    }

    private func synchronizeSelections() {
        guard let project = currentProject else { selectedAssetID = nil; return }
        if let selectedAssetID, project.assets.contains(where: { $0.id == selectedAssetID }) { return }
        selectedAssetID = project.assets.first { $0.kind == selectedAssetKind && $0.reviewDecision != .rejected }?.id
    }

    private func mutateProject(_ body: (inout ArtDepartmentProject) -> Void) {
        guard let id = currentProject?.id, let index = document.projects.firstIndex(where: { $0.id == id }) else { return }
        body(&document.projects[index])
        document.updatedAt = .now
    }

    private func persist() async {
        do { try await persistence.save(document) }
        catch { errorMessage = error.localizedDescription }
    }

    private func runWork(_ operation: () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        progress = .idle
        errorMessage = nil
        defer { isWorking = false }
        do { try await operation() }
        catch {
            mutateProject { $0.pipelineStage = .failed; $0.updatedAt = .now }
            errorMessage = error.localizedDescription
            await persist()
        }
    }
}
