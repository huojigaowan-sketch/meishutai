import Foundation

enum PromptCompiler {
    static func compile(_ asset: AssetItem) -> String {
        var fragments = [
            asset.kind.title,
            asset.name,
            asset.summary,
            asset.evidence
        ]

        switch asset.kind {
        case .scene:
            if let profile = asset.sceneProfile {
                fragments.append(profile.locationGroup ?? "")
                fragments.append(profile.timeOfDayID)
                fragments.append(profile.weatherID)
                fragments.append(profile.season)
                fragments.append(profile.period)
                fragments.append(profile.locationType)
                fragments.append(profile.productionNotes)
            }
        case .character:
            if let profile = asset.characterProfile {
                fragments.append(profile.importance.title)
                fragments.append(profile.narrativeRole.title)
                if let affiliation = profile.affiliation {
                    fragments.append(affiliation)
                }
                if let appearanceCount = profile.appearanceCount {
                    fragments.append("appearanceCount:")
                    fragments.append(String(appearanceCount))
                }
                fragments.append(profile.genderPresentation)
                fragments.append(profile.ageRange)
                fragments.append(contentsOf: profile.wardrobe.map { look in
                    [look.title, look.season, look.occasion, look.storyBeat]
                }.flatMap { $0 })
            }
        case .prop:
            if let profile = asset.propProfile {
                fragments.append(profile.category)
                fragments.append(profile.storyFunction)
                fragments.append(profile.stateChanges)
            }
        }

        return fragments
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(englishProjection)
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    static func hasRejectedNonEnglishText(_ asset: AssetItem) -> Bool {
        [asset.summary, asset.evidence].contains { text in
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !english(text)
        }
    }

    static func english(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { scalar in
            (32..<127).contains(scalar.value)
                || scalar.value == 9
                || scalar.value == 10
                || scalar.value == 13
        }
    }

    private static func englishProjection(_ value: String) -> String {
        let folded = value.folding(
            options: [.diacriticInsensitive, .widthInsensitive, .caseFold],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return folded.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
