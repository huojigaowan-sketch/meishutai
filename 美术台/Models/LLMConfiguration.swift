import Foundation

enum LLMProvider: String, CaseIterable, Identifiable, Sendable {
    case deepSeek = "deepseek"
    case openAICompatible = "openai-compatible"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deepSeek:
            "DeepSeek"
        case .openAICompatible:
            "OpenAI 兼容接口"
        }
    }
}

enum OpenAICompatibleEndpoint {
    static let siliconFlowBaseURL = "https://api.siliconflow.cn/v1"
    static let siliconFlowExampleModelID = "deepseek-ai/DeepSeek-V4-Flash"

    static func resolve(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil
        else {
            return nil
        }

        var path = components.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        if !path.hasSuffix("/chat/completions") {
            path += path.isEmpty || path == "/"
                ? "chat/completions"
                : "/chat/completions"
        }
        if !path.hasPrefix("/") {
            path = "/" + path
        }
        components.path = path
        components.fragment = nil
        return components.url
    }

    static func modelsURL(for rawValue: String) -> URL? {
        guard let completionURL = resolve(rawValue),
              var components = URLComponents(url: completionURL, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        let completionSuffix = "/chat/completions"
        guard components.path.hasSuffix(completionSuffix) else { return nil }
        components.path.removeLast(completionSuffix.count)
        components.path += "/models"
        components.fragment = nil
        components.queryItems = isSiliconFlow(completionURL)
            ? [URLQueryItem(name: "sub_type", value: "chat")]
            : nil
        return components.url
    }

    static func isSiliconFlow(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "api.siliconflow.cn" || host.hasSuffix(".siliconflow.cn")
    }
}

enum OpenAICompatibleModelCatalog {
    static func fetch(from rawURL: String, apiKey: String) async throws -> [String] {
        guard let url = OpenAICompatibleEndpoint.modelsURL(for: rawURL) else {
            throw OpenAICompatibleModelCatalogError.invalidURL
        }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw OpenAICompatibleModelCatalogError.missingAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAICompatibleModelCatalogError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let envelope = try? JSONDecoder().decode(ModelCatalogErrorEnvelope.self, from: data)
            let message = envelope?.error?.message
                ?? envelope?.message
                ?? String(data: data, encoding: .utf8)
                ?? "未知错误"
            throw OpenAICompatibleModelCatalogError.http(httpResponse.statusCode, message)
        }

        let envelope = try JSONDecoder().decode(ModelCatalogEnvelope.self, from: data)
        let identifiers = Set(
            envelope.data
                .map(\.id)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        guard !identifiers.isEmpty else {
            throw OpenAICompatibleModelCatalogError.emptyCatalog
        }
        return identifiers.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }
}

private struct ModelCatalogEnvelope: Decodable {
    let data: [Model]

    struct Model: Decodable {
        let id: String
    }
}

private struct ModelCatalogErrorEnvelope: Decodable {
    let message: String?
    let error: APIError?

    struct APIError: Decodable {
        let message: String
    }
}

enum OpenAICompatibleModelCatalogError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case invalidResponse
    case emptyCatalog
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "无法从当前接口 URL 推导模型列表地址。"
        case .missingAPIKey:
            "请先填写 OpenAI 兼容接口的 API Key。"
        case .invalidResponse:
            "模型列表接口返回了无法识别的网络响应。"
        case .emptyCatalog:
            "服务商没有返回任何可用的对话模型。"
        case .http(let status, let message):
            "获取模型失败（HTTP \(status)）：\(message)"
        }
    }
}
