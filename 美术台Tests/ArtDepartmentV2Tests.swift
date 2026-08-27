import XCTest
@testable import 美术台

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
        XCTAssertTrue(scenes.first?.paragraphs.contains(where: { $0.element == .character && $0.text == "女儿" }) == true)
        XCTAssertTrue(scenes.first?.paragraphs.contains(where: { $0.element == .dialogue }) == true)
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

    func testLowConfidenceAssetRequiresReview() {
        let asset = ProductionAsset(
            kind: .prop,
            canonicalName: "护照",
            summary: "关键道具",
            visualDescription: "一本护照",
            sourceEvidence: [EvidenceQuote(sceneID: UUID(), sceneHeading: "内. 厨房 - 夜", quote: "护照", explanation: "逐字证据")],
            modelConfidence: 0.7,
            validatedConfidence: 0.78,
            firstSceneOrder: 0
        )
        XCTAssertTrue(asset.requiresReview)
    }
}
