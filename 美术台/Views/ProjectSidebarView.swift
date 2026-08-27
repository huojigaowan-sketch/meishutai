import SwiftUI

struct ProjectSidebarView: View {
    @Bindable var store: WorkspaceStore
    let onSelectSection: (WorkspaceSection) -> Void

    @State private var projectBeingRenamed: AssetProject?
    @State private var renameDraft = ""
    @State private var projectPendingDeletion: AssetProject?

    var body: some View {
        List(selection: workspaceSelection) {
            Section("项目") {
                HStack(spacing: 8) {
                    Picker("当前项目", selection: projectSelection) {
                        ForEach(store.projects) { project in
                            Text(project.title)
                                .tag(Optional(project.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        if store.addProject() != nil {
                            onSelectSection(.script)
                        }
                    } label: {
                        Label("新建项目", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("新建项目")
                    .disabled(store.isAnalyzing)

                    Menu {
                        if let currentProject = store.currentProject {
                            Button {
                                beginRenaming(currentProject)
                            } label: {
                                Label("重命名项目", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                projectPendingDeletion = currentProject
                            } label: {
                                Label("删除项目", systemImage: "trash")
                            }
                            .disabled(store.isAnalyzing)
                        }
                    } label: {
                        Label("项目操作", systemImage: "ellipsis")
                            .labelStyle(.iconOnly)
                    }
                    .menuStyle(.borderlessButton)
                    .help("项目操作")
                }
            }

            Section("工作区") {
                WorkspaceSectionRow(
                    title: "剧本提取",
                    systemImage: WorkspaceSection.script.systemImage,
                    count: store.count(for: .script)
                )
                .tag(WorkspaceSection.script)

                WorkspaceSectionRow(
                    title: "提取结果",
                    systemImage: WorkspaceSection.allAssets.systemImage,
                    count: store.count(for: .allAssets)
                )
                .tag(WorkspaceSection.allAssets)
            }
        }
        .listStyle(.sidebar)
        .alert(
            "重命名项目",
            isPresented: Binding(
                get: { projectBeingRenamed != nil },
                set: { isPresented in
                    if !isPresented {
                        projectBeingRenamed = nil
                    }
                }
            )
        ) {
            TextField("项目名称", text: $renameDraft)

            Button("保存") {
                if let projectBeingRenamed {
                    store.renameProject(
                        id: projectBeingRenamed.id,
                        title: renameDraft
                    )
                }
                projectBeingRenamed = nil
            }

            Button("取消", role: .cancel) {
                projectBeingRenamed = nil
            }
        } message: {
            Text("项目名称只影响左侧导航，不会改变剧本或资产内容。")
        }
        .confirmationDialog(
            "删除“\(projectPendingDeletion?.title ?? "")”？",
            isPresented: Binding(
                get: { projectPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        projectPendingDeletion = nil
                    }
                }
            )
        ) {
            Button("删除项目", role: .destructive) {
                if let projectPendingDeletion {
                    store.deleteProject(id: projectPendingDeletion.id)
                    onSelectSection(.script)
                }
                projectPendingDeletion = nil
            }

            Button("取消", role: .cancel) {
                projectPendingDeletion = nil
            }
        } message: {
            Text("该项目内的所有分集和资产快照都会被删除，其他项目不受影响。")
        }
    }

    private var workspaceSelection: Binding<WorkspaceSection?> {
        Binding(
            get: {
                store.selectedSection == .script ? .script : .allAssets
            },
            set: { section in
                if let section {
                    onSelectSection(section)
                }
            }
        )
    }

    private var projectSelection: Binding<UUID?> {
        Binding(
            get: { store.selectedProjectID },
            set: { projectID in
                guard let projectID else { return }
                store.selectProject(projectID)
                onSelectSection(.script)
            }
        )
    }

    private func beginRenaming(_ project: AssetProject) {
        renameDraft = project.title
        projectBeingRenamed = project
    }
}

#Preview {
    ProjectSidebarView(
        store: WorkspaceStore(),
        onSelectSection: { _ in }
    )
    .frame(width: 280, height: 720)
}

private struct WorkspaceSectionRow: View {
    let title: String
    let systemImage: String
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(title)

            Spacer()

            Text(count, format: .number)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }
}
