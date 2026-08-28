#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one anchor, found {count}")
    return text.replace(old, new, 1)


def replace_regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    result, count = re.subn(pattern, replacement, text, count=1, flags=re.S | re.M)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one regex match, found {count}")
    return result


def patch_models() -> None:
    path = "美术台/Models/ArtDepartmentV2Models.swift"
    text = read(path)
    if "struct AssetConfidenceBreakdown" not in text:
        anchor = "nonisolated struct AssetAutomationSummary: Codable, Hashable, Sendable {"
        insertion = r'''nonisolated struct AssetConfidenceBreakdown: Codable, Hashable, Sendable {
    var deterministicEvidence: Double
    var exactQuoteCoverage: Double
    var independentAgreement: Double
    var crossSceneSupport: Double
    var identityStability: Double
    var continuityConsistency: Double
    var schemaCompleteness: Double
    var modelCalibration: Double

    var weightedScore: Double {
        let values = [
            deterministicEvidence,
            exactQuoteCoverage,
            independentAgreement,
            crossSceneSupport,
            identityStability,
            continuityConsistency,
            schemaCompleteness,
            modelCalibration,
        ].map { min(1, max(0, $0)) }
        let raw = values[0] * 0.18
            + values[1] * 0.22
            + values[2] * 0.18
            + values[3] * 0.10
            + values[4] * 0.10
            + values[5] * 0.08
            + values[6] * 0.07
            + values[7] * 0.07
        // A non-deterministic candidate cannot earn the format-evidence share.
        // Normalize against the maximum available evidence path so a fully
        // corroborated prop or non-speaking character can still reach 100%.
        let availableMaximum = values[0] >= 0.999 ? 1.0 : 0.82
        return min(1, raw / availableMaximum)
    }
}

nonisolated struct AssetReliabilityAudit: Codable, Hashable, Sendable {
    var version: Int
    var sceneCount: Int
    var candidateCount: Int
    var productionCount: Int
    var quarantinedCount: Int
    var deterministicCount: Int
    var independentlyVerifiedCount: Int
    var exactEvidenceRejectedCount: Int
    var preventedSemanticMergeCount: Int
    var productionThreshold: Double
    var engineNames: [String]
    var elapsedMilliseconds: Int
    var completedAt: Date
}

'''
        text = replace_once(text, anchor, insertion + anchor, "insert reliability models")

    if "var confidenceBreakdown: AssetConfidenceBreakdown?" not in text:
        text = replace_once(
            text,
            "    var verificationReport: AssetVerificationReport?\n",
            "    var verificationReport: AssetVerificationReport?\n"
            "    var confidenceBreakdown: AssetConfidenceBreakdown?\n"
            "    var independentVerdictCount: Int?\n"
            "    var identityFingerprint: String?\n"
            "    var continuityVariantKey: String?\n",
            "production asset reliability fields",
        )
        text = replace_once(
            text,
            "        verificationReport: AssetVerificationReport? = nil\n",
            "        verificationReport: AssetVerificationReport? = nil,\n"
            "        confidenceBreakdown: AssetConfidenceBreakdown? = nil,\n"
            "        independentVerdictCount: Int? = nil,\n"
            "        identityFingerprint: String? = nil,\n"
            "        continuityVariantKey: String? = nil\n",
            "production asset reliability init params",
        )
        text = replace_once(
            text,
            "        self.verificationReport = verificationReport\n",
            "        self.verificationReport = verificationReport\n"
            "        self.confidenceBreakdown = confidenceBreakdown\n"
            "        self.independentVerdictCount = independentVerdictCount\n"
            "        self.identityFingerprint = identityFingerprint\n"
            "        self.continuityVariantKey = continuityVariantKey\n",
            "production asset reliability assignments",
        )

    if "var parentID: UUID?" not in text:
        text = replace_once(
            text,
            "    var referenceImagePath: String?\n    var isPromptLocked: Bool\n",
            "    var referenceImagePath: String?\n"
            "    var parentID: UUID?\n"
            "    var lifecycleRawValue: String?\n"
            "    var branchLabel: String?\n"
            "    var branchOrder: Int?\n"
            "    var revisionNumber: Int?\n"
            "    var archivedAt: Date?\n"
            "    var sampleMedia: [StyleSampleMedia]?\n"
            "    var isPromptLocked: Bool\n",
            "style hierarchy fields",
        )
        text = replace_once(
            text,
            "        referenceImagePath: String? = nil,\n        isPromptLocked: Bool = true,\n",
            "        referenceImagePath: String? = nil,\n"
            "        parentID: UUID? = nil,\n"
            "        lifecycleRawValue: String? = nil,\n"
            "        branchLabel: String? = nil,\n"
            "        branchOrder: Int? = nil,\n"
            "        revisionNumber: Int? = nil,\n"
            "        archivedAt: Date? = nil,\n"
            "        sampleMedia: [StyleSampleMedia]? = nil,\n"
            "        isPromptLocked: Bool = true,\n",
            "style hierarchy init params",
        )
        text = replace_once(
            text,
            "        self.referenceImagePath = referenceImagePath\n        self.isPromptLocked = isPromptLocked\n",
            "        self.referenceImagePath = referenceImagePath\n"
            "        self.parentID = parentID\n"
            "        self.lifecycleRawValue = lifecycleRawValue\n"
            "        self.branchLabel = branchLabel\n"
            "        self.branchOrder = branchOrder\n"
            "        self.revisionNumber = revisionNumber\n"
            "        self.archivedAt = archivedAt\n"
            "        self.sampleMedia = sampleMedia\n"
            "        self.isPromptLocked = isPromptLocked\n",
            "style hierarchy assignments",
        )

    if "var reliabilityAudit: AssetReliabilityAudit?" not in text:
        text = replace_once(
            text,
            "    var engineStatus: AppleEngineStatusSnapshot?\n",
            "    var engineStatus: AppleEngineStatusSnapshot?\n"
            "    var reliabilityAudit: AssetReliabilityAudit?\n",
            "project reliability field",
        )
        text = replace_once(
            text,
            "        engineStatus: AppleEngineStatusSnapshot? = nil\n",
            "        engineStatus: AppleEngineStatusSnapshot? = nil,\n"
            "        reliabilityAudit: AssetReliabilityAudit? = nil\n",
            "project reliability init",
        )
        text = replace_once(
            text,
            "        self.engineStatus = engineStatus\n",
            "        self.engineStatus = engineStatus\n"
            "        self.reliabilityAudit = reliabilityAudit\n",
            "project reliability assignment",
        )

    text = text.replace("schemaVersion: 4,", "schemaVersion: 5,")
    if "case styleSampleRequired" not in text:
        text = replace_once(
            text,
            "    case unsupportedFile\n",
            "    case unsupportedFile\n"
            "    case styleSampleRequired\n"
            "    case cannotModifyBuiltIn\n"
            "    case styleBranchCycle\n"
            "    case remoteSampleUnavailable\n",
            "new style errors",
        )
        text = replace_once(
            text,
            "        case .unsupportedFile: \"当前文件格式不受支持。请使用 TXT、Markdown、Fountain、FDX、PDF 或图片。\"\n",
            "        case .unsupportedFile: \"当前文件格式不受支持。请使用 TXT、Markdown、Fountain、FDX、PDF 或图片。\"\n"
            "        case .styleSampleRequired: \"正式风格节点必须至少有一张完整样板图；实验分支可以先保存再测试。\"\n"
            "        case .cannotModifyBuiltIn: \"内置开源模板不可直接修改或删除，请在它下面建立可编辑分支。\"\n"
            "        case .styleBranchCycle: \"风格分支不能把自身或后代设为父节点。\"\n"
            "        case .remoteSampleUnavailable: \"上游样板图暂时不可用，可稍后重试或为分支上传本地样板。\"\n",
            "new style error descriptions",
        )
    write(path, text)


