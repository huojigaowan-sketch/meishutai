import Foundation

nonisolated extension ArtPromptPlan {
    func requiresRebuild(
        for asset: ProductionAsset,
        styleCards: [StylePromptCard],
        mode expectedMode: ImageGenerationMode
    ) -> Bool {
        let expectedStyleTreatment = StyleOnlyPromptPolicy.subjectNeutralEnvelope(
            styleCards.map {
                StyleOnlyPromptPolicy.safeStyleFragment(
                    $0.prompt,
                    category: $0.category
                )
            }
        )
        return positivePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || mode != expectedMode
            || chosenStyleCardIDs != styleCards.map(\.id)
            || assetDesignPrompt != asset.designPrompt
            || styleTreatmentPrompt != expectedStyleTreatment
    }
}
