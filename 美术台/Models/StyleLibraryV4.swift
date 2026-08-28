import AppKit
import CryptoKit
import Foundation

nonisolated enum StylePromptLifecycle: String, Codable, CaseIterable, Sendable {
    case library
    case experiment
    case archived

    var title: String {
        switch self {
        case .library: "图书馆"
        case .experiment: "实验分支"
        case .archived: "已归档"
        }
    }
}

nonisolated struct StyleSampleMedia: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var remoteURLString: String?
    var encryptedLocalPath: String?
    var sha256: String?
    var sourceLabel: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        remoteURLString: String? = nil,
        encryptedLocalPath: String? = nil,
        sha256: String? = nil,
        sourceLabel: String = "用户样板",
        createdAt: Date = .now
    ) {
        self.id = id
        self.remoteURLString = remoteURLString
        self.encryptedLocalPath = encryptedLocalPath
        self.sha256 = sha256
        self.sourceLabel = sourceLabel
        self.createdAt = createdAt
    }
}

nonisolated struct PersistedStyleSamplePayload: Sendable {
    var path: String
    var sha256: String
    var data: Data
}

nonisolated struct StyleTreeNode: Identifiable, Hashable, Sendable {
    var id: UUID { card.id }
    var card: StylePromptCard
    var children: [StyleTreeNode]?
    var depth: Int
}

nonisolated enum StylePromptResolver {
    static func lineage(
        for cardID: UUID,
        in cards: [StylePromptCard]
    ) -> [StylePromptCard] {
        let index = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        var current = index[cardID]
        var result: [StylePromptCard] = []
        var visited = Set<UUID>()
        while let card = current, visited.insert(card.id).inserted {
            result.append(card)
            current = card.parentID.flatMap { index[$0] }
        }
        return result.reversed()
    }

    static func resolvedPrompt(
        for cardID: UUID,
        in cards: [StylePromptCard]
    ) -> String {
        let fragments = lineage(for: cardID, in: cards)
            .map {
                StyleOnlyPromptPolicy.safeStyleFragment(
                    $0.prompt,
                    category: $0.category
                )
            }
            .filter { !$0.isEmpty }
        return StyleOnlyPromptPolicy.subjectNeutralEnvelope(fragments)
    }

    static func resolvedSamples(
        for cardID: UUID,
        in cards: [StylePromptCard]
    ) -> [StyleSampleMedia] {
        let chain = lineage(for: cardID, in: cards).reversed()
        for card in chain {
            let media = card.styleSampleMedia
            if !media.isEmpty { return media }
        }
        return []
    }

    static func resolvedCard(
        _ card: StylePromptCard,
        in cards: [StylePromptCard]
    ) -> StylePromptCard {
        var resolved = card
        resolved.prompt = resolvedPrompt(for: card.id, in: cards)
        resolved.sampleMedia = resolvedSamples(for: card.id, in: cards)
        return resolved
    }

    static func descendants(
        of cardID: UUID,
        in cards: [StylePromptCard]
    ) -> Set<UUID> {
        var result: Set<UUID> = [cardID]
        var changed = true
        while changed {
            changed = false
            for card in cards where card.parentID.map(result.contains) == true {
                if result.insert(card.id).inserted { changed = true }
            }
        }
        return result
    }

    static func forest(
        from cards: [StylePromptCard],
        includeArchived: Bool,
        search: String
    ) -> [StyleTreeNode] {
        let visible = cards.filter {
            includeArchived || $0.lifecycle != .archived
        }
        let normalizedSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let byParent = Dictionary(grouping: visible, by: \.parentID)
        let allByID = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) })

        func containsMatch(_ card: StylePromptCard) -> Bool {
            guard !normalizedSearch.isEmpty else { return true }
            let haystack = ([card.title, card.prompt, card.notes] + card.tags)
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if haystack.contains(normalizedSearch) { return true }
            return (byParent[card.id] ?? []).contains(where: containsMatch)
        }

        func node(_ card: StylePromptCard, depth: Int, path: Set<UUID>) -> StyleTreeNode {
            guard !path.contains(card.id) else {
                return StyleTreeNode(card: card, children: nil, depth: depth)
            }
            let nextPath = path.union([card.id])
            let children = (byParent[card.id] ?? [])
                .filter(containsMatch)
                .sorted(by: sortCards)
                .map { node($0, depth: depth + 1, path: nextPath) }
            return StyleTreeNode(
                card: card,
                children: children.isEmpty ? nil : children,
                depth: depth
            )
        }

        let roots = visible.filter { card in
            guard let parentID = card.parentID else { return true }
            return allByID[parentID] == nil
        }
        return roots.filter(containsMatch).sorted(by: sortCards).map {
            node($0, depth: 0, path: [])
        }
    }

    static func hasCycle(
        parentID: UUID?,
        cardID: UUID,
        cards: [StylePromptCard]
    ) -> Bool {
        guard let parentID else { return false }
        return descendants(of: cardID, in: cards).contains(parentID)
    }

    private static func sortCards(_ lhs: StylePromptCard, _ rhs: StylePromptCard) -> Bool {
        if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn && !rhs.isBuiltIn }
        if lhs.branchOrderValue != rhs.branchOrderValue {
            return lhs.branchOrderValue < rhs.branchOrderValue
        }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}

nonisolated extension StylePromptCard {
    var lifecycle: StylePromptLifecycle {
        get { lifecycleRawValue.flatMap(StylePromptLifecycle.init(rawValue:)) ?? .library }
        set { lifecycleRawValue = newValue.rawValue }
    }

    var styleSampleMedia: [StyleSampleMedia] {
        if let sampleMedia, !sampleMedia.isEmpty { return sampleMedia }
        if let referenceImagePath, !referenceImagePath.isEmpty {
            return [StyleSampleMedia(
                id: id,
                encryptedLocalPath: referenceImagePath,
                sourceLabel: "旧版参考图",
                createdAt: createdAt
            )]
        }
        return []
    }

    var branchOrderValue: Int { branchOrder ?? 0 }
    var revisionValue: Int { revisionNumber ?? 1 }
    var isExperiment: Bool { lifecycle == .experiment }
    var isArchived: Bool { lifecycle == .archived }
}

nonisolated enum StyleSampleValidator {
    static let maximumBytes = 48 * 1_024 * 1_024

    static func validate(_ data: Data) throws {
        guard !data.isEmpty, data.count <= maximumBytes, NSImage(data: data) != nil else {
            throw ArtDepartmentV2Error.imageDataMissing
        }
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
