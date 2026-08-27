import Foundation
import Security

nonisolated struct ArtLLMConfiguration: Hashable, Sendable {
    var baseURL: URL
    var apiKey: String
    var model: String
    var providerName: String

    static func current() throws -> ArtLLMConfiguration {
        let defaults = UserDefaults.standard
        let provider = defaults.string(forKey: "art.llm.provider") ?? "deepseek"
        let base = defaults.string(forKey: "art.llm.baseURL")
            ?? (provider == "deepseek" ? "https://api.deepseek.com" : "")
        let model = defaults.string(forKey: "art.llm.model")
            ?? (provider == "deepseek" ? "deepseek-v4-flash" : "")
        let apiKey = ArtDepartmentKeychain.read(account: .llm)
        guard let baseURL = URL(string: base), !apiKey.isEmpty, !model.isEmpty else {
            throw ArtDepartmentV2Error.missingLLMConfiguration
        }
        return ArtLLMConfiguration(baseURL: baseURL, apiKey: apiKey, model: model, providerName: provider)
    }

    var completionURL: URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return baseURL }
        var path = components.path
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        if path.hasSuffix("/chat/completions") { return components.url ?? baseURL }
        if path.isEmpty || path == "/" { path = "/chat/completions" }
        else { path += "/chat/completions" }
        components.path = path
        return components.url ?? baseURL
    }
}

nonisolated struct ArkImageConfiguration: Hashable, Sendable {
    var endpoint: URL
    var apiKey: String
    var model: String

    static func current() throws -> ArkImageConfiguration {
        let defaults = UserDefaults.standard
        let endpointString = defaults.string(forKey: "art.ark.endpoint")
            ?? "https://ark.cn-beijing.volces.com/api/v3/images/generations"
        let model = defaults.string(forKey: "art.ark.model")
            ?? "doubao-seedream-4-0-250828"
        let apiKey = ArtDepartmentKeychain.read(account: .ark)
        guard let endpoint = URL(string: endpointString), !apiKey.isEmpty, !model.isEmpty else {
            throw ArtDepartmentV2Error.missingArkConfiguration
        }
        return ArkImageConfiguration(endpoint: endpoint, apiKey: apiKey, model: model)
    }
}

nonisolated enum ArtSecretAccount: String {
    case llm = "llm-api-key"
    case ark = "ark-api-key"
}

nonisolated enum ArtDepartmentKeychain {
    private static let service = "com.meishutai.art-department-v2"

    static func read(account: ArtSecretAccount) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    static func save(_ value: String, account: ArtSecretAccount) throws {
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
        SecItemDelete(lookup as CFDictionary)
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var entry = lookup
        entry[kSecValueData as String] = Data(clean.utf8)
        entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(entry as CFDictionary, nil)
        guard status == errSecSuccess else { throw ArtDepartmentNetworkError.keychain(status) }
    }
}

nonisolated struct ArtChatCompletionClient: Sendable {
    let configuration: ArtLLMConfiguration

    func completeJSON(
        system: String,
        user: String,
        maximumTokens: Int = 8_000,
        temperature: Double = 0.1
    ) async throws -> String {
        let payload = ChatPayload(
            model: configuration.model,
            messages: [
                .init(role: "system", content: system + "\n只返回一个合法 JSON 对象，不得使用 Markdown。"),
                .init(role: "user", content: user),
            ],
            temperature: temperature,
            maxTokens: maximumTokens,
            responseFormat: .init(type: "json_object"),
            stream: false
        )
        var request = URLRequest(url: configuration.completionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        var lastError: Error?
        for attempt in 1...3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw ArtDepartmentNetworkError.invalidResponse }
                guard (200..<300).contains(http.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw ArtDepartmentNetworkError.http(http.statusCode, body)
                }
                let envelope = try JSONDecoder().decode(ChatResponse.self, from: data)
                guard let content = envelope.choices.first?.message.content,
                      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ArtDepartmentNetworkError.emptyResponse
                }
                return Self.extractJSONObject(content)
            } catch {
                lastError = error
                if attempt < 3 { try? await Task.sleep(for: .seconds(attempt * 2)) }
            }
        }
        throw lastError ?? ArtDepartmentNetworkError.emptyResponse
    }

    static func extractJSONObject(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = clean.firstIndex(of: "{"), let end = clean.lastIndex(of: "}"), start <= end else { return clean }
        return String(clean[start...end])
    }
}

nonisolated struct ArtGeneratedImagePayload: Sendable {
    var data: Data
    var requestID: String?
    var fileExtension: String
}

nonisolated struct ArkImageGenerationClient: Sendable {
    let configuration: ArkImageConfiguration

    func generate(
        prompt: String,
        negativePrompt: String,
        recipe: ImageGenerationRecipe,
        referenceImages: [Data]
    ) async throws -> [ArtGeneratedImagePayload] {
        var body: [String: Any] = [
            "model": recipe.model.isEmpty ? configuration.model : recipe.model,
            "prompt": prompt,
            "size": recipe.size,
            "response_format": "b64_json",
            "watermark": recipe.watermark,
        ]
        if !negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["negative_prompt"] = negativePrompt
        }
        if !referenceImages.isEmpty {
            body["image"] = referenceImages.map { "data:image/png;base64,\($0.base64EncodedString())" }
        }
        if recipe.maxImages > 1 {
            body["sequential_image_generation"] = "auto"
            body["sequential_image_generation_options"] = ["max_images": min(15, max(1, recipe.maxImages))]
        }

        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ArtDepartmentNetworkError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ArtDepartmentNetworkError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let envelope = try JSONDecoder().decode(ArkImageResponse.self, from: data)
        let requestID = http.value(forHTTPHeaderField: "x-request-id") ?? envelope.id
        var results: [ArtGeneratedImagePayload] = []
        for item in envelope.data ?? [] {
            if let base64 = item.b64JSON, let imageData = Data(base64Encoded: base64) {
                results.append(.init(data: imageData, requestID: requestID, fileExtension: "png"))
            } else if let rawURL = item.url, let url = URL(string: rawURL) {
                let (imageData, _) = try await URLSession.shared.data(from: url)
                results.append(.init(data: imageData, requestID: requestID, fileExtension: url.pathExtension.isEmpty ? "png" : url.pathExtension))
            }
        }
        guard !results.isEmpty else { throw ArtDepartmentNetworkError.emptyImageResponse }
        return results
    }
}

private struct ChatPayload: Encodable {
    struct Message: Encodable { var role: String; var content: String }
    struct ResponseFormat: Encodable { var type: String }
    var model: String
    var messages: [Message]
    var temperature: Double
    var maxTokens: Int
    var responseFormat: ResponseFormat
    var stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { var content: String? }
        var message: Message
    }
    var choices: [Choice]
}

private struct ArkImageResponse: Decodable {
    struct Item: Decodable {
        var url: String?
        var b64JSON: String?
        enum CodingKeys: String, CodingKey { case url; case b64JSON = "b64_json" }
    }
    var id: String?
    var data: [Item]?
}

nonisolated enum ArtDepartmentNetworkError: LocalizedError {
    case invalidResponse
    case emptyResponse
    case emptyImageResponse
    case http(Int, String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "服务端返回了无法识别的网络响应。"
        case .emptyResponse: "大模型没有返回可用内容。"
        case .emptyImageResponse: "Ark 没有返回图像数据。"
        case .http(let status, let message): "接口请求失败（HTTP \(status)）：\(message.prefix(500))"
        case .keychain(let status): "无法保存 API Key（Keychain 状态码 \(status)）。"
        }
    }
}
