#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    destination = ROOT / path
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, lambda _: replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{label}: expected one regex match, found {count}")
    return updated


def patch_models() -> None:
    path = "美术台/Models/ArtDepartmentV2Models.swift"
    text = read(path)

    production_kind = '''nonisolated enum ProductionAssetKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case scene = "场景"
    case character = "人物"
    case prop = "道具"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .scene: "building.2.crop.circle"
        case .character: "person.crop.circle"
        case .prop: "shippingbox"
        }
    }
}
'''
    delivery_standard = production_kind + '''
nonisolated enum AssetDeliveryStandard {
    static func summary(for kind: ProductionAssetKind) -> String {
        switch kind {
        case .scene:
            "空场景：无人物、无人影、无动物、无无关杂物，只保留剧本明确的空间结构与固定陈设。"
        case .character:
            "纯白背景四视图：左一头肩特写；右侧依次为全身正面、严格侧面、严格背面；中立站姿、双手自然垂放、无表情、均匀光照。"
        case .prop:
            "单体道具：干净中性背景，无人物、手部、复杂环境与无关杂物。"
        }
    }

    static func positiveInstruction(for kind: ProductionAssetKind) -> String {
        switch kind {
        case .scene:
            """
            【场景资产强制交付规范】
            生成无人空场景设计图。画面不得出现人物、人影、人体局部、动物或拟人主体。移除垃圾、散乱物、临时堆放物、非剧本要求的小物件和无关装饰；只保留剧本逐字证据明确的建筑、固定陈设、必要道具与空间关系。场地整洁、无遮挡、空间结构清楚，适合置景、勘景与镜头规划。
            """
        case .character:
            """
            【人物资产强制交付规范】
            纯白无缝背景，横向四栏人物设定板，四栏之间留有清晰空白，不添加文字、尺寸线或装饰边框。左一为头肩特写，人物正面直视镜头。右侧三栏均为从头顶到脚底完整入画、同一尺度的全身视图，依次为严格正视图、严格 90° 侧视图、严格 180° 背视图；镜头正对各自视图平面，不使用三分之四角度。所有视图保持同一人物身份、年龄、体貌、发型、服装、配饰和连续性状态。站姿中立，双脚自然分开，双手自然垂放，手指放松，不持物，不遮挡身体；面部无表情；均匀无方向性棚拍光，白平衡中性，阴影极弱，正交或长焦低畸变，无透视夸张。
            """
        case .prop:
            """
            【道具资产强制交付规范】
            只呈现该道具本体，使用干净中性背景与均匀光照，不得出现人物、手部、人体局部、复杂环境或无关杂物。完整展示剧本明确的结构、材质、颜色、尺度、状态与识别特征，不增加无证据装饰。
            """
        }
    }

    static func negativeInstruction(for kind: ProductionAssetKind) -> String {
        switch kind {
        case .scene:
            "人物、人影、人群、人体局部、手脚、动物、拟人主体、无剧本依据的车辆、垃圾、杂物堆、散乱小物、临时箱包、无关装饰、无关道具、文字、水印"
        case .character:
            "非白背景、环境场景、地面纹理、家具、道具、手持物、文字标签、尺寸线、装饰边框、表情、动态姿势、交叉手臂、手插口袋、三分之四视角、回头、重复视图、缺少视图、裁切头脚、不同服装、不同发型、不同年龄、镜像错误、强烈阴影、戏剧光、透视变形、鱼眼、广角畸变"
        case .prop:
            "人物、手部、人体局部、复杂场景、无关杂物、无证据装饰、文字、水印"
        }
    }
}
'''
    text = replace_once(
        text,
        production_kind,
        delivery_standard,
        "insert asset delivery standard",
    )

    old_mode = '''nonisolated enum ImageGenerationMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case textToImage = "文生图"
    case referenceImage = "参考图生图"
    case characterLineup = "十人同服装队列"
    case aoWhiteModel = "AO 白模"
    case materialRepaint = "材质回绘"
    case reverseShot = "镜头反打"
    case cameraRebuild = "指定机位重构"
    case cleanup = "场景减噪"

    var id: String { rawValue }
}
'''
    new_mode = '''nonisolated enum ImageGenerationMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case textToImage = "文生图"
    case referenceImage = "参考图生图"
    case characterLineup = "十人同服装队列"
    case aoWhiteModel = "AO 白模"
    case materialRepaint = "材质回绘"
    case reverseShot = "镜头反打"
    case cameraRebuild = "指定机位重构"
    case cleanup = "场景减噪"

    var id: String { rawValue }

    static func selectableCases(
        for kind: ProductionAssetKind
    ) -> [ImageGenerationMode] {
        switch kind {
        case .scene:
            [
                .textToImage, .referenceImage, .aoWhiteModel, .materialRepaint,
                .reverseShot, .cameraRebuild, .cleanup,
            ]
        case .character, .prop:
            [.textToImage, .referenceImage, .aoWhiteModel, .materialRepaint]
        }
    }
}
'''
    text = replace_once(text, old_mode, new_mode, "filter incompatible generation modes")

    replacement = '''nonisolated enum ImageAspectRatio: String, CaseIterable, Codable, Identifiable, Sendable {
    case landscape16x9 = "16:9"
    case portrait9x16 = "9:16"
    case portrait3x4 = "3:4"
    case landscape4x3 = "4:3"
    case square1x1 = "1:1"
    case landscape3x2 = "3:2"
    case portrait2x3 = "2:3"
    case ultrawide21x9 = "21:9"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .landscape16x9: "16:9 横屏"
        case .portrait9x16: "9:16 竖屏"
        case .portrait3x4: "3:4 竖幅"
        case .landscape4x3: "4:3 横幅"
        case .square1x1: "1:1 方形"
        case .landscape3x2: "3:2 横幅"
        case .portrait2x3: "2:3 竖幅"
        case .ultrawide21x9: "21:9 超宽"
        }
    }

    var isPortrait: Bool {
        self == .portrait9x16 || self == .portrait3x4 || self == .portrait2x3
    }

    var promptInstruction: String {
        "输出画幅固定为 \(rawValue)（\(title)），构图必须完整填充该画幅，不得自动改成其他比例。"
    }

    func pixelSize(for resolution: String) -> String {
        let normalized = resolution
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let components = normalized.split(separator: "x")
        if components.count == 2,
           components.allSatisfy({ Int($0) != nil })
        {
            return normalized
        }
        switch normalized.uppercased() {
        case "1K": oneKSize
        case "4K": fourKSize
        default: twoKSize
        }
    }

    private var oneKSize: String {
        switch self {
        case .landscape16x9: "1280x720"
        case .portrait9x16: "720x1280"
        case .portrait3x4: "864x1152"
        case .landscape4x3: "1152x864"
        case .square1x1: "1024x1024"
        case .landscape3x2: "1248x832"
        case .portrait2x3: "832x1248"
        case .ultrawide21x9: "1512x648"
        }
    }

    private var twoKSize: String {
        switch self {
        case .landscape16x9: "2848x1600"
        case .portrait9x16: "1600x2848"
        case .portrait3x4: "1728x2304"
        case .landscape4x3: "2304x1728"
        case .square1x1: "2048x2048"
        case .landscape3x2: "2496x1664"
        case .portrait2x3: "1664x2496"
        case .ultrawide21x9: "3136x1344"
        }
    }

    private var fourKSize: String {
        switch self {
        case .landscape16x9: "5504x3040"
        case .portrait9x16: "3040x5504"
        case .portrait3x4: "3520x4704"
        case .landscape4x3: "4704x3520"
        case .square1x1: "4096x4096"
        case .landscape3x2: "4992x3328"
        case .portrait2x3: "3328x4992"
        case .ultrawide21x9: "6240x2656"
        }
    }
}

nonisolated struct ImageGenerationRecipe: Codable, Hashable, Sendable {
    var model: String
    var size: String
    var maxImages: Int
    var watermark: Bool
    var aspectRatio: ImageAspectRatio?

    var resolvedAspectRatio: ImageAspectRatio {
        aspectRatio ?? .landscape16x9
    }

    var providerSize: String {
        resolvedAspectRatio.pixelSize(for: size)
    }

    static let arkDefault = ImageGenerationRecipe(
        model: "doubao-seedream-4-0-250828",
        size: "2K",
        maxImages: 1,
        watermark: false,
        aspectRatio: .landscape16x9
    )
}

nonisolated struct GeneratedImageRecord'''
    text = regex_once(
        text,
        r"nonisolated struct ImageGenerationRecipe: Codable, Hashable, Sendable \{.*?\n\}\n\nnonisolated struct GeneratedImageRecord",
        replacement,
        "add selectable aspect ratios",
    )
    text = replace_once(text, "schemaVersion: 6", "schemaVersion: 7", "bump workspace schema")
    write(path, text)


