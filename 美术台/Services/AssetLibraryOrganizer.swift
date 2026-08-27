import Foundation

struct AssetLibraryOrganization: Sendable {
    let filteredAssets: [AssetItem]
    let items: [AssetLibraryItem]
    let folders: [AssetLibraryFolder]

    static let empty = AssetLibraryOrganization(
        filteredAssets: [],
        items: [],
        folders: []
    )
}

enum AssetLibraryOrganizer {
    static func organize(
        assets: [AssetItem],
        section: WorkspaceSection,
        searchText: String
    ) -> AssetLibraryOrganization {
        let visibleAssets = assets.filter { asset in
            guard asset.reviewState != .ignored else { return false }

            switch section {
            case .script, .allAssets:
                return true
            case .scenes:
                return asset.kind == .scene
            case .characters:
                return asset.kind == .character
            case .props:
                return asset.kind == .prop
            }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredAssets: [AssetItem]
        if query.isEmpty {
            filteredAssets = visibleAssets
        } else {
            filteredAssets = visibleAssets.filter {
                matchesSearch($0, query: query)
            }
        }

        // Persisted projects may contain a legacy duplicate UUID. Keep the
        // organizer total-ordering safe long enough for WorkspaceStore to
        // repair that corruption; Dictionary(uniqueKeysWithValues:) would
        // otherwise trap before the repair can run.
        var itemsByID: [UUID: AssetLibraryItem] = [:]
        for asset in filteredAssets where itemsByID[asset.id] == nil {
            itemsByID[asset.id] = makeItem(from: asset)
        }
        let items = filteredAssets.compactMap { itemsByID[$0.id] }

        let folders: [AssetLibraryFolder]
        switch section {
        case .scenes:
            folders = makeSceneFolders(
                assets: filteredAssets,
                itemsByID: itemsByID
            )
        case .characters:
            folders = makeCharacterFolders(
                assets: filteredAssets,
                itemsByID: itemsByID
            )
        case .script, .allAssets, .props:
            folders = []
        }

        return AssetLibraryOrganization(
            filteredAssets: filteredAssets,
            items: items,
            folders: folders
        )
    }

    private static func matchesSearch(
        _ asset: AssetItem,
        query: String
    ) -> Bool {
        if asset.name.localizedStandardContains(query)
            || asset.summary.localizedStandardContains(query)
            || asset.evidence.localizedStandardContains(query) {
            return true
        }

        if let locationGroup = asset.sceneProfile?.locationGroup,
           locationGroup.localizedStandardContains(query) {
            return true
        }

        if let affiliation = asset.characterProfile?.affiliation,
           affiliation.localizedStandardContains(query) {
            return true
        }

        return false
    }

    private static func makeItem(from asset: AssetItem) -> AssetLibraryItem {
        let profile = asset.characterProfile
        let extractedAppearanceCount = profile?.resolvedAppearanceCount ?? 0
        let episodeAppearanceCount = Set(asset.sourceEpisodeIDs ?? []).count
        let appearanceCount: Int?
        if asset.kind == .character {
            appearanceCount = max(extractedAppearanceCount, episodeAppearanceCount)
        } else {
            appearanceCount = nil
        }

        return AssetLibraryItem(
            id: asset.id,
            kind: asset.kind,
            name: asset.name,
            summary: asset.summary,
            reviewState: asset.reviewState,
            characterImportance: profile?.importance,
            narrativeRole: profile?.narrativeRole,
            appearanceCount: appearanceCount
        )
    }

    private static func makeSceneFolders(
        assets: [AssetItem],
        itemsByID: [UUID: AssetLibraryItem]
    ) -> [AssetLibraryFolder] {
        var locations: [String: SceneLocationAccumulator] = [:]

        for asset in assets {
            guard let item = itemsByID[asset.id] else { continue }

            let locationTitle = resolvedLocationGroup(for: asset)
            let locationKey = normalizedKey(locationTitle)
            let timeID = asset.sceneProfile?.timeOfDayID ?? PromptParameter.noneOptionID
            let timeTitle = timeOfDayTitle(timeID)
            let timeKey = normalizedKey(timeID)

            var location = locations[locationKey]
                ?? SceneLocationAccumulator(
                    title: locationTitle,
                    times: [:]
                )
            var time = location.times[timeKey]
                ?? SceneTimeAccumulator(
                    id: timeID,
                    title: timeTitle,
                    items: []
                )
            time.items.append(item)
            location.times[timeKey] = time
            locations[locationKey] = location
        }

        return locations
            .map { locationKey, location in
                let sortedTimes = location.times.values.sorted { lhs, rhs in
                    let lhsRank = timeOfDayRank(lhs.id)
                    let rhsRank = timeOfDayRank(rhs.id)
                    if lhsRank != rhsRank {
                        return lhsRank < rhsRank
                    }
                    return localizedAscending(lhs.title, rhs.title)
                }
                let timeFolders = sortedTimes.map { time in
                    AssetLibraryFolder(
                        id: "scene|\(locationKey)|\(normalizedKey(time.id))",
                        title: time.title,
                        systemImage: timeOfDaySystemImage(time.id),
                        items: sortedByName(time.items),
                        children: []
                    )
                }

                return AssetLibraryFolder(
                    id: "scene|\(locationKey)",
                    title: location.title,
                    systemImage: "folder.fill",
                    items: [],
                    children: timeFolders
                )
            }
            .sorted { localizedAscending($0.title, $1.title) }
    }

    private static func makeCharacterFolders(
        assets: [AssetItem],
        itemsByID: [UUID: AssetLibraryItem]
    ) -> [AssetLibraryFolder] {
        var groups: [String: CharacterGroupAccumulator] = [:]

        for asset in assets {
            guard let item = itemsByID[asset.id] else { continue }

            let title = resolvedAffiliation(for: asset)
            let key = normalizedKey(title)
            var group = groups[key]
                ?? CharacterGroupAccumulator(title: title, items: [])
            group.items.append(item)
            groups[key] = group
        }

        return groups
            .map { key, group in
                AssetLibraryFolder(
                    id: "character|\(key)",
                    title: group.title,
                    systemImage: "folder.fill",
                    items: group.items.sorted(by: characterPrecedes),
                    children: []
                )
            }
            .sorted { lhs, rhs in
                let lhsFrequency = lhs.items.first?.appearanceCount ?? 0
                let rhsFrequency = rhs.items.first?.appearanceCount ?? 0
                if lhsFrequency != rhsFrequency {
                    return lhsFrequency > rhsFrequency
                }
                return localizedAscending(lhs.title, rhs.title)
            }
    }

    private static func resolvedLocationGroup(for asset: AssetItem) -> String {
        if let explicit = nonempty(asset.sceneProfile?.locationGroup) {
            return explicit
        }

        let separators = CharacterSet(charactersIn: "·•・—–-－|｜/:：>＞")
        let inferred = asset.name
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
        return inferred ?? (asset.name.isEmpty ? "未归类场景" : asset.name)
    }

    private static func resolvedAffiliation(for asset: AssetItem) -> String {
        nonempty(asset.characterProfile?.affiliation) ?? "未分组人物"
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func sortedByName(
        _ items: [AssetLibraryItem]
    ) -> [AssetLibraryItem] {
        items.sorted { localizedAscending($0.name, $1.name) }
    }

    nonisolated private static func characterPrecedes(
        _ lhs: AssetLibraryItem,
        _ rhs: AssetLibraryItem
    ) -> Bool {
        let lhsCount = lhs.appearanceCount ?? 0
        let rhsCount = rhs.appearanceCount ?? 0
        if lhsCount != rhsCount {
            return lhsCount > rhsCount
        }

        let lhsRank = importanceRank(lhs.characterImportance)
        let rhsRank = importanceRank(rhs.characterImportance)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        return localizedAscending(lhs.name, rhs.name)
    }

    nonisolated private static func importanceRank(
        _ importance: CharacterImportance?
    ) -> Int {
        switch importance {
        case .s: 0
        case .a: 1
        case .b: 2
        case .c: 3
        case .d: 4
        case nil: 5
        }
    }

    private static func timeOfDayTitle(_ id: String) -> String {
        switch id {
        case "dawn": "黎明"
        case "day": "白天"
        case "golden-hour": "黄金时刻"
        case "dusk": "黄昏"
        case "blue-hour": "蓝调时刻"
        case "night": "夜晚"
        case "midnight": "深夜"
        case "interior-unspecified": "室内时段未标明"
        case "none", "script": "无"
        default: id.isEmpty ? "时段未标明" : id
        }
    }

    private static func timeOfDaySystemImage(_ id: String) -> String {
        switch id {
        case "dawn": "sun.horizon"
        case "day": "sun.max"
        case "golden-hour": "sun.max.trianglebadge.exclamationmark"
        case "dusk", "blue-hour": "sunset"
        case "night", "midnight": "moon.stars"
        default: "clock"
        }
    }

    private static func timeOfDayRank(_ id: String) -> Int {
        switch id {
        case "dawn": 0
        case "day": 1
        case "golden-hour": 2
        case "dusk": 3
        case "blue-hour": 4
        case "night": 5
        case "midnight": 6
        case "interior-unspecified": 7
        case "none", "script": 8
        default: 9
        }
    }

    private static func normalizedKey(_ value: String) -> String {
        let normalized = value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            .components(separatedBy: .alphanumerics.inverted)
            .joined()
        return normalized.isEmpty ? "ungrouped" : normalized
    }

    nonisolated private static func localizedAscending(
        _ lhs: String,
        _ rhs: String
    ) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
}

private struct SceneLocationAccumulator {
    let title: String
    var times: [String: SceneTimeAccumulator]
}

private struct SceneTimeAccumulator {
    let id: String
    let title: String
    var items: [AssetLibraryItem]
}

private struct CharacterGroupAccumulator {
    let title: String
    var items: [AssetLibraryItem]
}
