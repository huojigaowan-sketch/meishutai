#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

ASSET_BASIC_SWIFT = 'import Foundation\n\nnonisolated struct AssetSceneAppearance: Codable, Hashable, Identifiable, Sendable {\n    var sceneID: UUID\n    var sceneOrder: Int\n    var sceneHeading: String\n    var evidenceQuotes: [String]\n\n    var id: UUID { sceneID }\n}\n\nnonisolated struct AssetEpisodeAppearance: Codable, Hashable, Identifiable, Sendable {\n    var episodeNumber: Int\n    var episodeTitle: String?\n    var scenes: [AssetSceneAppearance]\n\n    var id: Int { episodeNumber }\n\n    var label: String {\n        let title = episodeTitle?\n            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""\n        return title.isEmpty\n            ? "第\\(episodeNumber)集"\n            : "第\\(episodeNumber)集 · \\(title)"\n    }\n}\n\nnonisolated struct AssetBasicFactGroup: Codable, Hashable, Identifiable, Sendable {\n    var kind: AssetDesignFactKind\n    var values: [String]\n    var evidenceCount: Int\n\n    var id: String { kind.rawValue }\n}\n\nnonisolated struct AssetBasicInformation: Codable, Hashable, Identifiable, Sendable {\n    var assetID: UUID\n    var kind: ProductionAssetKind\n    var canonicalName: String\n    var aliases: [String]\n    var overview: String\n    var factGroups: [AssetBasicFactGroup]\n    var continuityState: String\n    var missingFactKinds: [AssetDesignFactKind]\n    var episodeAppearances: [AssetEpisodeAppearance]\n    var sceneCount: Int\n    var sourceEvidenceCount: Int\n    var aggregationConfidence: Double\n    var aggregationVersion: Int\n    var generatedAt: Date\n\n    var id: UUID { assetID }\n\n    var episodeNumbers: [Int] {\n        episodeAppearances.map(\\.episodeNumber).sorted()\n    }\n\n    var episodeSummary: String {\n        let numbers = episodeNumbers\n        guard !numbers.isEmpty else { return "集数未识别" }\n        return numbers.map { "第\\($0)集" }.joined(separator: "、")\n    }\n\n    /// Image generation receives grounded subject information only. Episode\n    /// appearances remain production metadata and do not contaminate the visual prompt.\n    var promptText: String {\n        var lines = [\n            "【基本资料】",\n            "类型：\\(kind.rawValue)",\n            "名称：\\(canonicalName)",\n        ]\n        if !aliases.isEmpty {\n            lines.append("明确别名：\\(aliases.joined(separator: "、"))")\n        }\n        for group in factGroups where !group.values.isEmpty {\n            lines.append("\\(group.kind.title)：\\(group.values.joined(separator: "；"))")\n        }\n        let continuity = continuityState\n            .trimmingCharacters(in: .whitespacesAndNewlines)\n        if !continuity.isEmpty {\n            lines.append("连续性状态：\\(continuity)")\n        }\n        if !missingFactKinds.isEmpty {\n            lines.append(\n                "剧本未明确、禁止臆造："\n                    + missingFactKinds.map(\\.title).joined(separator: "、")\n            )\n        }\n        lines.append(\n            "以上资料来自 Final Draft 场景级提取、逐字证据核验和全剧汇总；"\n                + "不得用风格样板或常识补充未记录的人物、场景或道具事实。"\n        )\n        return lines.joined(separator: "\\n")\n    }\n}\n\nnonisolated struct BasicInformationAudit: Codable, Hashable, Sendable {\n    var version: Int\n    var episodeCount: Int\n    var sceneCount: Int\n    var profileCount: Int\n    var unresolvedSceneCount: Int\n    var sourceFingerprint: String\n    var completedAt: Date\n\n    var isComplete: Bool {\n        version >= 1 && profileCount > 0 && sceneCount > 0 && episodeCount > 0\n    }\n}\n\nnonisolated struct AssetBasicInformationAggregationResult: Sendable {\n    var scenes: [CanonicalScene]\n    var assets: [ProductionAsset]\n    var audit: BasicInformationAudit\n}\n\nnonisolated struct AssetFormatTemplate: Codable, Hashable, Identifiable, Sendable {\n    var id: String\n    var kind: ProductionAssetKind\n    var title: String\n    var summary: String\n    var positiveInstruction: String\n    var negativeInstruction: String\n    var recommendedAspectRatios: [ImageAspectRatio]\n}\n\nnonisolated enum AssetFormatTemplateCatalog {\n    static let sceneCleanPlate = AssetFormatTemplate(\n        id: "format.scene.clean-empty.v1",\n        kind: .scene,\n        title: "场景 · 无人无杂物空景",\n        summary: "无人、无人影、无动物、无无关杂物；只保留剧本明确的空间结构、固定陈设和必要道具。",\n        positiveInstruction: """\n        【场景格式模板】\n        生成无人空场景设计图。画面不得出现人物、人影、人体局部、动物或拟人主体。移除垃圾、散乱物、临时堆放物、非剧本要求的小物件和无关装饰；只保留基本资料中有逐字证据的建筑、固定陈设、必要道具与空间关系。场地整洁、无遮挡、空间结构清楚，适合置景、勘景与镜头规划。\n        """,\n        negativeInstruction: "人物、人影、人群、人体局部、手脚、动物、拟人主体、无剧本依据的车辆、垃圾、杂物堆、散乱小物、临时箱包、无关装饰、无关道具、文字、水印",\n        recommendedAspectRatios: [.landscape16x9, .landscape4x3, .landscape3x2]\n    )\n\n    static let characterFourView = AssetFormatTemplate(\n        id: "format.character.white-four-view.v1",\n        kind: .character,\n        title: "人物 · 纯白背景四视图",\n        summary: "左一头肩特写；右侧为全身正面、严格侧面、严格背面；中立站姿、双手自然垂放、无表情、均匀光照。",\n        positiveInstruction: """\n        【人物格式模板】\n        纯白无缝背景，横向四栏人物设定板，四栏之间留有清晰空白，不添加文字、尺寸线或装饰边框。左一为头肩特写，人物正面直视镜头。右侧三栏均为从头顶到脚底完整入画、同一尺度的全身视图，依次为严格正视图、严格 90° 侧视图、严格 180° 背视图；镜头正对各自视图平面，不使用三分之四角度。所有视图保持同一人物身份、年龄、体貌、发型、服装、配饰和连续性状态。站姿中立，双脚自然分开，双手自然垂放，手指放松，不持物，不遮挡身体；面部无表情；均匀无方向性棚拍光，白平衡中性，阴影极弱，正交或长焦低畸变，无透视夸张。\n        """,\n        negativeInstruction: "非白背景、环境场景、地面纹理、家具、道具、手持物、文字标签、尺寸线、装饰边框、表情、动态姿势、交叉手臂、手插口袋、三分之四视角、回头、重复视图、缺少视图、裁切头脚、不同服装、不同发型、不同年龄、镜像错误、强烈阴影、戏剧光、透视变形、鱼眼、广角畸变",\n        recommendedAspectRatios: [.landscape16x9, .landscape4x3, .landscape3x2]\n    )\n\n    static let propNeutralPackshot = AssetFormatTemplate(\n        id: "format.prop.neutral-single.v1",\n        kind: .prop,\n        title: "道具 · 中性背景单体展示",\n        summary: "只呈现道具本体，干净中性背景、均匀光照，不出现人物、手部、复杂环境或无关杂物。",\n        positiveInstruction: """\n        【道具格式模板】\n        只呈现该道具本体，使用干净中性背景与均匀光照，不得出现人物、手部、人体局部、复杂环境或无关杂物。完整展示基本资料中有逐字证据的结构、材质、颜色、尺度、状态与识别特征，不增加无证据装饰。\n        """,\n        negativeInstruction: "人物、手部、人体局部、复杂场景、无关杂物、无证据装饰、文字、水印",\n        recommendedAspectRatios: [.square1x1, .landscape4x3, .portrait3x4]\n    )\n\n    static let templates: [AssetFormatTemplate] = [\n        sceneCleanPlate,\n        characterFourView,\n        propNeutralPackshot,\n    ]\n\n    static func template(for kind: ProductionAssetKind) -> AssetFormatTemplate {\n        switch kind {\n        case .scene: sceneCleanPlate\n        case .character: characterFourView\n        case .prop: propNeutralPackshot\n        }\n    }\n}\n\nnonisolated struct EpisodeIndexResolution: Sendable {\n    var scenes: [CanonicalScene]\n    var episodeTitles: [Int: String]\n    var explicitMarkerCount: Int\n    var unresolvedSceneCount: Int\n\n    var episodeCount: Int {\n        Set(scenes.compactMap(\\.episodeNumber)).count\n    }\n}\n\nnonisolated enum EpisodeIndexResolver {\n    static func resolve(\n        scenes: [CanonicalScene],\n        sourceText: String\n    ) -> EpisodeIndexResolution {\n        let units = SourceUnitBuilder.makeUnits(from: sourceText)\n        var currentEpisode = 1\n        var unitEpisodes: [String: Int] = [:]\n        var episodeTitles: [Int: String] = [:]\n        var explicitMarkerCount = 0\n\n        for unit in units {\n            if let marker = episodeMarker(in: unit.text) {\n                currentEpisode = marker.number\n                explicitMarkerCount += 1\n                let title = marker.title\n                    .trimmingCharacters(in: .whitespacesAndNewlines)\n                if !title.isEmpty, episodeTitles[currentEpisode] == nil {\n                    episodeTitles[currentEpisode] = title\n                }\n            }\n            unitEpisodes[unit.id] = currentEpisode\n        }\n\n        var lastEpisode = 1\n        var unresolvedSceneCount = 0\n        let annotated = scenes.sorted { $0.order < $1.order }.map { scene -> CanonicalScene in\n            var scene = scene\n            let candidates = scene.sourceUnitIDs.compactMap { unitEpisodes[$0] }\n            let resolvedEpisode: Int\n            if let candidate = mostFrequent(candidates) {\n                resolvedEpisode = candidate\n            } else if let marker = episodeMarker(in: scene.heading) {\n                resolvedEpisode = marker.number\n                let title = marker.title\n                    .trimmingCharacters(in: .whitespacesAndNewlines)\n                if !title.isEmpty, episodeTitles[resolvedEpisode] == nil {\n                    episodeTitles[resolvedEpisode] = title\n                }\n            } else if let existing = scene.episodeNumber, existing > 0 {\n                resolvedEpisode = existing\n            } else {\n                resolvedEpisode = lastEpisode\n                unresolvedSceneCount += 1\n            }\n            scene.episodeNumber = max(1, resolvedEpisode)\n            scene.episodeTitle = episodeTitles[resolvedEpisode] ?? scene.episodeTitle\n            lastEpisode = max(1, resolvedEpisode)\n            return scene\n        }\n\n        return EpisodeIndexResolution(\n            scenes: annotated,\n            episodeTitles: episodeTitles,\n            explicitMarkerCount: explicitMarkerCount,\n            unresolvedSceneCount: unresolvedSceneCount\n        )\n    }\n\n    static func relink(\n        parsedScenes: [CanonicalScene],\n        previousScenes: [CanonicalScene],\n        sourceText: String\n    ) -> [CanonicalScene] {\n        var usedPreviousIDs = Set<UUID>()\n        var linked = parsedScenes\n        for index in linked.indices {\n            let headingKey = AppleLinguisticAnalyzer.canonicalKey(\n                CanonicalFountainRenderer.normalizedHeading(linked[index].heading)\n            )\n            let sameIndex: CanonicalScene? = {\n                guard previousScenes.indices.contains(index) else { return nil }\n                let candidate = previousScenes[index]\n                let key = AppleLinguisticAnalyzer.canonicalKey(\n                    CanonicalFountainRenderer.normalizedHeading(candidate.heading)\n                )\n                return key == headingKey ? candidate : nil\n            }()\n            let candidate = sameIndex ?? previousScenes.first {\n                !usedPreviousIDs.contains($0.id)\n                    && AppleLinguisticAnalyzer.canonicalKey(\n                        CanonicalFountainRenderer.normalizedHeading($0.heading)\n                    ) == headingKey\n            }\n            guard let candidate else { continue }\n            linked[index].id = candidate.id\n            linked[index].sceneKey = candidate.sceneKey\n            linked[index].sourceUnitIDs = candidate.sourceUnitIDs\n            linked[index].episodeNumber = candidate.episodeNumber\n            linked[index].episodeTitle = candidate.episodeTitle\n            usedPreviousIDs.insert(candidate.id)\n        }\n        return resolve(scenes: linked, sourceText: sourceText).scenes\n    }\n\n    private static func mostFrequent(_ values: [Int]) -> Int? {\n        guard !values.isEmpty else { return nil }\n        let counts = Dictionary(grouping: values, by: { $0 }).mapValues { $0.count }\n        let maximum = counts.values.max() ?? 0\n        return values.first { counts[$0] == maximum }\n    }\n\n    private static func episodeMarker(\n        in rawText: String\n    ) -> (number: Int, title: String)? {\n        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)\n        guard !text.isEmpty else { return nil }\n        let patterns = [\n            #"^\\s*第\\s*([0-9０-９一二三四五六七八九十百千两〇零]+)\\s*(?:集|话|回|章|期)(?:\\s*[-—:：]\\s*(.*))?\\s*$"#,\n            #"(?i)^\\s*(?:EPISODE|EP|E)\\s*[-_:#.]?\\s*([0-9０-９]{1,4})(?:\\s*[-—:：]\\s*(.*))?\\s*$"#,\n            #"^\\s*([0-9０-９]{1,4})\\s*(?:集|话|回|章|期)(?:\\s*[-—:：]\\s*(.*))?\\s*$"#,\n        ]\n        for pattern in patterns {\n            guard let expression = try? NSRegularExpression(pattern: pattern) else {\n                continue\n            }\n            let range = NSRange(text.startIndex..<text.endIndex, in: text)\n            guard let match = expression.firstMatch(in: text, range: range),\n                  let numberRange = Range(match.range(at: 1), in: text),\n                  let number = episodeNumber(from: String(text[numberRange])),\n                  number > 0\n            else { continue }\n            let title: String\n            if match.numberOfRanges > 2,\n               match.range(at: 2).location != NSNotFound,\n               let titleRange = Range(match.range(at: 2), in: text)\n            {\n                title = String(text[titleRange])\n            } else {\n                title = ""\n            }\n            return (number, title)\n        }\n        return nil\n    }\n\n    private static func episodeNumber(from rawValue: String) -> Int? {\n        let normalized = normalizeFullWidthDigits(rawValue)\n        if let numeric = Int(normalized) { return numeric }\n\n        let digits: [Character: Int] = [\n            "零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3,\n            "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9,\n        ]\n        let units: [Character: Int] = ["十": 10, "百": 100, "千": 1_000]\n        var total = 0\n        var current = 0\n        for character in normalized {\n            if let digit = digits[character] {\n                current = digit\n            } else if let unit = units[character] {\n                total += max(1, current) * unit\n                current = 0\n            } else {\n                return nil\n            }\n        }\n        let result = total + current\n        return result > 0 ? result : nil\n    }\n\n    private static func normalizeFullWidthDigits(_ value: String) -> String {\n        var result = ""\n        for scalar in value.unicodeScalars {\n            if (0xFF10...0xFF19).contains(scalar.value),\n               let mapped = UnicodeScalar(scalar.value - 0xFF10 + 0x30)\n            {\n                result.append(Character(String(mapped)))\n            } else {\n                result.append(Character(String(scalar)))\n            }\n        }\n        return result\n    }\n}\n\nnonisolated enum AssetBasicInformationAggregator {\n    static let version = 1\n\n    static func summarize(\n        sourceText: String,\n        scenes: [CanonicalScene],\n        assets: [ProductionAsset]\n    ) -> AssetBasicInformationAggregationResult {\n        let episodeResolution = EpisodeIndexResolver.resolve(\n            scenes: scenes,\n            sourceText: sourceText\n        )\n        let resolvedScenes = episodeResolution.scenes\n        let sceneByID = Dictionary(\n            uniqueKeysWithValues: resolvedScenes.map { ($0.id, $0) }\n        )\n        let updatedAssets = assets.map { asset -> ProductionAsset in\n            var asset = asset\n            asset.basicInformation = profile(\n                for: asset,\n                sceneByID: sceneByID,\n                orderedScenes: resolvedScenes\n            )\n            return asset\n        }\n        let episodeCount = max(\n            1,\n            Set(resolvedScenes.map { $0.episodeNumber ?? 1 }).count\n        )\n        let audit = BasicInformationAudit(\n            version: version,\n            episodeCount: episodeCount,\n            sceneCount: resolvedScenes.count,\n            profileCount: updatedAssets.count { $0.basicInformation != nil },\n            unresolvedSceneCount: episodeResolution.unresolvedSceneCount,\n            sourceFingerprint: SourceUnitBuilder.fingerprint(sourceText),\n            completedAt: .now\n        )\n        return AssetBasicInformationAggregationResult(\n            scenes: resolvedScenes,\n            assets: updatedAssets,\n            audit: audit\n        )\n    }\n\n    private static func profile(\n        for asset: ProductionAsset,\n        sceneByID: [UUID: CanonicalScene],\n        orderedScenes: [CanonicalScene]\n    ) -> AssetBasicInformation {\n        let facts = asset.verifiedDesignFacts\n        let grouped = Dictionary(grouping: facts, by: \\.kind)\n        let factGroups = orderedFactKinds(for: asset.kind).compactMap { kind in\n            let items = grouped[kind] ?? []\n            let values = unique(items.map(\\.value))\n            guard !values.isEmpty else { return nil }\n            return AssetBasicFactGroup(\n                kind: kind,\n                values: values,\n                evidenceCount: items.count\n            )\n        }\n        let availableKinds = Set(factGroups.map(\\.kind))\n        let missing = AssetDesignPromptCompiler.recommendedKinds(for: asset.kind)\n            .filter { !availableKinds.contains($0) }\n\n        var sceneIDs = asset.sourceEvidence.map(\\.sceneID)\n        sceneIDs.append(contentsOf: facts.map(\\.sceneID))\n        let uniqueSceneIDs = uniqueUUIDs(sceneIDs)\n        var referencedScenes = uniqueSceneIDs.compactMap { sceneByID[$0] }\n        if referencedScenes.isEmpty,\n           let fallback = orderedScenes.first(where: {\n               $0.order == asset.firstSceneOrder\n           })\n        {\n            referencedScenes = [fallback]\n        }\n        referencedScenes.sort { $0.order < $1.order }\n\n        let sceneAppearances = referencedScenes.map { scene in\n            let quotes = unique(\n                asset.sourceEvidence\n                    .filter { $0.sceneID == scene.id }\n                    .map(\\.quote)\n                    + facts\n                    .filter { $0.sceneID == scene.id }\n                    .map(\\.evidence)\n            )\n            return AssetSceneAppearance(\n                sceneID: scene.id,\n                sceneOrder: scene.order,\n                sceneHeading: scene.heading,\n                evidenceQuotes: quotes\n            )\n        }\n        let episodeGroups = Dictionary(grouping: sceneAppearances) { appearance in\n            sceneByID[appearance.sceneID]?.episodeNumber ?? 1\n        }\n        let episodeAppearances = episodeGroups.keys.sorted().map { number in\n            let title = (episodeGroups[number] ?? [])\n                .compactMap { sceneByID[$0.sceneID]?.episodeTitle }\n                .first {\n                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty\n                }\n            return AssetEpisodeAppearance(\n                episodeNumber: number,\n                episodeTitle: title,\n                scenes: (episodeGroups[number] ?? []).sorted {\n                    $0.sceneOrder < $1.sceneOrder\n                }\n            )\n        }\n        let factConfidence = facts.isEmpty\n            ? asset.validatedConfidence\n            : facts.map(\\.confidence).reduce(0, +) / Double(facts.count)\n        let sceneCoverage = sceneAppearances.isEmpty ? 0.0 : 1.0\n        let confidence = min(\n            1,\n            asset.validatedConfidence * 0.65\n                + factConfidence * 0.25\n                + sceneCoverage * 0.10\n        )\n        return AssetBasicInformation(\n            assetID: asset.id,\n            kind: asset.kind,\n            canonicalName: asset.canonicalName,\n            aliases: unique(asset.aliases),\n            overview: overview(for: asset, factGroups: factGroups),\n            factGroups: factGroups,\n            continuityState: asset.continuityState,\n            missingFactKinds: missing,\n            episodeAppearances: episodeAppearances,\n            sceneCount: sceneAppearances.count,\n            sourceEvidenceCount: unique(asset.sourceEvidence.map(\\.quote)).count,\n            aggregationConfidence: confidence,\n            aggregationVersion: version,\n            generatedAt: .now\n        )\n    }\n\n    private static func overview(\n        for asset: ProductionAsset,\n        factGroups: [AssetBasicFactGroup]\n    ) -> String {\n        let details = factGroups.prefix(6).map {\n            "\\($0.kind.title)：\\($0.values.joined(separator: "；"))"\n        }\n        let fallback = asset.summary\n            .trimmingCharacters(in: .whitespacesAndNewlines)\n        let body = details.isEmpty ? fallback : details.joined(separator: "；")\n        return body.isEmpty\n            ? "\\(asset.kind.rawValue)“\\(asset.canonicalName)”的证据锁定基础资料。"\n            : "\\(asset.kind.rawValue)“\\(asset.canonicalName)”：\\(body)"\n    }\n\n    private static func orderedFactKinds(\n        for kind: ProductionAssetKind\n    ) -> [AssetDesignFactKind] {\n        switch kind {\n        case .scene:\n            [\n                .functionalPurpose, .environmentType, .spatialLayout, .architecture,\n                .timeWeather, .eraCulture, .material, .colorPattern, .lighting,\n                .distinctiveFeature, .relationship,\n            ]\n        case .character:\n            [\n                .ageRange, .genderPresentation, .identityRole, .physique, .faceHair,\n                .costume, .accessory, .characterState, .eraCulture, .colorPattern,\n                .distinctiveFeature, .relationship,\n            ]\n        case .prop:\n            [\n                .objectType, .objectFunction, .quantityScale, .material, .colorPattern,\n                .condition, .eraCulture, .distinctiveFeature, .relationship,\n            ]\n        }\n    }\n\n    private static func unique(_ values: [String]) -> [String] {\n        var seen = Set<String>()\n        return values.compactMap { value in\n            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)\n            guard !clean.isEmpty else { return nil }\n            let key = AppleLinguisticAnalyzer.canonicalKey(clean)\n            return seen.insert(key).inserted ? clean : nil\n        }\n    }\n\n    private static func uniqueUUIDs(_ values: [UUID]) -> [UUID] {\n        var seen = Set<UUID>()\n        return values.filter { seen.insert($0).inserted }\n    }\n}\n\nnonisolated extension ProductionAsset {\n    var basicInformationPrompt: String {\n        basicInformation?.promptText ?? designPrompt\n    }\n\n    var episodeAppearanceSummary: String {\n        basicInformation?.episodeSummary ?? "集数待汇总"\n    }\n}\n'
FORMAT_VIEW_SWIFT = 'import SwiftUI\n\nstruct FormatTemplateLibraryWorkspace: View {\n    @State private var selectedKind: ProductionAssetKind? = .scene\n\n    private var selectedTemplate: AssetFormatTemplate {\n        AssetFormatTemplateCatalog.template(for: selectedKind ?? .scene)\n    }\n\n    var body: some View {\n        VStack(spacing: 0) {\n            header\n            Divider()\n            HSplitView {\n                List(ProductionAssetKind.allCases, selection: $selectedKind) { kind in\n                    VStack(alignment: .leading, spacing: 4) {\n                        Label(\n                            AssetFormatTemplateCatalog.template(for: kind).title,\n                            systemImage: kind.systemImage\n                        )\n                        .font(.headline)\n                        Text(AssetFormatTemplateCatalog.template(for: kind).summary)\n                            .font(.caption)\n                            .foregroundStyle(.secondary)\n                            .lineLimit(3)\n                    }\n                    .padding(.vertical, 6)\n                    .tag(kind)\n                }\n                .frame(minWidth: 280, idealWidth: 340)\n\n                templateDetail(selectedTemplate)\n                    .id(selectedTemplate.id)\n            }\n        }\n    }\n\n    private var header: some View {\n        HStack {\n            VStack(alignment: .leading, spacing: 4) {\n                Text("格式模板")\n                    .font(.system(.largeTitle, design: .rounded, weight: .bold))\n                Text("第三部分：按场景、人物、道具分别锁定交付版式；模板不属于风格图书馆，也不能被风格覆盖。")\n                    .foregroundStyle(.secondary)\n            }\n            Spacer()\n            Label("系统保护", systemImage: "lock.shield")\n                .font(.caption.weight(.semibold))\n                .padding(9)\n                .background(.green.opacity(0.10), in: Capsule())\n        }\n        .padding(22)\n    }\n\n    private func templateDetail(_ template: AssetFormatTemplate) -> some View {\n        ScrollView {\n            VStack(alignment: .leading, spacing: 18) {\n                HStack(alignment: .top) {\n                    VStack(alignment: .leading, spacing: 5) {\n                        Text(template.kind.rawValue)\n                            .font(.caption.weight(.bold))\n                            .foregroundStyle(.secondary)\n                        Text(template.title)\n                            .font(.system(.title, design: .rounded, weight: .bold))\n                        Text(template.summary)\n                            .foregroundStyle(.secondary)\n                    }\n                    Spacer()\n                    Text(template.id)\n                        .font(.caption2.monospaced())\n                        .foregroundStyle(.secondary)\n                        .textSelection(.enabled)\n                }\n\n                templateField("强制正向要求", value: template.positiveInstruction)\n                templateField("强制排除项", value: template.negativeInstruction)\n\n                VStack(alignment: .leading, spacing: 8) {\n                    Text("推荐画幅")\n                        .font(.headline)\n                    HStack(spacing: 8) {\n                        ForEach(template.recommendedAspectRatios) { ratio in\n                            Text(ratio.title)\n                                .font(.caption.weight(.semibold))\n                                .padding(.horizontal, 10)\n                                .padding(.vertical, 6)\n                                .background(.blue.opacity(0.08), in: Capsule())\n                        }\n                    }\n                }\n\n                Label(\n                    "最终提示词固定按“基本资料 → 用户风格 → 格式模板”拼装。格式模板拥有交付优先级，用户风格只改变视觉表现。",\n                    systemImage: "square.stack.3d.up.fill"\n                )\n                .font(.callout)\n                .padding(14)\n                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))\n            }\n            .padding(24)\n            .frame(maxWidth: 900)\n            .frame(maxWidth: .infinity)\n        }\n    }\n\n    private func templateField(_ title: String, value: String) -> some View {\n        VStack(alignment: .leading, spacing: 7) {\n            Text(title)\n                .font(.headline)\n            Text(value)\n                .textSelection(.enabled)\n                .frame(maxWidth: .infinity, alignment: .topLeading)\n                .padding(12)\n                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))\n        }\n    }\n}\n\nstruct AssetBasicInformationPanel: View {\n    let information: AssetBasicInformation\n\n    var body: some View {\n        VStack(alignment: .leading, spacing: 14) {\n            HStack {\n                Label("第一部分 · 基本资料汇总", systemImage: "doc.text.magnifyingglass")\n                    .font(.headline)\n                Spacer()\n                Text(\n                    information.aggregationConfidence,\n                    format: .percent.precision(.fractionLength(0))\n                )\n                .font(.caption.monospacedDigit().weight(.semibold))\n                .foregroundStyle(.secondary)\n            }\n\n            Text(information.overview)\n                .textSelection(.enabled)\n\n            VStack(alignment: .leading, spacing: 7) {\n                Text("出现集数")\n                    .font(.caption.weight(.semibold))\n                    .foregroundStyle(.secondary)\n                Text(information.episodeSummary)\n                    .font(.title3.weight(.semibold))\n                    .textSelection(.enabled)\n            }\n\n            ForEach(information.episodeAppearances) { episode in\n                VStack(alignment: .leading, spacing: 7) {\n                    Text(episode.label)\n                        .font(.callout.weight(.semibold))\n                    ForEach(episode.scenes) { scene in\n                        VStack(alignment: .leading, spacing: 3) {\n                            Text("场 \\(scene.sceneOrder + 1) · \\(scene.sceneHeading)")\n                                .font(.caption.weight(.semibold))\n                            if !scene.evidenceQuotes.isEmpty {\n                                Text(scene.evidenceQuotes.prefix(3).joined(separator: "；"))\n                                    .font(.caption)\n                                    .foregroundStyle(.secondary)\n                                    .lineLimit(3)\n                                    .textSelection(.enabled)\n                            }\n                        }\n                        .padding(.leading, 10)\n                    }\n                }\n                .padding(11)\n                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))\n            }\n\n            if !information.factGroups.isEmpty {\n                VStack(alignment: .leading, spacing: 8) {\n                    Text("全剧汇总后的关键特征")\n                        .font(.caption.weight(.semibold))\n                        .foregroundStyle(.secondary)\n                    ForEach(information.factGroups) { group in\n                        HStack(alignment: .top, spacing: 10) {\n                            Text(group.kind.title)\n                                .font(.caption.weight(.semibold))\n                                .frame(width: 96, alignment: .leading)\n                            Text(group.values.joined(separator: "；"))\n                                .font(.callout)\n                                .textSelection(.enabled)\n                            Spacer(minLength: 0)\n                        }\n                    }\n                }\n            }\n        }\n        .padding(16)\n        .background(.blue.opacity(0.065), in: RoundedRectangle(cornerRadius: 14))\n    }\n}\n'
PROMPT_FRESHNESS_SWIFT = 'import Foundation\n\nnonisolated extension ArtPromptPlan {\n    func requiresRebuild(\n        for asset: ProductionAsset,\n        styleCards: [StylePromptCard],\n        mode expectedMode: ImageGenerationMode\n    ) -> Bool {\n        let expectedStyleTreatment = StyleOnlyPromptPolicy.subjectNeutralEnvelope(\n            styleCards.map {\n                StyleOnlyPromptPolicy.safeStyleFragment(\n                    $0.prompt,\n                    category: $0.category\n                )\n            }\n        )\n        let expectedBasicInformation = asset.basicInformationPrompt\n        let expectedTemplate = AssetFormatTemplateCatalog.template(for: asset.kind)\n        let storedBasicInformation = basicInformationPrompt ?? assetDesignPrompt\n        return positivePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty\n            || mode != expectedMode\n            || chosenStyleCardIDs != styleCards.map(\\.id)\n            || storedBasicInformation != expectedBasicInformation\n            || styleTreatmentPrompt != expectedStyleTreatment\n            || formatTemplateID != expectedTemplate.id\n            || formatTemplatePrompt != expectedTemplate.positiveInstruction\n    }\n}\n'
DOC_V8 = '# 三层生产架构与基础资料汇总 V8\n\n## 三个彼此独立的数据层\n\n最终生图提示词不再把主体、风格和版式混在同一段文字里，而是固定拆成：\n\n```text\n第一部分：基本资料\n+\n第二部分：用户从风格图书馆明确选择的纯视觉风格\n+\n第三部分：按场景 / 人物 / 道具确定的格式模板\n```\n\n优先级为：\n\n```text\n剧本证据与基本资料 > 格式模板 > 用户补充操作 > 视觉风格\n```\n\n视觉风格只能改变媒介、渲染、色彩、光线处理、镜头语言、线条、质感和氛围，不能新增或替换具体人物、场景、道具及其特征。\n\n## 第一部分：基本资料\n\n基础资料来自一条可追溯流水线：\n\n```text\n任意剧本文本\n    ↓ SourceUnit 全覆盖\n标准 Final Draft / Fountain\n    ↓ 逐场提取\n场景 / 人物 / 道具候选\n    ↓ 独立裁决、逐字证据、连续性与身份核验\n生产资产\n    ↓ 第二轮全剧汇总\n基础资料档案 + 分集出现索引\n```\n\n第二轮汇总不允许自由补写。它只对已经通过核验的事实执行确定性聚合：\n\n- 规范名称与明确别名；\n- 场景功能、空间、建筑、时间、材质和光源；\n- 人物年龄、性别呈现、身份、体貌、发型、服装、配饰和状态；\n- 道具类别、用途、数量、尺度、材质、颜色、损坏和时代信息；\n- 连续性状态；\n- 出现集数；\n- 每一集中的场次、场景标题和对应逐字证据；\n- 未被剧本说明、因此禁止臆造的字段。\n\n## 分集识别\n\n系统从原始剧本的 SourceUnit 中识别以下保守标记：\n\n- `第1集`、`第十二集：标题`；\n- `第2话`、`第3回`、`第4章`；\n- `EP 5`、`Episode 6 - Title`；\n- `7集`。\n\n场景继续保留 SourceUnit 关联，因此即使先转换成 Final Draft，也能回溯到原始分集。没有明确分集标记的剧本按第 1 集处理；无法重新关联的场景会记入汇总审计，但不会阻塞其余资产。\n\n## 第二部分：风格图书馆\n\n风格图书馆继续只保存主体中立的视觉风格：\n\n- 媒介与渲染；\n- 色彩体系；\n- 光线处理；\n- 构图与镜头语言；\n- 线条和表面质感；\n- 整体氛围。\n\n风格由用户明确选择。样板图只用于理解风格，不作为主体内容来源。\n\n## 第三部分：格式模板\n\n系统提供三张受保护的格式模板：\n\n### 场景\n\n无人、无人影、无动物、无无关杂物；只保留基本资料中有剧本证据的空间结构、固定陈设、必要道具和空间关系。\n\n### 人物\n\n纯白无缝背景四栏设定板：左一头肩特写，右侧依次为全身严格正面、严格 90° 侧面和严格 180° 背面。中立站姿、双手自然垂放、无表情、均匀光照。\n\n### 道具\n\n只呈现道具本体，干净中性背景、均匀光照，不出现人物、手部、复杂环境或无关杂物。\n\n格式模板与风格图书馆分别存储。用户风格不能覆盖格式模板。\n\n## 数据与兼容性\n\n- Workspace schema：V8；\n- `CanonicalScene` 保存可选 `episodeNumber` 和 `episodeTitle`；\n- `ProductionAsset` 保存可选 `AssetBasicInformation`；\n- `ArtDepartmentProject` 保存 `BasicInformationAudit`；\n- V7 及更早项目在加载时会从现有场景、资产和证据确定性补建基础资料；\n- 旧生图记录可继续读取；缺少三层元数据的旧提示词计划会自动失效并重新编译。\n'
NEW_TESTS = '\n    func testEpisodeIndexResolverAnnotatesEpisodeMarkers() {\n        let source = """\n        第1集：初见\n\n        内. 厨房 - 日\n\n        小雨推开窗户。\n\n        EP 2 - 追踪\n\n        外. 街道 - 夜\n\n        小雨追着出租车跑。\n        """\n        let first = CanonicalScene(\n            order: 0,\n            heading: "内. 厨房 - 日",\n            sceneKey: "scene-1",\n            paragraphs: [\n                CanonicalParagraph(\n                    element: .action,\n                    text: "小雨推开窗户。",\n                    sourceUnitIDs: ["U000003"]\n                )\n            ],\n            sourceUnitIDs: ["U000002", "U000003"]\n        )\n        let second = CanonicalScene(\n            order: 1,\n            heading: "外. 街道 - 夜",\n            sceneKey: "scene-2",\n            paragraphs: [\n                CanonicalParagraph(\n                    element: .action,\n                    text: "小雨追着出租车跑。",\n                    sourceUnitIDs: ["U000006"]\n                )\n            ],\n            sourceUnitIDs: ["U000005", "U000006"]\n        )\n\n        let result = EpisodeIndexResolver.resolve(\n            scenes: [first, second],\n            sourceText: source\n        )\n\n        XCTAssertEqual(result.scenes.map(\\.episodeNumber), [1, 2])\n        XCTAssertEqual(result.scenes.first?.episodeTitle, "初见")\n        XCTAssertEqual(result.scenes.last?.episodeTitle, "追踪")\n        XCTAssertEqual(result.episodeCount, 2)\n    }\n\n    func testBasicInformationAggregationSummarizesEpisodeAppearances() throws {\n        let firstSceneID = UUID()\n        let secondSceneID = UUID()\n        let scenes = [\n            CanonicalScene(\n                id: firstSceneID,\n                order: 0,\n                heading: "内. 教室 - 日",\n                sceneKey: "scene-1",\n                paragraphs: [],\n                sourceUnitIDs: [],\n                episodeNumber: 1,\n                episodeTitle: "入学"\n            ),\n            CanonicalScene(\n                id: secondSceneID,\n                order: 1,\n                heading: "外. 操场 - 日",\n                sceneKey: "scene-2",\n                paragraphs: [],\n                sourceUnitIDs: [],\n                episodeNumber: 3,\n                episodeTitle: "比赛"\n            ),\n        ]\n        let asset = ProductionAsset(\n            kind: .character,\n            canonicalName: "小雨",\n            aliases: ["林小雨"],\n            summary: "学生",\n            visualDescription: "17 岁，穿旧校服",\n            designFacts: [\n                AssetDesignFact(\n                    kind: .ageRange,\n                    value: "17 岁",\n                    evidence: "十七岁的小雨",\n                    sceneID: firstSceneID,\n                    sceneHeading: "内. 教室 - 日"\n                ),\n                AssetDesignFact(\n                    kind: .identityRole,\n                    value: "高中生",\n                    evidence: "高中生小雨",\n                    sceneID: firstSceneID,\n                    sceneHeading: "内. 教室 - 日"\n                ),\n                AssetDesignFact(\n                    kind: .costume,\n                    value: "洗得发白的旧校服",\n                    evidence: "洗得发白的旧校服",\n                    sceneID: secondSceneID,\n                    sceneHeading: "外. 操场 - 日"\n                ),\n            ],\n            sourceEvidence: [\n                EvidenceQuote(\n                    sceneID: firstSceneID,\n                    sceneHeading: "内. 教室 - 日",\n                    quote: "十七岁的高中生小雨",\n                    explanation: "身份与年龄"\n                ),\n                EvidenceQuote(\n                    sceneID: secondSceneID,\n                    sceneHeading: "外. 操场 - 日",\n                    quote: "小雨穿着洗得发白的旧校服",\n                    explanation: "服装"\n                ),\n            ],\n            modelConfidence: 1,\n            validatedConfidence: 1,\n            reviewDecision: .accepted,\n            firstSceneOrder: 0\n        )\n\n        let result = AssetBasicInformationAggregator.summarize(\n            sourceText: "",\n            scenes: scenes,\n            assets: [asset]\n        )\n        let information = try XCTUnwrap(result.assets.first?.basicInformation)\n\n        XCTAssertEqual(information.episodeNumbers, [1, 3])\n        XCTAssertEqual(information.sceneCount, 2)\n        XCTAssertTrue(information.promptText.contains("17 岁"))\n        XCTAssertTrue(information.promptText.contains("旧校服"))\n        XCTAssertEqual(result.audit.episodeCount, 2)\n        XCTAssertTrue(result.audit.isComplete)\n    }\n\n    func testThreeLayerPromptKeepsBasicStyleAndFormatSeparate() {\n        let sceneID = UUID()\n        var asset = ProductionAsset(\n            kind: .character,\n            canonicalName: "小雨",\n            summary: "学生",\n            visualDescription: "17 岁，穿旧校服",\n            designFacts: [\n                AssetDesignFact(\n                    kind: .identityRole,\n                    value: "高中生",\n                    evidence: "高中生小雨",\n                    sceneID: sceneID,\n                    sceneHeading: "内. 教室 - 日"\n                ),\n                AssetDesignFact(\n                    kind: .ageRange,\n                    value: "17 岁",\n                    evidence: "十七岁的小雨",\n                    sceneID: sceneID,\n                    sceneHeading: "内. 教室 - 日"\n                ),\n                AssetDesignFact(\n                    kind: .costume,\n                    value: "旧校服",\n                    evidence: "穿着旧校服",\n                    sceneID: sceneID,\n                    sceneHeading: "内. 教室 - 日"\n                ),\n            ],\n            sourceEvidence: [\n                EvidenceQuote(\n                    sceneID: sceneID,\n                    sceneHeading: "内. 教室 - 日",\n                    quote: "十七岁的高中生小雨穿着旧校服",\n                    explanation: "人物基本资料"\n                )\n            ],\n            modelConfidence: 1,\n            validatedConfidence: 1,\n            reviewDecision: .accepted,\n            firstSceneOrder: 0\n        )\n        let scene = CanonicalScene(\n            id: sceneID,\n            order: 0,\n            heading: "内. 教室 - 日",\n            sceneKey: "scene-1",\n            paragraphs: [],\n            sourceUnitIDs: [],\n            episodeNumber: 1\n        )\n        asset = AssetBasicInformationAggregator.summarize(\n            sourceText: "",\n            scenes: [scene],\n            assets: [asset]\n        ).assets[0]\n        let style = StylePromptCard(\n            title: "冷色写实",\n            prompt: "电影级写实摄影，低饱和冷色体系，均匀漫射光。",\n            category: .general\n        )\n\n        let plan = ArtDepartmentV2Pipeline.fallbackPromptPlan(\n            asset: asset,\n            styleCards: [style],\n            mode: .textToImage,\n            direction: ""\n        )\n\n        XCTAssertTrue(plan.positivePrompt.contains("【第一部分：基本资料】"))\n        XCTAssertTrue(plan.positivePrompt.contains("【第二部分：视觉风格】"))\n        XCTAssertTrue(plan.positivePrompt.contains("【第三部分：格式模板】"))\n        XCTAssertTrue(plan.basicInformationPrompt?.contains("17 岁") == true)\n        XCTAssertTrue(plan.styleTreatmentPrompt?.contains("低饱和冷色") == true)\n        XCTAssertEqual(\n            plan.formatTemplateID,\n            AssetFormatTemplateCatalog.characterFourView.id\n        )\n        XCTAssertTrue(plan.formatTemplatePrompt?.contains("纯白无缝背景") == true)\n        XCTAssertFalse(plan.basicInformationPrompt?.contains("低饱和冷色") == true)\n    }\n\n    func testFormatTemplateCatalogSeparatesAssetRequirements() {\n        let scene = AssetFormatTemplateCatalog.template(for: .scene)\n        let character = AssetFormatTemplateCatalog.template(for: .character)\n        let prop = AssetFormatTemplateCatalog.template(for: .prop)\n\n        XCTAssertEqual(AssetFormatTemplateCatalog.templates.count, 3)\n        XCTAssertTrue(scene.negativeInstruction.contains("人物"))\n        XCTAssertTrue(scene.negativeInstruction.contains("杂物"))\n        XCTAssertTrue(character.positiveInstruction.contains("头肩特写"))\n        XCTAssertTrue(character.positiveInstruction.contains("严格 180° 背视图"))\n        XCTAssertTrue(prop.positiveInstruction.contains("只呈现该道具本体"))\n        XCTAssertNotEqual(scene.id, character.id)\n        XCTAssertNotEqual(character.id, prop.id)\n    }\n'
PIPELINE_PROMPT_FUNCTIONS = '    static func makePromptPlan(\n        asset: ProductionAsset,\n        styleCards: [StylePromptCard],\n        mode: ImageGenerationMode,\n        direction: String,\n        client: ArtChatCompletionClient?\n    ) async throws -> ArtPromptPlan {\n        _ = client\n        guard AssetDesignReadiness.isReady(asset) else {\n            throw ArtDepartmentV2Error.invalidModelResponse(\n                AssetDesignReadiness.missingReason(asset)\n            )\n        }\n        let basicInformation = asset.basicInformationPrompt\n        let styleTreatment = StyleOnlyPromptPolicy.subjectNeutralEnvelope(\n            styleCards.map {\n                StyleOnlyPromptPolicy.safeStyleFragment(\n                    $0.prompt,\n                    category: $0.category\n                )\n            }\n        )\n        guard !styleTreatment.isEmpty else {\n            throw ArtDepartmentV2Error.noSelectedStyle\n        }\n        let formatTemplate = AssetFormatTemplateCatalog.template(for: asset.kind)\n        let operation = [\n            modeInstruction(mode),\n            direction,\n        ]\n        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }\n        .filter { !$0.isEmpty }\n        .joined(separator: "\\n")\n        let positive = """\n        【第一部分：基本资料】\n        \\(basicInformation)\n\n        【第二部分：视觉风格】\n        \\(styleTreatment)\n\n        【第三部分：格式模板】\n        \\(formatTemplate.positiveInstruction)\n\n        【本轮生成操作】\n        \\(operation)\n        """\n        let negative = uniqueText([\n            "不得从风格提示词或风格样板复制任何具体人物、场景、道具、服装、动作、数量、时代或空间关系；不得补全基本资料未明确的年龄、性别、体貌、材质、颜色和损坏状态；不得改变锁定身份与连续性；用户补充要求不得覆盖格式模板；避免文字、水印、畸形肢体和重复主体。",\n            formatTemplate.negativeInstruction,\n        ])\n        .joined(separator: "；")\n        let facts = asset.verifiedDesignFacts.map(\\.value)\n        return ArtPromptPlan(\n            title: "\\(asset.canonicalName) · \\(mode.rawValue)",\n            mode: mode,\n            subject: basicInformation,\n            materials: asset.materialNotes,\n            composition: asset.compositionNotes,\n            elements: asset.elementNotes,\n            lighting: asset.verifiedDesignFacts\n                .filter { $0.kind == .lighting }\n                .map(\\.value)\n                .joined(separator: "；"),\n            positivePrompt: positive,\n            negativePrompt: negative,\n            lockedFacts: uniqueText(\n                [asset.canonicalName, asset.continuityState]\n                    + facts\n                    + asset.sourceEvidence.prefix(12).map(\\.quote)\n            ),\n            chosenStyleCardIDs: styleCards.map(\\.id),\n            rationale: "三层确定性编译：基本资料提供主体事实，用户风格只提供视觉处理，格式模板锁定交付版式。",\n            assetDesignPrompt: basicInformation,\n            styleTreatmentPrompt: styleTreatment,\n            basicInformationPrompt: basicInformation,\n            formatTemplatePrompt: formatTemplate.positiveInstruction,\n            formatTemplateID: formatTemplate.id\n        )\n    }\n\n    static func fallbackPromptPlan(\n        asset: ProductionAsset,\n        styleCards: [StylePromptCard],\n        mode: ImageGenerationMode,\n        direction: String\n    ) -> ArtPromptPlan {\n        let basicInformation = asset.basicInformationPrompt\n        let styleTreatment = StyleOnlyPromptPolicy.subjectNeutralEnvelope(\n            styleCards.map {\n                StyleOnlyPromptPolicy.safeStyleFragment(\n                    $0.prompt,\n                    category: $0.category\n                )\n            }\n        )\n        let formatTemplate = AssetFormatTemplateCatalog.template(for: asset.kind)\n        let positive = [\n            "【第一部分：基本资料】\\n\\(basicInformation)",\n            "【第二部分：视觉风格】\\n\\(styleTreatment)",\n            "【第三部分：格式模板】\\n\\(formatTemplate.positiveInstruction)",\n            "【本轮生成操作】\\n\\(modeInstruction(mode))\\n\\(direction)",\n        ]\n        .joined(separator: "\\n\\n")\n        return ArtPromptPlan(\n            title: "\\(asset.canonicalName) · \\(mode.rawValue)",\n            mode: mode,\n            subject: basicInformation,\n            materials: asset.materialNotes,\n            composition: asset.compositionNotes,\n            elements: asset.elementNotes,\n            lighting: "",\n            positivePrompt: positive,\n            negativePrompt: uniqueText([\n                "风格不得提供主体内容；不得臆造基本资料未明确的事实；用户补充要求不得覆盖格式模板；避免文字、水印、畸形肢体和重复主体。",\n                formatTemplate.negativeInstruction,\n            ]).joined(separator: "；"),\n            lockedFacts: uniqueText(\n                [asset.canonicalName, asset.continuityState]\n                    + asset.verifiedDesignFacts.map(\\.value)\n                    + asset.sourceEvidence.prefix(12).map(\\.quote)\n            ),\n            chosenStyleCardIDs: styleCards.map(\\.id),\n            rationale: "本地三层确定性编译器。",\n            assetDesignPrompt: basicInformation,\n            styleTreatmentPrompt: styleTreatment,\n            basicInformationPrompt: basicInformation,\n            formatTemplatePrompt: formatTemplate.positiveInstruction,\n            formatTemplateID: formatTemplate.id\n        )\n    }\n\n'
APPLE_PROMPT_METHOD = '    func makePromptPlan(\n        asset: ProductionAsset,\n        styleCards: [StylePromptCard],\n        mode: ImageGenerationMode,\n        direction: String,\n        remote: ArtChatCompletionClient?\n    ) async throws -> AppleSchemaPromptPlan {\n        let basicInformation = asset.basicInformationPrompt\n        let styleTreatment = StyleOnlyPromptPolicy.subjectNeutralEnvelope(\n            styleCards.map {\n                StyleOnlyPromptPolicy.safeStyleFragment(\n                    $0.prompt,\n                    category: $0.category\n                )\n            }\n        )\n        let formatTemplate = AssetFormatTemplateCatalog.template(for: asset.kind)\n        let instructions = """\n        You are a film art director checking a strict three-layer image-generation plan.\n        BASIC INFORMATION is the only source of concrete people, places, props, age, gender, clothing, materials, spatial relationships, period and continuity.\n        VISUAL STYLE may control only medium, rendering, palette, lighting treatment, composition treatment, lens language, line quality, texture and atmosphere.\n        FORMAT TEMPLATE controls the mandatory delivery layout for the selected asset kind and cannot be weakened by style or user direction.\n        Never copy a person, setting, object, garment, action or narrative element from a style prompt or style sample into basic information.\n        Unknown traits must remain unspecified. Keep all three layers separate in the returned schema.\n        """\n        let prompt = """\n        BASIC_INFORMATION:\n        \\(basicInformation)\n\n        VISUAL_STYLE:\n        \\(styleTreatment)\n\n        FORMAT_TEMPLATE_ID: \\(formatTemplate.id)\n        FORMAT_TEMPLATE:\n        \\(formatTemplate.positiveInstruction)\n\n        GENERATION_MODE: \\(mode.rawValue)\n        USER_DIRECTION: \\(direction)\n        """\n\n        if canUseOnDeviceGeneral {\n            return try await localGenerate(\n                model: generalModel,\n                instructions: instructions,\n                prompt: prompt,\n                generating: AppleSchemaPromptPlan.self\n            )\n        }\n        if let remote {\n            return try await remote.complete(\n                instructions: instructions,\n                prompt: prompt,\n                generating: AppleSchemaPromptPlan.self,\n                maximumTokens: 4_000,\n                temperature: 0.02\n            )\n        }\n        throw ArtDepartmentV2Error.missingLLMConfiguration\n    }\n\n'
PROMPT_READONLY_VIEW = 'private struct PromptReadOnlyField: View {\n    let title: String\n    let text: String\n\n    var body: some View {\n        VStack(alignment: .leading, spacing: 5) {\n            Text(title)\n                .font(.caption.weight(.semibold))\n                .foregroundStyle(.secondary)\n            Text(text.isEmpty ? "—" : text)\n                .textSelection(.enabled)\n                .frame(maxWidth: .infinity, alignment: .topLeading)\n                .padding(9)\n                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))\n        }\n        .frame(maxWidth: .infinity, alignment: .topLeading)\n    }\n}\n\n'


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content.rstrip() + "\n", encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


