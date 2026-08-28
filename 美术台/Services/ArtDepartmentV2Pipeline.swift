import Foundation

nonisolated enum BuiltInStylePromptCatalog {
    static let cards: [StylePromptCard] = [
        StylePromptCard(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            title: "材质 / 构图 / 元素分析",
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
    var engineStatus: AppleEngineStatusSnapshot
}

nonisolated struct AutomatedAssetExtractionResult: Sendable {
    var assets: [ProductionAsset]
    var summary: AssetAutomationSummary
    var engineStatus: AppleEngineStatusSnapshot
}

nonisolated enum ArtDepartmentV2Pipeline {
    static func normalizeScript(
        sourceText: String,
        client: ArtChatCompletionClient?,
        modelName: String,
        progress: @MainActor @Sendable (PipelineProgress) -> Void
    ) async throws -> ScriptNormalizationResult {
        let units = SourceUnitBuilder.makeUnits(from: sourceText)
        guard !units.isEmpty else { throw ArtDepartmentV2Error.emptySource }

        let engine = AppleStructuredExtractionEngine.shared
        let engineStatus = await engine.status(remoteAvailable: client != nil)
        let maximumCharacters = engineStatus.onDeviceAvailable && client == nil ? 5_500 : 12_000
        let chunks = chunk(
            units: units,
            maximumCharacters: maximumCharacters,
            maximumUnits: 72
        )
        var drafts: [AppleSchemaNormalizationScene] = []
        var covered: [String] = []

        for (offset, item) in chunks.enumerated() {
            await progress(.init(
                title: "Apple Schema 标准化",
                detail: "\(engineStatus.activeRoute) · 区块 \(offset + 1) / \(chunks.count)",
                current: offset,
                total: chunks.count
            ))
            let response = try await engine.normalize(units: item, remote: client)
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
        guard !scenes.isEmpty else {
            throw ArtDepartmentV2Error.invalidModelResponse("没有形成合法场景")
        }
        let fountain = CanonicalFountainRenderer.render(scenes: scenes)
        let audit = ScriptNormalizationAudit(
            sourceFingerprint: SourceUnitBuilder.fingerprint(sourceText),
            sourceUnitCount: expected.count,
            coveredSourceUnitCount: Set(covered).count,
            duplicateSourceUnitIDs: duplicates,
            unknownSourceUnitIDs: unknown,
            uncoveredSourceUnitIDs: uncovered,
            sceneCount: scenes.count,
            model: modelName.isEmpty ? engineStatus.activeRoute : "\(engineStatus.activeRoute) · \(modelName)",
            completedAt: .now
        )
        await progress(.init(
            title: "Final Draft 已就绪",
            detail: "\(expected.count) 个证据单元全覆盖 · \(scenes.count) 场",
            current: chunks.count,
            total: chunks.count
        ))
        return ScriptNormalizationResult(
            scenes: scenes,
            fountain: fountain,
            audit: audit,
            engineStatus: engineStatus
        )
    }

    static func extractAssets(
        scenes: [CanonicalScene],
        client: ArtChatCompletionClient?,
        progress: @MainActor @Sendable (PipelineProgress) -> Void
    ) async throws -> AutomatedAssetExtractionResult {
        guard !scenes.isEmpty else { throw ArtDepartmentV2Error.noCanonicalScenes }
        let startedAt = ContinuousClock.now
        let engine = AppleStructuredExtractionEngine.shared
        let engineStatus = await engine.status(remoteAvailable: client != nil)
        let ordered = scenes.sorted { $0.order < $1.order }
        var allAssets: [ProductionAsset] = []
        var usedEngines = Set<String>()
        let parallelism = engineStatus.onDeviceAvailable ? 2 : 4

        for lowerBound in stride(from: 0, to: ordered.count, by: parallelism) {
            let upperBound = min(ordered.count, lowerBound + parallelism)
            let window = Array(ordered[lowerBound..<upperBound])
            await progress(.init(
                title: "自动提取与核验",
                detail: "\(engineStatus.activeRoute) · 场 \(lowerBound + 1)-\(upperBound) / \(ordered.count)",
                current: lowerBound,
                total: ordered.count
            ))

            let batchResults = await withTaskGroup(of: SceneAutomationResult.self) { group in
                for scene in window {
                    group.addTask {
                        await processScene(scene, client: client)
                    }
                }
                var values: [SceneAutomationResult] = []
                for await value in group { values.append(value) }
                return values.sorted { $0.sceneOrder < $1.sceneOrder }
            }
            for result in batchResults {
                allAssets.append(contentsOf: result.assets)
                usedEngines.formUnion(result.engineNames)
            }
        }

        let consolidated = automaticConsolidation(allAssets)
        let usable = consolidated.filter(\.isUsable)
        guard !usable.isEmpty else { throw ArtDepartmentV2Error.noUsableAssets }
        let quarantined = consolidated.count { $0.isQuarantined }
        let rejected = consolidated.count { $0.reviewDecision == .rejected }
        let elapsed = startedAt.duration(to: .now)
        let milliseconds = Int(elapsed.components.seconds * 1_000)
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        let summary = AssetAutomationSummary(
            sceneCount: usable.count { $0.kind == .scene },
            characterCount: usable.count { $0.kind == .character },
            propCount: usable.count { $0.kind == .prop },
            usableCount: usable.count,
            quarantinedCount: quarantined,
            rejectedCount: rejected,
            engineNames: Array(usedEngines).sorted(),
            elapsedMilliseconds: max(0, milliseconds),
            completedAt: .now
        )
        await progress(.init(
            title: "资产已就绪",
            detail: "自动通过 \(usable.count) 项；隔离 \(quarantined) 项，不需要人工确认",
            current: ordered.count,
            total: ordered.count
        ))
        return AutomatedAssetExtractionResult(
            assets: consolidated,
            summary: summary,
            engineStatus: engineStatus
        )
    }

    static func makePromptPlan(
        asset: ProductionAsset,
        styleCards: [StylePromptCard],
        mode: ImageGenerationMode,
        direction: String,
        client: ArtChatCompletionClient?
    ) async throws -> ArtPromptPlan {
        let lockedFacts = [asset.canonicalName, asset.visualDescription, asset.continuityState]
            + asset.sourceEvidence.prefix(8).map(\.quote)
        do {
            let draft = try await AppleStructuredExtractionEngine.shared.makePromptPlan(
                asset: asset,
                styleCards: styleCards,
                mode: mode,
                direction: direction,
                remote: client
            )
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
                lockedFacts: uniqueText(lockedFacts + draft.lockedFacts),
                chosenStyleCardIDs: styleCards.map(\.id),
                rationale: draft.rationale
            )
        } catch {
            return fallbackPromptPlan(
                asset: asset,
                styleCards: styleCards,
                mode: mode,
                direction: direction
            )
        }
    }

    static func fallbackPromptPlan(
        asset: ProductionAsset,
        styleCards: [StylePromptCard],
        mode: ImageGenerationMode,
        direction: String
    ) -> ArtPromptPlan {
        let styles = styleCards.map(\.prompt).joined(separator: "；")
        let positive = [
            asset.visualDescription,
            "材质：\(asset.materialNotes)",
            "构图：\(asset.compositionNotes)",
            "元素：\(asset.elementNotes)",
            styles,
            modeInstruction(mode),
            direction,
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "。")
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
            lockedFacts: uniqueText(
                [asset.canonicalName, asset.continuityState]
                    + asset.sourceEvidence.prefix(8).map(\.quote)
            ),
            chosenStyleCardIDs: styleCards.map(\.id),
            rationale: "Apple 确定性编译器按自动核验资产与用户锁定风格卡拼装。"
        )
    }

    static func recommendedStyleCards(
        for asset: ProductionAsset,
        cards: [StylePromptCard],
        mode: ImageGenerationMode
    ) -> [StylePromptCard] {
        let preferredCategories: [StylePromptCategory]
        switch mode {
        case .aoWhiteModel: preferredCategories = [.whiteModel, .general]
        case .materialRepaint: preferredCategories = [.repaint, .general]
        case .reverseShot, .cameraRebuild: preferredCategories = [.camera, .scene, .general]
        case .cleanup: preferredCategories = [.cleanup, .scene, .general]
        case .characterLineup: preferredCategories = [.costume, .character, .general]
        case .referenceImage, .textToImage:
            switch asset.kind {
            case .scene: preferredCategories = [.scene, .general, .camera]
            case .character: preferredCategories = [.character, .costume, .general]
            case .prop: preferredCategories = [.prop, .general]
            }
        }
        let ranked = cards.sorted { lhs, rhs in
            let l = preferredCategories.firstIndex(of: lhs.category) ?? preferredCategories.count + 1
            let r = preferredCategories.firstIndex(of: rhs.category) ?? preferredCategories.count + 1
            if l != r { return l < r }
            return lhs.updatedAt > rhs.updatedAt
        }
        return Array(ranked.prefix(3))
    }

    // MARK: - Scene automation

    private nonisolated struct SceneAutomationResult: Sendable {
        var sceneOrder: Int
        var assets: [ProductionAsset]
        var engineNames: [String]
    }

    private static func processScene(
        _ scene: CanonicalScene,
        client: ArtChatCompletionClient?
    ) async -> SceneAutomationResult {
        let bundle = await AppleStructuredExtractionEngine.shared.extract(
            scene: scene,
            remote: client
        )
        var assets = [deterministicSceneAsset(scene)]
        assets.append(contentsOf: deterministicCharacterAssets(scene))
        assets.append(contentsOf: validatedModelAssets(bundle, scene: scene))
        assets.append(contentsOf: contentTagPropAssets(bundle.contentTags, scene: scene))
        return SceneAutomationResult(
            sceneOrder: scene.order,
            assets: assets,
            engineNames: bundle.engineNames
        )
    }

    private static func validatedModelAssets(
        _ bundle: AppleSceneExtractionBundle,
        scene: CanonicalScene
    ) -> [ProductionAsset] {
        let source = scene.fountainText
        var grouped: [String: [(String, AppleSchemaAssetCandidate)]] = [:]
        for result in bundle.modelResults {
            for candidate in result.payload.assets {
                let name = candidate.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let evidence = candidate.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty,
                      evidence.count >= 2,
                      source.contains(evidence)
                else { continue }
                let kind = assetKind(candidate.kind)
                let key = "\(kind.rawValue)|\(AppleLinguisticAnalyzer.canonicalKey(name))"
                grouped[key, default: []].append((result.engine, candidate))
            }
        }

        return grouped.values.compactMap { values in
            guard let first = values.first else { return nil }
            let exemplar = values.max { $0.1.confidencePercent < $1.1.confidencePercent } ?? first
            let candidate = exemplar.1
            let kind = assetKind(candidate.kind)
            let evidence = candidate.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
            let engineNames = Array(Set(values.map(\.0))).sorted()
            let evidenceScore = min(1, 0.55 + Double(min(evidence.count, 40)) / 90)
            let fields = [
                candidate.summary,
                candidate.visualDescription,
                candidate.continuityState,
                candidate.materialNotes,
                candidate.compositionNotes,
                candidate.elementNotes,
            ]
            let completeCount = fields.count {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            let schemaCompleteness = Double(completeCount) / Double(fields.count)
            let linguisticSupport = linguisticSupport(
                kind: kind,
                name: candidate.name,
                entities: bundle.namedEntities,
                scene: scene
            )
            let consensus = min(1, Double(engineNames.count) / 2)
            let modelScore = Double(candidate.confidencePercent) / 100
            let validated = min(
                1,
                modelScore * 0.35
                    + evidenceScore * 0.28
                    + schemaCompleteness * 0.17
                    + consensus * 0.15
                    + linguisticSupport * 0.05
            )
            let report = AssetVerificationReport(
                engines: engineNames,
                consensusCount: engineNames.count,
                exactEvidenceScore: evidenceScore,
                schemaCompleteness: schemaCompleteness,
                linguisticSupport: linguisticSupport,
                deterministicSupport: false,
                reason: "逐字证据通过；\(engineNames.count) 个结构化引擎支持；字段完整度 \(Int(schemaCompleteness * 100))%。"
            )
            let decision: AssetReviewDecision
            if report.automaticallyUsable && validated >= 0.68 {
                decision = .accepted
            } else if validated >= 0.50 {
                decision = .conflict
            } else {
                decision = .rejected
            }
            let warnings = decision == .accepted
                ? []
                : ["自动隔离：证据或多引擎一致性不足，不进入生产资产库"]
            return ProductionAsset(
                kind: kind,
                canonicalName: candidate.name,
                aliases: uniqueText(values.flatMap { $0.1.aliases }).filter { $0 != candidate.name },
                summary: candidate.summary,
                visualDescription: candidate.visualDescription,
                continuityState: candidate.continuityState,
                materialNotes: candidate.materialNotes,
                compositionNotes: candidate.compositionNotes,
                elementNotes: candidate.elementNotes,
                sourceEvidence: [
                    EvidenceQuote(
                        sceneID: scene.id,
                        sceneHeading: scene.heading,
                        quote: evidence,
                        explanation: candidate.evidenceExplanation
                    )
                ],
                modelConfidence: modelScore,
                validatedConfidence: validated,
                reviewDecision: decision,
                warnings: warnings,
                firstSceneOrder: scene.order,
                verificationReport: report
            )
        }
    }

    private static func deterministicSceneAsset(_ scene: CanonicalScene) -> ProductionAsset {
        let actionText = scene.paragraphs
            .filter { $0.element == .action }
            .prefix(8)
            .map(\.text)
            .joined(separator: "；")
        let report = AssetVerificationReport(
            engines: ["Final Draft Scene Heading", "Apple deterministic parser"],
            consensusCount: 2,
            exactEvidenceScore: 1,
            schemaCompleteness: 1,
            linguisticSupport: 1,
            deterministicSupport: true,
            reason: "标准 Scene Heading 是物理场景的确定性身份。"
        )
        return ProductionAsset(
            kind: .scene,
            canonicalName: scene.heading,
            summary: "由标准 Final Draft 场景标题确定",
            visualDescription: actionText,
            compositionNotes: "以正式场景标题和动作段落为依据",
            elementNotes: actionText,
            sourceEvidence: [
                EvidenceQuote(
                    sceneID: scene.id,
                    sceneHeading: scene.heading,
                    quote: scene.heading,
                    explanation: "标准 Scene Heading"
                )
            ],
            modelConfidence: 1,
            validatedConfidence: 1,
            reviewDecision: .accepted,
            firstSceneOrder: scene.order,
            verificationReport: report
        )
    }

    private static func deterministicCharacterAssets(
        _ scene: CanonicalScene
    ) -> [ProductionAsset] {
        let names = scene.paragraphs
            .filter { $0.element == .character }
            .map {
                $0.text.replacingOccurrences(of: "@", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        return uniqueText(names).filter { !$0.isEmpty }.map { name in
            let report = AssetVerificationReport(
                engines: ["Final Draft Character element", "Apple deterministic parser"],
                consensusCount: 2,
                exactEvidenceScore: 1,
                schemaCompleteness: 0.75,
                linguisticSupport: 1,
                deterministicSupport: true,
                reason: "人物名以 Character 元素实际说话，身份确定。"
            )
            return ProductionAsset(
                kind: .character,
                canonicalName: name,
                summary: "人物提示符在当前场景中明确出现",
                visualDescription: "外观由动作段落、服装状态和连续场景自动补全",
                sourceEvidence: [
                    EvidenceQuote(
                        sceneID: scene.id,
                        sceneHeading: scene.heading,
                        quote: name,
                        explanation: "标准 Character 元素"
                    )
                ],
                modelConfidence: 1,
                validatedConfidence: 0.96,
                reviewDecision: .accepted,
                firstSceneOrder: scene.order,
                verificationReport: report
            )
        }
    }

    private static func contentTagPropAssets(
        _ tags: AppleSchemaContentTags?,
        scene: CanonicalScene
    ) -> [ProductionAsset] {
        guard let tags else { return [] }
        let source = scene.fountainText
        let excluded = Set(["人", "身体", "手", "脚", "眼睛", "声音", "空气", "情绪", "动作", "场景", "对白"])
        return uniqueText(tags.objects).compactMap { object in
            let clean = object.trimmingCharacters(in: .whitespacesAndNewlines)
            guard clean.count >= 2,
                  !excluded.contains(clean),
                  let range = source.range(of: clean)
            else { return nil }
            let quote = String(source[range])
            let report = AssetVerificationReport(
                engines: ["Apple contentTagging", "Exact substring validator"],
                consensusCount: 2,
                exactEvidenceScore: 1,
                schemaCompleteness: 0.6,
                linguisticSupport: 0.7,
                deterministicSupport: false,
                reason: "Apple 专用 contentTagging 检出物体，且名称逐字存在于本场。"
            )
            return ProductionAsset(
                kind: .prop,
                canonicalName: clean,
                summary: "Apple contentTagging 检出的物理对象",
                visualDescription: clean,
                sourceEvidence: [
                    EvidenceQuote(
                        sceneID: scene.id,
                        sceneHeading: scene.heading,
                        quote: quote,
                        explanation: "专用对象标签与逐字证据一致"
                    )
                ],
                modelConfidence: 0.82,
                validatedConfidence: 0.78,
                reviewDecision: report.automaticallyUsable ? .accepted : .conflict,
                firstSceneOrder: scene.order,
                verificationReport: report
            )
        }
    }

    private static func automaticConsolidation(
        _ assets: [ProductionAsset]
    ) -> [ProductionAsset] {
        var result: [ProductionAsset] = []
        for asset in assets {
            let exactIndex = result.firstIndex {
                $0.kind == asset.kind
                    && AppleLinguisticAnalyzer.canonicalKey($0.canonicalName)
                        == AppleLinguisticAnalyzer.canonicalKey(asset.canonicalName)
            }
            let semanticIndex = exactIndex ?? result.firstIndex {
                guard $0.kind == asset.kind else { return false }
                if asset.kind == .scene { return false }
                return AppleLinguisticAnalyzer.likelySameIdentity(
                    $0.canonicalName,
                    asset.canonicalName
                )
            }
            if let index = semanticIndex {
                result[index] = merge(result[index], asset)
            } else {
                result.append(asset)
            }
        }
        return result.sorted {
            if $0.kind == $1.kind { return $0.firstSceneOrder < $1.firstSceneOrder }
            return kindOrder($0.kind) < kindOrder($1.kind)
        }
    }

    private static func merge(
        _ lhs: ProductionAsset,
        _ rhs: ProductionAsset
    ) -> ProductionAsset {
        var merged = lhs
        merged.aliases = uniqueText(lhs.aliases + rhs.aliases + [rhs.canonicalName])
            .filter { $0 != lhs.canonicalName }
        merged.sourceEvidence = uniqueEvidence(lhs.sourceEvidence + rhs.sourceEvidence)
        merged.occurrenceCount += rhs.occurrenceCount
        merged.firstSceneOrder = min(lhs.firstSceneOrder, rhs.firstSceneOrder)
        merged.modelConfidence = max(lhs.modelConfidence, rhs.modelConfidence)
        merged.validatedConfidence = max(lhs.validatedConfidence, rhs.validatedConfidence)
        merged.summary = mergeText(lhs.summary, rhs.summary)
        merged.visualDescription = mergeText(lhs.visualDescription, rhs.visualDescription)
        merged.continuityState = mergeText(lhs.continuityState, rhs.continuityState)
        merged.materialNotes = mergeText(lhs.materialNotes, rhs.materialNotes)
        merged.compositionNotes = mergeText(lhs.compositionNotes, rhs.compositionNotes)
        merged.elementNotes = mergeText(lhs.elementNotes, rhs.elementNotes)
        merged.warnings = uniqueText(lhs.warnings + rhs.warnings)
        if lhs.reviewDecision == .accepted || rhs.reviewDecision == .accepted {
            merged.reviewDecision = .accepted
            merged.warnings = []
        } else if lhs.reviewDecision == .conflict || rhs.reviewDecision == .conflict {
            merged.reviewDecision = .conflict
        } else {
            merged.reviewDecision = .rejected
        }
        let lhsReport = lhs.verificationReport
        let rhsReport = rhs.verificationReport
        if lhsReport != nil || rhsReport != nil {
            merged.verificationReport = AssetVerificationReport(
                engines: uniqueText((lhsReport?.engines ?? []) + (rhsReport?.engines ?? [])),
                consensusCount: (lhsReport?.consensusCount ?? 0) + (rhsReport?.consensusCount ?? 0),
                exactEvidenceScore: max(lhsReport?.exactEvidenceScore ?? 0, rhsReport?.exactEvidenceScore ?? 0),
                schemaCompleteness: max(lhsReport?.schemaCompleteness ?? 0, rhsReport?.schemaCompleteness ?? 0),
                linguisticSupport: max(lhsReport?.linguisticSupport ?? 0, rhsReport?.linguisticSupport ?? 0),
                deterministicSupport: (lhsReport?.deterministicSupport ?? false) || (rhsReport?.deterministicSupport ?? false),
                reason: mergeText(lhsReport?.reason ?? "", rhsReport?.reason ?? "")
            )
        }
        return merged
    }

    // MARK: - Validation helpers

    private static func validateCoverage(
        _ response: AppleSchemaNormalizationBatch,
        expected: [String]
    ) throws {
        let paragraphIDs = response.scenes.flatMap(\.paragraphs).flatMap(\.sourceUnitIDs)
        let reported = response.coveredSourceUnitIDs
        let expectedSet = Set(expected)
        let missing = Array(expectedSet.subtracting(reported)).sorted()
        let unknown = Array(Set(reported).subtracting(expectedSet)).sorted()
        let paragraphMissing = Array(expectedSet.subtracting(paragraphIDs)).sorted()
        let duplicates = duplicateValues(in: reported)
        guard missing.isEmpty,
              unknown.isEmpty,
              paragraphMissing.isEmpty,
              duplicates.isEmpty,
              Set(paragraphIDs) == expectedSet
        else {
            throw ArtDepartmentV2Error.invalidModelResponse(
                "覆盖缺失 \(missing + paragraphMissing)，未知 \(unknown)，重复 \(duplicates)"
            )
        }
    }

    private static func mergeAndConvert(
        _ drafts: [AppleSchemaNormalizationScene]
    ) -> [CanonicalScene] {
        var merged: [(key: String, heading: String, paragraphs: [AppleSchemaNormalizationParagraph])] = []
        for draft in drafts where !draft.paragraphs.isEmpty {
            let heading = CanonicalFountainRenderer.normalizedHeading(draft.heading)
            let key = draft.sceneKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if let lastIndex = merged.indices.last,
               AppleLinguisticAnalyzer.canonicalKey(merged[lastIndex].heading)
                    == AppleLinguisticAnalyzer.canonicalKey(heading),
               merged[lastIndex].key == key
            {
                merged[lastIndex].paragraphs.append(contentsOf: draft.paragraphs)
            } else {
                merged.append((key, heading, draft.paragraphs))
            }
        }
        return merged.enumerated().compactMap { offset, draft in
            let paragraphs = draft.paragraphs.compactMap { item -> CanonicalParagraph? in
                let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return CanonicalParagraph(
                    element: element(item.element),
                    text: text,
                    sourceUnitIDs: uniqueText(item.sourceUnitIDs)
                )
            }
            guard !paragraphs.isEmpty else { return nil }
            return CanonicalScene(
                order: offset,
                heading: draft.heading,
                sceneKey: draft.key.isEmpty ? "scene-\(offset + 1)" : draft.key,
                paragraphs: paragraphs,
                sourceUnitIDs: uniqueText(paragraphs.flatMap(\.sourceUnitIDs))
            )
        }
    }

    private static func linguisticSupport(
        kind: ProductionAssetKind,
        name: String,
        entities: AppleLinguisticEntities,
        scene: CanonicalScene
    ) -> Double {
        switch kind {
        case .character:
            if entities.people.contains(where: { AppleLinguisticAnalyzer.likelySameIdentity($0, name) }) { return 1 }
            if scene.paragraphs.contains(where: { $0.element == .character && AppleLinguisticAnalyzer.likelySameIdentity($0.text, name) }) { return 1 }
            return 0.35
        case .scene:
            if entities.places.contains(where: { scene.heading.contains($0) || name.contains($0) }) { return 1 }
            return 0.65
        case .prop:
            return 0.6
        }
    }

    private static func chunk(
        units: [SourceUnit],
        maximumCharacters: Int,
        maximumUnits: Int
    ) -> [[SourceUnit]] {
        var chunks: [[SourceUnit]] = []
        var current: [SourceUnit] = []
        var count = 0
        for unit in units {
            let next = unit.text.count + unit.id.count + 8
            if !current.isEmpty,
               (count + next > maximumCharacters || current.count >= maximumUnits)
            {
                chunks.append(current)
                current = []
                count = 0
            }
            current.append(unit)
            count += next
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private static func element(
        _ value: AppleSchemaScreenplayElement
    ) -> ScreenplayElementKind {
        switch value {
        case .sceneHeading: .sceneHeading
        case .action: .action
        case .character: .character
        case .parenthetical: .parenthetical
        case .dialogue: .dialogue
        case .transition: .transition
        case .general: .note
        }
    }

    private static func assetKind(
        _ value: AppleSchemaAssetKind
    ) -> ProductionAssetKind {
        switch value {
        case .scene: .scene
        case .character: .character
        case .prop: .prop
        }
    }

    private static func duplicateValues(in values: [String]) -> [String] {
        Dictionary(grouping: values, by: { $0 })
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted()
    }

    private static func uniqueText(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return nil }
            let key = AppleLinguisticAnalyzer.canonicalKey(clean)
            return seen.insert(key).inserted ? clean : nil
        }
    }

    private static func uniqueEvidence(
        _ values: [EvidenceQuote]
    ) -> [EvidenceQuote] {
        var seen = Set<String>()
        return values.filter {
            seen.insert("\($0.sceneID.uuidString)|\($0.quote)").inserted
        }
    }

    private static func mergeText(_ lhs: String, _ rhs: String) -> String {
        uniqueText([lhs, rhs]).joined(separator: "；")
    }

    private static func kindOrder(_ kind: ProductionAssetKind) -> Int {
        switch kind {
        case .scene: 0
        case .character: 1
        case .prop: 2
        }
    }

    private static func modeInstruction(_ mode: ImageGenerationMode) -> String {
        switch mode {
        case .textToImage: "按照自动核验资产生成单张概念设计图"
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
