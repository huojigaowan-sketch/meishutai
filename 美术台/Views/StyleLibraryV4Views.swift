import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct StyleLibraryWorkspaceV4: View {
    @Bindable var store: ArtDepartmentV2Store

    @State private var editorRequest: StyleEditorRequest?
    @State private var pendingDeleteID: UUID?
    @State private var isImportingSample = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            detail
        }
        .navigationTitle("风格图书馆")
        .searchable(text: $store.styleSearchText, prompt: "搜索标题、提示词、标签")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("新建根风格", systemImage: "plus") {
                    editorRequest = .createRoot
                }
                Button("新建分支", systemImage: "arrow.triangle.branch") {
                    guard let card = store.selectedStyleNode else { return }
                    editorRequest = .createBranch(parentID: card.id)
                }
                .disabled(store.selectedStyleNode == nil)
            }
        }
        .sheet(item: $editorRequest) { request in
            StyleNodeEditorSheet(store: store, request: request) {
                editorRequest = nil
            }
        }
        .confirmationDialog(
            "删除这个风格分支及其全部子分支？",
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除整个分支树", role: .destructive) {
                if let id = pendingDeleteID { store.deleteStyleSubtree(id) }
                pendingDeleteID = nil
            }
            Button("取消", role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text("相关加密样板会一并删除；内置模板不能删除。")
        }
        .fileImporter(
            isPresented: $isImportingSample,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            guard let cardID = store.selectedStyleNode?.id,
                  let urls = try? result.get()
            else { return }
            Task { await store.addSampleImages(urls, to: cardID) }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("风格分支树")
                        .font(.title2.weight(.bold))
                    Text("根风格 → 增量分支 → 继续分支")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("归档", isOn: $store.showsArchivedStyles)
                    .toggleStyle(.button)
                    .help("显示已归档风格")
            }
            .padding(16)

            List(selection: $store.selectedStyleNodeID) {
                OutlineGroup(store.styleTree, children: \.children) { node in
                    StyleTreeRow(
                        card: node.card,
                        image: store.primaryStyleImage(for: node.card),
                        selectedForGeneration: store.selectedStyleCardIDs.contains(node.card.id)
                    )
                    .tag(node.card.id)
                    .task(id: node.card.id) {
                        await store.ensureStyleSamples(for: node.card.id)
                    }
                    .contextMenu {
                        Button("用于生图") { store.toggleStyleSelection(node.card.id) }
                        Button("新增子分支") {
                            editorRequest = .createBranch(parentID: node.card.id)
                        }
                        if !node.card.isBuiltIn {
                            Button("编辑") { editorRequest = .edit(cardID: node.card.id) }
                            Button(node.card.isArchived ? "恢复" : "归档") {
                                store.toggleStyleArchive(node.card.id)
                            }
                            Divider()
                            Button("删除分支树", role: .destructive) {
                                pendingDeleteID = node.card.id
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            HStack {
                Text("\(store.visibleStyleNodeCount) 个节点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("AES-GCM")
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let card = store.selectedStyleNode {
            StyleNodeDetailView(
                store: store,
                card: card,
                onEdit: { editorRequest = .edit(cardID: card.id) },
                onBranch: { editorRequest = .createBranch(parentID: card.id) },
                onAddSample: { isImportingSample = true },
                onDelete: { pendingDeleteID = card.id }
            )
            .id(card.id)
        } else {
            ContentUnavailableView(
                "选择一个风格",
                systemImage: "photo.on.rectangle.angled",
                description: Text("左侧是可以无限分支的风格资产树。每个正式节点都有完整样板。")
            )
        }
    }
}

private struct StyleTreeRow: View {
    let card: StylePromptCard
    let image: NSImage?
    let selectedForGeneration: Bool

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(width: 54, height: 38)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(card.title).lineLimit(1)
                HStack(spacing: 5) {
                    Text(card.category.rawValue)
                    if card.parentID != nil { Text("分支") }
                    if card.isExperiment { Text("实验") }
                    if card.isBuiltIn { Text("内置") }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if selectedForGeneration {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct StyleNodeDetailView: View {
    @Bindable var store: ArtDepartmentV2Store
    let card: StylePromptCard
    let onEdit: () -> Void
    let onBranch: () -> Void
    let onAddSample: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                sampleGallery
                lineage
                promptSection
                metadata
            }
            .padding(24)
            .frame(maxWidth: 1_050)
            .frame(maxWidth: .infinity)
        }
        .task(id: card.id) { await store.ensureStyleSamples(for: card.id) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(card.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                HStack(spacing: 8) {
                    Label(card.category.rawValue, systemImage: "tag")
                    Text(card.lifecycle.title)
                    if card.isBuiltIn { Text("固定开源模板") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button(
                store.selectedStyleCardIDs.contains(card.id) ? "已用于生图" : "用于生图",
                systemImage: store.selectedStyleCardIDs.contains(card.id)
                    ? "checkmark.circle.fill"
                    : "circle"
            ) {
                store.toggleStyleSelection(card.id)
            }
            .buttonStyle(.borderedProminent)
            Menu {
                Button("新增子分支", action: onBranch)
                Button("添加样板图", action: onAddSample)
                if !card.isBuiltIn {
                    Button("编辑", action: onEdit)
                    Button(card.isArchived ? "恢复" : "归档") {
                        store.toggleStyleArchive(card.id)
                    }
                    Divider()
                    Button("删除分支树", role: .destructive, action: onDelete)
                }
            } label: {
                Label("管理", systemImage: "ellipsis.circle")
            }
        }
    }

    private var sampleGallery: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("完整样板").font(.headline)
                Spacer()
                Text(store.sampleStatusText(for: card))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let media = store.resolvedSampleMedia(for: card)
            if media.isEmpty {
                ContentUnavailableView(
                    "尚无样板",
                    systemImage: "photo.badge.plus",
                    description: Text(card.isExperiment ? "实验分支会持久化；上传或生成图片后即可发布。" : "正式风格必须补充样板图。")
                )
                .frame(minHeight: 260)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(media) { sample in
                            VStack(alignment: .leading, spacing: 6) {
                                Group {
                                    if let image = store.styleImage(for: sample) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .scaledToFit()
                                    } else {
                                        ProgressView("载入样板…")
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                }
                                .frame(width: 420, height: 280)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                HStack {
                                    Text(sample.sourceLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if !card.isBuiltIn,
                                       card.styleSampleMedia.contains(where: { $0.id == sample.id })
                                    {
                                        Button(role: .destructive) {
                                            store.removeSample(sample.id, from: card.id)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.visible)
            }
        }
    }

    private var lineage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("继承路径").font(.headline)
            HStack(spacing: 6) {
                ForEach(store.styleLineage(for: card.id)) { ancestor in
                    Button(ancestor.title) { store.selectedStyleNodeID = ancestor.id }
                        .buttonStyle(.borderless)
                    if ancestor.id != card.id {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.parentID == nil ? "根提示词" : "本分支增加的变化")
                .font(.headline)
            Text(card.prompt)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(14)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))

            if card.parentID != nil {
                Text("最终有效提示词")
                    .font(.headline)
                Text(store.resolvedPrompt(for: card.id))
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("资产信息").font(.headline)
            LabeledContent("版本", value: "r\(card.revisionValue)")
            LabeledContent("标签", value: card.tags.joined(separator: "、"))
            LabeledContent("更新时间", value: card.updatedAt.formatted())
            if let provenance = card.provenance {
                LabeledContent("来源", value: provenance.repository)
                LabeledContent("固定提交", value: provenance.revision)
                LabeledContent("许可证", value: provenance.license)
            }
            if !card.notes.isEmpty {
                Text(card.notes).foregroundStyle(.secondary)
            }
        }
    }
}

struct StyleEditorRequest: Identifiable {
    enum Mode {
        case createRoot
        case createBranch(parentID: UUID)
        case edit(cardID: UUID)
    }

    let id = UUID()
    let mode: Mode

    static var createRoot: StyleEditorRequest { .init(mode: .createRoot) }
    static func createBranch(parentID: UUID) -> StyleEditorRequest {
        .init(mode: .createBranch(parentID: parentID))
    }
    static func edit(cardID: UUID) -> StyleEditorRequest {
        .init(mode: .edit(cardID: cardID))
    }
}

private struct StyleNodeEditorSheet: View {
    @Bindable var store: ArtDepartmentV2Store
    let request: StyleEditorRequest
    let onClose: () -> Void

    @State private var title = ""
    @State private var prompt = ""
    @State private var category: StylePromptCategory = .general
    @State private var tags = ""
    @State private var notes = ""
    @State private var imageURLs: [URL] = []
    @State private var isPickingImages = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sheetTitle).font(.title2.weight(.bold))
            Text(sheetDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("标题", text: $title)
            Picker("分类", selection: $category) {
                ForEach(StylePromptCategory.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            TextEditor(text: $prompt)
                .font(.body.monospaced())
                .frame(minHeight: 180)
                .overlay(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text(promptPlaceholder)
                            .foregroundStyle(.tertiary)
                            .padding(7)
                            .allowsHitTesting(false)
                    }
                }
            TextField("标签，以逗号分隔", text: $tags)
            TextField("备注", text: $notes)
            HStack {
                Button("选择样板图", systemImage: "photo.stack") {
                    isPickingImages = true
                }
                Text(imageURLs.isEmpty ? "未选择" : "已选择 \(imageURLs.count) 张")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消", action: onClose)
                Button("保存") {
                    Task {
                        await save()
                        if store.errorMessage == nil { onClose() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(22)
        .frame(width: 680, height: 620)
        .fileImporter(
            isPresented: $isPickingImages,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            imageURLs = (try? result.get()) ?? []
        }
        .onAppear { populate() }
    }

    private var sheetTitle: String {
        switch request.mode {
        case .createRoot: "新建根风格"
        case .createBranch: "新增风格分支"
        case .edit: "编辑风格节点"
        }
    }

    private var sheetDescription: String {
        switch request.mode {
        case .createRoot:
            "根风格必须包含完整提示词和至少一张样板图。"
        case .createBranch(let parentID):
            "只写相对“\(store.styleCard(parentID)?.title ?? "父风格")”增加的变化。没有新样板时会保存为持久化实验分支。"
        case .edit:
            "修改当前节点只影响本节点；所有后代会动态继承更新后的提示词。"
        }
    }

    private var promptPlaceholder: String {
        switch request.mode {
        case .createBranch: "例如：保持父风格，改为低照度冷月光，并增加潮湿地面反射"
        default: "输入精确、可复用的完整风格提示词"
        }
    }

    private var canSave: Bool {
        let base = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch request.mode {
        case .createRoot: return base && !imageURLs.isEmpty
        default: return base
        }
    }

    private func populate() {
        guard case .edit(let cardID) = request.mode,
              let card = store.styleCard(cardID),
              !card.isBuiltIn
        else { return }
        title = card.title
        prompt = card.prompt
        category = card.category
        tags = card.tags.joined(separator: ",")
        notes = card.notes
    }

    private func save() async {
        let tagList = tags.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        switch request.mode {
        case .createRoot:
            await store.createStyleNode(
                parentID: nil,
                title: title,
                prompt: prompt,
                category: category,
                tags: tagList,
                notes: notes,
                imageURLs: imageURLs,
                publish: true
            )
        case .createBranch(let parentID):
            await store.createStyleNode(
                parentID: parentID,
                title: title,
                prompt: prompt,
                category: category,
                tags: tagList,
                notes: notes,
                imageURLs: imageURLs,
                publish: !imageURLs.isEmpty
            )
        case .edit(let cardID):
            await store.editStyleNode(
                cardID,
                title: title,
                prompt: prompt,
                category: category,
                tags: tagList,
                notes: notes,
                imageURLs: imageURLs
            )
        }
    }
}