def replace_between(
    text: str,
    start: str,
    end: str,
    replacement: str,
    label: str,
) -> str:
    start_index = text.find(start)
    if start_index < 0:
        raise RuntimeError(f"{label}: start anchor missing")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise RuntimeError(f"{label}: end anchor missing")
    return text[:start_index] + replacement + text[end_index:]


def patch_models() -> None:
    path = "美术台/Models/ArtDepartmentV2Models.swift"
    text = read(path)

    text = replace_once(
        text,
        '''    case script = "剧本标准化"
    case assets = "自动资产库"
    case styles = "风格提示词库"
    case generation = "生图工坊"
''',
        '''    case script = "剧本标准化"
    case assets = "基本资料库"
    case styles = "风格提示词库"
    case templates = "格式模板"
    case generation = "生图工坊"
''',
        "workspace sections",
    )
    text = replace_once(
        text,
        '''        case .script: "doc.text.magnifyingglass"
        case .assets: "shippingbox.fill"
        case .styles: "photo.on.rectangle.angled"
        case .generation: "wand.and.stars.inverse"
''',
        '''        case .script: "doc.text.magnifyingglass"
        case .assets: "shippingbox.fill"
        case .styles: "photo.on.rectangle.angled"
        case .templates: "rectangle.3.group.bubble"
        case .generation: "wand.and.stars.inverse"
''',
        "workspace icons",
    )

    text = replace_once(
        text,
        '''    case extracting = "提取中"
    case adjudicating = "自动核验中"
    case reviewing = "等待审阅" // Legacy V2 value; normalized to adjudicating on load.
    case completed = "资产已确认"
''',
        '''    case extracting = "提取中"
    case adjudicating = "自动核验中"
    case summarizing = "基础资料汇总中"
    case reviewing = "等待审阅" // Legacy V2 value; normalized to adjudicating on load.
    case completed = "资产已确认"
''',
        "pipeline summarizing stage",
    )
    text = replace_once(
        text,
        '''        case .reviewing, .adjudicating: "自动核验中"
        case .completed: "资产已就绪"
''',
        '''        case .reviewing, .adjudicating: "自动核验中"
        case .summarizing: "基础资料汇总中"
        case .completed: "基本资料已就绪"
''',
        "pipeline stage titles",
    )

    text = replace_once(
        text,
        '''    var paragraphs: [CanonicalParagraph]
    var sourceUnitIDs: [String]

    init(
''',
        '''    var paragraphs: [CanonicalParagraph]
    var sourceUnitIDs: [String]
    var episodeNumber: Int?
    var episodeTitle: String?

    init(
''',
        "canonical scene episode fields",
    )
    text = replace_once(
        text,
        '''        sceneKey: String,
        paragraphs: [CanonicalParagraph],
        sourceUnitIDs: [String]
    ) {
''',
        '''        sceneKey: String,
        paragraphs: [CanonicalParagraph],
        sourceUnitIDs: [String],
        episodeNumber: Int? = nil,
        episodeTitle: String? = nil
    ) {
''',
        "canonical scene initializer",
    )
    text = replace_once(
        text,
        '''        self.paragraphs = paragraphs
        self.sourceUnitIDs = sourceUnitIDs
    }
''',
        '''        self.paragraphs = paragraphs
        self.sourceUnitIDs = sourceUnitIDs
        self.episodeNumber = episodeNumber
        self.episodeTitle = episodeTitle
    }
''',
        "canonical scene assignments",
    )

    delivery_wrapper = '''nonisolated enum AssetDeliveryStandard {
    static func template(for kind: ProductionAssetKind) -> AssetFormatTemplate {
        AssetFormatTemplateCatalog.template(for: kind)
    }

    static func summary(for kind: ProductionAssetKind) -> String {
        template(for: kind).summary
    }

    static func positiveInstruction(for kind: ProductionAssetKind) -> String {
        template(for: kind).positiveInstruction
    }

    static func negativeInstruction(for kind: ProductionAssetKind) -> String {
        template(for: kind).negativeInstruction
    }
}
'''
    text = replace_between(
        text,
        "nonisolated enum AssetDeliveryStandard {",
        "\n\n/// Raw values preserve V2 decoding.",
        delivery_wrapper,
        "delivery standard wrapper",
    )

    text = replace_once(
        text,
        '''    var identityFingerprint: String?
    var continuityVariantKey: String?

    init(
''',
        '''    var identityFingerprint: String?
    var continuityVariantKey: String?
    var basicInformation: AssetBasicInformation?

    init(
''',
        "asset basic information field",
    )
    text = replace_once(
        text,
        '''        independentVerdictCount: Int? = nil,
        identityFingerprint: String? = nil,
        continuityVariantKey: String? = nil
    ) {
''',
        '''        independentVerdictCount: Int? = nil,
        identityFingerprint: String? = nil,
        continuityVariantKey: String? = nil,
        basicInformation: AssetBasicInformation? = nil
    ) {
''',
        "asset initializer basic information",
    )
    text = replace_once(
        text,
        '''        self.independentVerdictCount = independentVerdictCount
        self.identityFingerprint = identityFingerprint
        self.continuityVariantKey = continuityVariantKey
    }
''',
        '''        self.independentVerdictCount = independentVerdictCount
        self.identityFingerprint = identityFingerprint
        self.continuityVariantKey = continuityVariantKey
        self.basicInformation = basicInformation
    }
''',
        "asset basic information assignment",
    )

    text = replace_once(
        text,
        '''    var rationale: String
    var assetDesignPrompt: String? = nil
    var styleTreatmentPrompt: String? = nil
''',
        '''    var rationale: String
    var assetDesignPrompt: String? = nil
    var styleTreatmentPrompt: String? = nil
    var basicInformationPrompt: String? = nil
    var formatTemplatePrompt: String? = nil
    var formatTemplateID: String? = nil
''',
        "prompt plan three layer metadata",
    )

    text = replace_once(
        text,
        '''    var automationSummary: AssetAutomationSummary?
    var engineStatus: AppleEngineStatusSnapshot?
    var reliabilityAudit: AssetReliabilityAudit?

    init(
''',
        '''    var automationSummary: AssetAutomationSummary?
    var engineStatus: AppleEngineStatusSnapshot?
    var reliabilityAudit: AssetReliabilityAudit?
    var basicInformationAudit: BasicInformationAudit?

    init(
''',
        "project basic information audit field",
    )
    text = replace_once(
        text,
        '''        automationSummary: AssetAutomationSummary? = nil,
        engineStatus: AppleEngineStatusSnapshot? = nil,
        reliabilityAudit: AssetReliabilityAudit? = nil
    ) {
''',
        '''        automationSummary: AssetAutomationSummary? = nil,
        engineStatus: AppleEngineStatusSnapshot? = nil,
        reliabilityAudit: AssetReliabilityAudit? = nil,
        basicInformationAudit: BasicInformationAudit? = nil
    ) {
''',
        "project audit initializer",
    )
    text = replace_once(
        text,
        '''        self.automationSummary = automationSummary
        self.engineStatus = engineStatus
        self.reliabilityAudit = reliabilityAudit
    }
''',
        '''        self.automationSummary = automationSummary
        self.engineStatus = engineStatus
        self.reliabilityAudit = reliabilityAudit
        self.basicInformationAudit = basicInformationAudit
    }
''',
        "project audit assignment",
    )

    text = replace_once(
        text,
        "        schemaVersion: 7,",
        "        schemaVersion: 8,",
        "workspace schema v8",
    )
    write(path, text)