def patch_pipeline() -> None:
    path = "美术台/Services/ArtDepartmentV2Pipeline.swift"
    text = read(path)
    old = '''        let operation = [modeInstruction(mode), direction]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\\n")
        let positive = """
        【资产设计层——唯一主体来源】
        \\(assetDesign)

        【视觉风格层——只改变表现方式】
        \\(styleTreatment)

        【生成任务】
        \\(operation)
        """
        let negative = "不要从风格提示词或风格样板复制任何具体人物、场景、道具、服装、动作、数量、时代或空间关系；不要补全剧本未明确的年龄、性别、体貌、材质、颜色和损坏状态；不要改变锁定身份与连续性；避免文字、水印、畸形肢体和重复主体。"
'''
    new = '''        let operation = [
            modeInstruction(mode),
            direction,
            AssetDeliveryStandard.positiveInstruction(for: asset.kind),
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\\n")
        let positive = """
        【资产设计层——唯一主体来源】
        \\(assetDesign)

        【视觉风格层——只改变表现方式】
        \\(styleTreatment)

        【生成任务】
        \\(operation)
        """
        let negative = uniqueText([
            "不要从风格提示词或风格样板复制任何具体人物、场景、道具、服装、动作、数量、时代或空间关系；不要补全剧本未明确的年龄、性别、体貌、材质、颜色和损坏状态；不要改变锁定身份与连续性；避免文字、水印、畸形肢体和重复主体。",
            AssetDeliveryStandard.negativeInstruction(for: asset.kind),
        ])
        .joined(separator: "；")
'''
    text = replace_once(text, old, new, "enforce delivery standard in main prompt")

    old_fallback_task = '''            "【生成任务】\\n\\(modeInstruction(mode))\\n\\(direction)",
'''
    new_fallback_task = '''            "【生成任务】\\n\\(modeInstruction(mode))\\n\\(direction)\\n\\(AssetDeliveryStandard.positiveInstruction(for: asset.kind))",
'''
    text = replace_once(
        text,
        old_fallback_task,
        new_fallback_task,
        "enforce delivery standard in fallback prompt",
    )
    old_fallback_negative = '''            negativePrompt: "风格不得提供主体内容；不得臆造剧本未明确事实；避免文字、水印、畸形肢体和重复主体。",
'''
    new_fallback_negative = '''            negativePrompt: uniqueText([
                "风格不得提供主体内容；不得臆造剧本未明确事实；避免文字、水印、畸形肢体和重复主体。",
                AssetDeliveryStandard.negativeInstruction(for: asset.kind),
            ]).joined(separator: "；"),
'''
    text = replace_once(
        text,
        old_fallback_negative,
        new_fallback_negative,
        "enforce delivery negatives in fallback prompt",
    )
    write(path, text)


