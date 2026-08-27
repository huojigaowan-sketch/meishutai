import SwiftUI

struct AssetInspectorView: View {
    @Binding var asset: AssetItem
    let onCommit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                identitySection
                sourceSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(asset.name)
        .task(id: asset) {
            do {
                try await Task.sleep(for: .milliseconds(450))
                onCommit()
            } catch {
                return
            }
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(asset.kind.title, systemImage: asset.kind.systemImage)
                    .font(.headline)

                if let importance = asset.characterProfile?.importance {
                    Text(importance.rawValue)
                        .font(.caption.weight(.black))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(importance == .s ? .red : .orange, in: .capsule)
                        .foregroundStyle(.white)
                        .help(importance.title)
                }

                Spacer()

                Picker("复核状态", selection: $asset.reviewState) {
                    ForEach(AssetReviewState.allCases, id: \.self) { state in
                        Label(state.title, systemImage: state.systemImage)
                            .tag(state)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 120)
            }

            TextField("资产名称", text: $asset.name)
                .font(.title3.weight(.semibold))

            TextField(
                "剧本提取摘要",
                text: $asset.summary,
                axis: .vertical
            )
            .lineLimit(3...8)
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("剧本依据", systemImage: "text.quote")
                    .font(.headline)

                Spacer()

                if let sourceEpisodeIDs = asset.sourceEpisodeIDs,
                   !sourceEpisodeIDs.isEmpty {
                    Label(
                        "来自 \(sourceEpisodeIDs.count) 集",
                        systemImage: "square.stack.3d.up"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Text(asset.evidence.isEmpty ? "模型未提供对应原文片段。" : asset.evidence)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

#Preview("提取结果检查器") {
    ExtractionInspectorPreview()
        .frame(width: 520, height: 620)
}

private struct ExtractionInspectorPreview: View {
    @State private var asset = AssetItem(
        kind: .character,
        name: "林默",
        summary: "女主角，调查员。",
        evidence: "女主角林默，32岁，身形高挑精瘦。",
        reviewState: .accepted
    )

    var body: some View {
        AssetInspectorView(
            asset: $asset,
            onCommit: {}
        )
    }
}
