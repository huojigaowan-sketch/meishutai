import Foundation

enum AssetDataExportFormat: String, CaseIterable, Identifiable, Sendable {
    case json
    case csv

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
    var fileExtension: String { rawValue }
}

struct AssetExportManifest: Codable, Sendable {
    let schemaVersion: Int
    let projectTitle: String
    let exportedAt: Date
    let assets: [ExportedAsset]
    let episodes: [EpisodeReference]

    struct EpisodeReference: Codable, Sendable {
        let id: UUID
        let order: Int
        let title: String
    }
}

private struct ExportedAsset: Codable, Sendable {
    let id: UUID
    let kind: AssetKind
    let name: String
    let summary: String
    let evidence: String
    let reviewState: AssetReviewState
    let sourceEpisodeIDs: [UUID]?
    let canonicalKey: String?
}

enum AssetDataExporter {
    static func data(
        format: AssetDataExportFormat,
        projectTitle: String,
        assets: [AssetItem],
        episodes: [ScriptEpisode],
        exportedAt: Date = .now
    ) throws -> Data {
        let exportedAssets = assets.map { asset in
            ExportedAsset(
                id: asset.id,
                kind: asset.kind,
                name: asset.name,
                summary: asset.summary,
                evidence: asset.evidence,
                reviewState: asset.reviewState,
                sourceEpisodeIDs: asset.sourceEpisodeIDs,
                canonicalKey: asset.canonicalKey
            )
        }
        switch format {
        case .json:
            let manifest = AssetExportManifest(
                schemaVersion: 1,
                projectTitle: projectTitle,
                exportedAt: exportedAt,
                assets: exportedAssets,
                episodes: episodes.sorted(using: KeyPathComparator(\.order)).map {
                    .init(id: $0.id, order: $0.order, title: $0.title)
                }
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(manifest)
        case .csv:
            let header = [
                "id", "kind", "name", "reviewState", "summary", "evidence",
                "canonicalKey", "sourceEpisodeIDs"
            ]
            let rows = assets.map { asset in
                [
                    asset.id.uuidString,
                    asset.kind.rawValue,
                    asset.name,
                    asset.reviewState.rawValue,
                    asset.summary,
                    asset.evidence,
                    asset.canonicalKey ?? "",
                    (asset.sourceEpisodeIDs ?? []).map(\.uuidString).joined(separator: "|")
                ].map(csvField).joined(separator: ",")
            }
            let text = ([header.map(csvField).joined(separator: ",")] + rows)
                .joined(separator: "\r\n") + "\r\n"
            return Data(text.utf8)
        }
    }

    static func csvField(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
