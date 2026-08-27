import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let assetWorkbook: UTType = {
        if let xlsxType = UTType(filenameExtension: "xlsx") {
            return xlsxType
        }

        return UTType(
            importedAs: "org.openxmlformats.spreadsheetml.sheet",
            conformingTo: .zip
        )
    }()
}

struct AssetWorkbookDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] { [.assetWorkbook] }

    private let data: Data

    init() {
        data = Data()
    }

    init(
        projectTitle: String,
        assets: [AssetItem],
        episodes: [ScriptEpisode],
        template: AssetWorkbookTemplate = .table1
    ) throws {
        data = try AssetWorkbookExporter.makeWorkbook(
            projectTitle: projectTitle,
            assets: assets,
            episodes: episodes,
            template: template
        )
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum AssetWorkbookTemplate: String, CaseIterable, Identifiable, Sendable {
    case table1
    case table2

    var id: Self { self }

    var defaultName: String {
        switch self {
        case .table1: "表格1"
        case .table2: "表格2"
        }
    }

    var description: String {
        switch self {
        case .table1: "当前资产库排序"
        case .table2: "场景按剧本顺序，同名场景由 AI 核验"
        }
    }

    var systemImage: String {
        switch self {
        case .table1: "square.grid.2x2"
        case .table2: "text.line.first.and.arrowtriangle.forward"
        }
    }
}

struct Table2SceneCandidateOccurrence: Codable, Hashable, Sendable {
    let id: String
    let episodeOrder: Int
    let episodeTitle: String
    let sceneIdentifier: String
    let heading: String
    let excerpt: String
    let truncated: Bool
}

struct Table2SceneCandidate: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let locationGroup: String?
    let timeOfDayID: String?
    let weatherID: String?
    let season: String?
    let period: String?
    let locationType: String?
    let occurrences: [Table2SceneCandidateOccurrence]
}

struct Table2SceneCandidateGroup: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let localName: String
    let candidates: [Table2SceneCandidate]
}

/// A merge group is accepted only after the configured AI provider has
/// explicitly confirmed that every listed candidate represents the same set.
/// Candidate IDs are stable opaque labels derived from model-owned asset IDs.
struct Table2SceneMergeGroup: Hashable, Sendable {
    let candidateIDs: [String]
}

struct Table2SceneIdentityResolution: Sendable {
    let mergeGroups: [Table2SceneMergeGroup]
    let warning: String?
}

enum AssetWorkbookExporter {
    static let maximumSceneInvestigationOccurrencesPerCandidate = 4
    static let maximumSceneInvestigationOccurrencesPerGroup = 12
    static let maximumSceneInvestigationCharactersPerOccurrence = 700
    static let maximumSceneInvestigationCharactersPerGroup = 6_000

    static func makeWorkbook(
        projectTitle: String,
        assets: [AssetItem],
        episodes: [ScriptEpisode],
        template: AssetWorkbookTemplate = .table1,
        table2MergeGroups: [Table2SceneMergeGroup] = []
    ) throws -> Data {
        let episodesByID = indexEpisodesByID(episodes)
        let worksheets = [
            sceneWorksheet(
                assets: orderedSceneAssets(
                    assets,
                    episodes: episodes,
                    template: template,
                    table2MergeGroups: table2MergeGroups
                ),
                episodesByID: episodesByID
            ),
            characterWorksheet(
                assets: libraryOrderedAssets(assets, section: .characters),
                episodesByID: episodesByID
            ),
            propWorksheet(
                assets: libraryOrderedAssets(assets, section: .props),
                episodesByID: episodesByID
            )
        ]

        return try XLSXPackageBuilder.makePackage(
            title: projectTitle,
            worksheets: worksheets
        )
    }

    static func orderedSceneAssets(
        _ assets: [AssetItem],
        episodes: [ScriptEpisode],
        template: AssetWorkbookTemplate,
        table2MergeGroups: [Table2SceneMergeGroup] = []
    ) -> [AssetItem] {
        let libraryOrder = libraryOrderedAssets(assets, section: .scenes)
        guard template == .table2 else { return libraryOrder }

        let sceneContexts = orderedSceneContexts(episodes)

        let scriptOrderedScenes = libraryOrder.enumerated()
            .map { entry in
                ScriptOrderedScene(
                    candidateID: table2CandidateID(for: entry.element),
                    asset: entry.element,
                    key: scriptSortKey(
                        for: entry.element,
                        contexts: sceneContexts,
                        fallbackOrder: entry.offset
                    )
                )
            }
            .sorted { $0.key < $1.key }

        return applyingAIVerifiedMerges(
            scriptOrderedScenes,
            mergeGroups: table2MergeGroups,
            contexts: sceneContexts
        )
    }

