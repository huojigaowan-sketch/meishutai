#!/usr/bin/env python3
from __future__ import annotations

import upgrade_v7


original_patch_models = upgrade_v7.patch_models


def fixed_patch_models() -> None:
    original_patch_models()
    path = "美术台/Models/ArtDepartmentV2Models.swift"
    text = upgrade_v7.read(path)
    text = upgrade_v7.replace_once(
        text,
        '''        switch normalized.uppercased() {
        case "1K": oneKSize
        case "4K": fourKSize
        default: twoKSize
        }
''',
        '''        switch normalized.uppercased() {
        case "1K": return oneKSize
        case "4K": return fourKSize
        default: return twoKSize
        }
''',
        "return ratio-specific provider size",
    )
    upgrade_v7.write(path, text)


def scoped_patch_view() -> None:
    path = "美术台/Views/ArtDepartmentV2Views.swift"
    text = upgrade_v7.read(path)
    marker = "private struct GenerationStudioWorkspace: View {"
    prefix, separator, generation = text.partition(marker)
    if not separator:
        raise RuntimeError("GenerationStudioWorkspace anchor missing")

    old_change = '''            .onChange(of: store.selectedAssetKind) { _, _ in
                store.selectedAssetID = store.filteredAssets.first?.id
            }
'''
    new_change = '''            .onChange(of: store.selectedAssetKind) { _, _ in
                store.selectedAssetID = store.filteredAssets.first?.id
                let modes = ImageGenerationMode.selectableCases(
                    for: store.selectedAssetKind
                )
                if !modes.contains(store.generationMode) {
                    store.generationMode = .textToImage
                }
                store.promptPlan = .empty
            }
'''
    generation = upgrade_v7.replace_once(
        generation,
        old_change,
        new_change,
        "sync generation mode with asset kind in studio",
    )

    old_controls = '''            Text("生成模式").font(.headline)
            Picker("模式", selection: $store.generationMode) {
                ForEach(ImageGenerationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            Text("补充要求").font(.headline)
'''
    new_controls = '''            Text("生成模式").font(.headline)
            Picker("模式", selection: $store.generationMode) {
                ForEach(ImageGenerationMode.selectableCases(for: store.selectedAssetKind)) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            Text("资产交付规范").font(.headline)
            Label(
                AssetDeliveryStandard.summary(for: store.selectedAssetKind),
                systemImage: store.selectedAssetKind == .character
                    ? "person.crop.rectangle.stack"
                    : "viewfinder"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))

            Text("画幅比例").font(.headline)
            Picker(
                "比例",
                selection: Binding(
                    get: { store.generationRecipe.resolvedAspectRatio },
                    set: { value in store.generationRecipe.aspectRatio = value }
                )
            ) {
                ForEach(ImageAspectRatio.allCases) { ratio in
                    Text(ratio.title).tag(ratio)
                }
            }
            .pickerStyle(.menu)
            HStack {
                Text("Ark 输出尺寸")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.generationRecipe.providerSize)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if store.selectedAssetKind == .character
                && store.generationRecipe.resolvedAspectRatio.isPortrait
            {
                Label(
                    "四视图横排在 16:9、4:3 或 3:2 下更稳定；竖幅仍可按项目需要选择。",
                    systemImage: "info.circle"
                )
                .font(.caption2)
                .foregroundStyle(.orange)
            }

            Text("补充要求").font(.headline)
'''
    generation = upgrade_v7.replace_once(
        generation,
        old_controls,
        new_controls,
        "add delivery and aspect controls",
    )

    old_history = '''            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
'''
    new_history = old_history + '''            Text("\\(record.recipe.resolvedAspectRatio.rawValue) · \\(record.recipe.providerSize)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
'''
    generation = upgrade_v7.replace_once(
        generation,
        old_history,
        new_history,
        "show ratio in generation history",
    )
    upgrade_v7.write(path, prefix + separator + generation)


original_patch_docs = upgrade_v7.patch_docs


def normalized_patch_docs() -> None:
    original_patch_docs()
    for path in ["README.md", "docs/ASSET_DELIVERY_STANDARD_V7.md"]:
        upgrade_v7.write(path, upgrade_v7.read(path).rstrip() + "\n")


upgrade_v7.patch_models = fixed_patch_models
upgrade_v7.patch_view = scoped_patch_view
upgrade_v7.patch_docs = normalized_patch_docs
upgrade_v7.main()
