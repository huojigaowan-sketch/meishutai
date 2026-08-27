import SwiftUI

#if DEBUG
/// A launch-argument-only surface for exercising the exact production click
/// preview controls without loading a full project into the accessibility tree.
struct PromptPreviewLabView: View {
    @State private var asset = AssetItem(
        kind: .character,
        name: "真人规格预览",
        summary: "用于逐项核对照片预览与最终提示词同步。",
        basePrompt: "fictional adult East Asian model in a cinematic studio portrait"
    )

    var body: some View {
        ScrollView {
            ParameterControlsView(asset: $asset)
                .padding(24)
                .frame(maxWidth: 620, alignment: .topLeading)
        }
        .navigationTitle("真人规格悬停验收")
    }
}
#endif
