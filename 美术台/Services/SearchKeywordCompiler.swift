import Foundation

enum SearchKeywordCompiler {
    static func compile(_ asset: AssetItem) -> String {
        var fragments = [
            valid(asset.searchKeywords)
        ]

        switch asset.kind {
        case .scene:
            if let scene = asset.sceneProfile {
                fragments.append(searchableMetadata(scene.period))
                fragments.append(searchableMetadata(scene.locationType))
                fragments.append(searchableMetadata(scene.season))
            }

        case .character:
            if let character = asset.characterProfile {
                fragments.append(valid(character.faceSearchKeywords))

                if let activeWardrobeID = asset.activeWardrobeID,
                   let wardrobe = character.wardrobe.first(
                       where: { $0.id == activeWardrobeID }
                   ) {
                    fragments.append(valid(wardrobe.searchKeywords))
                }

                fragments.append(valid(character.physiqueSearchKeywords))
                fragments.append(valid(character.hairMakeupSearchKeywords))
                fragments.append(valid(character.distinguishingFeaturesSearchKeywords))
            }

        case .prop:
            if let prop = asset.propProfile {
                fragments.append(valid(prop.materialSearchKeywords))
                fragments.append(valid(prop.constructionSearchKeywords))
                fragments.append(searchableMetadata(prop.category))
            }
        }

        fragments.append(contentsOf: selectedParameterKeywords(for: asset))

        var terms = uniqueTerms(from: fragments, limit: 28)
        if terms.isEmpty {
            terms = fallbackTerms(for: asset)
        }
        return terms.joined(separator: " ")
    }

    static func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                true
            default:
                false
            }
        }
    }

    private static func selectedParameterKeywords(
        for asset: AssetItem
    ) -> [String] {
        PromptParameter.allCases.compactMap { parameter in
            guard parameter.supports(asset.kind),
                  parameter.isVisibleInControls,
                  let selectedID = asset.parameterSelections[parameter.rawValue],
                  selectedID != PromptParameter.noneOptionID,
                  let option = parameter.options(for: asset.kind).first(
                      where: { $0.id == selectedID }
                  ),
                  !option.promptToken.isEmpty
            else {
                return nil
            }

            if containsChinese(option.title) {
                return option.title
            }
            if containsChinese(option.detail) {
                return "\(option.title) \(option.detail)"
            }
            return option.title
        }
    }

    private static func fallbackTerms(for asset: AssetItem) -> [String] {
        var values: [String] = []
        if containsChinese(asset.name) {
            values.append(asset.name)
        }

        switch asset.kind {
        case .scene:
            values.append("影视场景")
        case .character:
            values.append("真人角色造型")
        case .prop:
            values.append("影视道具")
        }

        if containsChinese(asset.summary) {
            values.append(asset.summary)
        }
        return uniqueTerms(from: values, limit: 16)
    }

    private static func valid(_ text: String?) -> String {
        let normalized = text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return containsChinese(normalized) ? normalized : ""
    }

    private static func searchableMetadata(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders = ["", "未标明", "未分类", "unspecified", "none", "script"]
        guard !placeholders.contains(normalized.lowercased()) else {
            return ""
        }
        return containsChinese(normalized) ? normalized : ""
    }

    private static func uniqueTerms(
        from fragments: [String],
        limit: Int
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for fragment in fragments {
            let normalized = fragment
                .replacingOccurrences(
                    of: "[，,、；;。|/\\\n\\\r\\\t]+",
                    with: " ",
                    options: .regularExpression
                )
                .replacingOccurrences(
                    of: "\\s+",
                    with: " ",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

            for term in normalized.split(separator: " ").map(String.init) {
                let key = term.folding(
                    options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                    locale: .current
                )
                guard seen.insert(key).inserted else {
                    continue
                }
                result.append(term)
                if result.count == limit {
                    return result
                }
            }
        }
        return result
    }
}
