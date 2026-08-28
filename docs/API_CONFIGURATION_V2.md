# API 与 Apple GenerationSchema 配置

## 1. 默认模型路线

美术台优先使用 macOS 27 的 Apple Foundation Models：

```text
SystemLanguageModel.default
  + LanguageModelSession
  + @Generable / @Guide
  + GenerationOptions(samplingMode: .greedy)
```

Apple Intelligence 可用且支持 `zh_CN` 时，标准化、资产提取和提示词计划不需要 API Key。

系统启动时检查：

- `SystemLanguageModel.isAvailable`；
- `SystemLanguageModel.availability`；
- `supportsLocale(Locale(identifier: "zh_CN"))`；
- `contextSize`。

设备不支持、模型尚未下载或中文不受支持时，应用显示明确路线，不伪装成本地模型已运行。

## 2. 唯一结构化接口

所有结构化任务均定义为 Apple `Generable` 类型：

- `AppleSchemaNormalizationBatch`
- `AppleSchemaAssetBatch`
- `AppleSchemaContentTags`
- `AppleSchemaPromptPlan`

本地调用：

```swift
session.respond(
    to: prompt,
    generating: AppleSchemaAssetBatch.self
)
```

远程调用：

```text
/chat/completions JSON
  → GeneratedContent(json:)
  → value(AppleSchemaAssetBatch.self)
```

远程接口因此只是 transport adapter，不拥有另一套业务 DTO。

## 3. 可选 DeepSeek / OpenAI 兼容增强

设置中填写：

- Base URL；
- 模型 ID；
- API Key。

留空 API Key：纯 Apple 本地路线。

填写 API Key：Apple 本地与远程模型并行生成同一 Schema，标准化按完整覆盖和结构质量选择；资产提取按逐字 evidence 和多引擎共识自动核验。

默认 DeepSeek：

```text
Base URL: https://api.deepseek.com
Endpoint: /chat/completions
```

应用请求 JSON mode，并把 `Output.generationSchema` 的结构说明放入系统指令。返回值必须能被 `GeneratedContent(json:)` 和对应 `Generable` 类型解码。

## 4. 火山方舟 Ark Images API

默认端点：

```text
https://ark.cn-beijing.volces.com/api/v3/images/generations
```

配置：

- Ark API Key；
- 模型 ID；
- 图片尺寸；
- 数量；
- 水印；
- 零张或多张参考图。

生图请求只使用自动通过资产、锁定风格卡和 Apple Schema 提示词计划。隔离资产不允许进入请求。

## 5. Keychain

- LLM Key：`llm-api-key`
- Ark Key：`ark-api-key`
- Service：`com.meishutai.art-department-v2`

密钥不写入 JSON、日志、Git 仓库或导出文件。

## 6. Apple 文档入口

- Foundation Models： https://developer.apple.com/documentation/foundationmodels
- Generable： https://developer.apple.com/documentation/foundationmodels/generable
- GeneratedContent： https://developer.apple.com/documentation/foundationmodels/generatedcontent
- LanguageModelSession： https://developer.apple.com/documentation/foundationmodels/languagemodelsession
- content tagging： https://developer.apple.com/documentation/foundationmodels/categorizing-and-organizing-data-with-content-tags
- Natural Language： https://developer.apple.com/documentation/naturallanguage
- Vision： https://developer.apple.com/documentation/vision

Foundation Models 与部分 Vision Swift API 仍可能标记为 beta；最终发布必须使用目标 Xcode 与系统 SDK 重新完成类型检查、真实设备运行和模型可用性测试。
