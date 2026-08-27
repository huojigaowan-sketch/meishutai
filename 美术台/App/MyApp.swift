import SwiftUI

@main
struct MyApp: App {
    @State private var store = WorkspaceStore()

    var body: some Scene {
        WindowGroup("资产台") {
            rootContent
                .frame(width: 1360, height: 860)
        }
        .defaultSize(width: 1360, height: 860)
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("项目") {
                Button("新建项目") {
                    store.addProject()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(store.isAnalyzing)

                Button("新建分集") {
                    store.addEpisode()
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(store.isAnalyzing)
            }
        }

        Settings {
            SettingsView()
        }
    }

    private var rootContent: some View {
        ContentView(store: store)
    }
}
