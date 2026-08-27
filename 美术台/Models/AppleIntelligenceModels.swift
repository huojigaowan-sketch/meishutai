import Foundation

enum AnalysisRoute: String, Codable, Hashable, Sendable {
    case hybrid
    case deepSeekOnly
    case deepSeekChunked
    case deepSeekFallback

    var title: String {
        switch self {
        case .hybrid:
            "本地判定 + 云端审计"
        case .deepSeekOnly:
            "DeepSeek 原文分析"
        case .deepSeekChunked:
            "DeepSeek 分段整理"
        case .deepSeekFallback:
            "已回退 DeepSeek 原文分析"
        }
    }
}

struct AnalysisMetrics: Codable, Hashable, Sendable {
    var route: AnalysisRoute
    var sourceCharacterCount: Int
    var remoteCharacterCount: Int
    var segmentCount: Int? = nil
    var requestCount: Int? = nil
    var promptTokens: Int? = nil
    var completionTokens: Int? = nil
    var totalTokens: Int? = nil
    var estimatedCostUSD: Double? = nil

    var savedCharacterCount: Int {
        max(0, sourceCharacterCount - remoteCharacterCount)
    }

    var savingsFraction: Double {
        guard sourceCharacterCount > 0 else { return 0 }
        return Double(savedCharacterCount) / Double(sourceCharacterCount)
    }

    var usageSummary: String? {
        guard let totalTokens, totalTokens > 0 else { return nil }
        let requests = requestCount.map { " · \($0) 次请求" } ?? ""
        let cost = estimatedCostUSD.map { String(format: " · 预估 $%.4f", $0) } ?? ""
        return "Token \(totalTokens.formatted())\(requests)\(cost)"
    }
}

struct GeneratedAssetImage: Identifiable, Hashable, Sendable {
    var id: UUID
    var workspaceID: UUID
    var assetID: UUID
    var imageData: Data
    var promptSnapshot: String
    var styleIdentifier: String
    var generationVariantID: String?
    var generationVariantTitle: String?
    var createdAt: Date
    var isPrimary: Bool
}