    static func table2SceneCandidateGroups(
        _ assets: [AssetItem],
        episodes: [ScriptEpisode]
    ) -> [Table2SceneCandidateGroup] {
        let libraryOrder = libraryOrderedAssets(assets, section: .scenes)
        let contexts = orderedSceneContexts(episodes)
        let entries = libraryOrder.enumerated().map { entry in
            LocalSceneCandidate(
                candidateID: table2CandidateID(for: entry.element),
                asset: entry.element
            )
        }

        var keyOrder: [String] = []
        var entriesByName: [String: [LocalSceneCandidate]] = [:]
        for entry in entries {
            guard let key = localSceneCandidateNameKey(entry.asset.name) else {
                continue
            }
            if entriesByName[key] == nil {
                keyOrder.append(key)
            }
            entriesByName[key, default: []].append(entry)
        }

        var groups: [Table2SceneCandidateGroup] = []
        for key in keyOrder {
            guard let groupedEntries = entriesByName[key], groupedEntries.count >= 2 else {
                continue
            }
            let candidateIDs = groupedEntries.map(\.candidateID)
            guard Set(candidateIDs).count == candidateIDs.count else {
                // Corrupted legacy data can contain duplicate UUIDs. Without a
                // unique stable mapping, never ask AI to merge those rows.
                continue
            }

            let allOccurrences = groupedEntries.map { entry in
                sceneInvestigationOccurrences(
                    for: entry.asset,
                    candidateID: entry.candidateID,
                    contexts: contexts
                )
            }
            let selectedOccurrences = budgetedSceneInvestigationOccurrences(
                allOccurrences
            )
            let candidates = zip(groupedEntries, selectedOccurrences).map {
                entry, occurrences in
                let profile = entry.asset.sceneProfile
                return Table2SceneCandidate(
                    id: entry.candidateID,
                    name: boundedText(entry.asset.name, maximumCharacters: 160),
                    locationGroup: boundedOptionalText(
                        profile?.locationGroup,
                        maximumCharacters: 160
                    ),
                    timeOfDayID: boundedOptionalText(
                        profile?.timeOfDayID,
                        maximumCharacters: 80
                    ),
                    weatherID: boundedOptionalText(
                        profile?.weatherID,
                        maximumCharacters: 80
                    ),
                    season: boundedOptionalText(
                        profile?.season,
                        maximumCharacters: 80
                    ),
                    period: boundedOptionalText(
                        profile?.period,
                        maximumCharacters: 120
                    ),
                    locationType: boundedOptionalText(
                        profile?.locationType,
                        maximumCharacters: 120
                    ),
                    occurrences: occurrences
                )
            }
            groups.append(
                Table2SceneCandidateGroup(
                    id: "same-chinese-name-\(groups.count + 1)",
                    localName: boundedText(
                        groupedEntries[0].asset.name,
                        maximumCharacters: 160
                    ),
                    candidates: candidates
                )
            )
        }
        return groups
    }

    private static func applyingAIVerifiedMerges(
        _ scenes: [ScriptOrderedScene],
        mergeGroups: [Table2SceneMergeGroup],
        contexts: [ScriptEpisodeSceneContext]
    ) -> [AssetItem] {
        let validCandidateIDs = Set(scenes.map(\.candidateID))
        var mergeGroupByCandidateID: [String: Int] = [:]
        for group in mergeGroups {
            let uniqueIDs = Array(Set(group.candidateIDs))
            guard uniqueIDs.count >= 2,
                  uniqueIDs.count == group.candidateIDs.count,
                  uniqueIDs.allSatisfy(validCandidateIDs.contains),
                  uniqueIDs.allSatisfy({ mergeGroupByCandidateID[$0] == nil })
            else {
                continue
            }
            let groupIndex = mergeGroupByCandidateID.count + 1
            for candidateID in uniqueIDs {
                mergeGroupByCandidateID[candidateID] = groupIndex
            }
        }

        var mergedScenes: [AssetItem] = []
        var mergedIndexByGroup: [Int: Int] = [:]

        for scene in scenes {
            guard let groupIndex = mergeGroupByCandidateID[scene.candidateID] else {
                mergedScenes.append(scene.asset)
                continue
            }
            if let mergedIndex = mergedIndexByGroup[groupIndex] {
                mergedScenes[mergedIndex].sourceEpisodeIDs = mergedEpisodeIDs(
                    mergedScenes[mergedIndex].sourceEpisodeIDs,
                    scene.asset.sourceEpisodeIDs,
                    contexts: contexts
                )
            } else {
                mergedIndexByGroup[groupIndex] = mergedScenes.count
                mergedScenes.append(scene.asset)
            }
        }

        return mergedScenes
    }

    private static func orderedSceneContexts(
        _ episodes: [ScriptEpisode]
    ) -> [ScriptEpisodeSceneContext] {
        let orderedEpisodes = episodes.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.order != rhs.element.order {
                    return lhs.element.order < rhs.element.order
                }
                return lhs.offset < rhs.offset
            }

