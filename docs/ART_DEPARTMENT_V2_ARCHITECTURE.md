# 美术台 2.0 架构

## 产品边界

美术台 2.0 不直接从未经整理的长文本生成资产表，也不把模型猜测当成事实。它维护三层彼此可追溯的数据：

```text
不可变原始剧本
    ↓ SourceUnit ID 与 SHA-256
标准 Final Draft / Fountain
    ↓ scene / paragraph / sourceUnitIDs
场景、人物、道具资产账本
    ↓ exact evidence / confidence / review
审阅后的美术资产
    ↓ locked style cards / prompt plan
图像生成记录
```

原始剧本是最高权威。标准剧本和资产都是可重新生成的派生层；人工确认只作用于当前派生版本。

## 1. 剧本标准化

`SourceUnitBuilder` 按非空段落建立稳定 ID，并保存 UTF-16 位置和长度。标准化请求以 `<<U000001>>` 形式传给大模型。

模型必须返回：

- `coveredSourceUnitIDs`；
- 场景标题；
- Final Draft 元素类型；
- 每个元素对应的 `sourceUnitIDs`。

本地接受条件：

```text
expected IDs == covered IDs == paragraph sourceUnitIDs union
且无重复 ID
且无未知 ID
且至少一个标准场景
```

任一条件不满足，本轮失败，不覆盖上一次成功结果。

## 2. 标准格式

中间正式格式使用 Fountain：

- Scene Heading
- Action
- Character
- Parenthetical
- Dialogue
- Transition
- General

`FinalDraftFDXExporter` 在本地将已验证的场景结构确定性写成 FDX XML。模型从不直接生成 FDX 文件。

## 3. 资产提取

提取按 `CanonicalScene` 顺序逐场执行，而不是对全文做一次模糊推断。

每项模型结果必须包含：

- 类型：场景 / 人物 / 道具；
- 规范名称和别名；
- 视觉描述和连续性状态；
- 材质、构图、元素；
- 当前标准场景中的逐字证据；
- 模型自报置信度。

确定性补强：

- 标准 Scene Heading 必然形成一个场景资产；
- 标准 Character 元素必然形成一个人物候选；
- 道具仍由模型识别，但必须通过逐字证据校验；
- 跨场合并仅使用保守规范键，不做激进语义合并。

## 4. 置信度

校验置信度由以下因素透明组合：

```text
0.55 × 模型自报置信度
+ 0.30 × 逐字证据质量
+ 0.15 × 视觉/连续性字段完整度
```

低于 `0.86`、存在警告或别名冲突的项目进入人工审阅。应用不显示虚构的全局“准确率”。

## 5. 风格提示词库

风格卡包含：

```text
title
category
referenceImagePath
user prompt (locked by default)
tags
notes
```

用户输入的提示词是权威字段。大模型可以在生图阶段引用和组合，但不能静默修改风格卡本身。

## 6. 生图提示词编译

输入：

- 已确认资产；
- 逐字剧本证据；
- 一张或多张风格卡；
- 生成模式；
- 用户补充限制。

输出 `ArtPromptPlan`：

- subject
- materials
- composition
- elements
- lighting
- positivePrompt
- negativePrompt
- lockedFacts
- rationale

用户可在调用图像 API 前逐项审阅和编辑。

## 7. Ark 图像生成

`ArkImageGenerationClient` 支持：

- 文生图；
- 一张或多张参考图的图生图；
- 顺序/批量图片；
- Base64 或 URL 返回；
- 本地保存及请求 ID 记录。

生成结果和完整提示词计划进入项目历史，便于复现。

## 8. 新 UI

旧的表格导出、参数实验和多级设计界面不再是默认入口。新根界面只有四个连续工作区：

```text
剧本标准化 → 资产审阅 → 风格提示词库 → 生图工坊
```

旧实现暂时保留在源码中，便于迁移旧数据和对照测试，但不再出现在主产品路径。

## 9. 关键源码

| 职责 | 文件 |
| --- | --- |
| V2 领域模型 | `美术台/Models/ArtDepartmentV2Models.swift` |
| 本地存储、Fountain/FDX | `美术台/Services/ArtDepartmentV2Persistence.swift` |
| LLM、Keychain、Ark | `美术台/Services/ArtDepartmentV2Clients.swift` |
| 标准化、提取、提示词规划 | `美术台/Services/ArtDepartmentV2Pipeline.swift` |
| 应用状态 | `美术台/Stores/ArtDepartmentV2Store.swift` |
| 四工作区 UI | `美术台/Views/ArtDepartmentV2Views.swift` |
| API 设置 | `美术台/Views/ArtDepartmentV2SettingsView.swift` |
