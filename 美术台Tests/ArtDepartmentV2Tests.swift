import CryptoKit
import XCTest
@testable import AssetDesk

final class ArtDepartmentV2Tests: XCTestCase {
    func testSourceUnitsAreStableAndNonEmpty() {
        let source = "第一段\n\n第二段\n\n第三段"
        let units = SourceUnitBuilder.makeUnits(from: source)
        XCTAssertEqual(units.map(\.id), ["U000001", "U000002", "U000003"])
        XCTAssertEqual(units.map(\.text), ["第一段", "第二段", "第三段"])
        XCTAssertEqual(Set(units.map(\.id)).count, units.count)
    }

    func testFountainParserFindsChineseScenesAndCharacters() {
        let text = """
        内. 厨房 - 夜

        母亲把护照埋进米缸。

        @女儿
        你见过我的护照吗？

        外. 楼道 - 夜

        女儿站在门外。
        """
        let scenes = CanonicalFountainParser.parse(text)
        XCTAssertEqual(scenes.count, 2)
        XCTAssertEqual(scenes.first?.heading, "内. 厨房 - 夜")
        XCTAssertTrue(
            scenes.first?.paragraphs.contains(where: {
                $0.element == .character && $0.text == "女儿"
            }) == true
        )
        XCTAssertTrue(
            scenes.first?.paragraphs.contains(where: { $0.element == .dialogue }) == true
        )
    }

    func testFDXExporterUsesDeterministicElementTypes() {
        let scene = CanonicalScene(
            order: 0,
            heading: "内. 客厅 - 日",
            sceneKey: "scene-1",
            paragraphs: [
                CanonicalParagraph(element: .action, text: "窗帘被风吹动。"),
                CanonicalParagraph(element: .character, text: "母亲"),
                CanonicalParagraph(element: .dialogue, text: "门没有锁。"),
            ],
            sourceUnitIDs: ["U000001"]
        )
        let data = FinalDraftFDXExporter.data(scenes: [scene], title: "测试")
        let xml = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(xml.contains("<FinalDraft"))
        XCTAssertTrue(xml.contains("Type=\"Scene Heading\""))
        XCTAssertTrue(xml.contains("Type=\"Character\""))
        XCTAssertTrue(xml.contains("Type=\"Dialogue\""))
    }

    func testBuiltInStyleTemplatesContainRequestedOperations() {
        let prompts = BuiltInStylePromptCatalog.projectCards.map(\.prompt).joined(separator: "\n")
        XCTAssertTrue(prompts.contains("十个"))
        XCTAssertTrue(prompts.contains("AO 白模"))
        XCTAssertTrue(prompts.contains("减少约 30%"))
        XCTAssertTrue(prompts.contains("镜头反打"))
        XCTAssertTrue(prompts.contains("材质"))
        XCTAssertTrue(prompts.contains("构图"))
        XCTAssertTrue(prompts.contains("元素"))
    }

    func testProductionAssetIsAutomaticallyUsableWithoutHumanApproval() {
        let report = AssetVerificationReport(
            engines: ["Apple Foundation Models", "Apple contentTagging"],
            consensusCount: 2,
            exactEvidenceScore: 1,
            schemaCompleteness: 0.9,
            linguisticSupport: 0.8,
            deterministicSupport: false,
            reason: "双引擎与逐字证据一致"
        )
        let asset = ProductionAsset(
            kind: .prop,
            canonicalName: "护照",
            summary: "关键道具",
            visualDescription: "一本用于出入境查验的护照",
            designFacts: [
                AssetDesignFact(
                    kind: .objectType,
                    value: "护照",
                    evidence: "一本用于出入境查验的护照",
                    sceneID: UUID(),
                    sceneHeading: "内. 边检大厅 - 日"
                ),
                AssetDesignFact(
                    kind: .objectFunction,
                    value: "用于出入境身份查验",
                    evidence: "一本用于出入境查验的护照",
                    sceneID: UUID(),
                    sceneHeading: "内. 边检大厅 - 日"
                )
            ],
            sourceEvidence: [
                EvidenceQuote(
                    sceneID: UUID(),
                    sceneHeading: "内. 边检大厅 - 日",
                    quote: "一本用于出入境查验的护照",
                    explanation: "逐字证据"
                )
            ],
            modelConfidence: 0.84,
            validatedConfidence: 0.82,
            reviewDecision: .accepted,
            firstSceneOrder: 0,
            verificationReport: report
        )
        XCTAssertTrue(report.automaticallyUsable)
        XCTAssertTrue(asset.isUsable)
        XCTAssertFalse(asset.isQuarantined)
        XCTAssertEqual(asset.reviewDecision.title, "自动通过")
    }

