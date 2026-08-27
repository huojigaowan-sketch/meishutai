import Foundation
import Testing
@testable import 美术台

@Suite(.serialized)
@MainActor
struct VerifiedInventoryClientTests {
    @Test("模型新增项的证据不是原文唯一子串时整批拒绝")
    func verifiedInventoryRejectsForgedEvidence() async {
        VerifiedInventoryURLProtocol.state.reset()
        VerifiedInventoryURLProtocol.state.setForgedAddition(true)
        do {
            _ = try await makeClient().extractVerifiedInventory(
                from: "1-1 日/内 测试院子\n林默：拿起手机。",
                episodeID: UUID()
            )
            Issue.record("伪造证据本应被本地校验拒绝")
        } catch let error as DeepSeekError {
            guard case .invalidJSON(let message) = error else {
                Issue.record("错误应保持为严格回执失败，实际为 \(error)")
                return
            }
            #expect(message.contains("原文子串"))
        } catch {
            Issue.record("错误类型应为 DeepSeekError，实际为 \(error)")
        }
    }

    private func makeClient() -> DeepSeekClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [VerifiedInventoryURLProtocol.self]
        return DeepSeekClient(
            apiKey: "test-key",
            endpoint: URL(string: "https://verified-inventory.test/chat/completions")!,
            modelID: "test-model",
            session: URLSession(configuration: configuration),
            retryPolicy: DeepSeekRetryPolicy(
                maximumAttempts: 1,
                initialDelay: 0,
                maximumDelay: 0
            ),
            sleeper: { _ in }
        )
    }
}

private final class VerifiedInventoryMockState: @unchecked Sendable {
    private let lock = NSLock()
    private var requests = 0
    private var failures: [String] = []
    private var forgedAddition = false

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    var failureMessages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return failures
    }

    var shouldForgeAddition: Bool {
        lock.lock()
        defer { lock.unlock() }
        return forgedAddition
    }

    func reset() {
        lock.lock()
        requests = 0
        failures = []
        forgedAddition = false
        lock.unlock()
    }

    func setForgedAddition(_ enabled: Bool) {
        lock.lock()
        forgedAddition = enabled
        lock.unlock()
    }

    func recordRequest() -> Int {
        lock.lock()
        defer { lock.unlock() }
        requests += 1
        return requests
    }

    func recordFailure(_ message: String) {
        lock.lock()
        failures.append(message)
        lock.unlock()
    }

}

private final class VerifiedInventoryURLProtocol: URLProtocol {
    static let state = VerifiedInventoryMockState()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let requestNumber = Self.state.recordRequest()
            let body = try verifiedRequestBodyData(request)
            let requestObject = try #require(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            let messages = try #require(requestObject["messages"] as? [[String: Any]])
            let system = messages
                .filter { $0["role"] as? String == "system" }
                .compactMap { $0["content"] as? String }
                .joined(separator: "\n")
            #expect(!system.isEmpty)
            let user = try #require(
                messages.first(where: {
                    $0["role"] as? String == "user"
                        && ($0["content"] as? String)?.contains("INVENTORY_PAYLOAD") == true
                })?["content"] as? String
            )
            let payloadData = try #require(
                DeepSeekClient.singleTopLevelJSONObjectData(from: user)
            )
            let payload = try #require(
                JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
            )
            let segmentID = try #require(payload["segmentID"] as? String)
            let units = try #require(payload["sourceUnits"] as? [[String: Any]])
            let candidates = try #require(payload["candidates"] as? [[String: Any]])
            let isCharacter = requestNumber == 2
            let isScene = requestNumber == 1
            let decisions: [[String: Any]] = try candidates.map { candidate in
                let id = try #require(candidate["candidateID"] as? String)
                let rawName = try #require(candidate["rawName"] as? String)
                return [
                    "candidateID": id,
                    "disposition": "accepted",
                    "canonicalName": rawName,
                    "identityQualifier": "",
                    "variantLabel": "",
                    "reason": "原文证据判定",
                    "confidence": 0.96
                ]
            }
            let receipt: [String: Any] = [
                "segmentID": segmentID,
                "coveredSourceUnitIDs": try units.map {
                    try #require($0["id"] as? String)
                },
                "decisions": decisions,
                "additions": Self.state.shouldForgeAddition && !isCharacter && !isScene
                    ? [[
                        "sourceUnitID": try #require(units.first?["id"] as? String),
                        "name": "伪造道具",
                        "exactEvidenceQuote": "这段文字绝不在原剧本中",
                        "disposition": "accepted",
                        "canonicalName": "伪造道具",
                        "identityQualifier": "",
                        "variantLabel": "",
                        "reason": "模拟伪造证据",
                        "confidence": 0.99
                    ]]
                    : []
            ]
            let receiptData = try JSONSerialization.data(withJSONObject: receipt)
            let receiptText = String(decoding: receiptData, as: UTF8.self)
            let responseObject: [String: Any] = [
                "id": "verified-\(requestNumber)",
                "model": "test-model",
                "created": requestNumber,
                "choices": [[
                    "finish_reason": "stop",
                    "message": ["content": receiptText]
                ]],
                "usage": [
                    "prompt_tokens": 10,
                    "completion_tokens": 5,
                    "total_tokens": 15
                ]
            ]
            let responseData = try JSONSerialization.data(withJSONObject: responseObject)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: responseData)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            Self.state.recordFailure(String(describing: error))
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func verifiedRequestBodyData(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else {
        throw VerifiedInventoryMockError.missingRequestBody
    }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 { throw stream.streamError ?? VerifiedInventoryMockError.unreadableStream }
        if count == 0 { break }
        data.append(buffer, count: count)
    }
    return data
}

private enum VerifiedInventoryMockError: Error {
    case missingRequestBody
    case unreadableStream
}
