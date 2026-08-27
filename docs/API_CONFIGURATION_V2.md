# API 配置与数据流

## 大语言模型

设置项：

```text
art.llm.provider
art.llm.baseURL
art.llm.model
Keychain: llm-api-key
```

默认 DeepSeek：

```text
Base URL: https://api.deepseek.com
Model: deepseek-v4-flash
Endpoint: /chat/completions
Response format: json_object
```

也可配置任意支持 OpenAI Chat Completions 结构和 JSON mode 的兼容接口。

大模型用于：

1. 原始剧本 → 标准 Final Draft 元素；
2. 标准场景 → 场景、人物、道具证据；
3. 已确认资产 + 风格卡 → 可审阅生图提示词。

模型不直接写 FDX 文件，也不直接把未经审阅的资产送去生图。

## 火山方舟 Ark Images API

设置项：

```text
art.ark.endpoint
art.ark.model
Keychain: ark-api-key
```

默认：

```text
Endpoint: https://ark.cn-beijing.volces.com/api/v3/images/generations
Model: doubao-seedream-4-0-250828
Response format: b64_json
```

应用请求字段：

- `model`
- `prompt`
- `negative_prompt`（可选）
- `size`
- `image`（参考图，可为多张 Data URI）
- `sequential_image_generation`
- `sequential_image_generation_options.max_images`
- `response_format`
- `watermark`

应用同时兼容返回：

- `data[].b64_json`
- `data[].url`

下载后立即写入本地应用支持目录，并保存完整 `ArtPromptPlan`、模型、尺寸、风格卡 ID 和服务端 request ID。

## 密钥安全

LLM 和 Ark API Key 使用独立的 macOS Keychain account：

```text
service: com.meishutai.art-department-v2
accounts:
- llm-api-key
- ark-api-key
```

Key 不写入 workspace JSON、不进入 Git、不显示在导出文件中。

## 数据发送范围

### 标准化

发送当前 SourceUnit 分块及其 ID，不发送本地图片。

### 资产提取

发送单个标准场景，不发送整部剧本。这样可以减少跨场污染，也降低单次请求长度。

### 提示词规划

发送当前已确认资产、少量原文证据和用户选中的风格提示词。参考图不发送给大语言模型。

### Ark 生图

发送用户审阅后的生图提示词，以及用户主动选中的参考图。

## 错误语义

- HTTP 非 2xx：显示状态码和截断后的服务端信息；
- LLM 空内容或非法 JSON：不覆盖上次成功结果；
- SourceUnit 覆盖不完整：标准化失败；
- Ark 无图像数据：不创建空生成记录；
- URL 图片下载失败：本轮失败，不写入不完整历史；
- 所有网络操作最多保留有限重试，不无限阻塞界面。