def patch_client() -> None:
    path = "美术台/Services/ArtDepartmentV2Clients.swift"
    text = read(path)
    old = '''        let cleanNegative = negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPrompt = cleanNegative.isEmpty
            ? prompt
            : prompt + "\\n\\n必须避免：" + cleanNegative
'''
    new = '''        let framedPrompt = prompt
            + "\\n\\n【输出画幅】\\n"
            + recipe.resolvedAspectRatio.promptInstruction
        let cleanNegative = negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPrompt = cleanNegative.isEmpty
            ? framedPrompt
            : framedPrompt + "\\n\\n必须避免：" + cleanNegative
'''
    text = replace_once(text, old, new, "append ratio contract to provider prompt")
    text = replace_once(
        text,
        '            "size": recipe.size,\n',
        '            "size": recipe.providerSize,\n',
        "send ratio-specific pixel size",
    )
    write(path, text)


def patch_view() -> None:
    path = "美术台/Views/ArtDepartmentV2Views.swift"
    text = read(path)
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
    text = replace_once(text, old_change, new_change, "sync generation mode with asset kind")

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
    text = replace_once(text, old_controls, new_controls, "add delivery and aspect controls")

    old_history = '''            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
'''
    new_history = old_history + '''            Text("\\(record.recipe.resolvedAspectRatio.rawValue) · \\(record.recipe.providerSize)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
'''
    text = replace_once(text, old_history, new_history, "show ratio in generation history")
    write(path, text)


