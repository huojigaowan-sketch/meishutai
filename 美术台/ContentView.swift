import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: WorkspaceStore

    @AppStorage("assetWorkbook.template1.name") private var table1Name = "表格1"
    @AppStorage("assetWorkbook.template2.name") private var table2Name = "表格2"
    @State private var isImportingScript = false
    @State private var isInspectorPresented = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var templateBeingRenamed: AssetWorkbookTemplate?
    @State private var isPreparingWorkbookExport = false
    @State private var workbookExportWarning: String?

    private var inspectorPresentation: Binding<Bool> {
        Binding(
            get: {
                isInspectorPresented && store.selectedSection != .script
            },
            set: { isPresented in
                isInspectorPresented = isPresented
            }
        )
    }

    private var importTypes: [UTType] {
        var types: [UTType] = [.plainText]
        if let markdown = UTType(filenameExtension: "md") {
            types.append(markdown)
        }
        return types
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ProjectSidebarView(
                store: store,
                onSelectSection: selectSection
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } detail: {
            detail
                .inspector(isPresented: inspectorPresentation) {
                inspector
                    .inspectorColumnWidth(min: 400, ideal: 460, max: 640)
            }
        }
        .navigationTitle(store.currentProject?.title ?? "资产台")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Section("导出模板") {
                        ForEach(AssetWorkbookTemplate.allCases) { template in
                            Button {
                                Task {
                                    await prepareWorkbookExport(using: template)
                                }
                            } label: {
                                Label(
                                    "\(workbookTemplateName(for: template)) — \(template.description)",
                                    systemImage: template.systemImage
                                )
                            }
                        }
                    }

                    Divider()

                    Menu {
                        ForEach(AssetWorkbookTemplate.allCases) { template in
                            Button(workbookTemplateName(for: template)) {
                                templateBeingRenamed = template
                            }
                        }
                    } label: {
                        Label("重命名模板", systemImage: "pencil")
                    }
                } label: {
                    Label(
                        isPreparingWorkbookExport ? "正在核验并导出" : "导出 XLSX",
                        systemImage: isPreparingWorkbookExport
                            ? "ellipsis.circle"
                            : "tablecells"
                    )
                }
                .help("选择模板，导出人物服装、场景和道具资产表")
                .disabled(store.currentProject == nil || isPreparingWorkbookExport)

                Menu {
                    ForEach(AssetDataExportFormat.allCases) { format in
                        Button(format.title) {
                            exportAssetData(format)
                        }
                    }
                } label: {
                    Label("导出数据", systemImage: "square.and.arrow.up")
                }
                .disabled(store.currentProject == nil)

                if store.selectedSection != .script {
                    Button {
                        isInspectorPresented.toggle()
                    } label: {
                        Label("资产检查器", systemImage: "sidebar.trailing")
                    }
                    .help(isInspectorPresented ? "隐藏资产检查器" : "显示资产检查器")
                }

                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                }
            }
        }
        .fileImporter(
            isPresented: $isImportingScript,
            allowedContentTypes: importTypes
        ) { result in
            do {
                try store.importScript(from: result.get())
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $templateBeingRenamed) { template in
            WorkbookTemplateRenameView(
                currentName: workbookTemplateName(for: template),
                fallbackName: template.defaultName,
                onCancel: {
                    templateBeingRenamed = nil
                },
                onSave: { name in
                    setWorkbookTemplateName(name, for: template)
                    templateBeingRenamed = nil
                }
            )
        }
        .alert(
            "无法完成",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.errorMessage = nil
                    }
                }
            )
        ) {
            Button("好") {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert(
            "表格已导出，场景已保守保留",
            isPresented: Binding(
                get: { workbookExportWarning != nil },
                set: { isPresented in
                    if !isPresented {
                        workbookExportWarning = nil
                    }
                }
            )
        ) {
            Button("好") {
                workbookExportWarning = nil
            }
        } message: {
            Text(workbookExportWarning ?? "")
        }
    }

    @ViewBuilder
    private var detail: some View {
        if store.selectedSection == .script {
            ScriptEditorView(
                store: store,
                onImport: { isImportingScript = true }
            )
        } else {
            AssetLibraryView(store: store)
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if let selectedAssetID = store.selectedAssetID,
           let index = store.assets.firstIndex(where: { $0.id == selectedAssetID }) {
            AssetInspectorView(
                asset: $store.assets[index],
                onCommit: store.persist
            )
        } else {
            ContentUnavailableView(
                "选择一个资产",
                systemImage: "slider.horizontal.3",
                description: Text("从提取结果中选择场景、人物或道具，再核对名称、摘要与剧本依据。")
            )
        }
    }

    private func workbookDefaultFilename(templateName: String) -> String {
        let title = store.currentProject?.title ?? "美术台项目"
        let safeTitle = safeFilenameComponent(title)
        let safeTemplateName = safeFilenameComponent(templateName)
        return "\(safeTitle)资产表-\(safeTemplateName).xlsx"
    }

    private func exportAssetData(_ format: AssetDataExportFormat) {
        let projectTitle = store.currentProject?.title ?? "美术台项目"
        do {
            let data = try AssetDataExporter.data(
                format: format,
                projectTitle: projectTitle,
                assets: store.assets,
                episodes: store.episodes
            )
            let panel = NSSavePanel()
            panel.title = "导出资产数据 · \(format.title)"
            panel.nameFieldStringValue = "\(safeFilenameComponent(projectTitle))资产.\(format.fileExtension)"
            panel.canCreateDirectories = true
            panel.showsTagField = false
            if let type = UTType(filenameExtension: format.fileExtension) {
                panel.allowedContentTypes = [type]
            }
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            store.storageNotice = "已导出 \(format.title)：\(url.path)"
            revealExportedFile(url)
        } catch {
            store.errorMessage = "无法导出 \(format.title)：\(error.localizedDescription)"
        }
    }

    private func prepareWorkbookExport(
        using template: AssetWorkbookTemplate
    ) async {
        guard !isPreparingWorkbookExport else { return }
        isPreparingWorkbookExport = true
        defer { isPreparingWorkbookExport = false }

        let templateName = workbookTemplateName(for: template)
        let projectTitle = store.currentProject?.title ?? "美术台项目"
        let assets = store.assets
        let episodes = store.episodes
        do {
            let identityResolution: Table2SceneIdentityResolution
            if template == .table2 {
                let candidateGroups = AssetWorkbookExporter.table2SceneCandidateGroups(
                    assets,
                    episodes: episodes
                )
                identityResolution = await store.resolveTable2SceneIdentity(
                    candidateGroups: candidateGroups
                )
            } else {
                identityResolution = Table2SceneIdentityResolution(
                    mergeGroups: [],
                    warning: nil
                )
            }

            let workbookData = try AssetWorkbookExporter.makeWorkbook(
                projectTitle: projectTitle,
                assets: assets,
                episodes: episodes,
                template: template,
                table2MergeGroups: identityResolution.mergeGroups
            )

            guard let destinationURL = promptWorkbookExportDestination(
                defaultName: workbookDefaultFilename(templateName: templateName),
                templateName: templateName
            ) else {
                return
            }

            try workbookData.write(to: destinationURL)
            let warningSuffix = identityResolution.warning.map {
                "\n\($0)"
            } ?? ""
            store.storageNotice = "已用“\(templateName)”导出到：\(destinationURL.path)\(warningSuffix)"
            workbookExportWarning = identityResolution.warning
            revealExportedFile(destinationURL)
        } catch {
            store.errorMessage = "无法用“\(templateName)”生成 XLSX：\(error.localizedDescription)"
        }
    }

    private func promptWorkbookExportDestination(
        defaultName: String,
        templateName: String
    ) -> URL? {
        let panel = NSSavePanel()
        panel.title = "导出资产表 · \(templateName)"
        panel.message = "选择“\(templateName)”导出到的文件位置"
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.isExtensionHidden = false

        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        if let xlsxType = UTType(filenameExtension: "xlsx") {
            panel.allowedContentTypes = [xlsxType]
        }

        return panel.runModal() == .OK ? panel.url : nil
    }

    private func workbookTemplateName(
        for template: AssetWorkbookTemplate
    ) -> String {
        let storedName = switch template {
        case .table1: table1Name
        case .table2: table2Name
        }
        let trimmedName = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? template.defaultName : trimmedName
    }

    private func setWorkbookTemplateName(
        _ name: String,
        for template: AssetWorkbookTemplate
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        switch template {
        case .table1:
            table1Name = trimmedName
        case .table2:
            table2Name = trimmedName
        }
    }

    private func safeFilenameComponent(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\n\r")
        let components = value.components(separatedBy: invalidCharacters)
        let sanitized = components.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "未命名" : sanitized
    }

    private func revealExportedFile(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func selectSection(_ section: WorkspaceSection) {
        store.selectedSection = section
        if section == .script {
            store.selectedAssetID = nil
        } else if store.selectedAssetID == nil {
            store.selectedAssetID = store.filteredAssets.first?.id
        }
    }
}

private struct WorkbookTemplateRenameView: View {
    let fallbackName: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var name: String
    @FocusState private var isNameFocused: Bool

    init(
        currentName: String,
        fallbackName: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.fallbackName = fallbackName
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: currentName)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重命名导出模板")
                .font(.title3.weight(.semibold))

            Text("模板名称会显示在导出菜单和默认文件名中，不会改变表格的列结构。")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField(fallbackName, text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)
                .onSubmit(save)

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("保存", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 400)
        .onAppear {
            isNameFocused = true
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        onSave(trimmedName)
    }
}

#Preview {
    ContentView(store: WorkspaceStore())
        .frame(width: 1240, height: 780)
}
