import SwiftUI

@MainActor
struct SettingsView: View {
    @AppStorage("llm.provider") private var providerRawValue = LLMProvider.deepSeek.rawValue
    @AppStorage("deepseek.model") private var modelRawValue = DeepSeekModel.pro.rawValue
    @AppStorage("openaiCompatible.url") private var compatibleURL = ""
    @AppStorage("openaiCompatible.model") private var compatibleModelID = ""
    @State private var deepSeekAPIKey = ""
    @State private var compatibleAPIKey = ""
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var showsKey = false
    @State private var compatibleModels: [String] = []
    @State private var isLoadingCompatibleModels = false
    @State private var compatibleModelMessage: String?
    @State private var compatibleModelMessageIsError = false

    var body: some View {
        Form {
            Section("大模型接口") {
                Picker("当前接口", selection: $providerRawValue) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.title).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            if selectedProvider == .deepSeek {
                deepSeekSection
            } else {
                openAICompatibleSection
            }

            Section {
                HStack {
                    Text("API Key 仅保存在本机 Keychain；剧本文本与资产保存在应用沙盒。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("保存") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let statusMessage {
                    Label(
                        statusMessage,
                        systemImage: statusIsError
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.circle.fill"
                    )
                    .foregroundStyle(statusIsError ? .red : .green)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 580, height: 640)
        .scenePadding()
        .task {
            deepSeekAPIKey = KeychainService.readAPIKey()
            compatibleAPIKey = KeychainService.readOpenAICompatibleAPIKey()
            if selectedProvider == .openAICompatible,
               !compatibleURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !compatibleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                await loadCompatibleModels()
            }
        }
    }

    private var selectedProvider: LLMProvider {
        LLMProvider(rawValue: providerRawValue) ?? .deepSeek
    }

    private var deepSeekSection: some View {
        Section("DeepSeek") {
            LabeledContent("API Key") {
                HStack {
                    Group {
                        if showsKey {
                            TextField("sk-…", text: $deepSeekAPIKey)
                        } else {
                            SecureField("sk-…", text: $deepSeekAPIKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)

                    Button {
                        showsKey.toggle()
                    } label: {
                        Image(systemName: showsKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(showsKey ? "隐藏 API Key" : "显示 API Key")
                }
            }

            Picker("模型", selection: $modelRawValue) {
                ForEach(DeepSeekModel.allCases) { model in
                    VStack(alignment: .leading) {
                        Text(model.title)
                        Text(model.detail)
                            .font(.caption)
                    }
                    .tag(model.rawValue)
                }
            }

            LabeledContent("接口") {
                Text("api.deepseek.com")
                    .foregroundStyle(.secondary)
            }

            Text("剧本会先在本地分集并保存，再逐集提取；每集完成后立即写入结果。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var openAICompatibleSection: some View {
        Section("OpenAI 兼容接口") {
            LabeledContent("URL") {
                HStack {
                    TextField("https://…/v1", text: $compatibleURL)
                        .textFieldStyle(.roundedBorder)

                    Button("SiliconFlow 预设") {
                        applySiliconFlowPreset()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(width: 390)
            }

            LabeledContent("API Key") {
                HStack {
                    Group {
                        if showsKey {
                            TextField("sk-…", text: $compatibleAPIKey)
                        } else {
                            SecureField("sk-…", text: $compatibleAPIKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)

                    Button {
                        showsKey.toggle()
                    } label: {
                        Image(systemName: showsKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(showsKey ? "隐藏 API Key" : "显示 API Key")
                }
            }

            LabeledContent("模型 ID") {
                HStack {
                    TextField(
                        "例如 deepseek-ai/DeepSeek-V4-Flash",
                        text: $compatibleModelID
                    )
                    .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            await loadCompatibleModels()
                        }
                    } label: {
                        if isLoadingCompatibleModels {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("获取模型", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingCompatibleModels)
                }
                .frame(width: 390)
            }

            if !compatibleModels.isEmpty {
                Picker("服务器可用模型", selection: $compatibleModelID) {
                    let currentModelID = compatibleModelID.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    if !currentModelID.isEmpty,
                       !compatibleModels.contains(currentModelID)
                    {
                        Text("\(currentModelID)（当前不可用）")
                            .tag(currentModelID)
                    }
                    ForEach(compatibleModels, id: \.self) { modelID in
                        Text(modelID).tag(modelID)
                    }
                }
            }

            if let compatibleModelMessage {
                Label(
                    compatibleModelMessage,
                    systemImage: compatibleModelMessageIsError
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(compatibleModelMessageIsError ? .orange : .green)
            }

            Text("可填写服务商提供的基础 URL 或完整的 /chat/completions URL。SiliconFlow 必须使用模型列表返回的完整 ID，不能填写其他平台的模型短名称。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        if selectedProvider == .openAICompatible {
            compatibleURL = compatibleURL.trimmingCharacters(in: .whitespacesAndNewlines)
            compatibleModelID = compatibleModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            compatibleAPIKey = compatibleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let endpoint = OpenAICompatibleEndpoint.resolve(compatibleURL) else {
                statusMessage = "OpenAI 兼容接口 URL 无效。"
                statusIsError = true
                return
            }
            guard !compatibleModelID.isEmpty else {
                statusMessage = "请填写模型 ID，或先获取服务器可用模型。"
                statusIsError = true
                return
            }
            if OpenAICompatibleEndpoint.isSiliconFlow(endpoint),
               !compatibleModelID.contains("/")
            {
                statusMessage = "SiliconFlow 需要完整模型 ID，例如 deepseek-ai/DeepSeek-V4-Flash。"
                statusIsError = true
                return
            }
        }

        do {
            try KeychainService.saveAPIKey(deepSeekAPIKey)
            try KeychainService.saveOpenAICompatibleAPIKey(compatibleAPIKey)
            let selectedKey = selectedProvider == .deepSeek
                ? deepSeekAPIKey
                : compatibleAPIKey
            statusMessage = selectedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "已从 Keychain 移除 API Key"
                : "接口配置已安全保存"
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    private func applySiliconFlowPreset() {
        compatibleURL = OpenAICompatibleEndpoint.siliconFlowBaseURL
        compatibleModelID = OpenAICompatibleEndpoint.siliconFlowExampleModelID
        compatibleModels = []
        compatibleModelMessage = "已填入 SiliconFlow 官方接口和示例模型；获取模型后可选择账号当前可用的其他模型。"
        compatibleModelMessageIsError = false
    }

    @MainActor
    private func loadCompatibleModels() async {
        guard !isLoadingCompatibleModels else { return }
        isLoadingCompatibleModels = true
        compatibleModelMessage = nil
        defer { isLoadingCompatibleModels = false }

        do {
            let models = try await OpenAICompatibleModelCatalog.fetch(
                from: compatibleURL,
                apiKey: compatibleAPIKey
            )
            compatibleModels = models

            let currentModelID = compatibleModelID.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if currentModelID.isEmpty {
                if models.contains(OpenAICompatibleEndpoint.siliconFlowExampleModelID) {
                    compatibleModelID = OpenAICompatibleEndpoint.siliconFlowExampleModelID
                } else if let firstModel = models.first {
                    compatibleModelID = firstModel
                }
                compatibleModelMessage = "已获取 \(models.count) 个对话模型，并选中一个可用模型。"
                compatibleModelMessageIsError = false
            } else if models.contains(currentModelID) {
                compatibleModelMessage = "模型“\(currentModelID)”当前可用。"
                compatibleModelMessageIsError = false
            } else {
                compatibleModelMessage = "当前模型“\(currentModelID)”不在服务器列表中，请从上方列表重新选择。"
                compatibleModelMessageIsError = true
            }
        } catch {
            compatibleModels = []
            compatibleModelMessage = error.localizedDescription
            compatibleModelMessageIsError = true
        }
    }
}