def patch_catalog() -> None:
    path = "美术台/Models/ImportedStylePromptCatalog.swift"
    text = read(path)
    if "sampleMedia:" in text:
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
        request = urllib.request.Request(url, headers={"User-Agent": "Meishutai-V5-Migration"})
        with urllib.request.urlopen(request, timeout=120) as response:
            records = json.load(response)
        for record in records:
            media = [
                item for item in (record.get("sourceMedia") or [])
                if isinstance(item, str) and item.startswith("https://")
            ]
            upstream[(source_path, str(record.get("id")))] = media

    pattern = re.compile(
        r"^        StylePromptCard\(\n.*?^        \),(?=\n        StylePromptCard\(|\n    \])",
        re.S | re.M,
    )
    blocks = pattern.findall(text)
    if len(blocks) != 56:
        raise RuntimeError(f"expected 56 catalog cards, found {len(blocks)}")
    replacements: dict[str, str] = {}
    for block in blocks:
        card_id = re.search(r'UUID\(uuidString: "([0-9A-F-]+)"\)', block)
        source_path = re.search(r'path: "([^"]+)"', block)
        original_id = re.search(r'originalID: "([^"]+)"', block)
        if not (card_id and source_path and original_id):
            raise RuntimeError("could not parse catalog card provenance")
        media = upstream.get((source_path.group(1), original_id.group(1)), [])
        if not media:
            raise RuntimeError(
                f"catalog card {original_id.group(1)} has no upstream sourceMedia"
            )
        media_lines = []
        namespace = uuid.UUID(card_id.group(1))
        for offset, url in enumerate(media[:6], start=1):
            sample_id = uuid.uuid5(namespace, url)
            media_lines.append(
                "                StyleSampleMedia(\n"
                f"                    id: UUID(uuidString: \"{str(sample_id).upper()}\")!,\n"
                f"                    remoteURLString: {json.dumps(url, ensure_ascii=False)},\n"
                f"                    sourceLabel: \"上游完整样板 {offset}\"\n"
                "                )"
            )
        insertion = "            sampleMedia: [\n" + ",\n".join(media_lines) + "\n            ],\n"
        updated = block.replace("            isPromptLocked: true,\n", insertion + "            isPromptLocked: true,\n", 1)
        replacements[block] = updated
    for old, new in replacements.items():
        text = text.replace(old, new, 1)
    if text.count("sampleMedia:") != 56:
        raise RuntimeError("not every imported style card received sample media")
    write(path, text)