def patch_pipeline() -> None:
    path = "美术台/Services/ArtDepartmentV2Pipeline.swift"
    text = read(path)

    text = replace_once(
        text,
        '''nonisolated struct AutomatedAssetExtractionResult: Sendable {
    var assets: [ProductionAsset]
    var summary: AssetAutomationSummary
    var engineStatus: AppleEngineStatusSnapshot
    var audit: AssetReliabilityAudit
}
''',
        '''nonisolated struct AutomatedAssetExtractionResult: Sendable {
    var scenes: [CanonicalScene]
    var assets: [ProductionAsset]
    var summary: AssetAutomationSummary
    var engineStatus: AppleEngineStatusSnapshot
    var audit: AssetReliabilityAudit
    var basicInformationAudit: BasicInformationAudit
}
''',
        "extraction result v8",
    )

    text = replace_once(
        text,
        '''        let scenes = mergeAndConvert(drafts)
        guard !scenes.isEmpty else {
            throw ArtDepartmentV2Error.invalidModelResponse("没有形成合法场景")
        }
        let fountain = CanonicalFountainRenderer.render(scenes: scenes)
''',
        '''        let rawScenes = mergeAndConvert(drafts)
        guard !rawScenes.isEmpty else {
            throw ArtDepartmentV2Error.invalidModelResponse("没有形成合法场景")
        }
        let scenes = EpisodeIndexResolver.resolve(
            scenes: rawScenes,
            sourceText: sourceText
        ).scenes
        let fountain = CanonicalFountainRenderer.render(scenes: scenes)
''',
        "normalize episode annotation",
    )

    text = replace_once(
        text,
        '''    static func extractAssets(
        scenes: [CanonicalScene],
        client: ArtChatCompletionClient?,
''',
        '''    static func extractAssets(
        scenes: [CanonicalScene],
        sourceText: String = "",
        client: ArtChatCompletionClient?,
''',
        "extract source text parameter",
    )
    text = replace_once(
        text,
        '''        let engine = AppleStructuredExtractionEngine.shared
        let engineStatus = await engine.status(remoteAvailable: client != nil)
        let ordered = scenes.sorted { $0.order < $1.order }
''',
        '''        let engine = AppleStructuredExtractionEngine.shared
        let engineStatus = await engine.status(remoteAvailable: client != nil)
        let episodeResolution = EpisodeIndexResolver.resolve(
            scenes: scenes,
            sourceText: sourceText
        )
        let ordered = episodeResolution.scenes.sorted { $0.order < $1.order }
''',
        "extract episode resolution",
    )
    text = replace_once(
        text,
        '''        let reliableAssets = reliability.assets
        let usable = reliableAssets.filter(\.isUsable)
''',
        '''        await progress(.init(
            title: "基础资料汇总",
            detail: "对已核验的场景、人物、道具建立全剧档案与分集出现索引",
            current: ordered.count,
            total: ordered.count
        ))
        let basicInformation = AssetBasicInformationAggregator.summarize(
            sourceText: sourceText,
            scenes: ordered,
            assets: reliability.assets
        )
        let reliableAssets = basicInformation.assets
        let usable = reliableAssets.filter(\.isUsable)
''',
        "second pass basic information aggregation",
    )
    text = replace_once(
        text,
        '''        await progress(.init(
            title: "资产已就绪",
            detail: "自动通过 \(usable.count) 项；隔离 \(quarantined) 项，不需要人工确认",
            current: ordered.count,
            total: ordered.count
        ))
        return AutomatedAssetExtractionResult(
            assets: reliableAssets,
            summary: summary,
            engineStatus: engineStatus,
            audit: reliability.audit
        )
''',
        '''        await progress(.init(
            title: "基本资料已就绪",
            detail: "汇总 \(basicInformation.audit.profileCount) 项资产，覆盖 \(basicInformation.audit.episodeCount) 集；隔离 \(quarantined) 项",
            current: ordered.count,
            total: ordered.count
        ))
        return AutomatedAssetExtractionResult(
            scenes: basicInformation.scenes,
            assets: reliableAssets,
            summary: summary,
            engineStatus: engineStatus,
            audit: reliability.audit,
            basicInformationAudit: basicInformation.audit
        )
''',
        "final aggregation result",
    )

    text = replace_between(
        text,
        "    static func makePromptPlan(",
        "    // MARK: - Scene automation",
        PIPELINE_PROMPT_FUNCTIONS,
        "three layer prompt functions",
    )
    write(path, text)