        var seenEpisodeIDs = Set<UUID>()
        var contexts: [ScriptEpisodeSceneContext] = []
        for entry in orderedEpisodes {
            guard seenEpisodeIDs.insert(entry.element.id).inserted else {
                continue
            }
            contexts.append(
                ScriptEpisodeSceneContext(
                    id: entry.element.id,
                    order: entry.element.order,
                    title: boundedText(
                        entry.element.displayTitle,
                        maximumCharacters: 120
                    ),
                    blocks: scriptSceneBlocks(in: entry.element.scriptText)
                )
            )
        }
        return contexts
    }

    private static func table2CandidateID(for asset: AssetItem) -> String {
        "scene-candidate-\(asset.id.uuidString.lowercased())"
    }

    private static func localSceneCandidateNameKey(_ name: String) -> String? {
        guard SearchKeywordCompiler.containsChinese(name) else { return nil }
        let halfwidth = name.applyingTransform(.fullwidthToHalfwidth, reverse: false)
            ?? name
        let folded = halfwidth.precomposedStringWithCanonicalMapping.folding(
            options: [.caseInsensitive],
            locale: Locale(identifier: "zh_Hans")
        )
        let insignificantCharacters: Set<Character> = [
            "·", "•", "・", "‧", "･"
        ]
        let normalized = folded.filter { character in
            !character.isWhitespace && !insignificantCharacters.contains(character)
        }
        return normalized.isEmpty ? nil : normalized
    }

    private static func sceneInvestigationOccurrences(
        for asset: AssetItem,
        candidateID: String,
        contexts: [ScriptEpisodeSceneContext]
    ) -> [Table2SceneCandidateOccurrence] {
        let sourceEpisodeIDs = Set(asset.sourceEpisodeIDs ?? [])
        guard !sourceEpisodeIDs.isEmpty else { return [] }

        var occurrences: [Table2SceneCandidateOccurrence] = []
        for (contextIndex, context) in contexts.enumerated()
            where sourceEpisodeIDs.contains(context.id) {
            for blockIndex in matchingSceneBlockIndexes(
                for: asset,
                in: context.blocks
            ) {
                guard occurrences.count
                        < maximumSceneInvestigationOccurrencesPerCandidate
                else {
                    return occurrences
                }
                let block = context.blocks[blockIndex]
                var heading = boundedText(
                    block.heading,
                    maximumCharacters: 220
                )
                let maximumExcerptCharacters = max(
                    0,
                    maximumSceneInvestigationCharactersPerOccurrence
                        - heading.count
                )
                let body = block.text.components(separatedBy: .newlines)
                    .dropFirst()
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let isOnlySceneInEpisode = context.blocks.count == 1
                let excerptLimit: Int
                if isOnlySceneInEpisode, !body.isEmpty {
                    // A one-scene episode can itself be shorter than the normal
                    // excerpt cap. Always omit at least 25% of its body so this
                    // investigation can never reconstruct the full screenplay.
                    excerptLimit = min(
                        maximumExcerptCharacters,
                        max(0, body.count - max(1, (body.count + 3) / 4))
                    )
                } else {
                    excerptLimit = maximumExcerptCharacters
                }
                let excerpt = boundedText(
                    body,
                    maximumCharacters: excerptLimit
                )
                if isOnlySceneInEpisode, body.isEmpty, !heading.isEmpty {
                    heading = String(heading.dropLast())
                }
                occurrences.append(
                    Table2SceneCandidateOccurrence(
                        id: "\(candidateID)-occurrence-\(contextIndex + 1)-\(blockIndex + 1)",
                        episodeOrder: context.order,
                        episodeTitle: context.title,
                        sceneIdentifier: boundedText(
                            block.identifier,
                            maximumCharacters: 40
                        ),
                        heading: heading,
                        excerpt: excerpt,
                        truncated: body.count > excerpt.count
                            || heading.count < block.heading
                                .trimmingCharacters(in: .whitespacesAndNewlines).count
                    )
                )
            }
        }
        return occurrences
    }

    private static func budgetedSceneInvestigationOccurrences(
        _ occurrencesByCandidate: [[Table2SceneCandidateOccurrence]]
    ) -> [[Table2SceneCandidateOccurrence]] {
        var selected = Array(
            repeating: [Table2SceneCandidateOccurrence](),
            count: occurrencesByCandidate.count
        )
        var selectedCount = 0
        var selectedCharacters = 0

        for occurrenceIndex in 0..<maximumSceneInvestigationOccurrencesPerCandidate {
            for candidateIndex in occurrencesByCandidate.indices {
                guard selectedCount < maximumSceneInvestigationOccurrencesPerGroup,
                      occurrencesByCandidate[candidateIndex].indices.contains(
                        occurrenceIndex
                      )
                else {
                    continue
                }
                let occurrence = occurrencesByCandidate[candidateIndex][occurrenceIndex]
                let scriptCharacterCount = occurrence.heading.count
                    + occurrence.excerpt.count
                guard selectedCharacters + scriptCharacterCount
                        <= maximumSceneInvestigationCharactersPerGroup
                else {
                    continue
                }
                selected[candidateIndex].append(occurrence)
                selectedCount += 1
                selectedCharacters += scriptCharacterCount
            }
        }
        return selected
    }

    private static func boundedOptionalText(
        _ value: String?,
        maximumCharacters: Int
    ) -> String? {
        guard let value else { return nil }
        let bounded = boundedText(value, maximumCharacters: maximumCharacters)
        return bounded.isEmpty ? nil : bounded
    }

    private static func boundedText(
        _ value: String,
        maximumCharacters: Int
    ) -> String {
        guard maximumCharacters > 0 else { return "" }
        return String(
            value.trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(maximumCharacters)
        )
    }

    private static func mergedEpisodeIDs(
        _ first: [UUID]?,
        _ second: [UUID]?,
        contexts: [ScriptEpisodeSceneContext]
    ) -> [UUID]? {
        var allIDs: [UUID] = []
        var seen = Set<UUID>()
        for id in (first ?? []) + (second ?? []) where seen.insert(id).inserted {
            allIDs.append(id)
        }
        guard !allIDs.isEmpty else { return nil }

        let allIDSet = Set(allIDs)
        var orderedIDs = contexts.map(\.id).filter(allIDSet.contains)
        let orderedIDSet = Set(orderedIDs)
        orderedIDs.append(contentsOf: allIDs.filter { !orderedIDSet.contains($0) })
        return orderedIDs
    }

    private static func characterWorksheet(
        assets: [AssetItem],
        episodesByID: [UUID: ScriptEpisode]
    ) -> XLSXWorksheet {
        let wardrobeHeaders = (1...10).map { "服装\($0)" }
        let headers: [String] = [
            "角色", "级别", "角色职能", "介绍", "剧本依据", "涉及集数"
        ] + wardrobeHeaders

        let rows: [[String]] = assets.map { asset in
            let profile = asset.characterProfile
            let wardrobes = (0..<10).map { index in
                guard let look = profile?.wardrobe[safe: index] else { return "" }
                return [
                    look.title,
                    "季节：\(look.season)",
                    "场合：\(look.occasion)",
                    look.storyBeat.isEmpty ? "" : "剧情阶段：\(look.storyBeat)"
                ]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            }

            return [
                asset.name,
                profile?.importance.rawValue ?? "",
                profile?.narrativeRole.title ?? "",
                asset.summary,
                asset.evidence,
                episodeList(for: asset, episodesByID: episodesByID)
            ] + wardrobes
        }

        return XLSXWorksheet(
            name: "人物服装",
            rows: [headers] + rows,
            columnWidths: [
                18, 8, 14, 34, 38, 18,
                30, 30, 30, 30, 30, 30, 30, 30, 30, 30
            ]
        )
    }

    private static func sceneWorksheet(
        assets: [AssetItem],
        episodesByID: [UUID: ScriptEpisode]
    ) -> XLSXWorksheet {
        let headers: [String] = [
            "主场景", "次场景", "涉及集数", "日夜 / 内外", "天气氛围",
            "介绍", "剧本依据", "制作备注"
        ]
        let rows: [[String]] = assets.map { asset in
            let profile = asset.sceneProfile

            return [
                profile?.locationGroupName ?? "",
                asset.name,
                episodeList(for: asset, episodesByID: episodesByID),
                dayNightAndInteriorExterior(for: profile),
                weatherTitle(for: profile),
                asset.summary,
                asset.evidence,
                profile?.productionNotes ?? ""
            ]
        }

        return XLSXWorksheet(
            name: "场景",
            rows: [headers] + rows,
            columnWidths: [20, 22, 18, 16, 16, 34, 38, 34]
        )
    }

    private static func dayNightAndInteriorExterior(for profile: SceneProfile?) -> String {
        guard let profile else { return "" }

        return [
            dayNightTitle(for: profile.timeOfDayID),
            interiorExteriorTitle(for: profile.locationType)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " / ")
    }

    private static func dayNightTitle(for id: String) -> String {
        switch id {
        case "dawn", "day", "golden-hour":
            "日"
        case "dusk", "blue-hour", "night", "midnight":
            "夜"
        case "none", "script", "interior-unspecified", "":
            ""
        default:
            id
        }
    }

    private static func interiorExteriorTitle(for locationType: String) -> String {
        let trimmed = locationType.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        let placeholders = ["", "none", "script", "unspecified", "未标明", "未分类"]
        guard !placeholders.contains(normalized) else { return "" }

        let isInterior = normalized == "int"
            || normalized.contains("interior")
            || normalized.contains("indoor")
            || trimmed.contains("室内")
            || trimmed.contains("内景")
        let isExterior = normalized == "ext"
            || normalized.contains("exterior")
            || normalized.contains("outdoor")
            || trimmed.contains("室外")
            || trimmed.contains("外景")

        switch (isInterior, isExterior) {
        case (true, true):
            return "内/外"
        case (true, false):
            return "内"
        case (false, true):
            return "外"
        case (false, false):
            return trimmed
        }
    }

    private static func weatherTitle(for profile: SceneProfile?) -> String {
        guard let weatherID = profile?.weatherID,
              !["", "none", "script"].contains(weatherID)
        else {
            return ""
        }

        return PromptParameter.weatherAtmosphere.options(for: .scene)
            .first(where: { $0.id == weatherID })?.title ?? weatherID
    }

    private static func propWorksheet(
        assets: [AssetItem],
        episodesByID: [UUID: ScriptEpisode]
    ) -> XLSXWorksheet {
        let headers: [String] = [
            "道具名称", "道具类型", "出现集数", "核心用途", "介绍",
            "剧本依据", "连续性变化"
        ]
        let rows: [[String]] = assets.map { asset in
            let profile = asset.propProfile
            return [
                asset.name,
                profile?.category ?? "",
                episodeList(for: asset, episodesByID: episodesByID),
                profile?.storyFunction ?? "",
                asset.summary,
                asset.evidence,
                profile?.stateChanges ?? ""
            ]
        }

        return XLSXWorksheet(
            name: "道具",
            rows: [headers] + rows,
            columnWidths: [22, 18, 18, 28, 34, 38, 28]
        )
    }

    private static func libraryOrderedAssets(
        _ assets: [AssetItem],
        section: WorkspaceSection
    ) -> [AssetItem] {
        // The model normally owns unique IDs, but corrupted or migrated data
        // must never make export trap in Dictionary(uniqueKeysWithValues:).
        // Give duplicate IDs temporary, verified-unique identities only while
        // asking the library organizer for its display order, then map every
        // row back to the untouched source asset.
        var usedIDs = Set<UUID>()
        var sourceAssetsByWorkingID: [UUID: AssetItem] = [:]
        var workingAssets: [AssetItem] = []
        workingAssets.reserveCapacity(assets.count)

        for sourceAsset in assets {
            var workingAsset = sourceAsset
            while !usedIDs.insert(workingAsset.id).inserted {
                workingAsset.id = UUID()
            }
            sourceAssetsByWorkingID[workingAsset.id] = sourceAsset
            workingAssets.append(workingAsset)
        }

        let organization = AssetLibraryOrganizer.organize(
            assets: workingAssets,
            section: section,
            searchText: ""
        )
        let orderedIDs: [UUID]
        switch section {
        case .scenes:
            orderedIDs = organization.folders.flatMap { location in
                location.children.flatMap { time in
                    time.items.map(\.id)
                }
            }
        case .characters:
            orderedIDs = organization.folders.flatMap { folder in
                folder.items.map(\.id)
            }
        case .props:
            orderedIDs = organization.items.map(\.id)
        case .script, .allAssets:
            orderedIDs = organization.items.map(\.id)
        }

        return orderedIDs.compactMap { sourceAssetsByWorkingID[$0] }
    }

    static func sceneReferenceList(
        for asset: AssetItem,
        episodes: [ScriptEpisode]
    ) -> String {
        let episodesByID = indexEpisodesByID(episodes)
        return episodeList(for: asset, episodesByID: episodesByID)
    }

    private static func indexEpisodesByID(
        _ episodes: [ScriptEpisode]
    ) -> [UUID: ScriptEpisode] {
        var result: [UUID: ScriptEpisode] = [:]
        for episode in episodes.sorted(using: KeyPathComparator(\.order))
            where result[episode.id] == nil {
            result[episode.id] = episode
        }
        return result
    }

    /// XML 1.0 permits tab, LF, CR, and the standard scalar ranges. Filtering
    /// happens on the exported copy only; screenplay and asset text in memory
    /// remains byte-for-byte untouched.
    static func sanitizedXML10Text(_ value: String) -> String {
        String(value.unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0x9, 0xA, 0xD,
                 0x20...0xD7FF,
                 0xE000...0xFFFD,
                 0x10000...0x10FFFF:
                return true
            default:
                return false
            }
        })
    }

    private static func episodeList(
        for asset: AssetItem,
        episodesByID: [UUID: ScriptEpisode]
    ) -> String {
        var references: [String] = []
        var seen = Set<String>()

        for episodeID in asset.sourceEpisodeIDs ?? [] {
            guard let episode = episodesByID[episodeID] else { continue }
            let sceneReferences = matchingSceneReferences(for: asset, in: episode)
            let resolvedReferences = sceneReferences.isEmpty
                ? [episodeIdentifier(for: episode)]
                : sceneReferences
            for reference in resolvedReferences where seen.insert(reference).inserted {
                references.append(reference)
            }
        }

        return references.joined(separator: "、")
    }

    private static func matchingSceneReferences(
        for asset: AssetItem,
        in episode: ScriptEpisode
    ) -> [String] {
        let blocks = scriptSceneBlocks(in: episode.scriptText)
        guard !blocks.isEmpty else { return [] }

        return matchingSceneBlockIndexes(for: asset, in: blocks)
            .map { blocks[$0].identifier }
    }

    private static func matchingSceneBlockIndexes(
        for asset: AssetItem,
        in blocks: [ScriptSceneBlock]
    ) -> [Int] {
        guard !blocks.isEmpty else { return [] }

        let normalizedName = normalizedLookupText(asset.name)
        if !normalizedName.isEmpty {
            let headingMatches = blocks.indices.filter { index in
                normalizedLookupText(blocks[index].heading)
                    .contains(normalizedName)
            }
            if !headingMatches.isEmpty {
                return headingMatches
            }
        }

        var evidenceFragments: [String] = []
        for fragment in asset.evidence.components(
            separatedBy: CharacterSet(charactersIn: "\n。！？；;，,")
        ) {
            let normalizedFragment = normalizedLookupText(fragment)
            if normalizedFragment.count >= 6 {
                evidenceFragments.append(normalizedFragment)
            }
        }

        let matches = blocks.indices.filter { index in
            let block = blocks[index]
            let normalizedBlock = normalizedLookupText(block.text)
            if normalizedName.count >= 2,
               normalizedBlock.contains(normalizedName) {
                return true
            }
            return evidenceFragments.contains { normalizedBlock.contains($0) }
        }
        if !matches.isEmpty {
            return matches
        }

        // A single-scene episode has no ambiguity even when the model chose a
        // canonical asset name that does not occur verbatim in the screenplay.
        return blocks.count == 1 ? [0] : []
    }

    private static func scriptSortKey(
        for asset: AssetItem,
        contexts: [ScriptEpisodeSceneContext],
        fallbackOrder: Int
    ) -> ScriptSceneSortKey {
        let sourceEpisodeIDs = Set(asset.sourceEpisodeIDs ?? [])
        guard !sourceEpisodeIDs.isEmpty else {
            return ScriptSceneSortKey(
                episodeOrder: .max,
                sceneOrder: .max,
                fallbackOrder: fallbackOrder
            )
        }

        var firstAssociatedEpisodeOrder: Int?
        for (episodeOrder, context) in contexts.enumerated()
            where sourceEpisodeIDs.contains(context.id) {
            if firstAssociatedEpisodeOrder == nil {
                firstAssociatedEpisodeOrder = episodeOrder
            }
            guard let sceneOrder = matchingSceneBlockIndexes(
                for: asset,
                in: context.blocks
            ).first else {
                continue
            }
            return ScriptSceneSortKey(
                episodeOrder: episodeOrder,
                sceneOrder: sceneOrder,
                fallbackOrder: fallbackOrder
            )
        }

        if let firstAssociatedEpisodeOrder {
            return ScriptSceneSortKey(
                episodeOrder: firstAssociatedEpisodeOrder,
                sceneOrder: .max,
                fallbackOrder: fallbackOrder
            )
        }

        return ScriptSceneSortKey(
            episodeOrder: .max,
            sceneOrder: .max,
            fallbackOrder: fallbackOrder
        )
    }

    private static func scriptSceneBlocks(in script: String) -> [ScriptSceneBlock] {
        let headingPattern = #"^\s*(?:>\s*)?(?:[-+]\s+)?(?:#{1,6}\s*)?(?:\*{1,3}|_{1,3})?\s*([0-9０-９]{1,4})\s*[-—–－]\s*([0-9０-９]{1,3}[A-Za-z]?)(?=[^0-9０-９A-Za-z]|$)"#
        guard let expression = try? NSRegularExpression(pattern: headingPattern) else {
            return []
        }

        var blocks: [ScriptSceneBlock] = []
        var currentIdentifier: String?
        var currentHeading = ""
        var currentLines: [String] = []

        func appendCurrentBlock() {
            guard let currentIdentifier else { return }
            blocks.append(
                ScriptSceneBlock(
                    identifier: currentIdentifier,
                    heading: currentHeading,
                    text: currentLines.joined(separator: "\n")
                )
            )
        }

        for line in EpisodeScriptSplitter.sanitizeNovelChapterMarkers(in: script)
            .components(separatedBy: .newlines) {
            let lineRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = expression.firstMatch(in: line, range: lineRange),
               let episodeRange = Range(match.range(at: 1), in: line),
               let sceneRange = Range(match.range(at: 2), in: line) {
                appendCurrentBlock()
                currentIdentifier = normalizedSceneIdentifier(
                    "\(line[episodeRange])-\(line[sceneRange])"
                )
                currentHeading = line
                currentLines = [line]
            } else if currentIdentifier != nil {
                currentLines.append(line)
            }
        }
        appendCurrentBlock()
        return blocks
    }

    private static func episodeIdentifier(for episode: ScriptEpisode) -> String {
        let sanitizedTitle = EpisodeScriptSplitter.sanitizeNovelChapterMarkers(
            in: episode.title
        )
        let candidates = [sanitizedTitle, episode.scriptText]
        let patterns = [
            #"第\s*([0-9０-９]{1,4})\s*集"#,
            #"(?:EPISODE|EP\.?|E)\s*([0-9０-９]{1,4})"#
        ]

        for candidate in candidates {
            for pattern in patterns {
                guard let expression = try? NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive]
                ) else {
                    continue
                }
                let candidateRange = NSRange(
                    candidate.startIndex..<candidate.endIndex,
                    in: candidate
                )
                if let match = expression.firstMatch(in: candidate, range: candidateRange),
                   let valueRange = Range(match.range(at: 1), in: candidate) {
                    return normalizedSceneIdentifier(String(candidate[valueRange]))
                }
            }
        }

        return String(episode.order)
    }

    private static func normalizedSceneIdentifier(_ value: String) -> String {
        let halfwidth = value.applyingTransform(.fullwidthToHalfwidth, reverse: false)
            ?? value
        return halfwidth
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: " ", with: "")
    }

    private static func normalizedLookupText(_ value: String) -> String {
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "zh_Hans")
        )
        return folded.unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()
    }

    private struct ScriptSceneBlock {
        let identifier: String
        let heading: String
        let text: String
    }

    private struct ScriptEpisodeSceneContext {
        let id: UUID
        let order: Int
        let title: String
        let blocks: [ScriptSceneBlock]
    }

    private struct ScriptOrderedScene {
        let candidateID: String
        let asset: AssetItem
        let key: ScriptSceneSortKey
    }

    private struct LocalSceneCandidate {
        let candidateID: String
        let asset: AssetItem
    }

    private struct ScriptSceneSortKey: Comparable {
        let episodeOrder: Int
        let sceneOrder: Int
        let fallbackOrder: Int

        static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.episodeOrder != rhs.episodeOrder {
                return lhs.episodeOrder < rhs.episodeOrder
            }
            if lhs.sceneOrder != rhs.sceneOrder {
                return lhs.sceneOrder < rhs.sceneOrder
            }
            return lhs.fallbackOrder < rhs.fallbackOrder
        }
    }
}

