import SwiftUI

@MainActor
struct ArtDepartmentV2SettingsView: View {
    @AppStorage("art.llm.provider") private var llmProvider = "deepseek"
    @AppStorage("art.llm.baseURL") private var llmBaseURL = "https://api.deepseek.com"
    @AppStorage("art.llm.model") private var llmModel = "deepseek-v4-flash"
    @AppStorage("art.ark.endpoint") private var arkEndpoint = "https://ark.cn-beijing.volces.com/api/v3/images/generations"
    @AppStorage("art.ark.model") private var arkModel = "doubao-seedream-4-0-250828"

    @State private var llmAPIKey = ""
    @State private var arkAPIKey = ""
    @State private var showKeys = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        Form {
            Section("剧本标准化与资产提取模型") {
                Picker("接口类型", selection: $llmProvider) {
                    Text("DeepSeek").tag("deepseek")
                    Text("OpenAI 兼容接口").tag("openai-compatible")
                }
                .pickerStyle(.segmented)

                LabeledContent("Base URL") {
                    TextField("https://api.deepseek.com", text: $llmBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 330)
                }
                LabeledContent("模型 ID") {
                    TextField("deepseek-v4-flash", text: $llmModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 330)
                }
                secretField("API Key", value: $llmAPIKey)
                Text("标准化调用 JSON mode：先覆盖全部原文证据单元，再生成标准场景；资产提取只读取标准场景并要求逐字证据。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("火山方舟 Ark 生图") {
                LabeledContent("Images API") {
                    TextField("https://ark.cn-beijing.volces.com/api/v3/images/generations", text: $arkEndpoint)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 330)
                }
                LabeledContent("默认模型") {
                    TextField("doubao-seedream-4-0-250828", text: $arkModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 330)
                }
                secretField("API Key", value: $arkAPIKey)
                Text("支持文生图和参考图生图。用户上传的参考图、风格提示词与生成结果仅保存在本机应用支持目录。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Toggle("显示 API Key", isOn: $showKeys)
                    Spacer()
                    Button("保存配置") { save() }
                        .buttonStyle(.borderedProminent)
                }
                if let statusMessage {
                    Label(statusMessage, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(statusIsError ? .red : .green)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 650, height: 650)
        .task {
            llmAPIKey = ArtDepartmentKeychain.read(account: .llm)
            arkAPIKey = ArtDepartmentKeychain.read(account: .ark)
        }
    }

    @ViewBuilder
    private func secretField(_ title: String, value: Binding<String>) -> some View {
        LabeledContent(title) {
            Group {
                if showKeys { TextField("sk-…", text: value) }
                else { SecureField("sk-…", text: value) }
            }
            .textFieldStyle(.roundedBorder)
            .frame(width: 330)
        }
    }

    private func save() {
        llmBaseURL = llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        llmModel = llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        arkEndpoint = arkEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        arkModel = arkModel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let llmURL = URL(string: llmBaseURL), llmURL.scheme != nil,
              let arkURL = URL(string: arkEndpoint), arkURL.scheme != nil,
              !llmModel.isEmpty, !arkModel.isEmpty else {
            statusMessage = "请检查接口 URL 和模型 ID。"
            statusIsError = true
            return
        }
        do {
            try ArtDepartmentKeychain.save(llmAPIKey, account: .llm)
            try ArtDepartmentKeychain.save(arkAPIKey, account: .ark)
            statusMessage = "大模型与 Ark 配置已保存到本机 Keychain。"
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }
}