def patch_versions() -> None:
    for path in [
        "美术台/Services/ArtDepartmentV2Persistence.swift",
        "美术台/Stores/ArtDepartmentV2Store.swift",
    ]:
        text = read(path)
        count = text.count("max(6, ")
        if count == 0:
            raise RuntimeError(f"{path}: no V6 schema migration anchor")
        text = text.replace("max(6, ", "max(7, ")
        write(path, text)


def patch_tests() -> None:
    path = "美术台Tests/ArtDepartmentV2Tests.swift"
    text = read(path)
    text = replace_once(
        text,
        "func testWorkspaceSchemaIsAutomaticV6()",
        "func testWorkspaceSchemaIsAutomaticV7()",
        "rename schema test",
    )
    text = replace_once(
        text,
        "XCTAssertEqual(ArtDepartmentWorkspaceDocument.empty.schemaVersion, 6)",
        "XCTAssertEqual(ArtDepartmentWorkspaceDocument.empty.schemaVersion, 7)",
        "update schema expectation",
    )

    tests = r'''
    func testSceneDeliveryStandardForbidsPeopleAndClutter() {
        let positive = AssetDeliveryStandard.positiveInstruction(for: .scene)
        let negative = AssetDeliveryStandard.negativeInstruction(for: .scene)
        XCTAssertTrue(positive.contains("无人空场景"))
        XCTAssertTrue(positive.contains("不得出现人物"))
        XCTAssertTrue(positive.contains("散乱物"))
        XCTAssertTrue(negative.contains("人物"))
        XCTAssertTrue(negative.contains("杂物堆"))
    }

    func testCharacterDeliveryStandardRequiresWhiteFourViewSheet() {
        let positive = AssetDeliveryStandard.positiveInstruction(for: .character)
        let negative = AssetDeliveryStandard.negativeInstruction(for: .character)
        XCTAssertTrue(positive.contains("纯白无缝背景"))
        XCTAssertTrue(positive.contains("头肩特写"))
        XCTAssertTrue(positive.contains("严格正视图"))
        XCTAssertTrue(positive.contains("严格 90° 侧视图"))
        XCTAssertTrue(positive.contains("严格 180° 背视图"))
        XCTAssertTrue(positive.contains("双手自然垂放"))
        XCTAssertTrue(positive.contains("面部无表情"))
        XCTAssertTrue(positive.contains("均匀无方向性棚拍光"))
        XCTAssertTrue(negative.contains("非白背景"))
        XCTAssertTrue(negative.contains("三分之四视角"))
    }

    func testAspectRatioMapsToArkPixelSize() {
        var recipe = ImageGenerationRecipe.arkDefault
        recipe.aspectRatio = .landscape16x9
        XCTAssertEqual(recipe.providerSize, "2848x1600")
        recipe.aspectRatio = .portrait9x16
        XCTAssertEqual(recipe.providerSize, "1600x2848")
        recipe.aspectRatio = .portrait3x4
        XCTAssertEqual(recipe.providerSize, "1728x2304")
        recipe.size = "1K"
        XCTAssertEqual(recipe.providerSize, "864x1152")
        recipe.size = "2048x1024"
        XCTAssertEqual(recipe.providerSize, "2048x1024")
    }

    func testSelectableGenerationModesAvoidConflictingLegacyLineup() {
        let characterModes = ImageGenerationMode.selectableCases(for: .character)
        XCTAssertFalse(characterModes.contains(.characterLineup))
        XCTAssertFalse(characterModes.contains(.reverseShot))
        XCTAssertTrue(characterModes.contains(.textToImage))
        XCTAssertTrue(ImageGenerationMode.selectableCases(for: .scene).contains(.reverseShot))
    }

    func testCharacterPromptIncludesMandatoryDeliveryStandard() {
        let sceneID = UUID()
        let asset = ProductionAsset(
            kind: .character,
            canonicalName: "小雨",
            summary: "主要人物",
            visualDescription: "十七岁的女孩，穿旧校服",
            designFacts: [
                AssetDesignFact(
                    kind: .identityRole,
                    value: "学生小雨",
                    evidence: "学生小雨",
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日"
                ),
                AssetDesignFact(
                    kind: .ageRange,
                    value: "17 岁",
                    evidence: "十七岁的学生小雨",
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日"
                ),
                AssetDesignFact(
                    kind: .costume,
                    value: "洗得发白的旧校服",
                    evidence: "穿着洗得发白的旧校服",
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日"
                )
            ],
            sourceEvidence: [
                EvidenceQuote(
                    sceneID: sceneID,
                    sceneHeading: "内. 教室 - 日",
                    quote: "十七岁的学生小雨穿着洗得发白的旧校服",
                    explanation: "人物关键设计依据"
                )
            ],
            modelConfidence: 1,
            validatedConfidence: 1,
            reviewDecision: .accepted,
            firstSceneOrder: 0
        )
        let style = StylePromptCard(
            title: "中性写实",
            prompt: "电影级写实摄影，中性白平衡，均匀漫射光，低畸变构图。",
            category: .general
        )
        let plan = ArtDepartmentV2Pipeline.fallbackPromptPlan(
            asset: asset,
            styleCards: [style],
            mode: .textToImage,
            direction: ""
        )
        XCTAssertTrue(plan.positivePrompt.contains("纯白无缝背景"))
        XCTAssertTrue(plan.positivePrompt.contains("头肩特写"))
        XCTAssertTrue(plan.positivePrompt.contains("严格 180° 背视图"))
        XCTAssertTrue(plan.negativePrompt.contains("非白背景"))
    }
'''
    if "testSceneDeliveryStandardForbidsPeopleAndClutter" in text:
        raise RuntimeError("delivery tests already present")
    head, marker, tail = text.rpartition("\n}")
    if not marker:
        raise RuntimeError("test class closing brace missing")
    text = head + "\n" + tests + "\n}" + tail
    write(path, text)