def patch_engine() -> None:
    path = "美术台/Services/AppleStructuredExtractionEngine.swift"
    text = read(path)
    text = replace_once(
        text,
        '''    var assetDesignPrompt: String
    var styleTreatmentPrompt: String
    var positivePrompt: String
''',
        '''    var assetDesignPrompt: String
    var styleTreatmentPrompt: String
    var basicInformationPrompt: String
    var formatTemplatePrompt: String
    var formatTemplateID: String
    var positivePrompt: String
''',
        "apple prompt schema three layers",
    )
    text = replace_between(
        text,
        "    func makePromptPlan(",
        "    private var canUseOnDeviceGeneral:",
        APPLE_PROMPT_METHOD,
        "apple prompt method",
    )
    write(path, text)


def patch_store() -> None:
    path = "美术台/Stores/ArtDepartmentV2Store.swift"
    text = read(path)

    text = re.sub(
        r'(?m)^([ \t]*)\$0\.automationSummary = nil$',
        lambda match: (
            match.group(0)
            + "\n"
            + match.group(1)
            + "$0.basicInformationAudit = nil"
        ),
        text,
    )

    text = replace_once(
        text,
        '''        mutateProject {
            $0.canonicalFountain = text
            $0.canonicalScenes = CanonicalFountainParser.parse(text)
            $0.pipelineStage = $0.canonicalScenes.isEmpty ? .source : .canonical
''',
        '''        mutateProject {
            let previousScenes = $0.canonicalScenes
            let parsedScenes = CanonicalFountainParser.parse(text)
            $0.canonicalFountain = text
            $0.canonicalScenes = EpisodeIndexResolver.relink(
                parsedScenes: parsedScenes,
                previousScenes: previousScenes,
                sourceText: $0.sourceText
            )
            $0.pipelineStage = $0.canonicalScenes.isEmpty ? .source : .canonical
''',
        "relink edited canonical scenes",
    )

    text = replace_once(
        text,
        '''            let extracted = try await ArtDepartmentV2Pipeline.extractAssets(
                scenes: normalized.scenes,
                client: client,
''',
        '''            let extracted = try await ArtDepartmentV2Pipeline.extractAssets(
                scenes: normalized.scenes,
                sourceText: project.sourceText,
                client: client,
''',
        "full pipeline extraction source",
    )
    text = replace_once(
        text,
        '''            mutateProject {
                $0.assets = extracted.assets
                $0.automationSummary = extracted.summary
                $0.reliabilityAudit = extracted.audit
''',
        '''            mutateProject {
                $0.canonicalScenes = extracted.scenes
                $0.assets = extracted.assets
                $0.automationSummary = extracted.summary
                $0.reliabilityAudit = extracted.audit
                $0.basicInformationAudit = extracted.basicInformationAudit
''',
        "store full aggregation result",
    )
    text = replace_once(
        text,
        "            noticeMessage = automationNotice(extracted.summary)",
        "            noticeMessage = automationNotice(extracted.summary, extracted.basicInformationAudit)",
        "full pipeline notice",
    )

    text = replace_once(
        text,
        '''            let result = try await ArtDepartmentV2Pipeline.extractAssets(
                scenes: scenes,
                client: client,
''',
        '''            let result = try await ArtDepartmentV2Pipeline.extractAssets(
                scenes: scenes,
                sourceText: project.sourceText,
                client: client,
''',
        "incremental extraction source",
    )
    text = replace_once(
        text,
        '''            mutateProject {
                $0.canonicalScenes = scenes
                $0.assets = result.assets
                $0.automationSummary = result.summary
                $0.reliabilityAudit = result.audit
''',
        '''            mutateProject {
                $0.canonicalScenes = result.scenes
                $0.assets = result.assets
                $0.automationSummary = result.summary
                $0.reliabilityAudit = result.audit
                $0.basicInformationAudit = result.basicInformationAudit
''',
        "store incremental aggregation result",
    )
    text = replace_once(
        text,
        "            noticeMessage = automationNotice(result.summary)",
        "            noticeMessage = automationNotice(result.summary, result.basicInformationAudit)",
        "incremental pipeline notice",
    )

    text = replace_once(
        text,
        '            noticeMessage = "已按“剧本资产设计 + 用户选择的纯视觉风格”生成双层生图计划。"',
        '            noticeMessage = "已按“基本资料 + 用户选择的视觉风格 + 资产格式模板”生成三层生图计划。"',
        "three layer planning notice",
    )
    text = replace_once(
        text,
        '                detail: "基于自动核验资产与用户明确选择的风格生成",',
        '                detail: "基于基本资料、用户明确选择的风格与受保护格式模板生成",',
        "generation progress detail",
    )

    export_anchor = '''    func assetJSONExportData() -> Data? {
        guard let project = currentProject else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(project.usableAssets)
    }
'''
    export_replacement = export_anchor + '''
    func basicInformationJSONExportData() -> Data? {
        guard let project = currentProject else { return nil }
        let profiles = project.usableAssets.compactMap(\.basicInformation)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(profiles)
    }
'''
    text = replace_once(
        text,
        export_anchor,
        export_replacement,
        "basic information export",
    )

    old_notice = '''    private func automationNotice(
        _ summary: AssetAutomationSummary
    ) -> String {
        "自动完成：\(summary.sceneCount) 场景、\(summary.characterCount) 人物、\(summary.propCount) 道具。另有 \(summary.quarantinedCount) 项低证据候选已自动隔离，不需要人工处理。"
    }
'''
    new_notice = '''    private func automationNotice(
        _ summary: AssetAutomationSummary,
        _ audit: BasicInformationAudit
    ) -> String {
        "自动完成：\(summary.sceneCount) 场景、\(summary.characterCount) 人物、\(summary.propCount) 道具；已建立 \(audit.profileCount) 份基本资料并索引 \(audit.episodeCount) 集。另有 \(summary.quarantinedCount) 项低证据候选已自动隔离。"
    }
'''
    text = replace_once(text, old_notice, new_notice, "automation notice v8")

    text = replace_once(
        text,
        "        document.schemaVersion = max(7, document.schemaVersion)",
        "        document.schemaVersion = max(8, document.schemaVersion)",
        "store schema v8",
    )
    old_migration_end = '''            if !document.projects[projectIndex].assets.isEmpty {
                document.projects[projectIndex].pipelineStage = .completed
            }
'''
    new_migration_end = '''            let project = document.projects[projectIndex]
            if !project.assets.isEmpty {
                let needsBasicInformation =
                    project.basicInformationAudit?.version
                        != AssetBasicInformationAggregator.version
                    || project.assets.contains { $0.basicInformation == nil }
                if needsBasicInformation {
                    let aggregation = AssetBasicInformationAggregator.summarize(
                        sourceText: project.sourceText,
                        scenes: project.canonicalScenes,
                        assets: project.assets
                    )
                    document.projects[projectIndex].canonicalScenes = aggregation.scenes
                    document.projects[projectIndex].assets = aggregation.assets
                    document.projects[projectIndex].basicInformationAudit = aggregation.audit
                }
                document.projects[projectIndex].pipelineStage = .completed
            }
'''
    text = replace_once(
        text,
        old_migration_end,
        new_migration_end,
        "legacy basic information migration",
    )

    write(path, text)