def patch_persistence() -> None:
    path = "美术台/Services/ArtDepartmentV2Persistence.swift"
    text = read(path)
    if "import AppKit" not in text:
        text = "import AppKit\n" + text
    if "private let legacyVaultURL" not in text:
        text = replace_once(
            text,
            "    private let legacyDocumentURL: URL\n    private let vaultURL: URL\n    private let backupsURL: URL\n    private let styleImagesURL: URL\n    private let generatedImagesURL: URL\n",
            "    private let legacyDocumentURL: URL\n"
            "    private let legacyVaultURL: URL\n"
            "    private let vaultURL: URL\n"
            "    private let backupsURL: URL\n"
            "    private let styleImagesURL: URL\n"
            "    private let styleSamplesURL: URL\n"
            "    private let generatedImagesURL: URL\n",
            "persistence URL fields",
        )
        text = replace_once(
            text,
            "        legacyDocumentURL = rootURL.appending(path: \"workspace-v2.json\")\n"
            "        vaultURL = rootURL.appending(path: \"workspace-v4.vault\")\n"
            "        backupsURL = rootURL.appending(path: \"vault-backups\", directoryHint: .isDirectory)\n"
            "        styleImagesURL = rootURL.appending(path: \"style-images\", directoryHint: .isDirectory)\n"
            "        generatedImagesURL = rootURL.appending(path: \"generated-images\", directoryHint: .isDirectory)\n",
            "        legacyDocumentURL = rootURL.appending(path: \"workspace-v2.json\")\n"
            "        legacyVaultURL = rootURL.appending(path: \"workspace-v4.vault\")\n"
            "        vaultURL = rootURL.appending(path: \"workspace-v5.vault\")\n"
            "        backupsURL = rootURL.appending(path: \"vault-backups\", directoryHint: .isDirectory)\n"
            "        styleImagesURL = rootURL.appending(path: \"style-images\", directoryHint: .isDirectory)\n"
            "        styleSamplesURL = rootURL.appending(path: \"style-samples\", directoryHint: .isDirectory)\n"
            "        generatedImagesURL = rootURL.appending(path: \"generated-images\", directoryHint: .isDirectory)\n",
            "persistence URL init",
        )
        text = replace_once(
            text,
            "        if fileManager.fileExists(atPath: vaultURL.path) {\n"
            "            let encrypted = try Data(contentsOf: vaultURL)\n"
            "            let plaintext = try StyleLibraryVault.open(encrypted, using: key)\n"
            "            document = try JSONDecoder.artDepartment.decode(ArtDepartmentWorkspaceDocument.self, from: plaintext)\n"
            "        } else if fileManager.fileExists(atPath: legacyDocumentURL.path) {\n",
            "        if fileManager.fileExists(atPath: vaultURL.path) {\n"
            "            let encrypted = try Data(contentsOf: vaultURL)\n"
            "            let plaintext = try StyleLibraryVault.open(encrypted, using: key)\n"
            "            document = try JSONDecoder.artDepartment.decode(ArtDepartmentWorkspaceDocument.self, from: plaintext)\n"
            "        } else if fileManager.fileExists(atPath: legacyVaultURL.path) {\n"
            "            let encrypted = try Data(contentsOf: legacyVaultURL)\n"
            "            let plaintext = try StyleLibraryVault.open(encrypted, using: key)\n"
            "            document = try JSONDecoder.artDepartment.decode(ArtDepartmentWorkspaceDocument.self, from: plaintext)\n"
            "            shouldPersistMigration = true\n"
            "        } else if fileManager.fileExists(atPath: legacyDocumentURL.path) {\n",
            "load legacy vault",
        )
        old_builtins = """        let knownBuiltIns = Set(document.styleCards.filter(\\.isBuiltIn).map(\\.id))
        let missingBuiltIns = BuiltInStylePromptCatalog.cards.filter { !knownBuiltIns.contains($0.id) }
        if !missingBuiltIns.isEmpty {
            document.styleCards.append(contentsOf: missingBuiltIns)
            shouldPersistMigration = true
        }
"""
        new_builtins = """        if mergePinnedBuiltIns(into: &document) {
            shouldPersistMigration = true
        }
"""
        text = replace_once(text, old_builtins, new_builtins, "merge pinned built-ins")
        text = text.replace("document.schemaVersion = max(4, document.schemaVersion)", "document.schemaVersion = max(5, document.schemaVersion)")

    if "func importStyleSample(" not in text:
        anchor = "    func saveGeneratedImage(\n"
        methods = r'''    func importStyleSample(
        data: Data,
        cardID: UUID,
        sampleID: UUID
    ) throws -> PersistedStyleSamplePayload {
        try prepareDirectories()
        try StyleSampleValidator.validate(data)
        let folder = styleSamplesURL.appending(path: cardID.uuidString, directoryHint: .isDirectory)
        try createProtectedDirectory(folder)
        let relative = "style-samples/\(cardID.uuidString)/\(sampleID.uuidString).vault"
        let destination = rootURL.appending(path: relative)
        let encrypted = try StyleLibraryVault.seal(data, using: vaultKey())
        try writeProtected(encrypted, to: destination)
        return PersistedStyleSamplePayload(
            path: relative,
            sha256: StyleSampleValidator.sha256(data),
            data: data
        )
    }

    func cacheRemoteStyleSample(
        from sourceURL: URL,
        cardID: UUID,
        sampleID: UUID
    ) async throws -> PersistedStyleSamplePayload {
        guard sourceURL.scheme?.lowercased() == "https" else {
            throw ArtDepartmentV2Error.remoteSampleUnavailable
        }
        var request = URLRequest(
            url: sourceURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 90
        )
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              data.count <= StyleSampleValidator.maximumBytes
        else { throw ArtDepartmentV2Error.remoteSampleUnavailable }
        try StyleSampleValidator.validate(data)
        return try importStyleSample(data: data, cardID: cardID, sampleID: sampleID)
    }

    func deleteStyleMedia(at relativePath: String?) throws {
        guard let relativePath,
              (relativePath.hasPrefix("style-samples/") || relativePath.hasPrefix("style-images/")),
              let url = absoluteURL(for: relativePath),
              fileManager.fileExists(atPath: url.path)
        else { return }
        try fileManager.removeItem(at: url)
    }

'''
        text = replace_once(text, anchor, methods + anchor, "style sample persistence methods")

    if "private func mergePinnedBuiltIns" not in text:
        anchor = "    private func migratePlaintextStyleImages(\n"
        helper = r'''    private func mergePinnedBuiltIns(
        into document: inout ArtDepartmentWorkspaceDocument
    ) -> Bool {
        var changed = false
        let pinned = Dictionary(uniqueKeysWithValues: BuiltInStylePromptCatalog.cards.map { ($0.id, $0) })
        let originalCount = document.styleCards.count
        document.styleCards.removeAll { card in
            card.isBuiltIn && pinned[card.id] == nil
        }
        changed = changed || originalCount != document.styleCards.count

        for pinnedCard in BuiltInStylePromptCatalog.cards {
            if let index = document.styleCards.firstIndex(where: { $0.id == pinnedCard.id }) {
                let cached = Dictionary(uniqueKeysWithValues: document.styleCards[index].styleSampleMedia.map {
                    ($0.id, $0)
                })
                var updated = pinnedCard
                updated.sampleMedia = pinnedCard.styleSampleMedia.map { sample in
                    guard let existing = cached[sample.id] else { return sample }
                    var merged = sample
                    merged.encryptedLocalPath = existing.encryptedLocalPath
                    merged.sha256 = existing.sha256
                    return merged
                }
                if document.styleCards[index] != updated {
                    document.styleCards[index] = updated
                    changed = true
                }
            } else {
                document.styleCards.append(pinnedCard)
                changed = true
            }
        }
        return changed
    }

'''
        text = replace_once(text, anchor, helper + anchor, "pinned built-in merge helper")

    text = text.replace(
        'if relativePath.hasPrefix("style-images/") && url.pathExtension == "vault" {',
        'if (relativePath.hasPrefix("style-images/") || relativePath.hasPrefix("style-samples/")) && url.pathExtension == "vault" {',
    )
    if "try createProtectedDirectory(styleSamplesURL)" not in text:
        text = replace_once(
            text,
            "        try createProtectedDirectory(styleImagesURL)\n        try createProtectedDirectory(generatedImagesURL)\n",
            "        try createProtectedDirectory(styleImagesURL)\n"
            "        try createProtectedDirectory(styleSamplesURL)\n"
            "        try createProtectedDirectory(generatedImagesURL)\n",
            "prepare style sample directory",
        )
    write(path, text)


