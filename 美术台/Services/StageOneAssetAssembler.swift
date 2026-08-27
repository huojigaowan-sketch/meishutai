import Foundation

enum StageOneAssetAssembler {
    nonisolated static func extractedAssets(
        from ledger: EpisodeExtractionLedger,
        source: String
    ) -> ExtractedAssets {
        let candidatesByID = Dictionary(
            ledger.candidates.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let scenesByID = Dictionary(
            ledger.scenes.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let accepted = ledger.decisions.compactMap {
            decision -> ResolvedOccurrence? in
            guard decision.disposition == .accepted,
                  let candidate = candidatesByID[decision.candidateID],
                  candidate.evidence.text(in: source) != nil else {
                return nil
            }
            let canonicalName = decision.canonicalName
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !canonicalName.isEmpty else { return nil }
            return ResolvedOccurrence(
                candidate: candidate,
                decision: decision,
                scene: scenesByID[candidate.sceneID]
            )
        }

        var groups: [String: [ResolvedOccurrence]] = [:]
        var orderedKeys: [String] = []
        for occurrence in accepted.sorted(by: occurrenceOrder) {
            let canonicalName = occurrence.candidate.kind == .character
                ? CharacterRolePolicy.canonicalName(for: occurrence.decision.canonicalName)
                : occurrence.decision.canonicalName
            let key = CanonicalAssetIdentity.key(
                kind: occurrence.candidate.kind,
                canonicalName: canonicalName,
                identityQualifier: occurrence.decision.identityQualifier
            )
            if groups[key] == nil { orderedKeys.append(key) }
            groups[key, default: []].append(occurrence)
        }

        var scenes: [ExtractedScene] = []
        var characters: [ExtractedCharacter] = []
        var props: [ExtractedProp] = []
        for key in orderedKeys {
            guard let values = groups[key], let first = values.first else { continue }
            let evidence = evidenceDigest(values)
            let sceneCount = Set(values.map { $0.candidate.sceneID }).count
            switch first.candidate.kind {
            case .scene:
                scenes.append(ExtractedScene(
                    name: first.decision.canonicalName,
                    description: "剧本中出现于 \(sceneCount) 个场次。",
                    evidence: evidence,
                    locationGroup: first.scene?.locationGroup,
                    timeOfDayID: nil,
                    weatherID: nil,
                    season: nil,
                    period: nil,
                    locationType: first.scene?.interiorExterior,
                    productionNotes: nil
                ))
            case .character:
                let canonicalName = CharacterRolePolicy.canonicalName(
                    for: first.decision.canonicalName
                )
                characters.append(ExtractedCharacter(
                    name: canonicalName,
                    description: "剧本中出现于 \(sceneCount) 个场次。",
                    evidence: evidence,
                    importanceTier: nil,
                    narrativeRole: nil,
                    affiliation: nil,
                    appearanceCount: max(sceneCount, 1),
                    genderPresentation: nil,
                    ageRange: nil,
                    wardrobes: nil
                ))
            case .prop:
                props.append(ExtractedProp(
                    name: first.decision.canonicalName,
                    description: "剧本中出现于 \(sceneCount) 个场次。",
                    evidence: evidence,
                    category: first.decision.identityQualifier,
                    storyFunction: nil,
                    stateChanges: values.compactMap { $0.decision.variantLabel }
                        .uniqued()
                        .joined(separator: "；")
                ))
            }
        }
        return ExtractedAssets(
            scenes: scenes,
            characters: characters,
            props: props
        )
    }

    nonisolated static func occurrences(
        from ledger: EpisodeExtractionLedger,
        source: String
    ) -> [String: [AssetOccurrence]] {
        let candidatesByID = Dictionary(
            ledger.candidates.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let scenesByID = Dictionary(
            ledger.scenes.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var result: [String: [AssetOccurrence]] = [:]
        for decision in ledger.decisions where decision.disposition == .accepted {
            guard let candidate = candidatesByID[decision.candidateID],
                  candidate.evidence.text(in: source) != nil else {
                continue
            }
            let canonicalName = candidate.kind == .character
                ? CharacterRolePolicy.canonicalName(for: decision.canonicalName)
                : decision.canonicalName
            let key = CanonicalAssetIdentity.key(
                kind: candidate.kind,
                canonicalName: canonicalName,
                identityQualifier: decision.identityQualifier
            )
            result[key, default: []].append(AssetOccurrence(
                id: candidate.id,
                episodeID: ledger.episodeID,
                sceneID: candidate.sceneID,
                candidateID: candidate.id,
                rawName: candidate.rawName,
                evidence: candidate.evidence,
                variantLabel: decision.variantLabel,
                timeOfDayID: scenesByID[candidate.sceneID]?.timeOfDayID
            ))
        }
        return result
    }

    private struct ResolvedOccurrence {
        let candidate: StageOneCandidate
        let decision: StageOneCandidateDecision
        let scene: ScreenplaySceneUnit?
    }

    nonisolated private static func occurrenceOrder(
        _ lhs: ResolvedOccurrence,
        _ rhs: ResolvedOccurrence
    ) -> Bool {
        if lhs.candidate.evidence.utf16Location != rhs.candidate.evidence.utf16Location {
            return lhs.candidate.evidence.utf16Location < rhs.candidate.evidence.utf16Location
        }
        return lhs.candidate.id < rhs.candidate.id
    }

    nonisolated private static func evidenceDigest(_ values: [ResolvedOccurrence]) -> String {
        values.map { value in
            let scene = value.scene?.sceneIdentifier ?? "未标场次"
            return "[\(scene)] \(value.candidate.evidence.excerpt)"
        }
        .uniqued()
        .prefix(12)
        .joined(separator: "\n")
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
