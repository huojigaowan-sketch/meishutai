import Foundation

nonisolated enum BuiltInStylePromptCatalog {
    static let cards: [StylePromptCard] = [
        StylePromptCard(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            title: "材质 / 构图 / 元素审阅",
            prompt: "先准确分析并分别列出：1.材质；2.构图；3.画面元素。任何未在参考图或资产证据中出现的内容都不得臆造。",
            category: .general,
            tags: ["分析", "材质", "构图", "元素"],
            isBuiltIn: true
        ),
        StylePromptCard(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            title: "十人同服装角色队列",
            prompt: "生成十个穿着完全相同服饰的人物，服装结构、颜色、材质和配件保持一致；十个人长相不同、姿态不同、年龄不同，高矮胖瘦明显不同，完整全身，站成一排，便于横向比较，不得遮挡。",
            category: .costume,
            tags: ["角色阵列", "同服装", "十人"],
            isBuiltIn: true
        ),
        StylePromptCard(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            title: "AO 白模严格复刻",
            prompt: "严格参考原图的所有结构、整体构图、轮廓、材质层次、纹理起伏与光影关系，生成 AO 白模。只移除颜色信息，不改变比例、物体位置、镜头、姿态或轮廓。",
            category: .whiteModel,
            tags: ["AO", "白模", "严格复刻"],
            isBuiltIn: true
        ),
        StylePromptCard(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
            title: "白模材质回绘",
            prompt: "仅重绘白模的色彩、材质、纹理与光影，结构、比例、姿态、轮廓和镜头不得改变；风格与配色严格参考原图，超写实质感，皮肤细腻，去除杂色、噪点和色斑。人物设计需保留正面、侧面和背面展示。",
            category: .repaint,
            tags: ["回绘", "超写实", "三视图"],
            isBuiltIn: true
        ),
        StylePromptCard(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
            title: "场景减噪 30%",
            prompt: "保持原场景布局、物体、结构、材质、光源和色调不变，仅减少约 30% 地面与墙面上的点状物、丝状物和圈状物；不得清空环境细节，不得改变主要陈设。",
            category: .cleanup,
            tags: ["减噪", "点状物", "丝状物", "圈状物"],
            isBuiltIn: true
        ),
        StylePromptCard(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
            title: "指定机位场景重构",
            prompt: "保持原场景整体布局、光源和物品不变。镜头放在远处柜子位置，朝向柜子的正对面；前景是地面，中景是地面及右侧靠窗的灶台和左侧靠墙的物品，后景是桌子和桌子后的墙。只改变机位，不重新设计场景。",
            category: .camera,
            tags: ["机位", "场景", "构图"],
            isBuiltIn: true
        ),
        StylePromptCard(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
            title: "场景镜头反打",
            prompt: "生成当前场景的镜头反打视图。保持空间拓扑、人物与物品连续性、色调、材质、纹理、光源方向和时代信息一致；只切换到合理的反向机位，不凭空增删物体。",
            category: .camera,
            tags: ["反打", "空间连续性", "同场景"],
            isBuiltIn: true
        ),
    ]
}

nonisolated struct ScriptNormalizationResult: Sendable {
    var scenes: [CanonicalScene]
    var fountain: String
    var audit: ScriptNormalizationAudit
}

