import Foundation

nonisolated enum ArtWorkspaceSection: String, CaseIterable, Codable, Identifiable, Sendable {
    case script = "剧本标准化"
    case assets = "自动资产库"
    case styles = "风格提示词库"
    case generation = "生图工坊"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .script: "doc.text.magnifyingglass"
        case .assets: "shippingbox.fill"
        case .styles: "photo.on.rectangle.angled"
        case .generation: "wand.and.stars.inverse"
        }
    }
}

/// Raw values remain compatible with V2 persisted workspaces. The visible title
/// reflects the V3 automatic pipeline: no asset requires a person to approve it.
nonisolated enum ScriptPipelineStage: String, Codable, Sendable {
    case source = "原始剧本"
    case normalizing = "标准化中"
    case canonical = "Final Draft 已就绪"
    case extracting = "提取中"
    case adjudicating = "自动核验中"
    case reviewing = "等待审阅" // Legacy V2 value; normalized to adjudicating on load.
    case completed = "资产已确认"
    case failed = "处理失败"

    var title: String {
        switch self {
        case .reviewing, .adjudicating: "自动核验中"
        case .completed: "资产已就绪"
        default: rawValue
        }
    }
}

nonisolated enum ScreenplayElementKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case sceneHeading = "Scene Heading"
    case action = "Action"
    case character = "Character"
    case parenthetical = "Parenthetical"
    case dialogue = "Dialogue"
    case transition = "Transition"
    case note = "General"

    var id: String { rawValue }
}

nonisolated struct PipelineProgress: Codable, Hashable, Sendable {
    var title: String
    var detail: String
    var current: Int
    var total: Int

    static let idle = PipelineProgress(title: "", detail: "", current: 0, total: 0)

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(current) / Double(total)))
    }
}

nonisolated struct SourceUnit: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var index: Int
    var text: String
    var utf16Location: Int
    var utf16Length: Int
}

nonisolated struct CanonicalParagraph: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var element: ScreenplayElementKind
    var text: String
    var sourceUnitIDs: [String]

    init(
        id: UUID = UUID(),
        element: ScreenplayElementKind,
        text: String,
        sourceUnitIDs: [String] = []
    ) {
        self.id = id
        self.element = element
        self.text = text
        self.sourceUnitIDs = sourceUnitIDs
    }
}

nonisolated struct CanonicalScene: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var order: Int
    var heading: String
    var sceneKey: String
    var paragraphs: [CanonicalParagraph]
    var sourceUnitIDs: [String]

    init(
        id: UUID = UUID(),
        order: Int,
        heading: String,
        sceneKey: String,
        paragraphs: [CanonicalParagraph],
        sourceUnitIDs: [String]
    ) {
        self.id = id
        self.order = order
        self.heading = heading
        self.sceneKey = sceneKey
        self.paragraphs = paragraphs
        self.sourceUnitIDs = sourceUnitIDs
    }

    var fountainText: String { CanonicalFountainRenderer.render(scene: self) }
}

nonisolated struct ScriptNormalizationAudit: Codable, Hashable, Sendable {
    var sourceFingerprint: String
    var sourceUnitCount: Int
    var coveredSourceUnitCount: Int
    var duplicateSourceUnitIDs: [String]
    var unknownSourceUnitIDs: [String]
    var uncoveredSourceUnitIDs: [String]
    var sceneCount: Int
    var model: String
    var completedAt: Date

    var isComplete: Bool {
        sourceUnitCount > 0
            && sourceUnitCount == coveredSourceUnitCount
            && duplicateSourceUnitIDs.isEmpty
            && unknownSourceUnitIDs.isEmpty
            && uncoveredSourceUnitIDs.isEmpty
            && sceneCount > 0
    }
}

nonisolated enum ProductionAssetKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case scene = "场景"
    case character = "人物"
    case prop = "道具"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .scene: "building.2.crop.circle"
        case .character: "person.crop.circle"
        case .prop: "shippingbox"
        }
    }
}

