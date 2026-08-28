# Apple 自动美术资产提取架构

## 1. 产品目标

美术台面向几十集、上百集甚至更大规模的剧本资产生产。系统不把“低置信度候选”转换成大量人工确认任务；准确性、失败隔离和可追溯性必须由软件自动完成。

```text
原始剧本
  → 完整标准 Final Draft
  → 逐场自动提取
  → 多引擎自动核验
  → 生产资产库 / 隔离诊断
  → 自动提示词规划与生图
```

生产资产库只包含自动通过的场景、人物和道具。隔离诊断不是待办事项，不阻塞流水线，也不会进入导出与生图。

## 2. 权威数据层级

```text
1. 原始剧本文本与 SourceUnit 范围
2. 标准 Final Draft / Fountain 元素
3. 当前场景中的逐字 evidence
4. 确定性解析结果
5. Apple 本地结构化模型结果
6. 可选远程模型结果
7. 聚合后的生产资产
```

下层数据不能覆盖上层。模型输出只是一种派生证据。

## 3. Apple GenerationSchema 是唯一模型接口

应用使用 `@Generable` 和 `@Guide` 定义：

- 剧本标准化批次；
- Final Draft 场景与段落；
- 场景、人物、道具候选；
- content tagging 结果；
- 生图提示词计划。

本地模型：

```swift
let response = try await session.respond(
    to: prompt,
    generating: AppleSchemaAssetBatch.self,
    options: GenerationOptions(samplingMode: .greedy)
)
```

远程模型：

```text
远程 JSON
  → GeneratedContent(json:)
  → value(AppleSchemaAssetBatch.self)
  → 相同的本地验证器
```

因此 DeepSeek、OpenAI 兼容接口或未来其他服务商不会拥有独立 DTO、独立 JSON 修补代码或独立业务规则。

Apple 文档指出，`Generable` 的类型与 guide 会转换为 JSON schema；guided generation 使用 constrained decoding 保证结构正确，并可改善准确率和推理效率。相关官方入口：

- https://developer.apple.com/documentation/foundationmodels/generable
- https://developer.apple.com/documentation/foundationmodels/generatedcontent
- https://developer.apple.com/documentation/foundationmodels/languagemodelsession
- https://developer.apple.com/videos/play/wwdc2025/286/

## 4. 剧本标准化

### 4.1 SourceUnit

每个非空原文段落具有稳定 ID、UTF-16 位置和长度：

```text
U000001
U000002
...
```

### 4.2 双重覆盖约束

每批模型结果必须满足：

```text
coveredSourceUnitIDs == 输入 ID 集合
所有 paragraph.sourceUnitIDs 的并集 == 输入 ID 集合
coveredSourceUnitIDs 无重复
没有未知 ID
```

任一条件失败，整批拒绝。

### 4.3 多候选选择

Apple 本地模型和已配置的远程适配器可以并行返回同一 `AppleSchemaNormalizationBatch`。只有覆盖完整的候选进入比较；系统按以下确定性指标选择：

- 专业 Final Draft 元素数量；
- 具体场景标题数量；
- 非空段落数量；
- 场景连续性。

### 4.4 FDX

模型不直接自由生成 XML。`CanonicalScene` 由本地渲染为 Fountain，再由 `FinalDraftFDXExporter` 确定性生成 FDX。

## 5. 逐场自动提取

### 5.1 确定性基础

- `Scene Heading` 必然建立一个场景资产；
- `Character` 元素必然建立一个说话人物资产；
- 每项均具有 100% 元素级来源。

### 5.2 Foundation Models general

一般模型通过 `AppleSchemaAssetBatch` 提取：

- 场景空间、时间、天气、时代和陈设；
- 人物可见年龄、体型、服装、伤损、伪装和连续性；
- 可采购、制作、陈设或被人物使用的实体道具；
- 材质、构图和元素说明。

### 5.3 content tagging

`SystemLanguageModel(useCase: .contentTagging)` 独立提取动作、对象、地点和制作主题。数组使用 `maximumCount`，避免长场景产生过多重复标签并减少 decoding 时间。

官方入口：

- https://developer.apple.com/documentation/foundationmodels/categorizing-and-organizing-data-with-content-tags
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/usecase/contenttagging

### 5.4 Natural Language

`NLTagger` 使用 `.nameType` 和 `.joinNames` 提取多词人名、地名和组织名。