def patch_docs() -> None:
    write(
        "docs/ASSET_DELIVERY_STANDARD_V7.md",
        '''# 资产交付规范与画幅 V7

## 场景资产

场景图固定按“无人空场景”交付：不得出现人物、人影、人体局部、动物或拟人主体；清除垃圾、散乱物、临时堆放物、非剧本要求的小物件与无关装饰。只保留剧本逐字证据明确的建筑、固定陈设、必要道具和空间关系。

## 人物资产

人物图固定为纯白无缝背景的横向四栏设定板：

1. 左一为正面头肩特写；
2. 右侧依次为全身严格正视图、严格 90° 侧视图、严格 180° 背视图；
3. 三个全身视图从头顶到脚底完整入画、尺度一致；
4. 同一人物身份、年龄、体貌、发型、服装、配饰和连续性状态；
5. 中立站姿、双手自然垂放、无手持物、无表情、均匀无方向性棚拍光；
6. 禁止三分之四角度、回头、裁切头脚、强透视、鱼眼、文字标签与环境背景。

## 道具资产

道具图只呈现道具本体，使用干净中性背景和均匀光照，不出现人物、手部、复杂环境或无关杂物。

## 画幅

生图工坊提供 16:9、9:16、3:4、4:3、1:1、3:2、2:3、21:9。默认分辨率仍为 2K；客户端把用户选择转换成 Ark 接受的宽高像素值，并把画幅约束同时加入最终提示词。
''',
    )

    path = "README.md"
    text = read(path)
    section = '''

## V7 资产交付规范

- 场景资产统一输出无人空场景，去除无关杂物，只保留剧本证据明确的空间结构、固定陈设与必要道具。
- 人物资产统一输出纯白背景四视图：头肩特写 + 全身正面 / 严格侧面 / 严格背面；中立站姿、双手自然垂放、无表情、均匀光照。
- 生图工坊可选择 16:9、9:16、3:4、4:3、1:1、3:2、2:3 与 21:9，Ark 请求使用与比例匹配的像素尺寸。
'''
    if "## V7 资产交付规范" not in text:
        text = text.rstrip() + section + "\n"
        write(path, text)


def main() -> None:
    patch_models()
    patch_pipeline()
    patch_client()
    patch_view()
    patch_versions()
    patch_tests()
    patch_docs()
    print("V7 asset delivery and aspect-ratio migration applied")


if __name__ == "__main__":
    main()