def patch_store() -> None:
    path = "美术台/Stores/ArtDepartmentV2Store.swift"
    text = read(path)
    if "var selectedStyleNodeID" not in text:
        text = replace_once(
            text,
            "    var showsDiagnostics = false\n",
            "    var showsDiagnostics = false\n"
            "    var selectedStyleNodeID: UUID?\n"
            "    var styleSearchText = \"\"\n"
            "    var showsArchivedStyles = false\n"
            "    var activeExternalStyleDraftID: UUID?\n"
            "    var styleSampleLoadingIDs: Set<UUID> = []\n"
            "    var styleSampleFailedIDs: Set<UUID> = []\n"
            "    @ObservationIgnored var externalDraftSaveTask: Task<Void, Never>?\n",
            "store V5 state",
        )
    text = text.replace(
        "@ObservationIgnored private let persistence = ArtDepartmentPersistence.shared",
        "@ObservationIgnored let persistence = ArtDepartmentPersistence.shared",
    )
    text = text.replace(
        "document.styleCards.filter { selectedStyleCardIDs.contains($0.id) }",
        "document.styleCards.filter { selectedStyleCardIDs.contains($0.id) && !$0.isArchived }",
    )
    if "restoreExternalStyleDraft()" not in text:
        text = replace_once(
            text,
            "            await reloadStyleImageCache()\n            await refreshEngineStatus()\n",
            "            await reloadStyleImageCache()\n"
            "            restoreExternalStyleDraft()\n"
            "            await refreshEngineStatus()\n",
            "restore persisted style experiment",
        )

    text = text.replace(
        "            $0.automationSummary = nil\n            $0.updatedAt = .now\n",
        "            $0.automationSummary = nil\n            $0.reliabilityAudit = nil\n            $0.updatedAt = .now\n",
    )

    if "$0.reliabilityAudit = extracted.audit" not in text:
        text = text.replace(
            "                $0.automationSummary = extracted.summary\n                $0.engineStatus = extracted.engineStatus\n",
            "                $0.automationSummary = extracted.summary\n"
            "                $0.reliabilityAudit = extracted.audit\n"
            "                $0.engineStatus = extracted.engineStatus\n",
        )
        text = text.replace(
            "                $0.automationSummary = result.summary\n                $0.engineStatus = result.engineStatus\n",
            "                $0.automationSummary = result.summary\n"
            "                $0.reliabilityAudit = result.audit\n"
            "                $0.engineStatus = result.engineStatus\n",
        )

    text = replace_regex_once(
        text,
        r"    func saveExternalStyleToLibrary\(\) \{.*?^    \}\n\n    func importGenerationReference",
        "    func saveExternalStyleToLibrary() {\n"
        "        promoteExternalStyleDraft()\n"
        "    }\n\n"
        "    func importGenerationReference",
        "replace external style publish",
    )

    text = text.replace(
        "            let cards = resolveStyleCards()\n            guard !cards.isEmpty else { throw ArtDepartmentV2Error.noSelectedStyle }\n",
        "            var cards = resolveStyleCards()\n"
        "            guard !cards.isEmpty else { throw ArtDepartmentV2Error.noSelectedStyle }\n"
        "            for card in cards { await ensureStyleSamples(for: card.id) }\n"
        "            cards = resolveStyleCards()\n",
    )
    old_refs = """            var references: [Data] = []
            for card in cards {
                if let data = try await persistence.data(for: card.referenceImagePath) {
                    references.append(data)
                }
            }
"""
    new_refs = """            var references: [Data] = []
            for card in cards {
                for sample in card.styleSampleMedia {
                    if let data = try await persistence.data(for: sample.encryptedLocalPath) {
                        references.append(data)
                    }
                }
            }
"""
    if old_refs in text:
        text = text.replace(old_refs, new_refs, 1)
    if "attachGeneratedSampleToActiveExperiment" not in text:
        text = replace_once(
            text,
            "            mutateProject {\n                $0.generatedImages.insert(contentsOf: records, at: 0)\n",
            "            if let firstPayload = payloads.first {\n"
            "                await attachGeneratedSampleToActiveExperiment(firstPayload.data)\n"
            "            }\n"
            "            mutateProject {\n                $0.generatedImages.insert(contentsOf: records, at: 0)\n",
            "persist generated experiment sample",
        )

    text = replace_regex_once(
        text,
        r"    private func resolveStyleCards\(\) -> \[StylePromptCard\] \{.*?^    \}\n\n    private func nearestDuplicateStyle",
        r'''    private func resolveStyleCards() -> [StylePromptCard] {
        var cards = selectedStyleCards.map {
            StylePromptResolver.resolvedCard($0, in: document.styleCards)
        }
        let prompt = externalStylePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty {
            if let draftID = activeExternalStyleDraftID,
               let draft = document.styleCards.first(where: { $0.id == draftID }),
               !cards.contains(where: { $0.id == draftID })
            {
                cards.append(StylePromptResolver.resolvedCard(draft, in: document.styleCards))
            } else if activeExternalStyleDraftID == nil {
                let title = externalStyleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                cards.append(StylePromptCard(
                    id: StyleSelectionPolicy.temporaryCardID,
                    title: title.isEmpty ? "本轮外部风格" : title,
                    prompt: prompt,
                    category: externalStyleCategory,
                    tags: ["持久化准备中", "用户明确选择"],
                    notes: "输入会自动保存为实验分支。",
                    isPromptLocked: false,
                    lifecycleRawValue: StylePromptLifecycle.experiment.rawValue,
                    sampleMedia: []
                ))
            }
        }
        return cards
    }

    private func nearestDuplicateStyle''',
        "resolve inherited style prompts",
    )

    text = replace_regex_once(
        text,
        r"    private func reloadStyleImageCache\(\) async \{.*?^    \}\n\n    private func refreshEngineStatus",
        r'''    private func reloadStyleImageCache() async {
        var cache: [String: Data] = [:]
        for card in document.styleCards {
            for sample in card.styleSampleMedia {
                guard let path = sample.encryptedLocalPath,
                      let data = try? await persistence.data(for: path)
                else { continue }
                cache[path] = data
            }
        }
        styleImageDataByPath = cache
    }

    private func refreshEngineStatus''',
        "reload encrypted style media",
    )
    text = text.replace("document.schemaVersion = max(4, document.schemaVersion)", "document.schemaVersion = max(5, document.schemaVersion)")
    text = text.replace("    private func persist() async {", "    func persist() async {")
    write(path, text)


