import SwiftUI

@main
struct MyApp: App {
    @State private var store = ArtDepartmentV2Store()

    var body: some Scene {
        WindowGroup("美术台") {
            ContentView(store: store)
                .frame(minWidth: 1_120, minHeight: 720)
        }
        .defaultSize(width: 1_440, height: 920)
        .commands {
            CommandMenu("项目") {
                Button("新建美术项目") { store.addProject() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Divider()
                Button("剧本标准化") { Task { await store.normalizeCurrentScript() } }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .disabled(store.isWorking)
                Button("提取场景人物道具") { Task { await store.extractCurrentAssets() } }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(store.isWorking)
            }
        }

        Settings {
            ArtDepartmentV2SettingsView()
        }
    }
}
