import AppKit
import SwiftUI

struct AssetLibraryView: View {
    @Bindable var store: WorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            AssetLibraryHeader(
                section: $store.selectedSection,
                assetCount: store.filteredAssets.count,
                isAnalyzing: store.isAnalyzing
            )
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            Divider()

            if store.filteredAssets.isEmpty {
                AssetLibraryEmptyState(
                    section: store.selectedSection,
                    searchText: store.searchText,
                    onClearSearch: { store.searchText = "" },
                    onReturnToScript: { store.selectedSection = .script }
                )
            } else {
                AssetLibraryList(store: store)
            }
        }
        .searchable(
            text: $store.searchText,
            placement: .toolbar,
            prompt: "搜索当前项目的资产"
        )
        .onChange(of: store.selectedSection) { _, _ in
            let visibleIDs = Set(store.filteredAssets.map(\.id))
            if let selectedAssetID = store.selectedAssetID,
               !visibleIDs.contains(selectedAssetID) {
                store.selectedAssetID = store.filteredAssets.first?.id
            }
        }
    }
}

private struct AssetLibraryHeader: View {
    @Binding var section: WorkspaceSection
    let assetCount: Int
    let isAnalyzing: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("第一阶段 · 提取结果")
                    .font(.title2.weight(.semibold))

                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("资产类型", selection: $section) {
                Text("全部").tag(WorkspaceSection.allAssets)
                Text("场景").tag(WorkspaceSection.scenes)
                Text("人物").tag(WorkspaceSection.characters)
                Text("道具").tag(WorkspaceSection.props)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            if isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在更新资产…")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var summary: String {
        if assetCount == 0 {
            return "先在第一阶段逐集提取资产与概览"
        }

        switch section {
        case .scenes:
            return "\(assetCount) 个场景 · 可在右侧核对名称、摘要与剧本依据"
        case .characters:
            return "\(assetCount) 个人物 · 可在右侧核对名称、摘要与剧本依据"
        case .props:
            return "\(assetCount) 个道具 · 可在右侧核对名称、摘要与剧本依据"
        case .script, .allAssets:
            return "\(assetCount) 个提取结果 · 可按人物、场景、道具筛选与复核"
        }
    }
}

private struct AssetLibraryEmptyState: View {
    let section: WorkspaceSection
    let searchText: String
    let onClearSearch: () -> Void
    let onReturnToScript: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("这里还很安静", systemImage: section.systemImage)
        } description: {
            Text(
                searchText.isEmpty
                    ? "先到剧本页完成一次拆解，场景、人物和道具会自动出现在这里。"
                    : "没有资产符合当前搜索，可以换个关键词。"
            )
        } actions: {
            if !searchText.isEmpty {
                Button("清除搜索", action: onClearSearch)
                    .buttonStyle(.bordered)
            } else {
                Button(action: onReturnToScript) {
                    Label("回到剧本", systemImage: "arrow.left")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct AssetLibraryList: View {
    @Bindable var store: WorkspaceStore

    var body: some View {
        List(selection: $store.selectedAssetID) {
            switch store.selectedSection {
            case .scenes:
                ForEach(store.assetLibraryFolders) { folder in
                    SceneLocationFolderRow(
                        folder: folder,
                        store: store
                    )
                }
            case .characters:
                ForEach(store.assetLibraryFolders) { folder in
                    CharacterFolderRow(
                        folder: folder,
                        store: store
                    )
                }
            case .script, .allAssets, .props:
                ForEach(store.assetLibraryItems) { item in
                    AssetLibraryItemRow(
                        item: item,
                        store: store
                    )
                }
            }
        }
        .listStyle(.inset)
    }
}

private struct SceneLocationFolderRow: View {
    let folder: AssetLibraryFolder
    @Bindable var store: WorkspaceStore

    var body: some View {
        DisclosureGroup {
            ForEach(folder.children) { timeFolder in
                SceneTimeFolderRow(
                    folder: timeFolder,
                    store: store
                )
            }
        } label: {
            AssetFolderLabel(
                title: folder.title,
                systemImage: folder.systemImage,
                itemCount: folder.itemCount,
                level: .location
            )
        }
    }
}

private struct SceneTimeFolderRow: View {
    let folder: AssetLibraryFolder
    @Bindable var store: WorkspaceStore

    var body: some View {
        DisclosureGroup {
            ForEach(folder.items) { item in
                AssetLibraryItemRow(
                    item: item,
                    store: store
                )
            }
        } label: {
            AssetFolderLabel(
                title: folder.title,
                systemImage: folder.systemImage,
                itemCount: folder.itemCount,
                level: .variant
            )
        }
    }
}

private struct CharacterFolderRow: View {
    let folder: AssetLibraryFolder
    @Bindable var store: WorkspaceStore

    var body: some View {
        DisclosureGroup {
            ForEach(folder.items) { item in
                AssetLibraryItemRow(
                    item: item,
                    store: store
                )
            }
        } label: {
            AssetFolderLabel(
                title: folder.title,
                systemImage: folder.systemImage,
                itemCount: folder.itemCount,
                level: .location
            )
        }
    }
}

private struct AssetFolderLabel: View {
    enum Level {
        case location
        case variant
    }

    let title: String
    let systemImage: String
    let itemCount: Int
    let level: Level

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(
                    level == .location ? Color.accentColor : Color.secondary
                )
                .frame(width: 18)

            Text(title)
                .fontWeight(level == .location ? .semibold : .regular)
                .lineLimit(1)

            Spacer()

            Text(itemCount, format: .number)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, level == .location ? 4 : 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(itemCount) 个资产")
    }
}

private struct AssetLibraryItemRow: View {
    let item: AssetLibraryItem
    @Bindable var store: WorkspaceStore

    var body: some View {
        HStack(spacing: 10) {
            AssetThumbnail(
                kind: item.kind,
                imageData: store.generatedImages(for: item.id)
                    .first(where: \.isPrimary)?
                    .imageData
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(item.summary.isEmpty ? "还没有视觉描述" : item.summary)
                    .foregroundStyle(
                        item.summary.isEmpty ? .tertiary : .secondary
                    )
                    .italic(item.summary.isEmpty)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Menu {
                AssetReviewStateMenu(
                    assetID: item.id,
                    store: store
                )
            } label: {
                Image(systemName: item.reviewState.systemImage)
                .foregroundStyle(
                    item.reviewState == .accepted ? .green : .secondary
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("更改审核状态")
        }
        .padding(.vertical, 5)
        .tag(item.id)
        .contextMenu {
            AssetReviewStateMenu(
                assetID: item.id,
                store: store
            )

            Divider()

            Button("删除资产", role: .destructive) {
                store.deleteAsset(id: item.id)
            }
        }
    }
}

private struct AssetThumbnail: View {
    let kind: AssetKind
    let imageData: Data?

    var body: some View {
        ZStack {
            if let imageData,
               let platformImage = NSImage(data: imageData) {
                Image(nsImage: platformImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: kind.systemImage)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: 36, height: 36)
        .background(.quaternary, in: .rect(cornerRadius: 8))
        .clipShape(.rect(cornerRadius: 8))
    }
}

private struct AssetReviewStateMenu: View {
    let assetID: UUID
    @Bindable var store: WorkspaceStore

    var body: some View {
        ForEach(AssetReviewState.allCases, id: \.self) { state in
            Button {
                store.setReviewState(state, for: assetID)
            } label: {
                Label(state.title, systemImage: state.systemImage)
            }
        }
    }
}
