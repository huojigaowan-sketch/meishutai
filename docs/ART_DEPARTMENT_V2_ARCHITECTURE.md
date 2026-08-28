# 美术台自动化架构

## 目标

把任意来源、任意格式、任意体量的剧本文本转换为可以直接驱动影视美术生产的场景、人物、道具和生图任务。系统不依赖逐项人工确认。

## 生产链

```text
导入文本 / FDX / PDF / 图片
  → Apple 文档读取与 OCR
  → SourceUnit 全覆盖
  → Apple GenerationSchema 标准化
  → CanonicalScene / Fountain / FDX
  → 逐场自动提取
  → 多引擎自动核验
  → ProductionAsset
  → 风格卡用户明确选择
  → AppleSchemaPromptPlan
  → Ark Images API
```

## 模块

### `ArtDepartmentV2Models.swift`

保存 Canonical Scene、Production Asset、自动核验报告、自动统计、风格卡、生图计划和工作区文档。V3 schema 继续兼容 V2 持久化 raw value，但 UI 和业务语义已变为完全自动。

### `AppleStructuredExtractionEngine.swift`

- Apple `@Generable` / `@Guide` 类型；
- `SystemLanguageModel.default`；
- `SystemLanguageModel(useCase: .contentTagging)`；
- `LanguageModelSession.prewarm`；
- 远程 JSON → `GeneratedContent` → 相同 Generable；
- `NLTagger` 与 `NLEmbedding`；
- Vision OCR 与 image feature print；
- PDFKit 文本与扫描页面读取。

### `ArtDepartmentV2Pipeline.swift`

- SourceUnit 分块与覆盖；
- 标准化候选选择；
- 受控并行逐场提取；
- 确定性资产；
- exact evidence 过滤；
- 自动评分、通过、隔离、拒绝；
- 保守跨场归并；
- 风格卡推荐和提示词计划。

### `ArtDepartmentV2Persistence.swift`

- 原文和工作区原子保存；
- 风格图与生成图本地存储；
- Fountain / FDX 确定性导入导出；
- SHA-256 来源指纹。

### `ArtDepartmentV2Store.swift`

- 一键完整运行；
- 纯 Apple 或双引擎路线；
- V2 数据自动迁移；
- 生产资产与隔离诊断分离；
- 风格参考图 Vision 查重；
- 自动计划并直接生图。

### `ArtDepartmentV2Views.swift`

可见 UI 只有：

1. 剧本标准化与自动提取；
2. 自动资产库；
3. 风格提示词库；
4. 生图工坊。

不存在人工审阅队列、确认按钮或必须处理的低置信度待办。

## 数据安全

- 原始剧本不可变；
- API Key 在 Keychain；
- 图片和工作区在 Application Support；
- 模型输出不能覆盖上次成功结果，直到完整校验通过；
- 低证据候选只能进入诊断数据。

## 完成语义

```text
normalizationAudit.isComplete
&& canonicalScenes.count > 0
&& 所有场景已执行提取
&& usableAssets.count > 0
```

隔离候选可以存在，不阻止项目完成。

## 性能策略

- 小 Schema、短字段名、`maximumCount`；
- Apple 模型本地预热；
- 标准化按 context-aware 分块；
- 场景受控并行；
- content tagging 专用适配器；
- 自然语言与确定性解析尽量在本地执行；
- 远程模型只处理同一 Generable Schema；
- 场景结果即时聚合，不需要整部剧本同时进入一个 prompt。
