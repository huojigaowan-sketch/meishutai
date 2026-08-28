import Foundation

nonisolated enum AssetDesignFactKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case functionalPurpose
    case environmentType
    case spatialLayout
    case architecture
    case timeWeather
    case ageRange
    case genderPresentation
    case identityRole
    case physique
    case faceHair
    case costume
    case accessory
    case characterState
    case objectType
    case objectFunction
    case quantityScale
    case material
    case colorPattern
    case condition
    case eraCulture
    case lighting
    case distinctiveFeature
    case relationship

    var id: String { rawValue }

    var title: String {
        switch self {
        case .functionalPurpose: "场景功能"
        case .environmentType: "环境类型"
        case .spatialLayout: "空间布局"
        case .architecture: "建筑与陈设"
        case .timeWeather: "时间与天气"
        case .ageRange: "年龄范围"
        case .genderPresentation: "性别呈现"
        case .identityRole: "身份与职业"
        case .physique: "体型与姿态"
        case .faceHair: "面部与发型"
        case .costume: "服装"
        case .accessory: "配饰"
        case .characterState: "人物状态"
        case .objectType: "道具类别"
        case .objectFunction: "道具用途"
        case .quantityScale: "数量与尺度"
        case .material: "材质"
        case .colorPattern: "颜色与图案"
        case .condition: "新旧与损坏状态"
        case .eraCulture: "时代与文化"
        case .lighting: "光源与照明"
        case .distinctiveFeature: "识别特征"
        case .relationship: "空间或人物关系"
        }
    }
}

nonisolated struct AssetDesignFact: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var kind: AssetDesignFactKind
    var value: String
    var evidence: String
    var sceneID: UUID
    var sceneHeading: String
    var confidence: Double

    init(
        id: UUID = UUID(),
        kind: AssetDesignFactKind,
        value: String,
        evidence: String,
        sceneID: UUID,
        sceneHeading: String,
        confidence: Double = 1
    ) {
        self.id = id
        self.kind = kind
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.evidence = evidence.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sceneID = sceneID
        self.sceneHeading = sceneHeading
        self.confidence = min(1, max(0, confidence))
    }

    var key: String {
        let valueKey = AppleLinguisticAnalyzer.canonicalKey(value)
        let evidenceKey = SourceUnitBuilder.fingerprint(evidence).prefix(12)
        return "\(kind.rawValue)|\(valueKey)|\(evidenceKey)"
    }
}

nonisolated enum AssetDesignPromptCompiler {
    static func compile(_ asset: ProductionAsset) -> String {
        let facts = verifiedFacts(asset.designFacts ?? [])
        let grouped = Dictionary(grouping: facts, by: \.kind)
        let orderedKinds = order(for: asset.kind)
        var lines = [
            "【资产设计】",
            "类型：\(asset.kind.rawValue)",
            "名称：\(asset.canonicalName)",
        ]

        for kind in orderedKinds {
            let values = unique((grouped[kind] ?? []).map(\.value))
            if !values.isEmpty {
                lines.append("\(kind.title)：\(values.joined(separator: "；"))")
            }
        }

        if !asset.continuityState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("连续性：\(asset.continuityState)")
        }

        let missing = recommendedKinds(for: asset.kind).filter {
            (grouped[$0] ?? []).isEmpty
        }
        if !missing.isEmpty {
            lines.append("剧本未明确、禁止臆造：\(missing.map(\.title).joined(separator: "、"))")
        }

        if facts.isEmpty {
            let legacy = unique([
                asset.visualDescription,
                asset.materialNotes,
                asset.compositionNotes,
                asset.elementNotes,
            ])
            if !legacy.isEmpty {
                lines.append("旧版证据描述（重新提取后将被结构化事实替换）：\(legacy.joined(separator: "；"))")
            }
        }

        let quotes = unique(asset.sourceEvidence.map(\.quote)).prefix(12)
        if !quotes.isEmpty {
            lines.append("【剧本逐字依据】")
            lines.append(contentsOf: quotes.map { "- \($0)" })
        }
        lines.append("只设计上述资产本身；所有未被剧本证据支持的年龄、性别、外形、服装、空间、材质、颜色、时代、数量和损坏状态均保持未定义。")
        return lines.joined(separator: "\n")
    }

    static func verifiedFacts(_ facts: [AssetDesignFact]) -> [AssetDesignFact] {
        var seen = Set<String>()
        return facts
            .filter {
                !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && $0.confidence >= 0.5
            }
            .filter { seen.insert($0.key).inserted }
    }

    static func recommendedKinds(
        for kind: ProductionAssetKind
    ) -> [AssetDesignFactKind] {
        switch kind {
        case .scene:
            [.functionalPurpose, .environmentType, .spatialLayout, .architecture, .timeWeather]
        case .character:
            [.ageRange, .genderPresentation, .identityRole, .physique, .faceHair, .costume, .characterState]
        case .prop:
            [.objectType, .objectFunction, .quantityScale, .material, .condition]
        }
    }

    private static func order(
        for kind: ProductionAssetKind
    ) -> [AssetDesignFactKind] {
        switch kind {
        case .scene:
            [
                .functionalPurpose, .environmentType, .spatialLayout, .architecture,
                .timeWeather, .eraCulture, .material, .colorPattern, .lighting,
                .distinctiveFeature, .relationship,
            ]
        case .character:
            [
                .ageRange, .genderPresentation, .identityRole, .physique, .faceHair,
                .costume, .accessory, .characterState, .eraCulture, .colorPattern,
                .distinctiveFeature, .relationship,
            ]
        case .prop:
            [
                .objectType, .objectFunction, .quantityScale, .material, .colorPattern,
                .condition, .eraCulture, .distinctiveFeature, .relationship,
            ]
        }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return nil }
            let key = AppleLinguisticAnalyzer.canonicalKey(clean)
            return seen.insert(key).inserted ? clean : nil
        }
    }
}

nonisolated extension ProductionAsset {
    var verifiedDesignFacts: [AssetDesignFact] {
        AssetDesignPromptCompiler.verifiedFacts(designFacts ?? [])
    }

    var designPrompt: String {
        AssetDesignPromptCompiler.compile(self)
    }
}
