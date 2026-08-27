import Foundation

enum WorkspaceSection: String, CaseIterable, Identifiable, Codable, Sendable {
    case script
    case allAssets
    case scenes
    case characters
    case props

    var id: String { rawValue }

    var title: String {
        switch self {
        case .script: "剧本"
        case .allAssets: "全部资产"
        case .scenes: "场景"
        case .characters: "人物"
        case .props: "道具"
        }
    }

    var systemImage: String {
        switch self {
        case .script: "doc.text"
        case .allAssets: "square.grid.2x2"
        case .scenes: "mountain.2"
        case .characters: "person.2"
        case .props: "shippingbox"
        }
    }
}

enum AssetKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case scene
    case character
    case prop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scene: "场景"
        case .character: "人物"
        case .prop: "道具"
        }
    }

    var systemImage: String {
        switch self {
        case .scene: "mountain.2"
        case .character: "person.crop.rectangle.stack"
        case .prop: "shippingbox"
        }
    }

    var promptPrefix: String {
        switch self {
        case .scene:
            "professional environment visual development, production design, spatial storytelling"
        case .character:
            "professional character visual development, identity consistency, production design"
        case .prop:
            "professional prop visual development, functional industrial design, production design"
        }
    }
}

enum AssetReviewState: String, CaseIterable, Codable, Hashable, Sendable {
    case candidate
    case accepted
    case ignored

    var title: String {
        switch self {
        case .candidate: "待确认"
        case .accepted: "已采用"
        case .ignored: "已忽略"
        }
    }

    var systemImage: String {
        switch self {
        case .candidate: "circle.dotted"
        case .accepted: "checkmark.circle.fill"
        case .ignored: "minus.circle"
        }
    }
}

struct AssetItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: AssetKind
    var name: String
    var summary: String
    var evidence: String
    var reviewState: AssetReviewState
    var characterProfile: CharacterProfile?
    var sceneProfile: SceneProfile?
    var propProfile: PropProfile?
    var activeWardrobeID: UUID?
    var sourceEpisodeIDs: [UUID]?
    /// Stable semantic identity produced by the stage-one entity resolver.
    /// It deliberately excludes generated descriptions and design fields.
    var canonicalKey: String?
    /// Exact screenplay occurrences that support this canonical asset.
    var occurrences: [AssetOccurrence]?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: AssetKind,
        name: String,
        summary: String,
        evidence: String = "",
        reviewState: AssetReviewState = .candidate,
        characterProfile: CharacterProfile? = nil,
        sceneProfile: SceneProfile? = nil,
        propProfile: PropProfile? = nil,
        activeWardrobeID: UUID? = nil,
        sourceEpisodeIDs: [UUID]? = nil,
        canonicalKey: String? = nil,
        occurrences: [AssetOccurrence]? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.summary = summary
        self.evidence = evidence
        self.reviewState = reviewState
        self.characterProfile = characterProfile
        self.sceneProfile = sceneProfile
        self.propProfile = propProfile
        self.activeWardrobeID = activeWardrobeID
        self.sourceEpisodeIDs = sourceEpisodeIDs
        self.canonicalKey = canonicalKey
        self.occurrences = occurrences
        self.updatedAt = updatedAt
    }
}

struct AssetLibraryItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: AssetKind
    let name: String
    let summary: String
    let reviewState: AssetReviewState
    let characterImportance: CharacterImportance?
    let narrativeRole: NarrativeRole?
    let appearanceCount: Int?
}

struct AssetLibraryFolder: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let items: [AssetLibraryItem]
    let children: [AssetLibraryFolder]

    var itemCount: Int {
        items.count + children.reduce(0) { $0 + $1.itemCount }
    }
}

enum DeepSeekModel: String, CaseIterable, Identifiable, Codable, Sendable {
    case flash = "deepseek-v4-flash"
    case pro = "deepseek-v4-pro"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flash: "DeepSeek V4 Flash"
        case .pro: "DeepSeek V4 Pro"
        }
    }

    var detail: String {
        switch self {
        case .flash: "速度优先，适合日常拆解"
        case .pro: "质量优先，适合复杂长剧本"
        }
    }
}

struct WorkspaceSnapshot: Codable, Sendable {
    var scriptText: String
    var sourceFileName: String?
    var assets: [AssetItem]
    var updatedAt: Date
}