private struct XLSXWorksheet {
    let name: String
    let rows: [[String]]
    let columnWidths: [Double]
}

private enum XLSXPackageBuilder {
    static func makePackage(
        title: String,
        worksheets: [XLSXWorksheet]
    ) throws -> Data {
        var files: [(String, Data)] = [
            ("[Content_Types].xml", xmlData(contentTypesXML(sheetCount: worksheets.count))),
            ("_rels/.rels", xmlData(rootRelationshipsXML)),
            ("docProps/core.xml", xmlData(corePropertiesXML(title: title))),
            ("docProps/app.xml", xmlData(appPropertiesXML(worksheets: worksheets))),
            ("xl/workbook.xml", xmlData(workbookXML(worksheets: worksheets))),
            ("xl/_rels/workbook.xml.rels", xmlData(workbookRelationshipsXML(sheetCount: worksheets.count))),
            ("xl/styles.xml", xmlData(stylesXML))
        ]

        for (index, worksheet) in worksheets.enumerated() {
            files.append((
                "xl/worksheets/sheet\(index + 1).xml",
                xmlData(worksheetXML(worksheet))
            ))
        }
        return try StoredZipArchive.makeArchive(files: files)
    }

    private static func xmlData(_ value: String) -> Data {
        Data(value.utf8)
    }

