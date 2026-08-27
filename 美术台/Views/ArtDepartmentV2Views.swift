import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ArtDepartmentV2RootView: View {
    @Bindable var store: ArtDepartmentV2Store

    @State private var isImportingScript = false
    @State private var isAddingStyle = false
    @State private var isImportingGenerationReference = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            detail
        }
        .navigationTitle(store.currentProject?.title ?? "美术台")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.isWorking {
                    ProgressView(value: store.progress.fraction)
                        .frame(width: 150)
                        .help(store.progress.detail)
                }
                Button {
                    store.addProject()
                } label: {
                    Label("新建项目", systemImage: "plus")
                }
                SettingsLink { Label("设置", systemImage: "gearshape") }
            }
        }
        .fileImporter(
            isPresented: $isImportingScript,
            allowedContentTypes: [.plainText, .xml, UTType(filenameExtension: "fdx") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            guard let url = try? result.get().first else { return }
            Task { await store.importScript(from: url) }
        }
        .fileImporter(
            isPresented: $isImportingGenerationReference,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            guard let url = try? result.get().first else { return }
            Task { await store.importGenerationReference(url) }
        }
        .sheet(isPresented: $isAddingStyle) {
            StyleCardEditorView(store: store) { isAddingStyle = false }
        }
        .alert("无法完成", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .task { await store.load() }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("美术台")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("SCRIPT → ASSETS → IMAGES")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.7)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            List {
                Section("工作流") {
                    ForEach(ArtWorkspaceSection.allCases) { section in
                        Button {
                            store.selectedSection = section
                        } label: {
                            Label(section.rawValue, systemImage: section.systemImage)
                                .foregroundStyle(store.selectedSection == section ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("项目") {
                    ForEach(store.projects) { project in
                        Button {
                            store.selectProject(project.id)
                        } label: {
                            HStack {
                                Image(systemName: project.id == store.currentProject?.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(project.id == store.currentProject?.id ? .blue : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.title).lineLimit(1)
                                    Text(project.pipelineStage.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.sidebar)

            HStack {
                Button("新建", systemImage: "plus") { store.addProject() }
                Spacer()
                Button(role: .destructive) { store.deleteCurrentProject() } label: { Image(systemName: "trash") }
                    .disabled(store.projects.count <= 1)
            }
            .buttonStyle(.borderless)
            .padding(14)
        }
    }

    @ViewBuilder
    private var detail: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor).ignoresSafeArea()
            switch store.selectedSection {
            case .script:
                ScriptNormalizationWorkspace(store: store, onImport: { isImportingScript = true })
            case .assets:
                AssetReviewWorkspace(store: store)
            case .styles:
                StyleVaultWorkspace(store: store, onAdd: { isAddingStyle = true })
            case .generation:
                GenerationStudioWorkspace(
                    store: store,
                    onImportReference: { isImportingGenerationReference = true }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let notice = store.noticeMessage {
                HStack {
                    Label(notice, systemImage: "checkmark.circle.fill")
                        .font(.callout)
                    Spacer()
                    Button { store.noticeMessage = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding()
            }
        }
    }
}

private struct ScriptNormalizationWorkspace: View {
    @Bindable var store: ArtDepartmentV2Store
    let onImport: () -> Void
    @State private var selectedEditor = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let project = store.currentProject {
                HSplitView {
                    sourcePane(project)
                    canonicalPane(project)
                }
                pipelineFooter(project)
            } else {
                ContentUnavailableView("没有项目", systemImage: "doc.badge.plus", description: Text("新建项目后导入任意格式的剧本文本。"))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("剧本标准化")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("先把任意剧本文本完整转换为标准 Final Draft/Fountain，再逐场提取场景、人物和道具。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("导入剧本", systemImage: "doc.badge.plus", action: onImport)
                .buttonStyle(.borderedProminent)
        }
        .padding(22)
    }

    private func sourcePane(_ project: ArtDepartmentProject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            paneTitle("原始剧本 · 权威来源", detail: project.sourceFileName ?? "粘贴或导入")
            TextEditor(text: Binding(
                get: { store.currentProject?.sourceText ?? "" },
                set: { store.updateSourceText($0) }
            ))
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            Text("\(project.sourceText.count.formatted()) 字符 · 原文不会被模型覆盖")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(minWidth: 380)
    }

    private func canonicalPane(_ project: ArtDepartmentProject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            paneTitle("标准 Final Draft / Fountain", detail: "\(project.canonicalScenes.count) 场")
            TextEditor(text: Binding(
                get: { store.currentProject?.canonicalFountain ?? "" },
                set: { store.updateCanonicalFountain($0) }
            ))
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            if let audit = project.normalizationAudit {
                Label(
                    audit.isComplete
                        ? "证据覆盖 \(audit.coveredSourceUnitCount)/\(audit.sourceUnitCount) · 无静默丢失"
                        : "标准化覆盖不完整",
                    systemImage: audit.isComplete ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                )
                .font(.caption)
                .foregroundStyle(audit.isComplete ? .green : .orange)
            } else {
                Text("完成标准化后，这里会显示可审阅、可导出的正式剧本。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(minWidth: 420)
    }

    private func pipelineFooter(_ project: ArtDepartmentProject) -> some View {
        HStack(spacing: 12) {
            StageBadge(number: 1, title: "原文", active: !project.sourceText.isEmpty)
            Image(systemName: "arrow.right")
            StageBadge(number: 2, title: "Final Draft", active: !project.canonicalScenes.isEmpty)
            Image(systemName: "arrow.right")
            StageBadge(number: 3, title: "资产证据", active: !project.assets.isEmpty)
            Spacer()

            Menu {
                Button("导出 Fountain") { export(data: store.fountainExportData(), name: "\(project.title).fountain") }
                Button("导出 Final Draft FDX") { export(data: store.fdxExportData(), name: "\(project.title).fdx") }
                Button("导出已确认资产 JSON") { export(data: store.assetJSONExportData(), name: "\(project.title)-assets.json") }
            } label: {
                Label("导出", systemImage: "square.and.arrow.up")
            }
            .disabled(project.canonicalScenes.isEmpty)

            Button("标准化为 Final Draft", systemImage: "text.badge.checkmark") {
                Task { await store.normalizeCurrentScript() }
            }
            .buttonStyle(.bordered)
            .disabled(store.isWorking || project.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("提取并建立证据账本", systemImage: "checklist.checked") {
                Task { await store.extractCurrentAssets(); store.selectedSection = .assets }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isWorking || project.canonicalScenes.isEmpty)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private func paneTitle(_ title: String, detail: String) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func export(data: Data?, name: String) {
        guard let data else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try data.write(to: url, options: .atomic); NSWorkspace.shared.activateFileViewerSelecting([url]) }
        catch { store.errorMessage = error.localizedDescription }
    }
}

private struct StageBadge: View {
    let number: Int
    let title: String
    let active: Bool
    var body: some View {
        Label("\(number). \(title)", systemImage: active ? "checkmark.circle.fill" : "circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(active ? .green : .secondary)
    }
}

private struct AssetReviewWorkspace: View {
    @Bindable var store: ArtDepartmentV2Store

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("资产审阅")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("所有结果都绑定标准场景和逐字证据；低置信度不会自动通过。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("资产类型", selection: $store.selectedAssetKind) {
                    ForEach(ProductionAssetKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                .onChange(of: store.selectedAssetKind) { _, _ in store.selectedAssetID = store.filteredAssets.first?.id }
            }
            .padding(22)
            Divider()

            HSplitView {
                List(store.filteredAssets, selection: $store.selectedAssetID) { asset in
                    AssetListRow(asset: asset).tag(asset.id)
                }
                .frame(minWidth: 280, idealWidth: 340)

                if let asset = store.selectedAsset {
                    AssetReviewDetail(asset: asset) { store.updateAsset($0) } onDecision: {
                        store.setAssetDecision($0, assetID: asset.id)
                    }
                    .id(asset.id)
                } else {
                    ContentUnavailableView("没有可审阅资产", systemImage: "shippingbox", description: Text("先完成 Final Draft 标准化和逐场提取。"))
                }
            }
        }
    }
}

private struct AssetListRow: View {
    let asset: ProductionAsset
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(asset.canonicalName, systemImage: asset.kind.systemImage)
                    .font(.headline)
                Spacer()
                Text(asset.validatedConfidence, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(asset.validatedConfidence >= 0.86 ? .green : .orange)
            }
            Text(asset.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            HStack {
                Text(asset.reviewDecision.rawValue)
                Text("·")
                Text("\(asset.sourceEvidence.count) 条证据")
                Text("·")
                Text("出现 \(asset.occurrenceCount) 次")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}

private struct AssetReviewDetail: View {
    @State var asset: ProductionAsset
    let onUpdate: (ProductionAsset) -> Void
    let onDecision: (AssetReviewDecision) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.kind.rawValue).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        TextField("资产名称", text: $asset.canonicalName)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .textFieldStyle(.plain)
                    }
                    Spacer()
                    confidenceBadge
                }

                editor("摘要", text: $asset.summary)
                editor("视觉描述", text: $asset.visualDescription)
                editor("连续性状态", text: $asset.continuityState)

                HStack(alignment: .top, spacing: 12) {
                    editor("材质", text: $asset.materialNotes)
                    editor("构图", text: $asset.compositionNotes)
                    editor("元素", text: $asset.elementNotes)
                }

                if !asset.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("需要复核", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.headline)
                        Text(asset.warnings.map { "• \($0)" }.joined(separator: "\n"))
                    }
                    .padding(14)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }

                Text("逐字证据").font(.headline)
                ForEach(asset.sourceEvidence) { evidence in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(evidence.sceneHeading).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text("“\(evidence.quote)”").font(.body.monospaced()).textSelection(.enabled)
                        Text(evidence.explanation).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                }

                HStack {
                    Button("排除", role: .destructive) { onDecision(.rejected) }
                    Spacer()
                    Button("保存修改") { onUpdate(asset) }
                        .buttonStyle(.bordered)
                    Button("确认资产") { onUpdate(asset); onDecision(.accepted) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
    }

    private var confidenceBadge: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(asset.validatedConfidence, format: .percent.precision(.fractionLength(0)))
                .font(.title2.monospacedDigit().weight(.bold))
            Text("证据校验置信度").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background((asset.validatedConfidence >= 0.86 ? Color.green : Color.orange).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func editor(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextEditor(text: text)
                .frame(minHeight: 70)
                .padding(8)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct StyleVaultWorkspace: View {
    @Bindable var store: ArtDepartmentV2Store
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("风格提示词库")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("参考图与用户提供的精确提示词成对保存；提示词默认锁定，不由模型擅自改写。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("添加风格卡", systemImage: "plus", action: onAdd)
                    .buttonStyle(.borderedProminent)
            }
            .padding(22)
            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 390), spacing: 14)], spacing: 14) {
                    ForEach(store.styleCards) { card in
                        StyleCardView(card: card, imageURL: store.imageURL(for: card.referenceImagePath)) {
                            store.toggleStyleSelection(card.id)
                        } onDelete: {
                            store.deleteStyleCard(card.id)
                        }
                    }
                }
                .padding(22)
            }
        }
    }
}

private struct StyleCardView: View {
    let card: StylePromptCard
    let imageURL: URL?
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04))
                if let imageURL, let image = NSImage(contentsOf: imageURL) {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: card.category == .camera ? "camera.viewfinder" : "photo")
                        .font(.system(size: 34)).foregroundStyle(.secondary)
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title).font(.headline)
                    Text(card.category.rawValue).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if card.isBuiltIn { Text("模板").font(.caption2.weight(.bold)).padding(5).background(.blue.opacity(0.1), in: Capsule()) }
            }

            Text(card.prompt).font(.callout).lineLimit(6).textSelection(.enabled)
            HStack {
                Button("用于生图", systemImage: "checkmark.circle", action: onSelect)
                Spacer()
                if !card.isBuiltIn { Button(role: .destructive, action: onDelete) { Image(systemName: "trash") } }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.08)) }
    }
}

