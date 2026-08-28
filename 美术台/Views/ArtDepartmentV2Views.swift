import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ArtDepartmentV2RootView: View {
    @Bindable var store: ArtDepartmentV2Store

    @State private var isImportingScript = false
    @State private var isAddingStyle = false
    @State private var isImportingGenerationReference = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var scriptImportTypes: [UTType] {
        var values: [UTType] = [.plainText, .xml, .pdf, .image]
        if let fdx = UTType(filenameExtension: "fdx") { values.append(fdx) }
        if let markdown = UTType(filenameExtension: "md") { values.append(markdown) }
        return values
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 245, max: 290)
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
            allowedContentTypes: scriptImportTypes,
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
        .sheet(isPresented: $store.showsDiagnostics) {
            AutomationDiagnosticsView(store: store)
        }
        .alert(
            "无法完成",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
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
                Section("自动工作流") {
                    ForEach(ArtWorkspaceSection.allCases) { section in
                        Button {
                            store.selectedSection = section
                        } label: {
                            Label(section.rawValue, systemImage: section.systemImage)
                                .foregroundStyle(
                                    store.selectedSection == section ? .primary : .secondary
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("项目") {
                    ForEach(store.projects) { project in
                        Button {
                            store.selectProject(project.id)
                        } label: {
                            HStack(spacing: 9) {
                                Image(
                                    systemName: project.id == store.currentProject?.id
                                        ? "checkmark.circle.fill"
                                        : "circle"
                                )
                                .foregroundStyle(
                                    project.id == store.currentProject?.id ? .blue : .secondary
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.title).lineLimit(1)
                                    Text(project.pipelineStage.title)
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
                Button(role: .destructive) {
                    store.deleteCurrentProject()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(store.projects.count <= 1)
            }
            .buttonStyle(.borderless)
            .padding(14)
        }
    }

    @ViewBuilder
    private var detail: some View {
        ZStack {
            switch store.selectedSection {
            case .script:
                ScriptNormalizationWorkspace(
                    store: store,
                    onImport: { isImportingScript = true }
                )
            case .assets:
                AutomaticAssetLibraryWorkspace(store: store)
            case .styles:
                StyleVaultWorkspace(
                    store: store,
                    onAdd: { isAddingStyle = true }
                )
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
                    Button {
                        store.noticeMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding()
            }
        }
    }
}

// MARK: - Script pipeline

private struct ScriptNormalizationWorkspace: View {
    @Bindable var store: ArtDepartmentV2Store
    let onImport: () -> Void

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
                ContentUnavailableView(
                    "没有项目",
                    systemImage: "doc.badge.plus",
                    description: Text("新建项目后导入任意格式的剧本。")
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("剧本标准化与自动提取")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Apple GenerationSchema 先建立标准 Final Draft，再由多引擎自动完成场景、人物与道具资产库。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let status = store.activeEngineStatus {
                EngineStatusBadge(status: status)
            }
            Button("导入剧本", systemImage: "doc.badge.plus", action: onImport)
                .buttonStyle(.bordered)
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
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            Text("\(project.sourceText.count.formatted()) 字符 · TXT / Markdown / Fountain / FDX / PDF / 图片")
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
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            if let audit = project.normalizationAudit {
                Label(
                    audit.isComplete
                        ? "SourceUnit 全覆盖 \(audit.coveredSourceUnitCount)/\(audit.sourceUnitCount) · \(audit.model)"
                        : "标准化覆盖不完整",
                    systemImage: audit.isComplete
                        ? "checkmark.shield.fill"
                        : "exclamationmark.shield.fill"
                )
                .font(.caption)
                .foregroundStyle(audit.isComplete ? .green : .orange)
            } else {
                Text("模型输出必须通过 Apple GenerationSchema 与完整覆盖校验，才会显示在这里。")
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
            StageBadge(number: 3, title: "自动资产库", active: !project.usableAssets.isEmpty)
            Spacer()

            Menu {
                Button("导出 Fountain") {
                    export(data: store.fountainExportData(), name: "\(project.title).fountain")
                }
                Button("导出 Final Draft FDX") {
                    export(data: store.fdxExportData(), name: "\(project.title).fdx")
                }
                Button("导出生产资产 JSON") {
                    export(data: store.assetJSONExportData(), name: "\(project.title)-assets.json")
                }
            } label: {
                Label("导出", systemImage: "square.and.arrow.up")
            }
            .disabled(project.canonicalScenes.isEmpty)

            Menu {
                Button("只标准化 Final Draft") {
                    Task { await store.normalizeCurrentScript() }
                }
                Button("从现有 Final Draft 重新提取") {
                    Task {
                        await store.extractCurrentAssets()
                        store.selectedSection = .assets
                    }
                }
                .disabled(project.canonicalScenes.isEmpty)
            } label: {
                Label("分步运行", systemImage: "ellipsis.circle")
            }
            .disabled(store.isWorking)

            Button("一键完成标准化与提取", systemImage: "bolt.fill") {
                Task { await store.runFullPipeline() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                store.isWorking
                    || project.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
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
        do {
            try data.write(to: url, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}

private struct EngineStatusBadge: View {
    let status: AppleEngineStatusSnapshot

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Label(
                status.activeRoute,
                systemImage: status.onDeviceAvailable
                    ? "apple.intelligence"
                    : "network"
            )
            .font(.caption.weight(.semibold))
            Text(status.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: 260, alignment: .trailing)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
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

// MARK: - Automatic asset library

private struct AutomaticAssetLibraryWorkspace: View {
    @Bindable var store: ArtDepartmentV2Store

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                List(store.filteredAssets, selection: $store.selectedAssetID) { asset in
                    AutomaticAssetRow(asset: asset).tag(asset.id)
                }
                .frame(minWidth: 280, idealWidth: 340)

                if let asset = store.selectedAsset {
                    AutomaticAssetDetail(asset: asset)
                        .id(asset.id)
                } else {
                    ContentUnavailableView(
                        "没有自动通过的资产",
                        systemImage: "shippingbox",
                        description: Text("运行剧本标准化与自动提取。低证据候选会自动隔离。")
                    )
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("自动资产库")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                if let summary = store.currentProject?.automationSummary {
                    Text("自动通过 \(summary.usableCount) 项 · 隔离 \(summary.quarantinedCount) 项 · 无需人工审阅")
                        .foregroundStyle(.secondary)
                } else {
                    Text("只有通过逐字证据、Apple Schema、多引擎共识与语言学校验的结果进入生产库。")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !store.diagnosticAssets.isEmpty {
                Button("查看自动诊断 \(store.diagnosticAssets.count)", systemImage: "waveform.path.ecg") {
                    store.showsDiagnostics = true
                }
                .buttonStyle(.bordered)
            }
            Picker("资产类型", selection: $store.selectedAssetKind) {
                ForEach(ProductionAssetKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            .onChange(of: store.selectedAssetKind) { _, _ in
                store.selectedAssetID = store.filteredAssets.first?.id
            }
        }
        .padding(22)
    }
}

private struct AutomaticAssetRow: View {
    let asset: ProductionAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(asset.canonicalName, systemImage: asset.kind.systemImage)
                    .font(.headline)
                Spacer()
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            }
            Text(asset.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Text(asset.reviewDecision.title)
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

private struct AutomaticAssetDetail: View {
    let asset: ProductionAsset

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.kind.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(asset.canonicalName)
                            .font(.system(.title, design: .rounded, weight: .bold))
                        if !asset.aliases.isEmpty {
                            Text("别名：\(asset.aliases.joined(separator: "、"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VerificationBadge(asset: asset)
                }

                readOnlyField("摘要", value: asset.summary)
                readOnlyField("视觉描述", value: asset.visualDescription)
                readOnlyField("连续性状态", value: asset.continuityState)

                HStack(alignment: .top, spacing: 12) {
                    readOnlyField("材质", value: asset.materialNotes)
                    readOnlyField("构图", value: asset.compositionNotes)
                    readOnlyField("元素", value: asset.elementNotes)
                }

                if let report = asset.verificationReport {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("自动核验链", systemImage: "cpu")
                            .font(.headline)
                        Text(report.engines.joined(separator: " · "))
                            .font(.callout)
                        Text(report.reason)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }

                Text("逐字证据").font(.headline)
                ForEach(asset.sourceEvidence) { evidence in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(evidence.sceneHeading)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("“\(evidence.quote)”")
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        Text(evidence.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
    }

    private func readOnlyField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(10)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct VerificationBadge: View {
    let asset: ProductionAsset

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(asset.validatedConfidence, format: .percent.precision(.fractionLength(0)))
                .font(.title2.monospacedDigit().weight(.bold))
            Text("自动核验得分")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct AutomationDiagnosticsView: View {
    @Bindable var store: ArtDepartmentV2Store

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("自动隔离诊断")
                        .font(.title2.weight(.bold))
                    Text("这些候选不会进入生产资产库，也不需要人工处理。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { store.showsDiagnostics = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(18)
            Divider()
            List(store.diagnosticAssets) { asset in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Label(asset.canonicalName, systemImage: asset.kind.systemImage)
                        Spacer()
                        Text(asset.reviewDecision.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Text(asset.verificationReport?.reason ?? asset.warnings.joined(separator: "；"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let evidence = asset.sourceEvidence.first {
                        Text("“\(evidence.quote)”")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .frame(minWidth: 720, idealWidth: 860, minHeight: 520, idealHeight: 650)
    }
}

// MARK: - Style prompt vault

private struct StyleVaultWorkspace: View {
    @Bindable var store: ArtDepartmentV2Store
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("风格提示词库")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("参考图与用户精确提示词成对保存；Apple Vision 自动查重，提示词默认锁定。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("添加风格卡", systemImage: "plus", action: onAdd)
                    .buttonStyle(.borderedProminent)
            }
            .padding(22)
            Divider()

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300, maximum: 390), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(store.styleCards) { card in
                        StyleCardView(
                            card: card,
                            imageURL: store.imageURL(for: card.referenceImagePath),
                            selected: store.selectedStyleCardIDs.contains(card.id)
                        ) {
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
    let selected: Bool
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
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
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
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                if card.isBuiltIn {
                    Text("模板")
                        .font(.caption2.weight(.bold))
                        .padding(5)
                        .background(.blue.opacity(0.1), in: Capsule())
                }
            }

            Text(card.prompt)
                .font(.callout)
                .lineLimit(6)
                .textSelection(.enabled)
            HStack {
                Button(
                    selected ? "已用于生图" : "用于生图",
                    systemImage: selected ? "checkmark.circle.fill" : "circle",
                    action: onSelect
                )
                Spacer()
                if !card.isBuiltIn {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(selected ? Color.green.opacity(0.65) : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 1)
        }
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
            Text("提示词由用户提供并锁定；参考图会由 Apple Vision 建立本地相似度签名。")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("标题", text: $title)
            Picker("分类", selection: $category) {
                ForEach(StylePromptCategory.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            TextEditor(text: $prompt)
                .frame(minHeight: 170)
                .overlay(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("粘贴精确风格提示词")
                            .foregroundStyle(.tertiary)
                            .padding(7)
                            .allowsHitTesting(false)
                    }
                }
            TextField("标签，以逗号分隔", text: $tags)
            TextField("备注", text: $notes)
            HStack {
                Button("选择参考图", systemImage: "photo.badge.plus") {
                    isPickingImage = true
                }
                if let imageURL { Text(imageURL.lastPathComponent).foregroundStyle(.secondary) }
                Spacer()
                Button("取消", action: onClose)
                Button("保存") {
                    Task {
                        await store.addStyleCard(
                            title: title,
                            prompt: prompt,
                            category: category,
                            tags: tags.split(separator: ",").map {
                                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                            },
                            notes: notes,
                            imageURL: imageURL
                        )
                        onClose()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(22)
        .frame(width: 620, height: 580)
        .fileImporter(
            isPresented: $isPickingImage,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            imageURL = try? result.get().first
        }
    }
}

// MARK: - Generation studio

private struct GenerationStudioWorkspace: View {
    @Bindable var store: ArtDepartmentV2Store
    let onImportReference: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                selectionPane
                    .frame(minWidth: 300, idealWidth: 360)
                promptPane
                    .frame(minWidth: 420, idealWidth: 560)
                resultsPane
                    .frame(minWidth: 320, idealWidth: 420)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("生图工坊")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("自动核验资产 + 用户锁定风格卡 → Apple Schema 提示词 → Ark 文生图 / 图生图")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("加入本轮参考图", systemImage: "photo.badge.plus", action: onImportReference)
                .buttonStyle(.bordered)
            Button("直接生图", systemImage: "wand.and.stars") {
                Task { await store.generateImages() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isWorking || store.selectedAsset == nil)
        }
        .padding(22)
    }

    private var selectionPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("生产资产").font(.headline)
            Picker("类型", selection: $store.selectedAssetKind) {
                ForEach(ProductionAssetKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: store.selectedAssetKind) { _, _ in
                store.selectedAssetID = store.filteredAssets.first?.id
            }
            List(store.filteredAssets, selection: $store.selectedAssetID) { asset in
                Text(asset.canonicalName).tag(asset.id)
            }

            Text("生成模式").font(.headline)
            Picker("模式", selection: $store.generationMode) {
                ForEach(ImageGenerationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            Text("补充要求").font(.headline)
            TextEditor(text: $store.generationDirection)
                .frame(minHeight: 90)
                .padding(7)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))

            Text("风格卡").font(.headline)
            if store.selectedStyleCards.isEmpty {
                Text("未手动选择时，系统会按资产类型和生成模式自动匹配最多三张风格卡。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(store.selectedStyleCards.map(\.title).joined(separator: "、"))
                    .font(.callout)
            }
        }
        .padding(18)
    }

    private var promptPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Apple GenerationSchema 提示词计划").font(.headline)
                    Spacer()
                    Button("重新规划", systemImage: "arrow.clockwise") {
                        Task { await store.planGenerationPrompt() }
                    }
                    .disabled(store.isWorking || store.selectedAsset == nil)
                }
                PromptField(title: "标题", text: $store.promptPlan.title, minHeight: 38)
                PromptField(title: "主体", text: $store.promptPlan.subject)
                HStack(alignment: .top, spacing: 10) {
                    PromptField(title: "材质", text: $store.promptPlan.materials)
                    PromptField(title: "构图", text: $store.promptPlan.composition)
                    PromptField(title: "元素", text: $store.promptPlan.elements)
                }
                PromptField(title: "光影", text: $store.promptPlan.lighting)
                PromptField(title: "正向提示词", text: $store.promptPlan.positivePrompt, minHeight: 150)
                PromptField(title: "必须避免", text: $store.promptPlan.negativePrompt, minHeight: 100)
                if !store.promptPlan.lockedFacts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("锁定事实").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(store.promptPlan.lockedFacts.map { "• \($0)" }.joined(separator: "\n"))
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    .padding(12)
                    .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(18)
        }
    }

    private var resultsPane: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("生成历史").font(.headline)
                if let project = store.currentProject, !project.generatedImages.isEmpty {
                    ForEach(project.generatedImages) { record in
                        GeneratedImageCard(
                            record: record,
                            imageURL: store.imageURL(for: record.localImagePath)
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "还没有生成图",
                        systemImage: "photo.stack",
                        description: Text("选择资产后可直接生图；系统会自动规划提示词。")
                    )
                }
            }
            .padding(18)
        }
    }
}

private struct PromptField: View {
    let title: String
    @Binding var text: String
    var minHeight: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .padding(7)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct GeneratedImageCard: View {
    let record: GeneratedImageRecord
    let imageURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL, let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text(record.promptPlan.title)
                .font(.headline)
            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08)) }
    }
}
