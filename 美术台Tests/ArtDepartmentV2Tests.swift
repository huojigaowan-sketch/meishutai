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
        let prompts = BuiltInStylePromptCatalog.cards.map(\.prompt).joined(separator: "\n")
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
            visualDescription: "一本护照",
            sourceEvidence: [
                EvidenceQuote(
                    sceneID: UUID(),
                    sceneHeading: "内. 厨房 - 夜",
                    quote: "护照",
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

    func testWorkspaceSchemaIsAutomaticV4() {
        XCTAssertEqual(ArtDepartmentWorkspaceDocument.empty.schemaVersion, 4)
        XCTAssertEqual(ArtWorkspaceSection.assets.rawValue, "自动资产库")
        XCTAssertEqual(ScriptPipelineStage.completed.title, "资产已就绪")
    }
}