    private static func contentTypesXML(sheetCount: Int) -> String {
        let worksheets = (1...sheetCount).map {
            #"<Override PartName="/xl/worksheets/sheet\#($0).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>"#
        }
        .joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        \(worksheets)
        <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
        <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
        </Types>
        """
    }

    private static let rootRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
    <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
    </Relationships>
    """

    private static func corePropertiesXML(title: String) -> String {
        let timestamp = ISO8601DateFormatter().string(from: .now)
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <dc:title>\(escapeXML(title))</dc:title>
        <dc:creator>美术台</dc:creator>
        <cp:lastModifiedBy>美术台</cp:lastModifiedBy>
        <dcterms:created xsi:type="dcterms:W3CDTF">\(timestamp)</dcterms:created>
        <dcterms:modified xsi:type="dcterms:W3CDTF">\(timestamp)</dcterms:modified>
        </cp:coreProperties>
        """
    }

    private static func appPropertiesXML(worksheets: [XLSXWorksheet]) -> String {
        let names = worksheets
            .map { "<vt:lpstr>\(escapeXML($0.name))</vt:lpstr>" }
            .joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
        <Application>美术台</Application>
        <HeadingPairs><vt:vector size="2" baseType="variant"><vt:variant><vt:lpstr>工作表</vt:lpstr></vt:variant><vt:variant><vt:i4>\(worksheets.count)</vt:i4></vt:variant></vt:vector></HeadingPairs>
        <TitlesOfParts><vt:vector size="\(worksheets.count)" baseType="lpstr">\(names)</vt:vector></TitlesOfParts>
        </Properties>
        """
    }

    private static func workbookXML(worksheets: [XLSXWorksheet]) -> String {
        let sheets = worksheets.enumerated().map { index, worksheet in
            #"<sheet name="\#(escapeXML(worksheet.name))" sheetId="\#(index + 1)" r:id="rId\#(index + 1)"/>"#
        }
        .joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <bookViews><workbookView activeTab="0"/></bookViews>
        <sheets>\(sheets)</sheets>
        <calcPr calcId="191029"/>
        </workbook>
        """
    }

    private static func workbookRelationshipsXML(sheetCount: Int) -> String {
        let worksheets = (1...sheetCount).map {
            #"<Relationship Id="rId\#($0)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet\#($0).xml"/>"#
        }
        .joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        \(worksheets)
        <Relationship Id="rId\(sheetCount + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """
    }

    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
    <fonts count="2">
    <font><sz val="11"/><name val="Aptos"/></font>
    <font><b/><color rgb="FFFFFFFF"/><sz val="11"/><name val="Aptos"/></font>
    </fonts>
    <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF294766"/><bgColor indexed="64"/></patternFill></fill>
    </fills>
    <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border><left style="thin"><color rgb="FFD8DEE6"/></left><right style="thin"><color rgb="FFD8DEE6"/></right><top style="thin"><color rgb="FFD8DEE6"/></top><bottom style="thin"><color rgb="FFD8DEE6"/></bottom><diagonal/></border>
    </borders>
    <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
    <cellXfs count="3">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
    </cellXfs>
    <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
    </styleSheet>
    """

    private static func worksheetXML(_ worksheet: XLSXWorksheet) -> String {
        let rowCount = max(worksheet.rows.count, 1)
        let columnCount = max(worksheet.rows.map(\.count).max() ?? 1, 1)
        let lastCell = "\(columnName(columnCount))\(rowCount)"
        let columns = worksheet.columnWidths.enumerated().map { index, width in
            #"<col min="\#(index + 1)" max="\#(index + 1)" width="\#(width)" customWidth="1"/>"#
        }
        .joined()
        let rows = worksheet.rows.enumerated().map { rowIndex, values in
            let cells = values.enumerated().map { columnIndex, value in
                let reference = "\(columnName(columnIndex + 1))\(rowIndex + 1)"
                let preserve = value.hasPrefix(" ") || value.hasSuffix(" ") || value.contains("\n")
                    ? #" xml:space="preserve""#
                    : ""
                return #"<c r="\#(reference)" s="\#(rowIndex == 0 ? 1 : 2)" t="inlineStr"><is><t\#(preserve)>\#(escapeXML(value))</t></is></c>"#
            }
            .joined()
            let height = rowIndex == 0 ? #" ht="32" customHeight="1""# : ""
            return #"<row r="\#(rowIndex + 1)"\#(height)>\#(cells)</row>"#
        }
        .joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>
        <dimension ref="A1:\(lastCell)"/>
        <sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
        <sheetFormatPr defaultRowHeight="30"/>
        <cols>\(columns)</cols>
        <sheetData>\(rows)</sheetData>
        <autoFilter ref="A1:\(lastCell)"/>
        <pageMargins left="0.25" right="0.25" top="0.5" bottom="0.5" header="0.2" footer="0.2"/>
        <pageSetup orientation="landscape" fitToWidth="1" fitToHeight="0"/>
        </worksheet>
        """
    }