def patch_persistence() -> None:
    path = "美术台/Services/ArtDepartmentV2Persistence.swift"
    text = read(path)
    count = text.count("max(7, document.schemaVersion)")
    if count != 2:
        raise RuntimeError(
            f"persistence schema anchors: expected 2, found {count}"
        )
    text = text.replace(
        "max(7, document.schemaVersion)",
        "max(8, document.schemaVersion)",
    )
    write(path, text)


def patch_prompt_freshness() -> None:
    write(
        "美术台/Models/PromptPlanFreshness.swift",
        PROMPT_FRESHNESS_SWIFT,
    )


def patch_views() -> None:
    path = "美术台/Views/ArtDepartmentV2Views.swift"
    text = read(path)

    text = replace_once(
        text,
        '''            case .styles:
                StyleLibraryWorkspaceV4(store: store)
            case .generation:
''',
        '''            case .styles:
                StyleLibraryWorkspaceV4(store: store)
            case .templates:
                FormatTemplateLibraryWorkspace()
            case .generation:
''',
        "root format template route",
    )

    text = replace_once(
        text,
        '''            StageBadge(number: 1, title: "原文", active: !project.sourceText.isEmpty)
            Image(systemName: "arrow.right")
            StageBadge(number: 2, title: "Final Draft", active: !project.canonicalScenes.isEmpty)
            Image(systemName: "arrow.right")
            StageBadge(number: 3, title: "自动资产库", active: !project.usableAssets.isEmpty)
            Spacer()
''',
        '''            StageBadge(number: 1, title: "原文", active: !project.sourceText.isEmpty)
            Image(systemName: "arrow.right")
            StageBadge(number: 2, title: "Final Draft", active: !project.canonicalScenes.isEmpty)
            Image(systemName: "arrow.right")
            StageBadge(number: 3, title: "资产提取", active: !project.usableAssets.isEmpty)
            Image(systemName: "arrow.right")
            StageBadge(
                number: 4,
                title: "基本资料汇总",
                active: project.basicInformationAudit?.isComplete == true
            )
            Spacer()
''',
        "four stage pipeline footer",
    )
    text = replace_once(
        text,
        '''                Button("导出生产资产 JSON") {
                    export(data: store.assetJSONExportData(), name: "\(project.title)-assets.json")
                }
''',
        '''                Button("导出生产资产 JSON") {
                    export(data: store.assetJSONExportData(), name: "\(project.title)-assets.json")
                }
                Button("导出基本资料 JSON") {
                    export(
                        data: store.basicInformationJSONExportData(),
                        name: "\(project.title)-basic-information.json"
                    )
                }
''',
        "basic information export menu",
    )
    text = replace_once(
        text,
        '            Button("一键完成标准化与提取", systemImage: "bolt.fill") {',
        '            Button("一键完成标准化、提取与汇总", systemImage: "bolt.fill") {',
        "full pipeline button",
    )

    text = replace_once(
        text,
        '''                Text("自动资产库")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
''',
        '''                Text("基本资料库")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
''',
        "basic information library title",
    )
    text = replace_once(
        text,
        '''                    Text("自动通过 \(summary.usableCount) 项 · 隔离 \(summary.quarantinedCount) 项 · 无需人工审阅")
                        .foregroundStyle(.secondary)
''',
        '''                    Text("已汇总 \(summary.usableCount) 项 · 隔离 \(summary.quarantinedCount) 项 · 无需人工审阅")
                        .foregroundStyle(.secondary)
                    if let basic = store.currentProject?.basicInformationAudit {
                        Text("覆盖 \(basic.episodeCount) 集 · \(basic.profileCount) 份基本资料 · \(basic.sceneCount) 场")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
''',
        "basic information library summary",
    )
    text = replace_once(
        text,
        '''            HStack {
                Text(asset.reviewDecision.title)
                Text("·")
                Text("\(asset.sourceEvidence.count) 条证据")
                Text("·")
                Text("出现 \(asset.occurrenceCount) 次")
            }
''',
        '''            HStack {
                Text(asset.episodeAppearanceSummary)
                Text("·")
                Text("\(asset.sourceEvidence.count) 条证据")
                Text("·")
                Text("\(asset.basicInformation?.sceneCount ?? asset.occurrenceCount) 场")
            }
''',
        "asset row episode summary",
    )
    text = replace_once(
        text,
        '''                readOnlyField("摘要", value: asset.summary)
                readOnlyField("资产设计提示词", value: asset.designPrompt)
''',
        '''                if let information = asset.basicInformation {
                    AssetBasicInformationPanel(information: information)
                } else {
                    Label(
                        "旧项目尚未生成基础资料；重新运行提取后会自动补建。",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }

                readOnlyField("摘要", value: asset.summary)
                readOnlyField("第一部分 · 基本资料提示词", value: asset.basicInformationPrompt)
''',
        "asset basic information panel",
    )

    text = replace_once(
        text,
        '                Text("剧本关键设计事实（唯一主体来源）+ 用户选择的纯视觉风格 → Ark")',
        '                Text("基本资料 + 用户选择的纯视觉风格 + 资产格式模板 → Ark")',
        "generation header three layers",
    )
    text = replace_once(
        text,
        '            Text("生产资产").font(.headline)',
        '            Text("1. 基本资料").font(.headline)',
        "generation basic layer label",
    )
    text = replace_once(
        text,
        '            Text("资产交付规范").font(.headline)',
        '            Text("3. 格式模板").font(.headline)',
        "generation format layer label",
    )
    text = replace_once(
        text,
        '            Text("风格来源（必须由用户决定）").font(.headline)',
        '            Text("2. 风格图书馆（必须由用户决定）").font(.headline)',
        "generation style layer label",
    )
    text = replace_once(
        text,
        '                    Text("资产设计 + 纯风格双层提示词").font(.headline)',
        '                    Text("基本资料 + 风格 + 格式模板三层提示词").font(.headline)',
        "prompt pane three layer title",
    )
    old_prompt_fields = '''                PromptField(title: "标题", text: $store.promptPlan.title, minHeight: 38)
                PromptField(title: "资产设计（唯一主体来源）", text: $store.promptPlan.subject)
                HStack(alignment: .top, spacing: 10) {
                    PromptField(title: "材质", text: $store.promptPlan.materials)
                    PromptField(title: "构图", text: $store.promptPlan.composition)
                    PromptField(title: "元素", text: $store.promptPlan.elements)
                }
                PromptField(title: "光影", text: $store.promptPlan.lighting)
'''
    new_prompt_fields = '''                PromptField(title: "标题", text: $store.promptPlan.title, minHeight: 38)
                PromptReadOnlyField(
                    title: "1. 基本资料",
                    text: store.promptPlan.basicInformationPrompt
                        ?? store.promptPlan.subject
                )
                PromptReadOnlyField(
                    title: "2. 风格图书馆",
                    text: store.promptPlan.styleTreatmentPrompt ?? ""
                )
                PromptReadOnlyField(
                    title: "3. 格式模板",
                    text: store.promptPlan.formatTemplatePrompt
                        ?? AssetFormatTemplateCatalog.template(
                            for: store.selectedAssetKind
                        ).positiveInstruction
                )
'''
    text = replace_once(
        text,
        old_prompt_fields,
        new_prompt_fields,
        "prompt pane layer fields",
    )
    text = replace_once(
        text,
        "private struct GeneratedImageCard: View {",
        PROMPT_READONLY_VIEW + "private struct GeneratedImageCard: View {",
        "readonly prompt field view",
    )

    write(path, text)