def patch_views() -> None:
    path = "美术台/Views/ArtDepartmentV2Views.swift"
    text = read(path)
    text = text.replace("    @State private var isAddingStyle = false\n", "")
    text = replace_regex_once(
        text,
        r"        \.sheet\(isPresented: \$isAddingStyle\) \{.*?^        \}\n",
        "",
        "remove legacy style sheet",
    )
    text = replace_regex_once(
        text,
        r"            case \.styles:\n                StyleVaultWorkspace\(\n                    store: store,\n                    onAdd: \{ isAddingStyle = true \}\n                \)",
        "            case .styles:\n                StyleLibraryWorkspaceV4(store: store)",
        "route to V4 style library",
    )
    start = text.find("// MARK: - Style prompt vault")
    end = text.find("// MARK: - Generation studio")
    if start != -1 and end != -1 and start < end:
        text = text[:start] + "// MARK: - Style library lives in StyleLibraryV4Views.swift\n\n" + text[end:]

    text = text.replace(
        '            TextField("名称（可选）", text: $store.externalStyleTitle)\n',
        '            TextField("名称（可选）", text: $store.externalStyleTitle)\n'
        '                .onChange(of: store.externalStyleTitle) { _, _ in\n'
        '                    store.persistExternalStyleDraft()\n'
        '                }\n',
    )
    text = text.replace(
        "            .pickerStyle(.menu)\n            TextEditor(text: $store.externalStylePrompt)\n",
        "            .pickerStyle(.menu)\n"
        "            .onChange(of: store.externalStyleCategory) { _, _ in\n"
        "                store.persistExternalStyleDraft()\n"
        "            }\n"
        "            TextEditor(text: $store.externalStylePrompt)\n",
        1,
    )
    text = text.replace(
        "                }\n            Button(\"测试后存入风格图书馆\", systemImage: \"lock.doc\") {\n                store.saveExternalStyleToLibrary()\n            }\n",
        "                }\n"
        "                .onChange(of: store.externalStylePrompt) { _, _ in\n"
        "                    store.persistExternalStyleDraft()\n"
        "                }\n"
        "            Button(\"发布到风格图书馆\", systemImage: \"lock.doc\") {\n"
        "                store.saveExternalStyleToLibrary()\n"
        "            }\n"
        "            .help(\"外部实验已经自动持久化；发布前必须至少完成一次生成或上传样板。\")\n",
        1,
    )
    text = text.replace(
        "                ForEach(store.styleCards) { card in\n",
        "                ForEach(store.styleCards.filter { !$0.isArchived }) { card in\n",
        1,
    )
    marker = "                    Text(\"自动通过 \\(summary.usableCount) 项 · 隔离 \\(summary.quarantinedCount) 项 · 无需人工审阅\")\n                        .foregroundStyle(.secondary)\n"
    if marker in text and "V4 生产阈值" not in text:
        text = text.replace(
            marker,
            marker
            + "                    if let audit = store.currentProject?.reliabilityAudit {\n"
            + "                        Text(\"V4 生产阈值 \\(audit.productionThreshold, format: .percent.precision(.fractionLength(0))) · 独立裁决 \\(audit.independentlyVerifiedCount) 项 · 逐字证据拒绝 \\(audit.exactEvidenceRejectedCount) 项\")\n"
            + "                            .font(.caption)\n"
            + "                            .foregroundStyle(.secondary)\n"
            + "                    }\n",
            1,
        )
    write(path, text)


