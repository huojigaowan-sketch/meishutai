#!/usr/bin/env python3
from __future__ import annotations

import re

import upgrade_v6


def robust_patch_imported_catalog() -> None:
    path = "美术台/Models/ImportedStylePromptCatalog.swift"
    text = upgrade_v6.read(path)
    text = upgrade_v6.replace_once(
        text,
        "    static let cards: [StylePromptCard] = [\n",
        "    private static let upstreamCards: [StylePromptCard] = [\n",
        "private upstream style cards",
    )
    replacement = """
    ]

    /// Public cards are compiled from the pinned upstream source into
    /// subject-neutral visual treatments. The raw vendored prompts remain
    /// private provenance data and never enter the runtime style library.
    static let cards: [StylePromptCard] = upstreamCards.enumerated().map { pair in
        StyleOnlyPromptPolicy.purifiedBuiltInCard(pair.element, index: pair.offset)
    }
}
"""
    updated, count = re.subn(r"\n    \]\n\}\s*$", replacement, text, count=1)
    if count != 1:
        raise RuntimeError("imported catalog ending anchor missing")
    upgrade_v6.write(path, updated)


def repair_generated_swift_newline_literals() -> None:
    for path in (
        "美术台/Services/AssetReliabilityV4.swift",
        "美术台/Services/ArtDepartmentV2Pipeline.swift",
    ):
        text = upgrade_v6.read(path)
        text = text.replace('"\n"', r'"\n"')
        text = text.replace('"\n\n"', r'"\n\n"')
        text = text.replace(
            '"【资产设计层——唯一主体来源】\n\\(assetDesign)"',
            r'"【资产设计层——唯一主体来源】\n\(assetDesign)"',
        )
        text = text.replace(
            '"【视觉风格层——只改变表现方式】\n\\(styleTreatment)"',
            r'"【视觉风格层——只改变表现方式】\n\(styleTreatment)"',
        )
        text = text.replace(
            '"【生成任务】\n\\(modeInstruction(mode))\n\\(direction)"',
            r'"【生成任务】\n\(modeInstruction(mode))\n\(direction)"',
        )
        upgrade_v6.write(path, text)


def repair_incremental_branch_test() -> None:
    path = "美术台Tests/ArtDepartmentV2Tests.swift"
    text = upgrade_v6.read(path)
    pattern = r"    func testStylePromptBranchesResolveIncrementally\(\) \{.*?\n    \}\n\n    func testReliabilityV4"
    replacement = """    func testStylePromptBranchesResolveIncrementally() {
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

    func testReliabilityV4"""
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError("incremental branch test anchor missing")
    upgrade_v6.write(path, updated)


upgrade_v6.patch_imported_catalog = robust_patch_imported_catalog
upgrade_v6.main()
repair_generated_swift_newline_literals()
repair_incremental_branch_test()
