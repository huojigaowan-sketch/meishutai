# 美术台 2.0

美术台是一套面向影视美术部门的 macOS 原生工作台。2.0 版本重构了旧的“直接从任意文本猜资产”流程：任何剧本文本先经过大模型完整转换为标准 Final Draft/Fountain，再从确定的场景边界逐场提取场景、人物和道具，并为每项结果保存逐字证据、置信度和人工审阅状态。

## 核心工作流

```text
任意剧本文本
    ↓ 证据单元覆盖校验
标准 Final Draft / Fountain
    ↓ 逐场结构化提取
场景 / 人物 / 道具证据账本
    ↓ 人工确认
风格提示词选择与锁定
    ↓ 大模型编译材质、构图、元素和连续性
可审阅生图提示词
    ↓ 火山方舟 Ark Images API
文生图 / 参考图生图 / AO 白模 / 材质回绘 / 反打 / 队列设计
```

## 为什么先标准化剧本

- 任意来源的剧本可能混用小说、分镜、聊天记录、Markdown、中文场号和非标准人物对白格式。
- 标准化阶段为每段原文分配稳定 `SourceUnit ID`，模型必须完整回执全部 ID；缺失、重复或未知 ID 会使本轮失败，而不是静默继续。
- 标准场景标题和 Final Draft 元素确定后，场景、人物和道具提取不再依赖模糊的全文切分。
- FDX 导出由本地确定性 XML 生成，不让模型自由书写 Final Draft 文件。

## 四个工作区

1. **剧本标准化**：导入 TXT、Markdown、Fountain 或 FDX；生成可审阅、可编辑、可导出的标准剧本。
2. **资产审阅**：按场景逐项核对场景、人物、道具；每项都展示逐字证据和校验置信度。
3. **风格提示词库**：参考图、标题、用户精确提示词、标签和备注成对本地保存；用户提示词默认锁定。
4. **生图工坊**：选择资产和风格卡，由大模型编译提示词，再调用火山方舟 Ark 文生图或参考图生图。

## 内置操作模板

内置模板来自项目需求本身，不捆绑第三方图片：

- 材质 / 构图 / 元素审阅
- 十人同服装角色队列
- AO 白模严格复刻
- 白模材质回绘与人物三视图
- 场景减噪 30%
- 指定机位重构
- 场景镜头反打

用户应为需要高度一致性的风格自行上传有权使用的参考图和精确提示词。

## API 配置

在应用设置中配置：

- 大语言模型：DeepSeek 或 OpenAI 兼容 `/chat/completions` 接口；
- 图像生成：火山方舟 Ark Images API；
- API Key 只写入 macOS Keychain；剧本、风格参考图和生成结果保存在应用支持目录。

详见：

- [`docs/ART_DEPARTMENT_V2_ARCHITECTURE.md`](docs/ART_DEPARTMENT_V2_ARCHITECTURE.md)
- [`docs/EXTRACTION_ACCURACY_CONTRACT.md`](docs/EXTRACTION_ACCURACY_CONTRACT.md)
- [`docs/STYLE_PROMPT_VAULT.md`](docs/STYLE_PROMPT_VAULT.md)
- [`docs/API_CONFIGURATION_V2.md`](docs/API_CONFIGURATION_V2.md)

## 工程

- 平台：macOS 27+
- UI：SwiftUI / AppKit
- 项目：`美术台.xcodeproj`
- Scheme：`美术台`
- 新源码放在文件系统同步的 `美术台/` 目录，无需手动维护 PBX 文件列表。

## 验证重点

最终本机验证应覆盖：

1. 大体量文本分块后 SourceUnit 仍全部覆盖；
2. 标准化失败时原文和上次成功结果不被覆盖；
3. FDX 导入、Fountain 编辑和 FDX 导出可往返；
4. 每项资产证据确实是对应场景的逐字子串；
5. 低于 0.86 的结果不会自动标为已确认；
6. 风格参考图与提示词重启后仍可读取；
7. Ark 文生图、参考图生图、批量结果和错误响应均可恢复。