def patch_pipeline() -> None:
    path = "美术台/Services/ArtDepartmentV2Pipeline.swift"
    text = read(path)
    text = text.replace(
        "    static let cards = projectCards + ImportedStylePromptCatalog.cards",
        "    // Operation templates remain available to generation modes but are not\n"
        "    // style-library nodes because they do not define a visual sample.\n"
        "    static let cards = ImportedStylePromptCatalog.cards",
    )
    if "var audit: AssetReliabilityAudit" not in text:
        text = replace_once(
            text,
            "nonisolated struct AutomatedAssetExtractionResult: Sendable {\n"
            "    var assets: [ProductionAsset]\n"
            "    var summary: AssetAutomationSummary\n"
            "    var engineStatus: AppleEngineStatusSnapshot\n"
            "}\n",
            "nonisolated struct AutomatedAssetExtractionResult: Sendable {\n"
            "    var assets: [ProductionAsset]\n"
            "    var summary: AssetAutomationSummary\n"
            "    var engineStatus: AppleEngineStatusSnapshot\n"
            "    var audit: AssetReliabilityAudit\n"
            "}\n",
            "automated extraction audit result",
        )

    old = r'''        let consolidated = automaticConsolidation(allAssets)
        let usable = consolidated.filter(\.isUsable)
        guard !usable.isEmpty else { throw ArtDepartmentV2Error.noUsableAssets }
        let quarantined = consolidated.count { $0.isQuarantined }
        let rejected = consolidated.count { $0.reviewDecision == .rejected }
'''
    new = r'''        let consolidated = automaticConsolidation(allAssets)
        let reliability = AssetReliabilityV4.finalize(
            consolidated,
            sceneCount: ordered.count,
            engineNames: Array(usedEngines).sorted(),
            startedAt: startedAt
        )
        let reliableAssets = reliability.assets
        let usable = reliableAssets.filter(\.isUsable)
        guard !usable.isEmpty else { throw ArtDepartmentV2Error.noUsableAssets }
        let quarantined = reliableAssets.count { $0.isQuarantined }
        let rejected = reliableAssets.count { $0.reviewDecision == .rejected }
'''
    text = replace_once(text, old, new, "finalize V4 reliability")
    text = replace_once(
        text,
        "            assets: consolidated,\n            summary: summary,\n            engineStatus: engineStatus\n",
        "            assets: reliableAssets,\n"
        "            summary: summary,\n"
        "            engineStatus: engineStatus,\n"
        "            audit: reliability.audit\n",
        "return V4 reliability audit",
    )

    text = replace_regex_once(
        text,
        r"    private static func processScene\(\n        _ scene: CanonicalScene,\n        client: ArtChatCompletionClient\?\n    \) async -> SceneAutomationResult \{.*?^    \}\n\n    private static func validatedModelAssets",
        r'''    private static func processScene(
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
        let adjudication = await AssetReliabilityModelEngine.shared.adjudicate(
            scene: scene,
            candidates: assets,
            remote: client
        )
        assets = AssetReliabilityV4.applyAdjudication(
            adjudication,
            to: assets,
            scene: scene
        )
        return SceneAutomationResult(
            sceneOrder: scene.order,
            assets: assets,
            engineNames: Array(Set(bundle.engineNames + adjudication.engineNames)).sorted()
        )
    }

    private static func validatedModelAssets''',
        "independent scene adjudication",
    )

    semantic_pattern = r'''            let semanticIndex = exactIndex \?\? result\.firstIndex \{
                guard \$0\.kind == asset\.kind else \{ return false \}
                if asset\.kind == \.scene \{ return false \}
                return AppleLinguisticAnalyzer\.likelySameIdentity\(
                    \$0\.canonicalName,
                    asset\.canonicalName
                \)
            \}'''
    text, count = re.subn(
        semantic_pattern,
        "            // V4 never performs unreviewed semantic identity merges. Exact\n"
        "            // normalized names merge; ambiguous aliases remain separate.\n"
        "            let semanticIndex = exactIndex",
        text,
        count=1,
        flags=re.S,
    )
    if count != 1:
        raise RuntimeError(f"disable semantic merge: expected 1 match, found {count}")
    text = text.replace(
        "                    && AppleLinguisticAnalyzer.canonicalKey($0.canonicalName)\n"
        "                        == AppleLinguisticAnalyzer.canonicalKey(asset.canonicalName)\n",
        "                    && AppleLinguisticAnalyzer.canonicalKey($0.canonicalName)\n"
        "                        == AppleLinguisticAnalyzer.canonicalKey(asset.canonicalName)\n"
        "                    && continuityVariantsAreCompatible($0, asset)\n",
    )
    if "private static func continuityVariantsAreCompatible" not in text:
        text = text.replace(
            "    private static func merge(\n",
            "    private static func continuityVariantsAreCompatible(\n"
            "        _ lhs: ProductionAsset,\n"
            "        _ rhs: ProductionAsset\n"
            "    ) -> Bool {\n"
            "        let left = (lhs.continuityVariantKey ?? \"\")\n"
            "            .trimmingCharacters(in: .whitespacesAndNewlines)\n"
            "        let right = (rhs.continuityVariantKey ?? \"\")\n"
            "            .trimmingCharacters(in: .whitespacesAndNewlines)\n"
            "        return left.isEmpty || right.isEmpty\n"
            "            || AppleLinguisticAnalyzer.canonicalKey(left)\n"
            "                == AppleLinguisticAnalyzer.canonicalKey(right)\n"
            "    }\n\n"
            "    private static func merge(\n",
            1,
        )
    merge_anchor = "        merged.warnings = uniqueText(lhs.warnings + rhs.warnings)\n"
    if merge_anchor in text and "merged.independentVerdictCount" not in text:
        text = text.replace(
            merge_anchor,
            merge_anchor
            + "        merged.independentVerdictCount = (lhs.independentVerdictCount ?? 0)\n"
            + "            + (rhs.independentVerdictCount ?? 0)\n"
            + "        merged.identityFingerprint = lhs.identityFingerprint ?? rhs.identityFingerprint\n"
            + "        if lhs.continuityVariantKey == rhs.continuityVariantKey {\n"
            + "            merged.continuityVariantKey = lhs.continuityVariantKey\n"
            + "        }\n"
            + "        if let left = lhs.confidenceBreakdown, let right = rhs.confidenceBreakdown {\n"
            + "            merged.confidenceBreakdown = AssetConfidenceBreakdown(\n"
            + "                deterministicEvidence: max(left.deterministicEvidence, right.deterministicEvidence),\n"
            + "                exactQuoteCoverage: min(left.exactQuoteCoverage, right.exactQuoteCoverage),\n"
            + "                independentAgreement: max(left.independentAgreement, right.independentAgreement),\n"
            + "                crossSceneSupport: max(left.crossSceneSupport, right.crossSceneSupport),\n"
            + "                identityStability: min(left.identityStability, right.identityStability),\n"
            + "                continuityConsistency: min(left.continuityConsistency, right.continuityConsistency),\n"
            + "                schemaCompleteness: max(left.schemaCompleteness, right.schemaCompleteness),\n"
            + "                modelCalibration: max(left.modelCalibration, right.modelCalibration)\n"
            + "            )\n"
            + "        } else {\n"
            + "            merged.confidenceBreakdown = lhs.confidenceBreakdown ?? rhs.confidenceBreakdown\n"
            + "        }\n",
            1,
        )
    write(path, text)