    private static func columnName(_ index: Int) -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var value = index
        var result = ""
        while value > 0 {
            value -= 1
            result = String(letters[value % letters.count]) + result
            value /= letters.count
        }
        return result
    }

    private static func escapeXML(_ value: String) -> String {
        AssetWorkbookExporter.sanitizedXML10Text(value)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private enum StoredZipArchive {
    private struct Entry {
        let nameData: Data
        let data: Data
        let checksum: UInt32
        let offset: UInt32
    }

    private enum ArchiveError: LocalizedError {
        case fileTooLarge

        var errorDescription: String? {
            "导出的 XLSX 数据超过 ZIP32 格式上限。"
        }
    }

    static func makeArchive(files: [(String, Data)]) throws -> Data {
        var archive = Data()
        var entries: [Entry] = []

        for (name, contents) in files {
            let nameData = Data(name.utf8)
            guard nameData.count <= Int(UInt16.max),
                  contents.count <= Int(UInt32.max),
                  archive.count <= Int(UInt32.max)
            else {
                throw ArchiveError.fileTooLarge
            }

            let entry = Entry(
                nameData: nameData,
                data: contents,
                checksum: crc32(contents),
                offset: UInt32(archive.count)
            )
            entries.append(entry)
            appendLocalHeader(entry, to: &archive)
            archive.append(contents)
        }

        guard archive.count <= Int(UInt32.max) else {
            throw ArchiveError.fileTooLarge
        }
        let centralDirectoryOffset = UInt32(archive.count)

        for entry in entries {
            appendCentralDirectoryHeader(entry, to: &archive)
        }

        let centralDirectorySize = UInt32(archive.count) - centralDirectoryOffset
        guard entries.count <= Int(UInt16.max) else {
            throw ArchiveError.fileTooLarge
        }

        archive.appendUInt32(0x06054B50)
        archive.appendUInt16(0)
        archive.appendUInt16(0)
        archive.appendUInt16(UInt16(entries.count))
        archive.appendUInt16(UInt16(entries.count))
        archive.appendUInt32(centralDirectorySize)
        archive.appendUInt32(centralDirectoryOffset)
        archive.appendUInt16(0)
        return archive
    }

    private static func appendLocalHeader(_ entry: Entry, to archive: inout Data) {
        archive.appendUInt32(0x04034B50)
        archive.appendUInt16(20)
        archive.appendUInt16(0x0800)
        archive.appendUInt16(0)
        archive.appendUInt16(0)
        archive.appendUInt16(0x0021)
        archive.appendUInt32(entry.checksum)
        archive.appendUInt32(UInt32(entry.data.count))
        archive.appendUInt32(UInt32(entry.data.count))
        archive.appendUInt16(UInt16(entry.nameData.count))
        archive.appendUInt16(0)
        archive.append(entry.nameData)
    }

    private static func appendCentralDirectoryHeader(
        _ entry: Entry,
        to archive: inout Data
    ) {
        archive.appendUInt32(0x02014B50)
        archive.appendUInt16(20)
        archive.appendUInt16(20)
        archive.appendUInt16(0x0800)
        archive.appendUInt16(0)
        archive.appendUInt16(0)
        archive.appendUInt16(0x0021)
        archive.appendUInt32(entry.checksum)
        archive.appendUInt32(UInt32(entry.data.count))
        archive.appendUInt32(UInt32(entry.data.count))
        archive.appendUInt16(UInt16(entry.nameData.count))
        archive.appendUInt16(0)
        archive.appendUInt16(0)
        archive.appendUInt16(0)
        archive.appendUInt16(0)
        archive.appendUInt32(0)
        archive.appendUInt32(entry.offset)
        archive.append(entry.nameData)
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var checksum = UInt32.max
        for byte in data {
            checksum ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = 0 &- (checksum & 1)
                checksum = (checksum >> 1) ^ (0xEDB88320 & mask)
            }
        }
        return checksum ^ UInt32.max
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }
}