private struct StyleCardEditorView: View {
    @Bindable var store: ArtDepartmentV2Store
    let onClose: () -> Void
    @State private var title = ""
    @State private var prompt = ""
    @State private var category: StylePromptCategory = .general
    @State private var tags = ""
    @State private var notes = ""
    @State private var imageURL: URL?
    @State private var isPickingImage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加风格提示词卡").font(.title2.weight(.bold))
            TextField("标题", text: $title)
            Picker("分类", selection: $category) { ForEach(StylePromptCategory.allCases) { Text($0.rawValue).tag($0) } }
            Text("精确风格提示词").font(.headline)
            TextEditor(text: $prompt).frame(minHeight: 180).padding(8).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            TextField("标签，用逗号分隔", text: $tags)
            TextField("备注", text: $notes, axis: .vertical)
            HStack {
                Button(imageURL == nil ? "选择参考图" : imageURL!.lastPathComponent, systemImage: "photo") { isPickingImage = true }
                Spacer()
                Button("取消", action: onClose)
                Button("保存") {
                    Task {
                        await store.addStyleCard(
                            title: title,
                            prompt: prompt,
                            category: category,
                            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                            notes: notes,
                            imageURL: imageURL
                        )
                        onClose()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 620, height: 600)
        .fileImporter(isPresented: $isPickingImage, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            imageURL = try? result.get().first
        }
    }
}

private struct GenerationStudioWorkspace: View {
    @Bindable var store: ArtDepartmentV2Store
    let onImportReference: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("生图工坊")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("大模型只负责把已确认资产和用户锁定风格编译成可审阅提示词；Ark 负责文生图或参考图生图。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(22)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    selectionSection
                    promptSection
                    generationSection
                    gallerySection
                }
                .padding(22)
                .frame(maxWidth: 1_100)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var selectionSection: some View {
        GroupBox("1. 选择资产与风格") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("资产类型", selection: $store.selectedAssetKind) {
                    ForEach(ProductionAssetKind.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("资产", selection: $store.selectedAssetID) {
                    ForEach(store.filteredAssets) { asset in Text(asset.canonicalName).tag(Optional(asset.id)) }
                }
                Picker("生成模式", selection: $store.generationMode) {
                    ForEach(ImageGenerationMode.allCases) { Text($0.rawValue).tag($0) }
                }

                Text("风格卡（可多选）").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(store.styleCards) { card in
                            let selected = store.selectedStyleCardIDs.contains(card.id)
                            Button {
                                store.toggleStyleSelection(card.id)
                            } label: {
                                Label(card.title, systemImage: selected ? "checkmark.circle.fill" : "circle")
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(selected ? Color.blue.opacity(0.12) : Color.primary.opacity(0.04), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                TextField("补充机位、数量、姿态、时代或制作限制", text: $store.generationDirection, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("上传额外参考图", systemImage: "photo.badge.plus", action: onImportReference)
            }
            .padding(8)
        }
    }

    private var promptSection: some View {
        GroupBox("2. 审阅生图提示词") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("由大模型编译提示词", systemImage: "wand.and.stars") { Task { await store.planGenerationPrompt() } }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Text("材质 / 构图 / 元素 / 锁定事实均可见").font(.caption).foregroundStyle(.secondary)
                }
                PromptField(title: "主体", text: $store.promptPlan.subject)
                HStack(alignment: .top) {
                    PromptField(title: "材质", text: $store.promptPlan.materials)
                    PromptField(title: "构图", text: $store.promptPlan.composition)
                    PromptField(title: "元素", text: $store.promptPlan.elements)
                }
                PromptField(title: "正向提示词", text: $store.promptPlan.positivePrompt, minHeight: 150)
                PromptField(title: "负向提示词", text: $store.promptPlan.negativePrompt, minHeight: 80)
                if !store.promptPlan.lockedFacts.isEmpty {
                    Text("锁定事实：\n" + store.promptPlan.lockedFacts.map { "• \($0)" }.joined(separator: "\n"))
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            .padding(8)
        }
    }

    private var generationSection: some View {
        GroupBox("3. 调用火山方舟 Ark") {
            HStack {
                TextField("模型 ID", text: $store.generationRecipe.model).textFieldStyle(.roundedBorder)
                Picker("尺寸", selection: $store.generationRecipe.size) {
                    Text("1K").tag("1K"); Text("2K").tag("2K"); Text("4K").tag("4K")
                }
                Stepper("最多 \(store.generationRecipe.maxImages) 张", value: $store.generationRecipe.maxImages, in: 1...10)
                Toggle("水印", isOn: $store.generationRecipe.watermark)
                Spacer()
                Button("生成图片", systemImage: "sparkles") { Task { await store.generateImages() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isWorking || store.promptPlan.positivePrompt.isEmpty)
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var gallerySection: some View {
        if let images = store.currentProject?.generatedImages, !images.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("生成结果").font(.title2.weight(.bold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 14)], spacing: 14) {
                    ForEach(images) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            if let url = store.imageURL(for: record.localImagePath), let image = NSImage(contentsOf: url) {
                                Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 320)
                            }
                            Text(record.promptPlan.title).font(.headline)
                            Text(record.createdAt.formatted()).font(.caption).foregroundStyle(.secondary)
                            if let url = store.imageURL(for: record.localImagePath) {
                                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                    .buttonStyle(.borderless)
                            }
                        }
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }
}

private struct PromptField: View {
    let title: String
    @Binding var text: String
    var minHeight: CGFloat = 70
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextEditor(text: $text).frame(minHeight: minHeight).padding(7).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