def patch_apple_engine() -> None:
    path = "美术台/Services/AppleStructuredExtractionEngine.swift"
    text = read(path)
    if "Structured generation used" not in text:
        text = replace_once(
            text,
            "        let response = try await session.respond(\n"
            "            to: prompt,\n"
            "            generating: Output.self,\n"
            "            options: GenerationOptions(sampling: .greedy)\n"
            "        )\n"
            "        return response.content\n",
            "        let response = try await session.respond(\n"
            "            to: prompt,\n"
            "            generating: Output.self,\n"
            "            options: GenerationOptions(sampling: .greedy)\n"
            "        )\n"
            "        logger.debug(\"Structured generation used \\(response.usage.totalTokenCount, privacy: .public) tokens\")\n"
            "        return response.content\n",
            "log macOS 27 model usage",
        )
    write(path, text)


def patch_project() -> None:
    path = "美术台.xcodeproj/project.pbxproj"
    text = read(path)
    text = text.replace("CreatedOnToolsVersion = 26.3;", "CreatedOnToolsVersion = 27.0;")
    text = text.replace("MACOSX_DEPLOYMENT_TARGET = 26.0;", "MACOSX_DEPLOYMENT_TARGET = 27.0;")
    text = text.replace("SWIFT_VERSION = 5.0;", "SWIFT_VERSION = 6.0;")
    if "SWIFT_STRICT_CONCURRENCY = complete;" not in text:
        text = text.replace(
            "SWIFT_VERSION = 6.0;",
            "SWIFT_STRICT_CONCURRENCY = complete;\n\t\t\t\tSWIFT_VERSION = 6.0;",
        )
    text = text.replace("CURRENT_PROJECT_VERSION = 2;", "CURRENT_PROJECT_VERSION = 5;")
    text = text.replace("MARKETING_VERSION = 1.0;", "MARKETING_VERSION = 5.0;")
    write(path, text)


def patch_tests() -> None:
    path = "美术台Tests/ArtDepartmentV2Tests.swift"
    text = read(path)
    text = text.replace(
        "let prompts = BuiltInStylePromptCatalog.cards.map(\\.prompt)",
        "let prompts = BuiltInStylePromptCatalog.projectCards.map(\\.prompt)",
    )
    text = text.replace("func testWorkspaceSchemaIsAutomaticV4", "func testWorkspaceSchemaIsAutomaticV5")
    text = text.replace("XCTAssertEqual(ArtDepartmentWorkspaceDocument.empty.schemaVersion, 4)", "XCTAssertEqual(ArtDepartmentWorkspaceDocument.empty.schemaVersion, 5)")
    if "testEveryImportedStyleHasACompleteSample" not in text:
        insertion = r'''
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
            prompt: "电影写实，真实材质",
            category: .general,
            sampleMedia: [StyleSampleMedia(remoteURLString: "https://example.com/root.jpg")]
        )
        let child = StylePromptCard(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            title: "冷月光",
            prompt: "改为低照度冷月光",
            category: .scene,
            parentID: root.id,
            lifecycleRawValue: StylePromptLifecycle.library.rawValue
        )
        let grandchild = StylePromptCard(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            title: "潮湿地面",
            prompt: "增加潮湿地面反射",
            category: .scene,
            parentID: child.id,
            lifecycleRawValue: StylePromptLifecycle.library.rawValue
        )
        let cards = [root, child, grandchild]
        let resolved = StylePromptResolver.resolvedPrompt(for: grandchild.id, in: cards)
        XCTAssertTrue(resolved.contains("电影写实"))
        XCTAssertTrue(resolved.contains("冷月光"))
        XCTAssertTrue(resolved.contains("潮湿地面"))
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
'''
        closing = text.rfind("}\n")
        if closing == -1:
            raise RuntimeError("test class closing brace not found")
        text = text[:closing] + insertion + text[closing:]
    write(path, text)


