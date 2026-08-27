import Foundation

nonisolated enum ArtWorkspaceSection: String, CaseIterable, Codable, Identifiable, Sendable {
    case script = "剧本标准化"
    case assets = "资产审阅"
    case styles = "风格提示词库"
    case generation = "生图工坊"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .script: "doc.text.magnifyingglass"
        case .assets: "shippingbox.and.arrow.backward"
        case .styles: "photo.on.rectangle.angled"
        case .generation: "wand.and.stars.inverse"
        }
    }
}

nonisolated enum ScriptPipelineStage: String, Codable, Sendable {
    case source = "原始剧本"
    case normalizing = "标准化中"
    case canonical = "Final Draft 已就绪"
    case extracting = "提取中"
    case reviewing = "等待审阅"
    case completed = "资产已确认"
    case failed = "处理失败"
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

    init(id: UUID = UUID(), element: ScreenplayElementKind, text: String, sourceUnitIDs: [String] = []) {
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

    init(id: UUID = UUID(), order: Int, heading: String, sceneKey: String, paragraphs: [CanonicalParagraph], sourceUnitIDs: [String]) {
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
        sourceUnitCount > 0 && sourceUnitCount == coveredSourceUnitCount
            && duplicateSourceUnitIDs.isEmpty && unknownSourceUnitIDs.isEmpty
            && uncoveredSourceUnitIDs.isEmpty && sceneCount > 0
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

nonisolated enum AssetReviewDecision: String, CaseIterable, Codable, Sendable {
    case pending = "待审阅"
    case accepted = "已确认"
    case rejected = "已排除"
    case conflict = "有冲突"
}

nonisolated struct EvidenceQuote: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var sceneID: UUID
    var sceneHeading: String
    var quote: String
    var explanation: String

    init(id: UUID = UUID(), sceneID: UUID, sceneHeading: String, quote: String, explanation: String) {
        self.id = id
        self.sceneID = sceneID
        self.sceneHeading = sceneHeading
        self.quote = quote
        self.explanation = explanation
    }
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

    init(id: UUID = UUID(), kind: ProductionAssetKind, canonicalName: String, aliases: [String] = [], summary: String, visualDescription: String, continuityState: String = "", materialNotes: String = "", compositionNotes: String = "", elementNotes: String = "", sourceEvidence: [EvidenceQuote], modelConfidence: Double, validatedConfidence: Double, reviewDecision: AssetReviewDecision = .pending, warnings: [String] = [], firstSceneOrder: Int, occurrenceCount: Int = 1) {
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
    }

    var requiresReview: Bool {
        reviewDecision == .pending || reviewDecision == .conflict || validatedConfidence < 0.86 || !warnings.isEmpty
    }
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

    init(id: UUID = UUID(), title: String, prompt: String, category: StylePromptCategory, tags: [String] = [], notes: String = "", referenceImagePath: String? = nil, isPromptLocked: Bool = true, isBuiltIn: Bool = false, createdAt: Date = .now, updatedAt: Date = .now) {
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

    static let empty = ArtPromptPlan(title: "", mode: .textToImage, subject: "", materials: "", composition: "", elements: "", lighting: "", positivePrompt: "", negativePrompt: "", lockedFacts: [], chosenStyleCardIDs: [], rationale: "")
}

nonisolated struct ImageGenerationRecipe: Codable, Hashable, Sendable {
    var model: String
    var size: String
    var maxImages: Int
    var watermark: Bool
    static let arkDefault = ImageGenerationRecipe(model: "doubao-seedream-4-0-250828", size: "2K", maxImages: 1, watermark: false)
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

    init(id: UUID = UUID(), projectID: UUID, assetID: UUID?, styleCardIDs: [UUID], promptPlan: ArtPromptPlan, recipe: ImageGenerationRecipe, localImagePath: String, providerRequestID: String? = nil, createdAt: Date = .now) {
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

    init(id: UUID = UUID(), title: String = "未命名美术项目", sourceFileName: String? = nil, sourceText: String = "", sourceFingerprint: String = "", pipelineStage: ScriptPipelineStage = .source, canonicalScenes: [CanonicalScene] = [], canonicalFountain: String = "", normalizationAudit: ScriptNormalizationAudit? = nil, assets: [ProductionAsset] = [], generatedImages: [GeneratedImageRecord] = [], createdAt: Date = .now, updatedAt: Date = .now) {
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
    }
}

nonisolated struct ArtDepartmentWorkspaceDocument: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var projects: [ArtDepartmentProject]
    var styleCards: [StylePromptCard]
    var updatedAt: Date

    static let empty = ArtDepartmentWorkspaceDocument(schemaVersion: 2, projects: [], styleCards: BuiltInStylePromptCatalog.cards, updatedAt: .now)
}

nonisolated enum ArtDepartmentV2Error: LocalizedError {
    case noProject
    case emptySource
    case missingLLMConfiguration
    case missingArkConfiguration
    case invalidModelResponse(String)
    case incompleteCoverage([String])
    case noCanonicalScenes
    case noSelectedAsset
    case noSelectedStyle
    case imageDataMissing
    case unsupportedFile

    var errorDescription: String? {
        switch self {
        case .noProject: "请先创建或选择一个美术项目。"
        case .emptySource: "请先导入或粘贴剧本文本。"
        case .missingLLMConfiguration: "请先在设置中配置大语言模型 API。"
        case .missingArkConfiguration: "请先在设置中配置火山方舟 Ark 生图 API。"
        case .invalidModelResponse(let detail): "模型结果无法通过结构校验：\(detail)"
        case .incompleteCoverage(let ids): "剧本标准化未覆盖全部原文段落：\(ids.joined(separator: ", "))"
        case .noCanonicalScenes: "请先把原始剧本标准化为 Final Draft/Fountain 场景。"
        case .noSelectedAsset: "请先选择一个已提取的场景、人物或道具。"
        case .noSelectedStyle: "请先选择一张风格提示词卡。"
        case .imageDataMissing: "参考图或生成结果的图像数据不存在。"
        case .unsupportedFile: "当前文件格式不受支持。请使用 TXT、Markdown、Fountain 或 FDX。"
        }
    }
}
