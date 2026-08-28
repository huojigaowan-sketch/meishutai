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


upgrade_v6.patch_imported_catalog = robust_patch_imported_catalog
upgrade_v6.main()
repair_generated_swift_newline_literals()