def patch_docs() -> None:
    readme_path = "README.md"
    readme = read(readme_path)
    readme = readme.replace("# 美术台 3.0", "# 美术台 5.0")
    if "## 风格分支树与完整样板" not in readme:
        readme += r'''

## 风格分支树与完整样板

- 56 张固定 MIT 提示词卡全部带上游 `sourceMedia` 完整样板；首次显示后以 AES-GCM 加密缓存。
- 正式根风格必须有样板；实验分支会自动持久化，并在第一次生成后自动把结果保存为加密样板。
- 每个节点只保存相对父节点增加的变化，最终提示词按根 → 子 → 孙动态组合。
- 用户可以新增、编辑、归档、恢复、删除整棵用户分支树；内置模板只能建立分支，不能被篡改。
- 风格选择始终由用户完成，系统不会自动匹配或代选。

## 资产可靠性 V4

场景、人物、道具经过 Final Draft 确定性元素、第一遍高召回提取、第二遍独立 Apple GenerationSchema 裁决、逐字证据复核、保守身份归并、跨场支持和连续性评分。非确定性资产必须达到 92% 生产阈值；语义相似名称不再自动合并，宁可隔离重复项，也不错误合并不同资产。

## macOS 27

工程部署目标为 macOS 27，使用 Xcode 27 / Swift 6、Foundation Models 的最新系统模型、`LanguageModelSession.usage`、Vision Swift API、Natural Language、Observation、CryptoKit 与 Keychain。
'''
    write(readme_path, readme)

    write(
        "docs/STYLE_LIBRARY_V5.md",
        r'''# 风格图书馆 V5

## 数据模型

```text
根风格（完整提示词 + 完整样板）
├── 分支 A（只保存变化）
│   └── 分支 A.1（继续增加变化）
└── 分支 B
```

每个节点保存 `parentID`、本节点提示词片段、生命周期、版本、样板媒体与来源。最终提示词在使用时动态解析，不复制父提示词，因此父节点修改会自然传递给后代。

## 生命周期

- `library`：正式图书馆节点，至少拥有本节点样板或可追溯的继承样板；
- `experiment`：自动持久化的测试分支；
- `archived`：保留数据但不出现在默认选择器中。

外部提示词输入立即加密持久化为实验节点。完成 Ark 测试后，第一张结果会自动复制到加密风格媒体区，用户再决定是否发布。

## 完整样板

导入的 56 张 MIT 卡保留上游 `sourceMedia` URL、原始 ID、文件路径、固定提交与许可证。应用首次查看时下载图片，验证格式与大小，计算 SHA-256，并使用图书馆 Keychain 密钥加密保存。不会把明文参考图长期写入缓存。

## 管理

用户节点支持新增根风格、无限分支、编辑、添加/删除样板、归档、恢复和删除整棵分支树。内置模板不可直接修改或删除，但可以建立任意深度的用户分支。
''',
    )
    write(
        "docs/ASSET_RELIABILITY_V4.md",
        r'''# 资产提取可靠性 V4

## 多层证据链

1. 任意文本先转换为带 SourceUnit 全覆盖的 Final Draft/Fountain；
2. Scene Heading 与 Character 元素建立确定性场景和说话人物；
3. Foundation Models general、content tagging 与可选远程 Apple Schema 生成高召回候选；
4. 独立可靠性会话逐项判断是否为可拍摄实体、证据是否真正成立；
5. 所有证据必须是当前场景逐字子串；
6. 全剧只自动合并规范名称完全一致的资产，禁用无监督语义合并；
7. 综合跨场支持、身份稳定性、连续性、字段完整度与模型校准；
8. 非确定性资产达到 92% 才进入生产库，否则自动隔离。

## 置信度分解

- 确定性格式证据：18%
- 逐字证据覆盖：22%
- 独立裁决一致性：18%
- 跨场支持：10%
- 身份稳定性：10%
- 连续性一致性：8%
- Schema 完整度：7%
- 模型校准：7%

以上权重会按当前可用证据路径归一化；非确定性资产不会因缺少 Final Draft 确定性格式证据而失去达到 100% 的可能。单一模型自报置信度不再决定生产状态。
''',
    )

    style_doc = read("docs/STYLE_PROMPT_VAULT.md")
    if "V5 分支与样板" not in style_doc:
        style_doc += r'''

## V5 分支与样板

风格图书馆从平面卡片升级为无限层级分支树。根节点保存完整提示词，子节点只保存增量变化。外部测试输入立即持久化为 `experiment`；测试生成的第一张图自动进入 AES-GCM 样板库。56 张内置开源卡全部绑定上游完整样板 URL，并在本机加密缓存。
'''
    write("docs/STYLE_PROMPT_VAULT.md", style_doc)


def main() -> None:
    patch_models()
    patch_catalog()
    patch_persistence()
    patch_store()
    patch_views()
    patch_pipeline()
    patch_apple_engine()
    patch_project()
    patch_tests()
    patch_docs()
    print("V5 upgrade applied")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"upgrade failed: {exc}", file=sys.stderr)
        raise
