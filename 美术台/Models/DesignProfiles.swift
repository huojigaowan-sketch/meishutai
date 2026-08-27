import Foundation

enum CharacterImportance: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .s: "S · 主角"
        case .a: "A · 核心配角"
        case .b: "B · 重要常驻"
        case .c: "C · 单场角色"
        case .d: "D · 群演背景"
        }
    }
}

enum NarrativeRole: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case maleLead = "male-lead"
    case femaleLead = "female-lead"
    case coLead = "co-lead"
    case protagonist = "protagonist"
    case primaryAntagonist = "primary-antagonist"
    case supporting = "supporting"
    case recurring = "recurring"
    case episodic = "episodic"
    case background = "background"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maleLead: "男主"
        case .femaleLead: "女主"
        case .coLead: "联合主角"
        case .protagonist: "核心主角"
        case .primaryAntagonist: "主要反派"
        case .supporting: "主要配角"
        case .recurring: "常驻角色"
        case .episodic: "单场角色"
        case .background: "背景角色"
        }
    }

    var minimumImportance: CharacterImportance {
        switch self {
        case .maleLead, .femaleLead, .coLead, .protagonist:
            .s
        case .primaryAntagonist, .supporting:
            .a
        case .recurring:
            .b
        case .episodic:
            .c
        case .background:
            .d
        }
    }
}

struct WardrobeLook: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var season: String
    var occasion: String
    var storyBeat: String
    var sourceEvidence: String

    init(
        id: UUID = UUID(),
        title: String,
        season: String = "unspecified",
        occasion: String = "unspecified",
        storyBeat: String = "",
        sourceEvidence: String = ""
    ) {
        self.id = id
        self.title = title
        self.season = season
        self.occasion = occasion
        self.storyBeat = storyBeat
        self.sourceEvidence = sourceEvidence
    }

    static func empty(index: Int) -> WardrobeLook {
        WardrobeLook(title: "服装方案 \(index)")
    }
}

struct CharacterProfile: Codable, Hashable, Sendable {
    var importance: CharacterImportance
    var narrativeRole: NarrativeRole
    var affiliation: String? = nil
    var appearanceCount: Int? = nil
    var genderPresentation: String
    var ageRange: String
    var wardrobe: [WardrobeLook]

    static var empty: CharacterProfile {
        CharacterProfile(
            importance: .c,
            narrativeRole: .episodic,
            genderPresentation: "unspecified",
            ageRange: "unspecified",
            wardrobe: []
        )
    }

    var affiliationName: String {
        get { affiliation ?? "" }
        set { affiliation = newValue }
    }

    var resolvedAppearanceCount: Int {
        max(appearanceCount ?? 0, 0)
    }
}

struct SceneProfile: Codable, Hashable, Sendable {
    var locationGroup: String? = nil
    var timeOfDayID: String
    var weatherID: String
    var season: String
    var period: String
    var locationType: String
    var productionNotes: String

    var locationGroupName: String {
        get { locationGroup ?? "" }
        set { locationGroup = newValue }
    }
}

struct PropProfile: Codable, Hashable, Sendable {
    var category: String
    var storyFunction: String
    var productionPriority: ProductionAssetPriority? = nil
    var stateChanges: String
}

enum ProductionAssetPriority: String, CaseIterable, Codable, Hashable, Sendable {
    case hero
    case featured
    case consumable
    case setDressing

    var title: String {
        switch self {
        case .hero: "核心道具"
        case .featured: "重点道具"
        case .consumable: "消耗品"
        case .setDressing: "陈设/普通道具"
        }
    }
}