nonisolated enum ArtDepartmentV2Pipeline {
    static func normalizeScript(
        sourceText: String,
        client: ArtChatCompletionClient,
        modelName: String,
        progress: @Sendable (PipelineProgress) async -> Void
    ) async throws -> ScriptNormalizationResult {
        let units = SourceUnitBuilder.makeUnits(from: sourceText)
        guard !units.isEmpty else { throw ArtDepartmentV2Error.emptySource }
        let chunks = chunk(units: units, maximumCharacters: 14_000, maximumUnits: 64)
        var drafts: [NormalizationSceneDraft] = []
        var covered: [String] = []

        for (offset, item) in chunks.enumerated() {
            await progress(.init(title: "标准化为 Final Draft", detail: "正在处理第 \(offset + 1) / \(chunks.count) 个原文区块", current: offset, total: chunks.count))
            let response = try await normalizeChunk(item, client: client)
            try validateCoverage(response, expected: item.map(\.id))
            drafts.append(contentsOf: response.scenes)
            covered.append(contentsOf: response.coveredSourceUnitIDs)
        }

        let expected = units.map(\.id)
        let duplicates = duplicateValues(in: covered)
        let unknown = Array(Set(covered).subtracting(expected)).sorted()
        let uncovered = Array(Set(expected).subtracting(covered)).sorted()
        guard duplicates.isEmpty, unknown.isEmpty, uncovered.isEmpty else {
            throw ArtDepartmentV2Error.incompleteCoverage(uncovered + unknown + duplicates)
        }

        let scenes = mergeAndConvert(drafts)
        guard !scenes.isEmpty else { throw ArtDepartmentV2Error.invalidModelResponse("没有生成任何场景") }
        let fountain = CanonicalFountainRenderer.render(scenes: scenes)
        let audit = ScriptNormalizationAudit(
            sourceFingerprint: SourceUnitBuilder.fingerprint(sourceText),
            sourceUnitCount: expected.count,
            coveredSourceUnitCount: Set(covered).count,
            duplicateSourceUnitIDs: duplicates,
            unknownSourceUnitIDs: unknown,
            uncoveredSourceUnitIDs: uncovered,
            sceneCount: scenes.count,
            model: modelName,
            completedAt: .now
        )
        await progress(.init(title: "Final Draft 已就绪", detail: "原文 \(expected.count) 个证据单元已全部覆盖，得到 \(scenes.count) 场", current: chunks.count, total: chunks.count))
        return ScriptNormalizationResult(scenes: scenes, fountain: fountain, audit: audit)
    }

    static func extractAssets(
        scenes: [CanonicalScene],
        client: ArtChatCompletionClient,
        progress: @Sendable (PipelineProgress) async -> Void
    ) async throws -> [ProductionAsset] {
        guard !scenes.isEmpty else { throw ArtDepartmentV2Error.noCanonicalScenes }
        var allAssets: [ProductionAsset] = []

        for (offset, scene) in scenes.sorted(by: { $0.order < $1.order }).enumerated() {
            await progress(.init(title: "提取场景、人物、道具", detail: "逐场核验 \(offset + 1) / \(scenes.count) · \(scene.heading)", current: offset, total: scenes.count))
            allAssets.append(deterministicSceneAsset(scene))
            allAssets.append(contentsOf: deterministicCharacterAssets(scene))
            let response = try await extractScene(scene, client: client)
            allAssets.append(contentsOf: validatedAssets(response.assets, scene: scene))
        }

        let consolidated = conservativeConsolidation(allAssets)
        await progress(.init(title: "等待人工审阅", detail: "共形成 \(consolidated.count) 项资产；低置信度和别名冲突已单独标记", current: scenes.count, total: scenes.count))
        return consolidated.sorted {
            if $0.kind == $1.kind { return $0.firstSceneOrder < $1.firstSceneOrder }
            return kindOrder($0.kind) < kindOrder($1.kind)
        }
    }

    static func makePromptPlan(
        asset: ProductionAsset,
        styleCards: [StylePromptCard],
        mode: ImageGenerationMode,
        direction: String,
        client: ArtChatCompletionClient?
    ) async throws -> ArtPromptPlan {
        let lockedFacts = [asset.canonicalName, asset.visualDescription, asset.continuityState]
            + asset.sourceEvidence.prefix(4).map(\.quote)
        let styleText = styleCards.map { "【\($0.title)】\n\($0.prompt)" }.joined(separator: "\n\n")
        guard let client else {
            return fallbackPromptPlan(asset: asset, styleCards: styleCards, mode: mode, direction: direction)
        }

        let raw = try await client.completeJSON(
            system: "你是影视美术总监。根据经过审阅的资产证据和用户锁定的风格提示词，生成可审阅的生图提示词。不得改写锁定事实；不得补造人物、道具、建筑或时代信息。",
            user: """
            【资产】
            类型：\(asset.kind.rawValue)
            名称：\(asset.canonicalName)
            摘要：\(asset.summary)
            视觉证据：\(asset.visualDescription)
            连续性：\(asset.continuityState)
            材质：\(asset.materialNotes)
            构图：\(asset.compositionNotes)
            元素：\(asset.elementNotes)
            原文证据：\(asset.sourceEvidence.map(\.quote).joined(separator: "；"))

            【生成模式】\(mode.rawValue)
            【用户补充要求】\(direction)
            【用户锁定风格卡】
            \(styleText)

            返回 JSON：
            {"title":"","subject":"","materials":"","composition":"","elements":"","lighting":"","positivePrompt":"","negativePrompt":"","lockedFacts":[""],"rationale":""}
            positivePrompt 必须明确材质、构图、元素和连续性；negativePrompt 只写应避免的错误。
            """,
            maximumTokens: 4_000,
            temperature: 0.15
        )
        let draft = try decode(PromptPlanDraft.self, from: raw)
        return ArtPromptPlan(
            title: draft.title,
            mode: mode,
            subject: draft.subject,
            materials: draft.materials,
            composition: draft.composition,
            elements: draft.elements,
            lighting: draft.lighting,
            positivePrompt: draft.positivePrompt,
            negativePrompt: draft.negativePrompt,
            lockedFacts: Array(Set(lockedFacts + draft.lockedFacts)).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            chosenStyleCardIDs: styleCards.map(\.id),
            rationale: draft.rationale
        )
    }

    static func fallbackPromptPlan(asset: ProductionAsset, styleCards: [StylePromptCard], mode: ImageGenerationMode, direction: String) -> ArtPromptPlan {
        let styles = styleCards.map(\.prompt).joined(separator: "；")
        let positive = [
            asset.visualDescription,
            "材质：\(asset.materialNotes)",
            "构图：\(asset.compositionNotes)",
            "元素：\(asset.elementNotes)",
            styles,
            modeInstruction(mode),
            direction,
        ].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "。")
        return ArtPromptPlan(
            title: "\(asset.canonicalName) · \(mode.rawValue)",
            mode: mode,
            subject: asset.visualDescription,
            materials: asset.materialNotes,
            composition: asset.compositionNotes,
            elements: asset.elementNotes,
            lighting: "保持资产与参考图中已有光源关系",
            positivePrompt: positive,
            negativePrompt: "不要改变锁定结构、空间拓扑、服装结构、人物身份和时代信息；不要增加无证据物体；避免文字、水印、畸形肢体和重复主体。",
            lockedFacts: [asset.canonicalName, asset.continuityState] + asset.sourceEvidence.prefix(4).map(\.quote),
            chosenStyleCardIDs: styleCards.map(\.id),
            rationale: "本地按资产证据与用户锁定风格卡确定性拼装。"
        )
    }

    private static func normalizeChunk(_ units: [SourceUnit], client: ArtChatCompletionClient) async throws -> NormalizationEnvelope {
        let source = units.map { "<<\($0.id)>>\n\($0.text)" }.joined(separator: "\n\n")
        let raw = try await client.completeJSON(
            system: "你是严格的 Final Draft 剧本标准化器。你只重排和格式化原文，不提取资产，不续写，不删减，不总结。每个 source unit ID 必须且只能覆盖一次。",
            user: """
            将下列任意格式剧本文本转换为标准单场或多场剧本结构。
            场景标题统一为“内./外. 具体地点 - 日/夜”；元素只能使用 Scene Heading、Action、Character、Parenthetical、Dialogue、Transition、General。
            对小说式叙述只做可拍摄段落归类，不得创造原文不存在的动作、人物和道具。

            返回 JSON：
            {"coveredSourceUnitIDs":["U000001"],"scenes":[{"sceneKey":"稳定短标识","heading":"内. 地点 - 日","paragraphs":[{"element":"Action","text":"","sourceUnitIDs":["U000001"]}]}]}
            coveredSourceUnitIDs 和所有 paragraph.sourceUnitIDs 的并集必须与输入 ID 完全相等。

            【原文证据单元】
            \(source)
            """,
            maximumTokens: 12_000,
            temperature: 0.05
        )
        return try decode(NormalizationEnvelope.self, from: raw)
    }

    private static func validateCoverage(_ response: NormalizationEnvelope, expected: [String]) throws {
        let paragraphIDs = response.scenes.flatMap(\.paragraphs).flatMap(\.sourceUnitIDs)
        let reported = response.coveredSourceUnitIDs
        let expectedSet = Set(expected)
        let missing = Array(expectedSet.subtracting(reported)).sorted()
        let unknown = Array(Set(reported).subtracting(expectedSet)).sorted()
        let paragraphMissing = Array(expectedSet.subtracting(paragraphIDs)).sorted()
        let duplicates = duplicateValues(in: reported)
        guard missing.isEmpty, unknown.isEmpty, paragraphMissing.isEmpty, duplicates.isEmpty else {
            throw ArtDepartmentV2Error.invalidModelResponse("覆盖回执缺失 \(missing + paragraphMissing)，未知 \(unknown)，重复 \(duplicates)")
        }
    }

    private static func mergeAndConvert(_ drafts: [NormalizationSceneDraft]) -> [CanonicalScene] {
        var merged: [NormalizationSceneDraft] = []
        for draft in drafts where !draft.paragraphs.isEmpty {
            let heading = CanonicalFountainRenderer.normalizedHeading(draft.heading)
            if var last = merged.last, canonicalKey(last.heading) == canonicalKey(heading), last.sceneKey == draft.sceneKey {
                last.paragraphs.append(contentsOf: draft.paragraphs)
                merged[merged.count - 1] = last
            } else {
                var value = draft
                value.heading = heading
                merged.append(value)
            }
        }
        return merged.enumerated().map { offset, draft in
            let paragraphs = draft.paragraphs.compactMap { item -> CanonicalParagraph? in
                let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return CanonicalParagraph(element: element(item.element), text: text, sourceUnitIDs: item.sourceUnitIDs)
            }
            return CanonicalScene(
                order: offset,
                heading: draft.heading,
                sceneKey: draft.sceneKey.isEmpty ? "scene-\(offset + 1)" : draft.sceneKey,
                paragraphs: paragraphs,
                sourceUnitIDs: Array(Set(paragraphs.flatMap(\.sourceUnitIDs))).sorted()
            )
        }
    }

    private static func extractScene(_ scene: CanonicalScene, client: ArtChatCompletionClient) async throws -> ExtractionEnvelope {
        let raw = try await client.completeJSON(
            system: "你是影视美术资产审计员。只从当前标准剧本场景提取场景、人物、道具。每项必须引用当前场景中的逐字证据；证据不存在则不要返回。不要把动作、情绪、抽象概念或普通身体部位当作道具。",
            user: """
            场次：\(scene.order + 1)
            场景 ID：\(scene.id.uuidString)
            正式 Fountain：
            \(scene.fountainText)

            返回 JSON：
            {"assets":[{"kind":"场景|人物|道具","name":"","aliases":[""],"summary":"","visualDescription":"","continuityState":"","materialNotes":"","compositionNotes":"","elementNotes":"","evidence":"逐字短引文","evidenceExplanation":"","confidence":0.0}]}
            场景应说明空间、时间、天气、时代、室内外和关键陈设；人物应说明可见年龄、体型、服装、伤损或伪装；道具应是能被采购、制作、陈设或由人物使用的实体。
            """,
            maximumTokens: 6_000,
            temperature: 0.08
        )
        return try decode(ExtractionEnvelope.self, from: raw)
    }

    private static func validatedAssets(_ drafts: [AssetDraft], scene: CanonicalScene) -> [ProductionAsset] {
        let source = scene.fountainText
        return drafts.compactMap { item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let evidence = item.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, evidence.count >= 2, source.contains(evidence), let kind = assetKind(item.kind) else { return nil }
            let evidenceScore = min(1, Double(evidence.count) / 24.0 + 0.35)
            let detailScore = [item.visualDescription, item.continuityState, item.materialNotes, item.compositionNotes, item.elementNotes]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            let validated = min(1, max(0, item.confidence * 0.55 + evidenceScore * 0.30 + Double(detailScore) / 5.0 * 0.15))
            var warnings: [String] = []
            if item.confidence < 0.75 { warnings.append("模型自报置信度偏低") }
            if validated < 0.86 { warnings.append("需要人工确认名称或身份") }
            return ProductionAsset(
                kind: kind,
                canonicalName: name,
                aliases: item.aliases.filter { !$0.isEmpty && $0 != name },
                summary: item.summary,
                visualDescription: item.visualDescription,
                continuityState: item.continuityState,
                materialNotes: item.materialNotes,
                compositionNotes: item.compositionNotes,
                elementNotes: item.elementNotes,
                sourceEvidence: [EvidenceQuote(sceneID: scene.id, sceneHeading: scene.heading, quote: evidence, explanation: item.evidenceExplanation)],
                modelConfidence: item.confidence,
                validatedConfidence: validated,
                warnings: warnings,
                firstSceneOrder: scene.order
            )
        }
    }

    private static func deterministicSceneAsset(_ scene: CanonicalScene) -> ProductionAsset {
        ProductionAsset(
            kind: .scene,
            canonicalName: scene.heading,
            summary: "由标准 Final Draft 场景标题确定",
            visualDescription: scene.paragraphs.filter { $0.element == .action }.prefix(5).map(\.text).joined(separator: "；"),
            compositionNotes: "以正式场景标题和动作段落为依据",
            elementNotes: scene.paragraphs.filter { $0.element == .action }.prefix(8).map(\.text).joined(separator: "；"),
            sourceEvidence: [EvidenceQuote(sceneID: scene.id, sceneHeading: scene.heading, quote: scene.heading, explanation: "标准场景标题是确定性场景身份")],
            modelConfidence: 1,
            validatedConfidence: 1,
            reviewDecision: .pending,
            firstSceneOrder: scene.order
        )
    }

    private static func deterministicCharacterAssets(_ scene: CanonicalScene) -> [ProductionAsset] {
        let names = scene.paragraphs.filter { $0.element == .character }.map { $0.text.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(Set(names)).filter { !$0.isEmpty }.map { name in
            ProductionAsset(
                kind: .character,
                canonicalName: name,
                summary: "人物提示符在当前场景中明确出现",
                visualDescription: "外观信息等待从动作、对白和连续场景补充",
                sourceEvidence: [EvidenceQuote(sceneID: scene.id, sceneHeading: scene.heading, quote: name, explanation: "标准 Character 元素")],
                modelConfidence: 1,
                validatedConfidence: 0.92,
                reviewDecision: .pending,
                firstSceneOrder: scene.order
            )
        }
    }

    private static func conservativeConsolidation(_ assets: [ProductionAsset]) -> [ProductionAsset] {
        var result: [ProductionAsset] = []
        for asset in assets {
            let key = "\(asset.kind.rawValue)|\(canonicalKey(asset.canonicalName))"
            if let index = result.firstIndex(where: { "\($0.kind.rawValue)|\(canonicalKey($0.canonicalName))" == key }) {
                var existing = result[index]
                existing.aliases = Array(Set(existing.aliases + asset.aliases)).sorted()
                existing.sourceEvidence.append(contentsOf: asset.sourceEvidence.filter { !existing.sourceEvidence.contains($0) })
                existing.occurrenceCount += asset.occurrenceCount
                existing.firstSceneOrder = min(existing.firstSceneOrder, asset.firstSceneOrder)
                existing.validatedConfidence = min(existing.validatedConfidence, asset.validatedConfidence)
                existing.visualDescription = mergeText(existing.visualDescription, asset.visualDescription)
                existing.continuityState = mergeText(existing.continuityState, asset.continuityState)
                existing.materialNotes = mergeText(existing.materialNotes, asset.materialNotes)
                existing.compositionNotes = mergeText(existing.compositionNotes, asset.compositionNotes)
                existing.elementNotes = mergeText(existing.elementNotes, asset.elementNotes)
                existing.warnings = Array(Set(existing.warnings + asset.warnings)).sorted()
                result[index] = existing
            } else {
                result.append(asset)
            }
        }
        return result
    }

    private static func chunk(units: [SourceUnit], maximumCharacters: Int, maximumUnits: Int) -> [[SourceUnit]] {
        var chunks: [[SourceUnit]] = []
        var current: [SourceUnit] = []
        var count = 0
        for unit in units {
            let next = unit.text.count + unit.id.count + 8
            if !current.isEmpty && (count + next > maximumCharacters || current.count >= maximumUnits) {
                chunks.append(current); current = []; count = 0
            }
            current.append(unit); count += next
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private static func decode<T: Decodable>(_ type: T.Type, from raw: String) throws -> T {
        guard let data = ArtChatCompletionClient.extractJSONObject(raw).data(using: .utf8) else {
            throw ArtDepartmentV2Error.invalidModelResponse("JSON 编码失败")
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw ArtDepartmentV2Error.invalidModelResponse(error.localizedDescription) }
    }

    private static func element(_ raw: String) -> ScreenplayElementKind {
        ScreenplayElementKind.allCases.first { raw.localizedCaseInsensitiveContains($0.rawValue) }
            ?? (raw.contains("场景") ? .sceneHeading : raw.contains("对白") ? .dialogue : raw.contains("人物") ? .character : .action)
    }

    private static func assetKind(_ raw: String) -> ProductionAssetKind? {
        ProductionAssetKind.allCases.first { raw.contains($0.rawValue) || $0.rawValue.contains(raw) }
    }

    private static func canonicalKey(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func duplicateValues(in values: [String]) -> [String] {
        Dictionary(grouping: values, by: { $0 }).filter { $0.value.count > 1 }.map(\.key).sorted()
    }

    private static func mergeText(_ lhs: String, _ rhs: String) -> String {
        let values = [lhs, rhs].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return Array(Set(values)).joined(separator: "；")
    }

    private static func kindOrder(_ kind: ProductionAssetKind) -> Int {
        switch kind { case .scene: 0; case .character: 1; case .prop: 2 }
    }

    private static func modeInstruction(_ mode: ImageGenerationMode) -> String {
        switch mode {
        case .textToImage: "按照已审阅资产生成单张概念设计图"
        case .referenceImage: "以参考图控制风格、色调和材质，资产证据控制内容"
        case .characterLineup: BuiltInStylePromptCatalog.cards[1].prompt
        case .aoWhiteModel: BuiltInStylePromptCatalog.cards[2].prompt
        case .materialRepaint: BuiltInStylePromptCatalog.cards[3].prompt
        case .cleanup: BuiltInStylePromptCatalog.cards[4].prompt
        case .cameraRebuild: BuiltInStylePromptCatalog.cards[5].prompt
        case .reverseShot: BuiltInStylePromptCatalog.cards[6].prompt
        }
    }
}

private struct NormalizationEnvelope: Decodable {
    var coveredSourceUnitIDs: [String]
    var scenes: [NormalizationSceneDraft]
}

private struct NormalizationSceneDraft: Decodable {
    var sceneKey: String
    var heading: String
    var paragraphs: [NormalizationParagraphDraft]
}

private struct NormalizationParagraphDraft: Decodable {
    var element: String
    var text: String
    var sourceUnitIDs: [String]
}

private struct ExtractionEnvelope: Decodable { var assets: [AssetDraft] }

private struct AssetDraft: Decodable {
    var kind: String
    var name: String
    var aliases: [String]
    var summary: String
    var visualDescription: String
    var continuityState: String
    var materialNotes: String
    var compositionNotes: String
    var elementNotes: String
    var evidence: String
    var evidenceExplanation: String
    var confidence: Double
}

private struct PromptPlanDraft: Decodable {
    var title: String
    var subject: String
    var materials: String
    var composition: String
    var elements: String
    var lighting: String
    var positivePrompt: String
    var negativePrompt: String
    var lockedFacts: [String]
    var rationale: String
}