`NLEmbedding.sentenceEmbedding(for:)` 只在距离非常低时辅助别名归并。策略是宁可保留重复，也不错误合并同名人物、不同地点或不同连续性状态。

官方入口：

- https://developer.apple.com/documentation/naturallanguage/nltagger
- https://developer.apple.com/documentation/naturallanguage/nlembedding

## 6. 自动核验与隔离

模型候选先通过硬条件：

```text
名称非空
证据长度 >= 2
当前场景包含 evidence 逐字子串
资产类型合法
```

再计算自动核验信号：

```text
35% 模型置信度
28% 逐字证据质量
17% Schema 字段完整度
15% 多引擎共识
 5% Natural Language 支持
```

确定性 Scene Heading 和 Character 元素不依赖该阈值。

结果状态：

- `accepted`：进入生产资产库；
- `conflict`：自动隔离，只保留诊断；
- `rejected`：自动排除。

没有人工确认按钮，没有“等待审阅”阶段。

## 7. 并行与性能

- 标准化按 context-aware SourceUnit 分块；
- Apple 本地模型单路线时使用更小块，减少 `contextSizeExceeded`；
- Foundation Models 与远程适配器可并行产生候选；
- 场景按受控窗口并发，Apple 本地路线默认较低并发，远程路线可提高；
- `LanguageModelSession.prewarm(promptPrefix:)` 提前加载模型与公共提示前缀；
- `GenerationOptions(samplingMode: .greedy)` 用于提取、分类和标准化；
- `@Guide(.maximumCount)` 限制数组，缩小 schema 与输出 token；
- 结果按场景即时聚合，不要求整部剧本一次驻留在上下文。

## 8. Apple Vision

### 8.1 剧本文档

- 原生 PDF 文本优先使用 PDFKit；
- 扫描 PDF 页面渲染后使用 `RecognizeTextRequest`；
- 图片剧本直接使用 Swift Vision OCR；
- OCR 开启准确模式、自动语言检测和语言校正。

### 8.2 风格参考图

`GenerateImageFeaturePrintRequest` 为每张用户参考图建立本地视觉签名。导入新风格卡时与已有图片比较，极高相似度时复用已有风格卡，避免模板库膨胀和重复调用。

官方入口：

- https://developer.apple.com/documentation/vision/recognizetextrequest
- https://developer.apple.com/documentation/vision/generateimagefeatureprintrequest

## 9. 生图

```text
自动通过资产
  + 用户明确选择的图书馆卡片或本轮外部风格
  + 生成模式
  + 用户补充方向
  → AppleSchemaPromptPlan
  → Ark Images API
```

提示词计划包含：主体、材质、构图、元素、光影、正向提示词、负向限制和不可改变的事实。

用户精确风格提示词是权威输入，模型不能静默改写其意义。

## 10. 可用性与降级

```text
Apple Intelligence + 远程 Key
  → 双引擎自动共识

Apple Intelligence only
  → 纯本地 guided generation + content tagging + NL + Vision

远程 Key only
  → 远程 JSON → GeneratedContent → Apple Generable

两者都不可用
  → 确定性 Final Draft 解析仍可工作；需要语义模型的步骤明确失败
```

Private Cloud Compute 和自定义 `LanguageModelExecutor` 适合作为后续扩展，但需要对应系统版本、资格和 entitlement；当前代码不假设其必然可用。

## 11. 关键源码

| 职责 | 文件 |
| --- | --- |
| Apple Generable 类型与模型路由 | `美术台/Services/AppleStructuredExtractionEngine.swift` |
| 自动标准化、提取、核验与提示词 | `美术台/Services/ArtDepartmentV2Pipeline.swift` |
| 文档、Fountain、FDX 与持久化 | `美术台/Services/ArtDepartmentV2Persistence.swift` |
| 自动工作流状态 | `美术台/Stores/ArtDepartmentV2Store.swift` |
| 自动资产库 UI | `美术台/Views/ArtDepartmentV2Views.swift` |
| Foundation Models / Ark 配置 | `美术台/Views/ArtDepartmentV2SettingsView.swift` |

## 12. 验证原则

- 不以模型自报置信度单独决定生产入库；
- 不以人工点击作为系统正确性的补丁；
- 不允许无逐字证据的模型资产进入生产库；
- 不允许隔离资产进入导出和生图；
- 不允许标准化覆盖不完整时更新成功结果；
- Apple beta API 必须在最终 Xcode/macOS SDK 上进行类型检查和运行测试。
