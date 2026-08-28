#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


def patch_asset_usability() -> None:
    path = "美术台/Models/ArtDepartmentV2Models.swift"
    text = read(path)
    text = replace_once(
        text,
        """    var isUsable: Bool {
        reviewDecision == .accepted
            && !canonicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && sourceEvidence.contains { !$0.quote.isEmpty }
    }
""",
        """    var isUsable: Bool {
        reviewDecision == .accepted
            && !canonicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && sourceEvidence.contains { !$0.quote.isEmpty }
            && AssetDesignReadiness.isReady(self)
    }
""",
        "generation-ready production asset gate",
    )
    write(path, text)


def patch_prompt_freshness() -> None:
    path = "美术台/Stores/ArtDepartmentV2Store.swift"
    text = read(path)
    text = replace_once(
        text,
        """            if promptPlan.positivePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || promptPlan.mode != generationMode
                || promptPlan.chosenStyleCardIDs != cards.map(\.id)
            {
""",
        """            if promptPlan.requiresRebuild(
                for: asset,
                styleCards: cards,
                mode: generationMode
            ) {
""",
        "asset/style prompt freshness",
    )
    write(path, text)


def patch_style_subject_lexicon() -> None:
    path = "美术台/Models/StyleOnlyPromptPolicy.swift"
    text = read(path)
    anchor = '''            (#"[一二两三四五六七八九十0-9]+(个|名|位|把|辆|本|间|座)[^，。；\\n]{0,24}(男人|女人|女孩|男孩|人物|角色|火车|汽车|房间|厨房|卧室|街道|建筑|刀|剑|枪|瓶|手机|道具)"#, "包含可识别的具体资产描述"),
'''
    insertion = anchor + '''            (#"(?i)\\b(kitchen|bedroom|living room|classroom|hospital room|train|car|logo|passport|phone|sword|gun|bottle|table|chair|cabinet|stove|mother|father|daughter|son|girl|boy|woman|man|doctor|police officer|soldier)\\b"#, "包含具体人物、地点或物件名词"),
            (#"(厨房|卧室|客厅|教室|病房|楼道|火车|汽车|护照|手机|刀|剑|枪|瓶子|桌子|椅子|柜子|灶台|米缸|母亲|父亲|女儿|儿子|女孩|男孩|女人|男人|老人|医生|警察|士兵)"#, "包含具体人物、地点或物件名词"),
'''
    text = replace_once(text, anchor, insertion, "concrete subject lexicon")
    write(path, text)


def patch_tests() -> None:
    path = "美术台Tests/ArtDepartmentV2Tests.swift"
    text = read(path)
    text = text.replace(
        "func testWorkspaceSchemaIsAutomaticV5()",
        "func testWorkspaceSchemaIsAutomaticV6()",
        1,
    )
    text = replace_once(
        text,
        '''            summary: "关键道具",
            visualDescription: "一本护照",
            sourceEvidence: [
                EvidenceQuote(
                    sceneID: UUID(),
                    sceneHeading: "内. 厨房 - 夜",
                    quote: "护照",
                    explanation: "逐字证据"
                )
            ],
''',
        '''            summary: "关键道具",
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
''',
        "usable prop design facts fixture",
    )
    text = replace_once(
        text,
        '''        XCTAssertThrowsError(try StyleOnlyPromptPolicy.validatedUserPrompt(
            "A young woman wearing a red dress stands in a kitchen holding a passport."
        ))
        XCTAssertNoThrow(try StyleOnlyPromptPolicy.validatedUserPrompt(
''',
        '''        XCTAssertThrowsError(try StyleOnlyPromptPolicy.validatedUserPrompt(
            "A young woman wearing a red dress stands in a kitchen holding a passport."
        ))
        XCTAssertThrowsError(try StyleOnlyPromptPolicy.validatedUserPrompt(
            "厨房里的女孩拿着护照，电影级写实摄影与柔和光线。"
        ))
        XCTAssertNoThrow(try StyleOnlyPromptPolicy.validatedUserPrompt(
''',
        "Chinese concrete style rejection",
    )
    text = replace_once(
        text,
        '''        XCTAssertFalse(AssetDesignReadiness.isReady(prop))
        XCTAssertTrue(AssetDesignReadiness.missingReason(prop).contains("只有名称"))
    }

}
''',
        '''        XCTAssertFalse(AssetDesignReadiness.isReady(prop))
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

}
''',
        "prompt freshness tests",
    )
    write(path, text)


def main() -> None:
    patch_asset_usability()
    patch_prompt_freshness()
    patch_style_subject_lexicon()
    patch_tests()
    print("V6 final safety patch applied")


if __name__ == "__main__":
    main()
