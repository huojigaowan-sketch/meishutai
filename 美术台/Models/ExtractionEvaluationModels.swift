import Foundation

struct ExtractionGoldLabel: Codable, Hashable, Sendable, Identifiable {
    let kind: AssetKind
    let canonicalName: String
    let aliases: Set<String>

    var id: String {
        CanonicalAssetIdentity.key(kind: kind, canonicalName: canonicalName)
    }

    init(kind: AssetKind, canonicalName: String, aliases: Set<String> = []) {
        self.kind = kind
        self.canonicalName = canonicalName
        self.aliases = aliases.union([canonicalName])
    }

    func matches(_ asset: AssetItem) -> Bool {
        guard asset.kind == kind else { return false }
        let predicted = CanonicalAssetIdentity.normalizedName(asset.name, kind: kind)
        return aliases.contains { alias in
            CanonicalAssetIdentity.normalizedName(alias, kind: kind) == predicted
        }
    }
}

struct ExtractionClassMetrics: Codable, Hashable, Sendable {
    let kind: AssetKind
    let truePositive: Int
    let falsePositive: Int
    let falseNegative: Int

    var precision: Double {
        ratio(truePositive, truePositive + falsePositive)
    }

    var recall: Double {
        ratio(truePositive, truePositive + falseNegative)
    }

    var f1: Double {
        guard precision + recall > 0 else { return 0 }
        return 2 * precision * recall / (precision + recall)
    }

    private func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        denominator == 0 ? 1 : Double(numerator) / Double(denominator)
    }
}

struct ExtractionEvaluationReport: Codable, Hashable, Sendable {
    let generatedAt: Date
    let metrics: [ExtractionClassMetrics]

    var microPrecision: Double {
        ratio(
            metrics.reduce(0) { $0 + $1.truePositive },
            metrics.reduce(0) { $0 + $1.truePositive + $1.falsePositive }
        )
    }

    var microRecall: Double {
        ratio(
            metrics.reduce(0) { $0 + $1.truePositive },
            metrics.reduce(0) { $0 + $1.truePositive + $1.falseNegative }
        )
    }

    var microF1: Double {
        guard microPrecision + microRecall > 0 else { return 0 }
        return 2 * microPrecision * microRecall / (microPrecision + microRecall)
    }

    private func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        denominator == 0 ? 1 : Double(numerator) / Double(denominator)
    }
}

enum ExtractionEvaluator {
    static func evaluate(
        assets: [AssetItem],
        goldLabels: [ExtractionGoldLabel]
    ) -> ExtractionEvaluationReport {
        let activeAssets = assets.filter { $0.reviewState != .ignored }
        let metrics = AssetKind.allCases.map { kind in
            let predictions = activeAssets.filter { $0.kind == kind }
            let labels = goldLabels.filter { $0.kind == kind }
            var unmatchedPredictionIDs = Set(predictions.map(\.id))
            var truePositive = 0

            for label in labels {
                guard let match = predictions.first(where: {
                    unmatchedPredictionIDs.contains($0.id) && label.matches($0)
                }) else {
                    continue
                }
                truePositive += 1
                unmatchedPredictionIDs.remove(match.id)
            }

            return ExtractionClassMetrics(
                kind: kind,
                truePositive: truePositive,
                falsePositive: unmatchedPredictionIDs.count,
                falseNegative: max(0, labels.count - truePositive)
            )
        }
        return ExtractionEvaluationReport(generatedAt: .now, metrics: metrics)
    }
}

