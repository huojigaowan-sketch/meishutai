# 美术台 3.0 · Apple 自动美术资产流水线

美术台是一套面向影视美术部门的 macOS 原生工作台。3.0 不再把低置信度结果交给人逐项确认，而是把准确性做成自动化系统属性：任意剧本先转为标准 Final Draft/Fountain，再由 Apple Foundation Models、content tagging、Natural Language、Vision、确定性解析器和可选远程模型共同完成场景、人物、道具的提取、核验、隔离和生产入库。

## 核心工作流

```text
TXT / Markdown / Fountain / FDX / PDF / 图片剧本
    ↓ Apple 文档读取、OCR 与 SourceUnit 全覆盖
标准 Final Draft / Fountain
    ↓ @Generable / @Guide / GenerationSchema
逐场多引擎提取
    ↓ Scene Heading + Character 确定性候选
    ↓ Foundation Models general + contentTagging
    ↓ Natural Language 实体与别名校验
    ↓ 逐字 evidence + 多引擎共识
自动通过的场景 / 人物 / 道具生产库
    ↓ 低证据候选自动隔离，不阻塞、不分配人工任务
用户锁定风格提示词 + Apple Vision 参考图签名
    ↓ Apple GenerationSchema 生图计划
火山方舟 Ark 文生图 / 图生图
```

## 没有人工审阅步骤

- 标准 `Scene Heading` 确定性建立场景资产。
- 标准 `Character` 元素确定性建立说话人物资产。
- 模型候选必须引用当前场景中的逐字子串。
- Apple 本地模型、专用 content tagging、Natural Language 和可选远程模型形成自动共识。
- 通过策略的结果直接进入生产资产库；证据不足的候选进入只读诊断区并自动排除在导出、生图和后续生产之外。
- 诊断区用于观察系统行为，不要求用户逐项处理。

## Apple 原生技术栈

- **Foundation Models**：`SystemLanguageModel`、`LanguageModelSession`、`@Generable`、`@Guide`、`GenerationSchema`、`GeneratedContent(json:)`、`prewarm`。
- **Foundation Models content tagging**：专用适配器提取动作、物体、地点和制作主题。
- **Natural Language**：`NLTagger` 提取人名/地名/组织名；`NLEmbedding` 只在高相似度时自动归并别名。
- **Vision Swift API**：`RecognizeTextRequest` 读取图片与扫描 PDF；`GenerateImageFeaturePrintRequest` 为风格参考图建立相似度签名并自动查重。
- **PDFKit / AppKit**：PDF 文本与无文本页面渲染；原生 macOS 文件工作流。
- **Swift Concurrency / Observation / CryptoKit / Keychain**：并行逐场处理、现代状态管理、来源指纹和安全密钥存储。

Apple Foundation Models 的 `Generable` 类型会转换为 JSON schema。应用内所有结构化模型调用都以同一组 Apple 类型为权威接口：本地模型直接 guided generation；远程接口返回的 JSON 先转为 `GeneratedContent`，再解码为相同的 `Generable` 类型，不再维护第二套响应结构。

## 四个工作区

1. **剧本标准化**：导入任意支持格式，一键完成 Final Draft 标准化和自动资产提取。
2. **自动资产库**：只显示自动通过的场景、人物、道具及逐字证据；隔离候选只在可选诊断窗口中展示。
3. **风格提示词库**：标题、用户精确提示词、标签、备注和参考图成对保存；提示词默认锁定，Vision 自动查重。
4. **生图工坊**：用户必须从风格图书馆明确选择卡片，或输入本轮外部风格；Apple Schema 随后生成材质、构图、元素、光影与锁定事实，再调用 Ark。

## 风格选择与数据保护

- 风格不根据资产类型、生成模式或模型判断自行选择。
- 用户可以从风格图书馆勾选一张或多张卡片，也可以粘贴本轮外部风格；外部风格仅在用户点击保存后进入图书馆。
- 自建提示词、项目数据和参考图使用 AES-GCM 加密；256 位密钥存入 macOS Keychain，文件与目录分别限制为 `0600` / `0700`。
- 加密工作区采用原子替换并保留最近 20 个加密备份；旧版明文工作区和参考图在迁移成功后删除。
- 内置开源卡固定到 `YouMind-OpenLab/ai-image-prompts-skill` 的 MIT 提交 `7c065c2b429bc75334239965768849cb00c8987d`，来源记录见 `docs/STYLE_LIBRARY_SOURCES.md`。

## 内置操作模板

- 材质 / 构图 / 元素分析
- 十人同服装角色队列
- AO 白模严格复刻
- 白模材质回绘与人物三视图
- 场景减噪 30%
- 指定机位重构
- 场景镜头反打

内置模板不捆绑来源不明的第三方图片。需要高一致性时，用户上传有权使用的参考图和精确提示词。

## API 配置

- Apple Foundation Models 是默认结构化提取核心，不需要 API Key。
- DeepSeek 或其他 OpenAI 兼容接口是可选的双引擎增强/兜底；留空即可纯本地运行。
- 远程模型必须通过相同 Apple `GenerationSchema` 适配器返回结构化数据。
- 图像生成使用火山方舟 Ark Images API。
- API Key 只写入 macOS Keychain。

## 文档

- [`docs/APPLE_AUTOMATED_EXTRACTION_ARCHITECTURE.md`](docs/APPLE_AUTOMATED_EXTRACTION_ARCHITECTURE.md)
- [`docs/ART_DEPARTMENT_V2_ARCHITECTURE.md`](docs/ART_DEPARTMENT_V2_ARCHITECTURE.md)
- [`docs/EXTRACTION_ACCURACY_CONTRACT.md`](docs/EXTRACTION_ACCURACY_CONTRACT.md)
- [`docs/STYLE_PROMPT_VAULT.md`](docs/STYLE_PROMPT_VAULT.md)
- [`docs/API_CONFIGURATION_V2.md`](docs/API_CONFIGURATION_V2.md)

## 工程

- 平台：macOS 26+
- UI：SwiftUI / AppKit
- AI：Foundation Models + Natural Language + Vision
- 项目：`美术台.xcodeproj`
- Scheme：`美术台`
- 源码目录采用 Xcode 文件系统同步，无需手工维护 PBX 文件列表。

## 最终本机验证重点

1. Apple Intelligence 可用、未就绪和设备不支持三种状态；
2. 纯 Apple 本地路线与 Apple + 远程双引擎路线；
3. 超长文本分块后 SourceUnit 无缺失、重复或未知 ID；
4. PDF 原生文本、扫描 PDF 和图片 OCR；
5. FDX 导入、Fountain 编辑与 FDX 导出往返；
6. 每项生产资产的 evidence 是对应场景逐字子串；
7. 隔离候选不会进入资产 JSON、生图选择或生产统计；
8. 风格参考图 Vision 查重和持久化；
9. Ark 文生图、参考图生图、批量结果和错误恢复。