    func testLowEvidenceCandidateIsQuarantinedNotAssignedToHuman() {
        let asset = ProductionAsset(
            kind: .prop,
            canonicalName: "疑似物件",
            summary: "证据不足",
            visualDescription: "",
            sourceEvidence: [],
            modelConfidence: 0.3,
            validatedConfidence: 0.25,
            reviewDecision: .conflict,
            warnings: ["自动隔离"],
            firstSceneOrder: 0
        )
        XCTAssertTrue(asset.isQuarantined)
        XCTAssertFalse(asset.isUsable)
        XCTAssertEqual(asset.reviewDecision.title, "隔离诊断")
    }

    func testImportedMITStyleCatalogIsLargeAndTraceable() {
        let cards = ImportedStylePromptCatalog.cards
        XCTAssertEqual(cards.count, 56)
        XCTAssertEqual(ImportedStylePromptCatalog.revision, "7c065c2b429bc75334239965768849cb00c8987d")
        XCTAssertEqual(Set(cards.map(\.id)).count, cards.count)
        XCTAssertTrue(cards.allSatisfy { !$0.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertTrue(cards.allSatisfy { card in
            card.provenance?.repository == "YouMind-OpenLab/ai-image-prompts-skill"
                && card.provenance?.revision == "7c065c2b429bc75334239965768849cb00c8987d"
                && card.provenance?.license == "MIT"
                && !(card.provenance?.originalID ?? "").isEmpty
        })
    }

    func testStyleSelectionRequiresExplicitHumanInput() {
        XCTAssertFalse(StyleSelectionPolicy.hasExplicitSelection(
            selectedStyleCardIDs: [],
            externalPrompt: ""
        ))
        XCTAssertTrue(StyleSelectionPolicy.hasExplicitSelection(
            selectedStyleCardIDs: [UUID()],
            externalPrompt: ""
        ))
        XCTAssertTrue(StyleSelectionPolicy.hasExplicitSelection(
            selectedStyleCardIDs: [],
            externalPrompt: "用户粘贴的外部风格"
        ))
    }

    func testStyleVaultRoundTripAndTamperDetection() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("重要风格提示词与参考图索引".utf8)
        let encrypted = try StyleLibraryVault.seal(plaintext, using: key)
        XCTAssertNotEqual(encrypted, plaintext)
        XCTAssertEqual(try StyleLibraryVault.open(encrypted, using: key), plaintext)

        var tampered = encrypted
        let last = tampered.index(before: tampered.endIndex)
        tampered[last] ^= 0x01
        XCTAssertThrowsError(try StyleLibraryVault.open(tampered, using: key))
    }

    func testWorkspaceSchemaIsAutomaticV7() {
        XCTAssertEqual(ArtDepartmentWorkspaceDocument.empty.schemaVersion, 7)
        XCTAssertEqual(ArtWorkspaceSection.assets.rawValue, "自动资产库")
        XCTAssertEqual(ScriptPipelineStage.completed.title, "资产已就绪")
    }

    func testEveryImportedStyleHasACompleteSample() {
        let cards = ImportedStylePromptCatalog.cards
        XCTAssertEqual(cards.count, 56)
        XCTAssertTrue(cards.allSatisfy { !$0.styleSampleMedia.isEmpty })
        XCTAssertTrue(cards.flatMap(\.styleSampleMedia).allSatisfy {
            guard let raw = $0.remoteURLString, let url = URL(string: raw) else { return false }
            return url.scheme == "https"
        })
    }

    func testStylePromptBranchesResolveIncrementally() {
        let root = StylePromptCard(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            title: "电影写实",
            prompt: "电影级写实摄影，真实材质质感",
            category: .general,
            sampleMedia: [StyleSampleMedia(remoteURLString: "https://example.com/root.jpg")]
        )
        let child = StylePromptCard(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            title: "冷色侧光",
            prompt: "光线处理改为低照度冷色侧光",
            category: .scene,
            parentID: root.id,
            lifecycleRawValue: StylePromptLifecycle.library.rawValue
        )
        let grandchild = StylePromptCard(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            title: "湿润反射质感",
            prompt: "表面质感增加湿润高光与柔和反射",
            category: .scene,
            parentID: child.id,
            lifecycleRawValue: StylePromptLifecycle.library.rawValue
        )
        let cards = [root, child, grandchild]
        let resolved = StylePromptResolver.resolvedPrompt(for: grandchild.id, in: cards)
        XCTAssertTrue(resolved.contains("电影级写实摄影"))
        XCTAssertTrue(resolved.contains("低照度冷色侧光"))
        XCTAssertTrue(resolved.contains("湿润高光与柔和反射"))
        XCTAssertTrue(resolved.contains("【视觉风格】"))
        XCTAssertTrue(resolved.contains("【主体中立规则】"))
        let rootRange = resolved.range(of: "电影级写实摄影")
        let childRange = resolved.range(of: "低照度冷色侧光")
        let grandchildRange = resolved.range(of: "湿润高光与柔和反射")
        XCTAssertNotNil(rootRange)
        XCTAssertNotNil(childRange)
        XCTAssertNotNil(grandchildRange)
        if let rootRange, let childRange, let grandchildRange {
            XCTAssertLessThan(rootRange.lowerBound, childRange.lowerBound)
            XCTAssertLessThan(childRange.lowerBound, grandchildRange.lowerBound)
        }
        XCTAssertEqual(
            StylePromptResolver.resolvedSamples(for: grandchild.id, in: cards).count,
            1
        )
        XCTAssertFalse(StylePromptResolver.hasCycle(
            parentID: root.id,
            cardID: grandchild.id,
            cards: cards
        ))
        XCTAssertTrue(StylePromptResolver.hasCycle(
            parentID: grandchild.id,
            cardID: root.id,
            cards: cards
        ))
    }

    func testReliabilityV4RequiresIndependentEvidenceForNonDeterministicAssets() {
        let weak = AssetConfidenceBreakdown(
            deterministicEvidence: 0,
            exactQuoteCoverage: 1,
            independentAgreement: 0,
            crossSceneSupport: 1,
            identityStability: 1,
            continuityConsistency: 1,
            schemaCompleteness: 1,
            modelCalibration: 1
        )
        XCTAssertLessThan(weak.weightedScore, AssetReliabilityV4.productionThreshold)

        let strong = AssetConfidenceBreakdown(
            deterministicEvidence: 0,
            exactQuoteCoverage: 1,
            independentAgreement: 1,
            crossSceneSupport: 1,
            identityStability: 1,
            continuityConsistency: 1,
            schemaCompleteness: 1,
            modelCalibration: 1
        )
        XCTAssertGreaterThanOrEqual(strong.weightedScore, AssetReliabilityV4.productionThreshold)
    }

    func testPublicStyleCatalogContainsOnlySubjectNeutralVisualTreatments() {
        let cards = ImportedStylePromptCatalog.cards
        XCTAssertEqual(cards.count, 56)
        XCTAssertTrue(cards.allSatisfy(\.isSubjectNeutralStyle))
        XCTAssertTrue(cards.allSatisfy { StyleOnlyPromptPolicy.isSubjectNeutralTitle($0.title) })
        XCTAssertFalse(cards.map(\.prompt).joined(separator: "\n").contains("young woman"))
        XCTAssertFalse(cards.map(\.prompt).joined(separator: "\n").contains("retrofuturistic train"))
    }

    func testConcreteSubjectCannotBeSavedAsAStylePrompt() {
        let bad = StyleOnlyPromptPolicy.assessment(
            "A young woman wearing a red dress stands in a kitchen holding a passport."
        )
        XCTAssertFalse(bad.isStyleOnly)
        XCTAssertThrowsError(try StyleOnlyPromptPolicy.validatedUserPrompt(
            "A young woman wearing a red dress stands in a kitchen holding a passport."
        ))
        XCTAssertThrowsError(try StyleOnlyPromptPolicy.validatedUserPrompt(
            "厨房里的女孩拿着护照，电影级写实摄影与柔和光线。"
        ))
        XCTAssertNoThrow(try StyleOnlyPromptPolicy.validatedUserPrompt(
            "电影级写实摄影，低饱和冷色体系，柔和侧光，克制构图，细颗粒表面质感。"
        ))
    }

    func testStyleSamplesArePreviewOnlyProviderReferences() {
        XCTAssertFalse(GenerationReferencePolicy.shouldSendToProvider(.stylePreview))
        XCTAssertTrue(GenerationReferencePolicy.shouldSendToProvider(.userContentReference))
    }

    func testCharacterDesignPromptUsesGroundedAgeGenderAndCostumeFacts() {
        let sceneID = UUID()
        let asset = ProductionAsset(
            kind: .character,
            canonicalName: "小雨",
            summary: "主要人物",
            visualDescription: "十七岁的女孩，穿旧校服",
            designFacts: [
                AssetDesignFact(
                    kind: .ageRange,
                    value: "17 岁",
                    evidence: "十七岁的女孩小雨",
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日"
                ),
                AssetDesignFact(
                    kind: .genderPresentation,
                    value: "女性",
                    evidence: "十七岁的女孩小雨",
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日"
                ),
                AssetDesignFact(
                    kind: .costume,
                    value: "洗得发白的旧校服",
                    evidence: "穿着洗得发白的旧校服",
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日"
                )
            ],
            sourceEvidence: [
                EvidenceQuote(
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日",
                    quote: "十七岁的女孩小雨穿着洗得发白的旧校服",
                    explanation: "人物关键设计依据"
                )
            ],
            modelConfidence: 1,
            validatedConfidence: 1,
            reviewDecision: .accepted,
            firstSceneOrder: 0
        )
        XCTAssertTrue(AssetDesignReadiness.isReady(asset))
        XCTAssertTrue(asset.designPrompt.contains("17 岁"))
        XCTAssertTrue(asset.designPrompt.contains("女性"))
        XCTAssertTrue(asset.designPrompt.contains("旧校服"))
    }

    func testNameOnlyAssetsCannotEnterGenerationReadyLibrary() {
        let sceneID = UUID()
        let prop = ProductionAsset(
            kind: .prop,
            canonicalName: "护照",
            summary: "道具名称",
            visualDescription: "护照",
            designFacts: [
                AssetDesignFact(
                    kind: .objectType,
                    value: "护照",
                    evidence: "护照",
                    sceneID: sceneID,
                    sceneHeading: "内. 厨房 - 夜"
                )
            ],
            sourceEvidence: [
                EvidenceQuote(
                    sceneID: sceneID,
                    sceneHeading: "内. 厨房 - 夜",
                    quote: "护照",
                    explanation: "仅证明名称"
                )
            ],
            modelConfidence: 1,
            validatedConfidence: 1,
            reviewDecision: .accepted,
            firstSceneOrder: 0
        )
        XCTAssertFalse(AssetDesignReadiness.isReady(prop))
        XCTAssertFalse(prop.isUsable)
        XCTAssertTrue(AssetDesignReadiness.missingReason(prop).contains("只有名称"))
    }

    func testPromptPlanFreshnessTracksSelectedAssetAndStyleContent() {
        let sceneID = UUID()
        let first = ProductionAsset(
            kind: .prop,
            canonicalName: "护照",
            summary: "证件道具",
            visualDescription: "用于边检",
            designFacts: [
                AssetDesignFact(
                    kind: .objectType,
                    value: "护照",
                    evidence: "护照递到边检窗口",
                    sceneID: sceneID,
                    sceneHeading: "内. 边检大厅 - 日"
                ),
                AssetDesignFact(
                    kind: .objectFunction,
                    value: "边检身份查验",
                    evidence: "护照递到边检窗口",
                    sceneID: sceneID,
                    sceneHeading: "内. 边检大厅 - 日"
                )
            ],
            sourceEvidence: [
                EvidenceQuote(
                    sceneID: sceneID,
                    sceneHeading: "内. 边检大厅 - 日",
                    quote: "护照递到边检窗口",
                    explanation: "道具与用途"
                )
            ],
            modelConfidence: 1,
            validatedConfidence: 1,
            reviewDecision: .accepted,
            firstSceneOrder: 0
        )
        let second = ProductionAsset(
            kind: .prop,
            canonicalName: "手机",
            summary: "通讯道具",
            visualDescription: "用于拨号",
            designFacts: [
                AssetDesignFact(
                    kind: .objectType,
                    value: "手机",
                    evidence: "她用手机拨通电话",
                    sceneID: sceneID,
                    sceneHeading: "内. 候机厅 - 日"
                ),
                AssetDesignFact(
                    kind: .objectFunction,
                    value: "拨打电话",
                    evidence: "她用手机拨通电话",
                    sceneID: sceneID,
                    sceneHeading: "内. 候机厅 - 日"
                )
            ],
            sourceEvidence: [
                EvidenceQuote(
                    sceneID: sceneID,
                    sceneHeading: "内. 候机厅 - 日",
                    quote: "她用手机拨通电话",
                    explanation: "道具与用途"
                )
            ],
            modelConfidence: 1,
            validatedConfidence: 1,
            reviewDecision: .accepted,
            firstSceneOrder: 1
        )
        let style = StylePromptCard(
            title: "冷色写实",
            prompt: "电影级写实摄影，低饱和冷色体系，柔和侧光与细颗粒质感。",
            category: .general
        )
        let plan = ArtDepartmentV2Pipeline.fallbackPromptPlan(
            asset: first,
            styleCards: [style],
            mode: .textToImage,
            direction: ""
        )
        XCTAssertFalse(plan.requiresRebuild(
            for: first,
            styleCards: [style],
            mode: .textToImage
        ))
        XCTAssertTrue(plan.requiresRebuild(
            for: second,
            styleCards: [style],
            mode: .textToImage
        ))
        var changedStyle = style
        changedStyle.prompt = "水彩绘画，柔和粉彩体系，纸张颗粒质感与高调漫射光。"
        XCTAssertTrue(plan.requiresRebuild(
            for: first,
            styleCards: [changedStyle],
            mode: .textToImage
        ))
    }


    func testSceneDeliveryStandardForbidsPeopleAndClutter() {
        let positive = AssetDeliveryStandard.positiveInstruction(for: .scene)
        let negative = AssetDeliveryStandard.negativeInstruction(for: .scene)
        XCTAssertTrue(positive.contains("无人空场景"))
        XCTAssertTrue(positive.contains("不得出现人物"))
        XCTAssertTrue(positive.contains("散乱物"))
        XCTAssertTrue(negative.contains("人物"))
        XCTAssertTrue(negative.contains("杂物堆"))
    }

    func testCharacterDeliveryStandardRequiresWhiteFourViewSheet() {
        let positive = AssetDeliveryStandard.positiveInstruction(for: .character)
        let negative = AssetDeliveryStandard.negativeInstruction(for: .character)
        XCTAssertTrue(positive.contains("纯白无缝背景"))
        XCTAssertTrue(positive.contains("头肩特写"))
        XCTAssertTrue(positive.contains("严格正视图"))
        XCTAssertTrue(positive.contains("严格 90° 侧视图"))
        XCTAssertTrue(positive.contains("严格 180° 背视图"))
        XCTAssertTrue(positive.contains("双手自然垂放"))
        XCTAssertTrue(positive.contains("面部无表情"))
        XCTAssertTrue(positive.contains("均匀无方向性棚拍光"))
        XCTAssertTrue(negative.contains("非白背景"))
        XCTAssertTrue(negative.contains("三分之四视角"))
    }

    func testAspectRatioMapsToArkPixelSize() {
        var recipe = ImageGenerationRecipe.arkDefault
        recipe.aspectRatio = .landscape16x9
        XCTAssertEqual(recipe.providerSize, "2848x1600")
        recipe.aspectRatio = .portrait9x16
        XCTAssertEqual(recipe.providerSize, "1600x2848")
        recipe.aspectRatio = .portrait3x4
        XCTAssertEqual(recipe.providerSize, "1728x2304")
        recipe.size = "1K"
        XCTAssertEqual(recipe.providerSize, "864x1152")
        recipe.size = "2048x1024"
        XCTAssertEqual(recipe.providerSize, "2048x1024")
    }

    func testSelectableGenerationModesAvoidConflictingLegacyLineup() {
        let characterModes = ImageGenerationMode.selectableCases(for: .character)
        XCTAssertFalse(characterModes.contains(.characterLineup))
        XCTAssertFalse(characterModes.contains(.reverseShot))
        XCTAssertTrue(characterModes.contains(.textToImage))
        XCTAssertTrue(ImageGenerationMode.selectableCases(for: .scene).contains(.reverseShot))
    }

    func testCharacterPromptIncludesMandatoryDeliveryStandard() {
        let sceneID = UUID()
        let asset = ProductionAsset(
            kind: .character,
            canonicalName: "小雨",
            summary: "主要人物",
            visualDescription: "十七岁的女孩，穿旧校服",
            designFacts: [
                AssetDesignFact(
                    kind: .identityRole,
                    value: "学生小雨",
                    evidence: "学生小雨",
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日"
                ),
                AssetDesignFact(
                    kind: .ageRange,
                    value: "17 岁",
                    evidence: "十七岁的学生小雨",
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日"
                ),
                AssetDesignFact(
                    kind: .costume,
                    value: "洗得发白的旧校服",
                    evidence: "穿着洗得发白的旧校服",
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日"
                )
            ],
            sourceEvidence: [
                EvidenceQuote(
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日",
                    quote: "十七岁的学生小雨穿着洗得发白的旧校服",
                    explanation: "人物关键设计依据"
                )
            ],
            modelConfidence: 1,
            validatedConfidence: 1,
            reviewDecision: .accepted,
            firstSceneOrder: 0
        )
        let style = StylePromptCard(
            title: "中性写实",
            prompt: "电影级写实摄影，中性白平衡，均匀漫射光，低畸变构图。",
            category: .general
        )
        let plan = ArtDepartmentV2Pipeline.fallbackPromptPlan(
            asset: asset,
            styleCards: [style],
            mode: .textToImage,
            direction: ""
        )
        XCTAssertTrue(plan.positivePrompt.contains("纯白无缝背景"))
        XCTAssertTrue(plan.positivePrompt.contains("头肩特写"))
        XCTAssertTrue(plan.positivePrompt.contains("严格 180° 背视图"))
        XCTAssertTrue(plan.negativePrompt.contains("非白背景"))
    }

}
