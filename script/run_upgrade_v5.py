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


def post_patch_generated_sources() -> None:
    # Swift argument labels must follow the declaration order in Swift 6.
    store_path = "美术台/Stores/ArtDepartmentV2Store.swift"
    store = upgrade_v5.read(store_path)
    wrong = '''                    notes: "输入会自动保存为实验分支。",
                    isPromptLocked: false,
                    lifecycleRawValue: StylePromptLifecycle.experiment.rawValue,
                    sampleMedia: []
'''
    correct = '''                    notes: "输入会自动保存为实验分支。",
                    lifecycleRawValue: StylePromptLifecycle.experiment.rawValue,
                    sampleMedia: [],
                    isPromptLocked: false
'''
    if wrong not in store:
        raise RuntimeError("generated external style initializer anchor missing")
    upgrade_v5.write(store_path, store.replace(wrong, correct, 1))

    extension_path = "美术台/Stores/ArtDepartmentV2Store+StyleLibraryV4.swift"
    extension = upgrade_v5.read(extension_path)
    wrong_root = '''            notes: notes,
            isPromptLocked: false,
            parentID: parentID,
            lifecycleRawValue: (publish ? StylePromptLifecycle.library : .experiment).rawValue,
            branchLabel: parentID == nil ? "根风格" : "变化分支",
            branchOrder: nextBranchOrder(parentID: parentID),
            revisionNumber: 1,
            sampleMedia: []
'''
    correct_root = '''            notes: notes,
            parentID: parentID,
            lifecycleRawValue: (publish ? StylePromptLifecycle.library : .experiment).rawValue,
            branchLabel: parentID == nil ? "根风格" : "变化分支",
            branchOrder: nextBranchOrder(parentID: parentID),
            revisionNumber: 1,
            sampleMedia: [],
            isPromptLocked: false
'''
    wrong_draft = '''                notes: "输入即持久化；测试结果会自动成为加密样板。",
                isPromptLocked: false,
                lifecycleRawValue: StylePromptLifecycle.experiment.rawValue,
                branchLabel: "外部实验",
                revisionNumber: 1,
                sampleMedia: []
'''
    correct_draft = '''                notes: "输入即持久化；测试结果会自动成为加密样板。",
                lifecycleRawValue: StylePromptLifecycle.experiment.rawValue,
                branchLabel: "外部实验",
                revisionNumber: 1,
                sampleMedia: [],
                isPromptLocked: false
'''
    for label, old, new in (
        ("root style initializer", wrong_root, correct_root),
        ("external experiment initializer", wrong_draft, correct_draft),
    ):
        if old not in extension:
            raise RuntimeError(f"{label} anchor missing")
        extension = extension.replace(old, new, 1)

    # Persist keystroke edits without writing the encrypted vault for every key.
    extension = extension.replace(
        '''            document.styleCards[index].updatedAt = .now
            Task { await persist() }
            return
''',
        '''            document.styleCards[index].updatedAt = .now
            scheduleExternalDraftPersist()
            return
''',
        1,
    )
    extension = extension.replace(
        '''        Task { await persist() }
    }

    func restoreExternalStyleDraft()''',
        '''        scheduleExternalDraftPersist()
    }

    func restoreExternalStyleDraft()''',
        1,
    )
    helper_anchor = '''    private func nextBranchOrder(parentID: UUID?) -> Int {
'''
    helper = '''    private func scheduleExternalDraftPersist() {
        externalDraftSaveTask?.cancel()
        externalDraftSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await self?.persist()
        }
    }

'''
    if helper_anchor not in extension:
        raise RuntimeError("external draft debounce insertion anchor missing")
    extension = extension.replace(helper_anchor, helper + helper_anchor, 1)
    upgrade_v5.write(extension_path, extension)

    # Xcode 27 renamed the preferred GenerationOptions argument.
    for path in (
        "美术台/Services/AppleStructuredExtractionEngine.swift",
        "美术台/Services/AssetReliabilityV4.swift",
    ):
        source = upgrade_v5.read(path).replace(
            "GenerationOptions(sampling: .greedy)",
            "GenerationOptions(samplingMode: .greedy)",
        )
        upgrade_v5.write(path, source)

    # LanguageModelSession usage accounting is a macOS 27 API. Keep it in the
    # shipping target while allowing pure unit tests to compile on the hosted
    # macOS 26 compatibility host used by the Xcode 27 runner.
    apple_path = "美术台/Services/AppleStructuredExtractionEngine.swift"
    apple = upgrade_v5.read(apple_path)
    old_apple_usage = '''        logger.debug("Structured generation used \\(response.usage.totalTokenCount, privacy: .public) tokens")
'''
    new_apple_usage = '''        if #available(macOS 27.0, *) {
            logger.debug("Structured generation used \\(response.usage.totalTokenCount, privacy: .public) tokens")
        }
'''
    if old_apple_usage not in apple:
        raise RuntimeError("Apple usage logging anchor missing")
    upgrade_v5.write(apple_path, apple.replace(old_apple_usage, new_apple_usage, 1))

    reliability_path = "美术台/Services/AssetReliabilityV4.swift"
    reliability = upgrade_v5.read(reliability_path)
    old_reliability_usage = '''        let tokens = session.usage.totalTokenCount
        logger.debug("Reliability adjudication used \\(tokens, privacy: .public) tokens")
'''
    new_reliability_usage = '''        let tokens: Int
        if #available(macOS 27.0, *) {
            tokens = session.usage.totalTokenCount
            logger.debug("Reliability adjudication used \\(tokens, privacy: .public) tokens")
        } else {
            tokens = 0
        }
'''
    if old_reliability_usage not in reliability:
        raise RuntimeError("Reliability usage logging anchor missing")
    upgrade_v5.write(
        reliability_path,
        reliability.replace(old_reliability_usage, new_reliability_usage, 1),
    )


upgrade_v5.patch_catalog = robust_patch_catalog
upgrade_v5.main()
post_patch_generated_sources()
