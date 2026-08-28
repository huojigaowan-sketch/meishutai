import FoundationModels
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
    @State private var engineStatus: AppleEngineStatusSnapshot?

    var body: some View {
        Form {
            Section("Apple 智能提取核心") {
                if let engineStatus {
                    LabeledContent("当前路线") {
                        Label(
                            engineStatus.activeRoute,
                            systemImage: engineStatus.onDeviceAvailable
                                ? "apple.intelligence"
                                : "cpu"
                        )
                    }
                    LabeledContent("中文支持") {
                        Text(engineStatus.supportsChinese ? "可用" : "不可用")
                            .foregroundStyle(engineStatus.supportsChinese ? .green : .orange)
                    }
                    if let contextSize = engineStatus.contextSize {
                        LabeledContent("本地上下文") {
                            Text("\(contextSize.formatted()) tokens")
                                .monospacedDigit()
                        }
                    }
                    Text(engineStatus.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView("正在检查 Foundation Models…")
                }

                Text("标准化、资产提取、内容标签和生图提示词统一使用 @Generable / @Guide 定义的 Apple GenerationSchema。Apple Intelligence 可用时优先本地执行；远程模型只作为同一 Schema 的并行增强或兜底。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("可选远程双引擎") {
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
                Text("留空即可仅使用 Apple 本地模型。配置后，远程 JSON 会先转换为 GeneratedContent，再按同一 Generable 类型解码，不再维护第二套响应模型。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("火山方舟 Ark 生图") {
                LabeledContent("Images API") {
                    TextField(
                        "https://ark.cn-beijing.volces.com/api/v3/images/generations",
                        text: $arkEndpoint
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 330)
                }
                LabeledContent("默认模型") {
                    TextField("doubao-seedream-4-0-250828", text: $arkModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 330)
                }
                secretField("API Key", value: $arkAPIKey)
                Text("文生图与参考图生图继续使用 Ark；资产选择、风格匹配和提示词规划由 Apple 框架自动完成。")
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
        .frame(width: 680, height: 720)
        .task {
            llmAPIKey = ArtDepartmentKeychain.read(account: .llm)
            arkAPIKey = ArtDepartmentKeychain.read(account: .ark)
            let remote = !llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            engineStatus = await AppleStructuredExtractionEngine.shared.status(
                remoteAvailable: remote
            )
        }
    }

    @ViewBuilder
    private func secretField(
        _ title: String,
        value: Binding<String>
    ) -> some View {
        LabeledContent(title) {
            Group {
                if showKeys {
                    TextField("sk-…", text: value)
                } else {
                    SecureField("sk-…", text: value)
                }
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

        let hasRemoteKey = !llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasRemoteKey {
            guard let llmURL = URL(string: llmBaseURL), llmURL.scheme != nil,
                  !llmModel.isEmpty else {
                statusMessage = "请检查远程接口 URL 和模型 ID。"
                statusIsError = true
                return
            }
        }
        guard let arkURL = URL(string: arkEndpoint), arkURL.scheme != nil,
              !arkModel.isEmpty else {
            statusMessage = "请检查 Ark 接口 URL 和模型 ID。"
            statusIsError = true
            return
        }

        do {
            try ArtDepartmentKeychain.save(llmAPIKey, account: .llm)
            try ArtDepartmentKeychain.save(arkAPIKey, account: .ark)
            statusMessage = hasRemoteKey
                ? "Apple 本地模型、远程 Schema 适配器与 Ark 配置已保存。"
                : "已启用 Apple 本地模型；Ark 配置已保存。"
            statusIsError = false
            Task {
                engineStatus = await AppleStructuredExtractionEngine.shared.status(
                    remoteAvailable: hasRemoteKey
                )
            }
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }
}