def patch_tests() -> None:
    path = "美术台Tests/ArtDepartmentV2Tests.swift"
    text = read(path)
    text = replace_once(
        text,
        '''    func testWorkspaceSchemaIsAutomaticV7() {
        XCTAssertEqual(ArtDepartmentWorkspaceDocument.empty.schemaVersion, 7)
        XCTAssertEqual(ArtWorkspaceSection.assets.rawValue, "自动资产库")
        XCTAssertEqual(ScriptPipelineStage.completed.title, "资产已就绪")
    }
''',
        '''    func testWorkspaceSchemaIsAutomaticV8() {
        XCTAssertEqual(ArtDepartmentWorkspaceDocument.empty.schemaVersion, 8)
        XCTAssertEqual(ArtWorkspaceSection.assets.rawValue, "基本资料库")
        XCTAssertEqual(ArtWorkspaceSection.templates.rawValue, "格式模板")
        XCTAssertEqual(ScriptPipelineStage.completed.title, "基本资料已就绪")
    }
''',
        "workspace schema v8 test",
    )
    closing = text.rfind("\n}")
    if closing < 0:
        raise RuntimeError("test file closing brace missing")
    text = text[:closing] + NEW_TESTS + text[closing:]
    write(path, text)


def patch_readme() -> None:
    path = "README.md"
    text = read(path)
    text = replace_once(
        text,
        "# 美术台 6.0 · Apple 自动美术资产流水线",
        "# 美术台 8.0 · Apple 三层美术资产流水线",
        "readme title",
    )
    text = replace_once(
        text,
        "## 四个工作区",
        "## 五个工作区",
        "readme workspace count",
    )
    old_workspaces = '''1. **剧本标准化**：导入任意支持格式，一键完成 Final Draft 标准化和自动资产提取。
2. **自动资产库**：只显示自动通过的场景、人物、道具及逐字证据；隔离候选只在可选诊断窗口中展示。
3. **风格提示词库**：标题、用户精确提示词、标签、备注和参考图成对保存；提示词默认锁定，Vision 自动查重。
4. **生图工坊**：用户必须从风格图书馆明确选择卡片，或输入本轮外部风格；Apple Schema 随后生成材质、构图、元素、光影与锁定事实，再调用 Ark。
'''
    new_workspaces = '''1. **剧本标准化**：导入任意支持格式，先建立标准 Final Draft，再逐场提取并自动核验。
2. **基本资料库**：提取完成后再执行一轮全剧汇总，为每个场景、人物、道具建立关键特征、连续性、出现集数、场次和证据索引。
3. **风格提示词库**：只保存主体中立的视觉风格与样板，风格始终由用户明确选择。
4. **格式模板**：分别查看场景、人物、道具的受保护交付版式；模板与风格图书馆完全分离。
5. **生图工坊**：按“基本资料 + 用户风格 + 格式模板”确定性拼装提示词，再调用 Ark。
'''
    text = replace_once(
        text,
        old_workspaces,
        new_workspaces,
        "readme workspaces",
    )
    text = replace_once(
        text,
        "- 平台：macOS 26+",
        "- 平台：macOS 27+",
        "readme platform",
    )
    text = replace_once(
        text,
        "- [`docs/API_CONFIGURATION_V2.md`](docs/API_CONFIGURATION_V2.md)",
        "- [`docs/API_CONFIGURATION_V2.md`](docs/API_CONFIGURATION_V2.md)\n- [`docs/THREE_LAYER_PRODUCTION_ARCHITECTURE_V8.md`](docs/THREE_LAYER_PRODUCTION_ARCHITECTURE_V8.md)",
        "readme v8 doc link",
    )
    v8_section = '''

## V8 三层生产架构与分集基础资料

- 第一部分是从 Final Draft 提取结果中再次确定性汇总的基本资料，包括名称、明确别名、关键特征、连续性、出现集数、每集场次和逐字证据。
- 第二部分只来自用户明确选择的风格图书馆节点；风格不得包含具体人物、场景、道具或剧情内容。
- 第三部分是受保护的格式模板：场景无人无杂物、人物纯白背景四视图、道具中性背景单体展示。
- Final Draft 场景保留 SourceUnit 与分集关联，支持 `第1集`、`第十二集：标题`、`EP 5`、`Episode 6 - Title` 等保守标记。
- 旧 V7 项目加载时会从现有场景、资产和证据自动补建 V8 基本资料；旧双层提示词计划会自动失效并重新编译。
'''
    text = text.rstrip() + v8_section
    write(path, text)


def main() -> None:
    write("美术台/Models/AssetBasicInformation.swift", ASSET_BASIC_SWIFT)
    write("美术台/Views/FormatTemplateLibraryView.swift", FORMAT_VIEW_SWIFT)
    write("docs/THREE_LAYER_PRODUCTION_ARCHITECTURE_V8.md", DOC_V8)
    patch_models()
    patch_pipeline()
    patch_engine()
    patch_store()
    patch_persistence()
    patch_prompt_freshness()
    patch_views()
    patch_tests()
    patch_readme()
    print("V8 three-layer basic-information migration applied")


if __name__ == "__main__":
    main()
