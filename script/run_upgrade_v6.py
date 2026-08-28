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


upgrade_v6.patch_imported_catalog = robust_patch_imported_catalog
upgrade_v6.main()