/// Raw values preserve V2 decoding. These are automatic machine decisions, not
/// buttons a person must press.
nonisolated enum AssetReviewDecision: String, CaseIterable, Codable, Sendable {
    case pending = "待审阅"
    case accepted = "已确认"
    case rejected = "已排除"
    case conflict = "有冲突"

    var title: String {
        switch self {
        case .pending: "自动核验中"
        case .accepted: "自动通过"
        case .rejected: "自动排除"
        case .conflict: "隔离诊断"
        }
    }
}

nonisolated struct EvidenceQuote: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var sceneID: UUID
    var sceneHeading: String
    var quote: String
    var explanation: String

    init(
        id: UUID = UUID(),
        sceneID: UUID,
        sceneHeading: String,
        quote: String,
        explanation: String
    ) {
        self.id = id
        self.sceneID = sceneID
        self.sceneHeading = sceneHeading
        self.quote = quote
        self.explanation = explanation
    }
}

nonisolated struct AssetVerificationReport: Codable, Hashable, Sendable {
    var engines: [String]
    var consensusCount: Int
    var exactEvidenceScore: Double
    var schemaCompleteness: Double
    var linguisticSupport: Double
    var deterministicSupport: Bool
    var reason: String

    var automaticallyUsable: Bool {
        deterministicSupport
            || (consensusCount >= 2 && exactEvidenceScore >= 0.75)
            || (exactEvidenceScore == 1 && schemaCompleteness >= 0.72)
    }
}

nonisolated struct AssetAutomationSummary: Codable, Hashable, Sendable {
    var sceneCount: Int
    var characterCount: Int
    var propCount: Int
    var usableCount: Int
    var quarantinedCount: Int
    var rejectedCount: Int
    var engineNames: [String]
    var elapsedMilliseconds: Int
    var completedAt: Date
}

nonisolated struct AppleEngineStatusSnapshot: Codable, Hashable, Sendable {
    var onDeviceAvailable: Bool
    var supportsChinese: Bool
    var contextSize: Int?
    var remoteFallbackAvailable: Bool
    var activeRoute: String
    var detail: String
}

nonisolated struct ProductionAsset: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var kind: ProductionAssetKind
    var canonicalName: String
    var aliases: [String]
    var summary: String
    var visualDescription: String
    var continuityState: String
    var materialNotes: String
    var compositionNotes: String
    var elementNotes: String
    var sourceEvidence: [EvidenceQuote]
    var modelConfidence: Double
    var validatedConfidence: Double
    var reviewDecision: AssetReviewDecision
    var warnings: [String]
    var firstSceneOrder: Int
    var occurrenceCount: Int
    var verificationReport: AssetVerificationReport?

    init(
        id: UUID = UUID(),
        kind: ProductionAssetKind,
        canonicalName: String,
        aliases: [String] = [],
        summary: String,
        visualDescription: String,
        continuityState: String = "",
        materialNotes: String = "",
        compositionNotes: String = "",
        elementNotes: String = "",
        sourceEvidence: [EvidenceQuote],
        modelConfidence: Double,
        validatedConfidence: Double,
        reviewDecision: AssetReviewDecision = .pending,
        warnings: [String] = [],
        firstSceneOrder: Int,
        occurrenceCount: Int = 1,
        verificationReport: AssetVerificationReport? = nil
    ) {
        self.id = id
        self.kind = kind
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.summary = summary
        self.visualDescription = visualDescription
        self.continuityState = continuityState
        self.materialNotes = materialNotes
        self.compositionNotes = compositionNotes
        self.elementNotes = elementNotes
        self.sourceEvidence = sourceEvidence
        self.modelConfidence = min(1, max(0, modelConfidence))
        self.validatedConfidence = min(1, max(0, validatedConfidence))
        self.reviewDecision = reviewDecision
        self.warnings = warnings
        self.firstSceneOrder = firstSceneOrder
        self.occurrenceCount = occurrenceCount
        self.verificationReport = verificationReport
    }

    var isUsable: Bool {
        reviewDecision == .accepted
            && !canonicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && sourceEvidence.contains { !$0.quote.isEmpty }
    }

    var isQuarantined: Bool {
        reviewDecision == .conflict || reviewDecision == .pending
    }

    @available(*, deprecated, message: "V3 is fully automatic; inspect isQuarantined instead.")
    var requiresReview: Bool { isQuarantined }
}

