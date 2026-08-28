#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import urllib.request
import uuid

import upgrade_v5


def robust_patch_catalog() -> None:
    path = "美术台/Models/ImportedStylePromptCatalog.swift"
    text = upgrade_v5.read(path)
    if text.count("sampleMedia:") == 56:
        return

    revision = "7c065c2b429bc75334239965768849cb00c8987d"
    files = [
        "references/app-web-design.json",
        "references/comic-storyboard.json",
        "references/ecommerce-main-image.json",
        "references/game-asset.json",
        "references/infographic-edu-visual.json",
        "references/others.json",
        "references/poster-flyer.json",
        "references/profile-avatar.json",
    ]
    upstream: dict[tuple[str, str], list[str]] = {}
    for source_path in files:
        url = (
            "https://raw.githubusercontent.com/YouMind-OpenLab/"
            f"ai-image-prompts-skill/{revision}/{source_path}"
        )
        request = urllib.request.Request(
            url,
            headers={"User-Agent": "Meishutai-V5-Migration"},
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            records = json.load(response)
        for record in records:
            media = [
                item
                for item in (record.get("sourceMedia") or [])
                if isinstance(item, str) and item.startswith("https://")
            ]
            upstream[(source_path, str(record.get("id")))] = media

    starts = list(re.finditer(r"^        StylePromptCard\(", text, re.M))
    if len(starts) != 56:
        raise RuntimeError(f"expected 56 StylePromptCard starts, found {len(starts)}")

    output: list[str] = [text[: starts[0].start()]]
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        block = text[match.start() : end]
        card_id = re.search(r'UUID\(uuidString: "([0-9A-F-]+)"\)', block)
        source_path = re.search(r'\n\s+path: "([^"]+)"', block)
        original_id = re.search(r'\n\s+originalID: "([^"]+)"', block)
        if not (card_id and source_path and original_id):
            raise RuntimeError(f"could not parse card {index + 1} provenance")
        media = upstream.get((source_path.group(1), original_id.group(1)), [])
        if not media:
            raise RuntimeError(
                f"catalog card {original_id.group(1)} has no upstream sourceMedia"
            )
        namespace = uuid.UUID(card_id.group(1))
        media_lines: list[str] = []
        for offset, raw_url in enumerate(media[:6], start=1):
            sample_id = uuid.uuid5(namespace, raw_url)
            media_lines.append(
                "                StyleSampleMedia(\n"
                f"                    id: UUID(uuidString: \"{str(sample_id).upper()}\")!,\n"
                f"                    remoteURLString: {json.dumps(raw_url, ensure_ascii=False)},\n"
                f"                    sourceLabel: \"上游完整样板 {offset}\"\n"
                "                )"
            )
        insertion = (
            "            sampleMedia: [\n"
            + ",\n".join(media_lines)
            + "\n            ],\n"
        )
        if "            isPromptLocked: true,\n" not in block:
            raise RuntimeError(f"card {index + 1} missing insertion anchor")
        output.append(
            block.replace(
                "            isPromptLocked: true,\n",
                insertion + "            isPromptLocked: true,\n",
                1,
            )
        )

    updated = "".join(output)
    if updated.count("sampleMedia:") != 56:
        raise RuntimeError(
            f"not every imported style card received sample media: {updated.count('sampleMedia:')}"
        )
    upgrade_v5.write(path, updated)


upgrade_v5.patch_catalog = robust_patch_catalog
upgrade_v5.main()