nonisolated enum StylePromptCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case general = "通用风格"
    case character = "人物"
    case costume = "服装"
    case scene = "场景"
    case prop = "道具"
    case whiteModel = "AO 白模"
    case repaint = "材质回绘"
    case camera = "机位与反打"
    case cleanup = "场景减噪"

    var id: String { rawValue }
}

nonisolated struct StylePromptProvenance: Codable, Hashable, Sendable {
    var repository: String
    var path: String
    var revision: String
    var license: String
    var originalID: String?
}

nonisolated struct StylePromptCard: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var prompt: String
    var category: StylePromptCategory
    var tags: [String]
    var notes: String
    var referenceImagePath: String?
    var isPromptLocked: Bool
    var isBuiltIn: Bool
    var createdAt: Date
    var updatedAt: Date
    var visionFingerprintBase64: String?
    var visionAestheticScore: Double?
    var provenance: StylePromptProvenance?

    init(
        id: UUID = UUID(),
        title: String,
        prompt: String,
        category: StylePromptCategory,
        tags: [String] = [],
        notes: String = "",
        referenceImagePath: String? = nil,
        isPromptLocked: Bool = true,
        isBuiltIn: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        visionFingerprintBase64: String? = nil,
        visionAestheticScore: Double? = nil,
        provenance: StylePromptProvenance? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.category = category
        self.tags = tags
        self.notes = notes
        self.referenceImagePath = referenceImagePath
        self.isPromptLocked = isPromptLocked
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.visionFingerprintBase64 = visionFingerprintBase64
        self.visionAestheticScore = visionAestheticScore
        self.provenance = provenance
    }
}

nonisolated enum ImageGenerationMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case textToImage = "文生图"
    case referenceImage = "参考图生图"
    case characterLineup = "十人同服装队列"
    case aoWhiteModel = "AO 白模"
    case materialRepaint = "材质回绘"
    case reverseShot = "镜头反打"
    case cameraRebuild = "指定机位重构"
    case cleanup = "场景减噪"

    var id: String { rawValue }
}

nonisolated struct ArtPromptPlan: Codable, Hashable, Sendable {
    var title: String
    var mode: ImageGenerationMode
    var subject: String
    var materials: String
    var composition: String
    var elements: String
    var lighting: String
    var positivePrompt: String
    var negativePrompt: String
    var lockedFacts: [String]
    var chosenStyleCardIDs: [UUID]
    var rationale: String

    static let empty = ArtPromptPlan(
        title: "",
        mode: .textToImage,
        subject: "",
        materials: "",
        composition: "",
        elements: "",
        lighting: "",
        positivePrompt: "",
        negativePrompt: "",
        lockedFacts: [],
        chosenStyleCardIDs: [],
        rationale: ""
    )
}

nonisolated struct ImageGenerationRecipe: Codable, Hashable, Sendable {
    var model: String
    var size: String
    var maxImages: Int
    var watermark: Bool

    static let arkDefault = ImageGenerationRecipe(
        model: "doubao-seedream-4-0-250828",
        size: "2K",
        maxImages: 1,
        watermark: false
    )
}

nonisolated struct GeneratedImageRecord: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var projectID: UUID
    var assetID: UUID?
    var styleCardIDs: [UUID]
    var promptPlan: ArtPromptPlan
    var recipe: ImageGenerationRecipe
    var localImagePath: String
    var providerRequestID: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        projectID: UUID,
        assetID: UUID?,
        styleCardIDs: [UUID],
        promptPlan: ArtPromptPlan,
        recipe: ImageGenerationRecipe,
        localImagePath: String,
        providerRequestID: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.projectID = projectID
        self.assetID = assetID
        self.styleCardIDs = styleCardIDs
        self.promptPlan = promptPlan
        self.recipe = recipe
        self.localImagePath = localImagePath
        self.providerRequestID = providerRequestID
        self.createdAt = createdAt
    }
}

nonisolated struct ArtDepartmentProject: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var sourceFileName: String?
    var sourceText: String
    var sourceFingerprint: String
    var pipelineStage: ScriptPipelineStage
    var canonicalScenes: [CanonicalScene]
    var canonicalFountain: String
    var normalizationAudit: ScriptNormalizationAudit?
    var assets: [ProductionAsset]
    var generatedImages: [GeneratedImageRecord]
    var createdAt: Date
    var updatedAt: Date
    var automationSummary: AssetAutomationSummary?
    var engineStatus: AppleEngineStatusSnapshot?

    init(
        id: UUID = UUID(),
        title: String = "未命名美术项目",
        sourceFileName: String? = nil,
        sourceText: String = "",
        sourceFingerprint: String = "",
        pipelineStage: ScriptPipelineStage = .source,
        canonicalScenes: [CanonicalScene] = [],
        canonicalFountain: String = "",
        normalizationAudit: ScriptNormalizationAudit? = nil,
        assets: [ProductionAsset] = [],
        generatedImages: [GeneratedImageRecord] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        automationSummary: AssetAutomationSummary? = nil,
        engineStatus: AppleEngineStatusSnapshot? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceFileName = sourceFileName
        self.sourceText = sourceText
        self.sourceFingerprint = sourceFingerprint
        self.pipelineStage = pipelineStage
        self.canonicalScenes = canonicalScenes
        self.canonicalFountain = canonicalFountain
        self.normalizationAudit = normalizationAudit
        self.assets = assets
        self.generatedImages = generatedImages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.automationSummary = automationSummary
        self.engineStatus = engineStatus
    }

    var usableAssets: [ProductionAsset] { assets.filter(\.isUsable) }
    var quarantinedAssets: [ProductionAsset] { assets.filter(\.isQuarantined) }
}

nonisolated struct ArtDepartmentWorkspaceDocument: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var projects: [ArtDepartmentProject]
    var styleCards: [StylePromptCard]
    var updatedAt: Date

    static let empty = ArtDepartmentWorkspaceDocument(
        schemaVersion: 4,
        projects: [],
        styleCards: BuiltInStylePromptCatalog.cards,
        updatedAt: .now
    )
}

nonisolated enum ArtDepartmentV2Error: LocalizedError {
    case noProject
    case emptySource
    case missingLLMConfiguration
    case missingArkConfiguration
    case foundationModelUnavailable(String)
    case invalidModelResponse(String)
    case incompleteCoverage([String])
    case noCanonicalScenes
    case noSelectedAsset
    case noSelectedStyle
    case noUsableAssets
    case imageDataMissing
    case unsupportedFile

    var errorDescription: String? {
        switch self {
        case .noProject: "请先创建或选择一个美术项目。"
        case .emptySource: "请先导入或粘贴剧本文本。"
        case .missingLLMConfiguration: "Apple 本地模型不可用，且没有配置远程模型兜底。"
        case .missingArkConfiguration: "请先在设置中配置火山方舟 Ark 生图 API。"
        case .foundationModelUnavailable(let detail): "Apple Foundation Models 当前不可用：\(detail)"
        case .invalidModelResponse(let detail): "模型结果无法通过 Apple GenerationSchema 与证据校验：\(detail)"
        case .incompleteCoverage(let ids): "剧本标准化未覆盖全部原文段落：\(ids.joined(separator: ", "))"
        case .noCanonicalScenes: "请先把原始剧本标准化为 Final Draft/Fountain 场景。"
        case .noSelectedAsset: "当前没有自动通过的场景、人物或道具。"
        case .noSelectedStyle: "必须由用户从风格图书馆明确选择至少一张卡片，或输入本轮外部风格提示词。"
        case .noUsableAssets: "自动核验没有找到具有逐字证据的可用资产。"
        case .imageDataMissing: "参考图或生成结果的图像数据不存在。"
        case .unsupportedFile: "当前文件格式不受支持。请使用 TXT、Markdown、Fountain、FDX、PDF 或图片。"
        }
    }
}
