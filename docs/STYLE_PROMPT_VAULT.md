# 风格提示词图书馆

## 决策权

风格是创作决策，不是可由系统推断的技术参数。每次提示词规划和生图必须满足以下任一条件：

1. 用户从风格图书馆明确勾选一张或多张卡片；
2. 用户在生图工坊输入本轮外部风格提示词。

没有明确风格来源时，重新规划和生图按钮不可用，管线也会抛出 `noSelectedStyle`。系统不根据资产类型、生成模式、更新时间或模型评分自行选卡。

外部风格可先测试，不会静默写入图书馆；只有用户点击“测试后存入风格图书馆”才会成为持久资产。

## 数据契约

每张风格卡保存：标题、分类、精确提示词、参考图、标签、备注、锁定状态、Apple Vision 特征签名，以及开源卡可选的仓库/路径/提交/许可证/原始 ID。

## 本机加密

```text
Application Support/MeishutaiV2/
  workspace-v4.vault          # 项目、提示词、生成历史元数据
  vault-backups/              # 最近 20 个加密快照
  style-images/*.vault        # 参考图 AES-GCM 容器
  generated-images/           # 生图结果
```

- 算法：CryptoKit `AES.GCM`，同时提供机密性与完整性校验；
- 密钥：随机 256 位，只存入 macOS Keychain，属性为 `WhenUnlockedThisDeviceOnly`；
- 权限：目录 `0700`、加密文件 `0600`；
- 写入：临时文件、原子替换、替换前加密备份；
- 迁移：成功生成并验证加密容器后，删除旧 `workspace-v2.json` 和明文参考图；
- 显示：参考图仅在内存中解密为 `NSImage`，不为界面生成明文缓存文件。

Keychain 密钥属于本机保护边界。仅复制 `.vault` 文件到另一台设备不足以解密；迁移设备必须同时使用受信任的系统迁移方案迁移 Keychain。

## Apple Vision 本地查重

参考图解密到内存后，使用 `GenerateImageFeaturePrintRequest` 生成特征并比较距离。查重数据不上传第三方。极近重复图会提示复用已有卡片，但最终是否采用该风格仍由用户选择。

## 内置开源卡

项目内置 56 张来自 MIT 仓库的提示词卡，固定到不可变提交并保留逐卡来源元数据。详见：

- `docs/STYLE_LIBRARY_SOURCES.md`
- `THIRD_PARTY_NOTICES.md`

参考图片未从第三方仓库复制；用户必须自行提供有权使用的图片。

## 生图计划

```text
自动通过资产
  + 用户明确选择的图书馆卡片 / 本轮外部风格
  + 生成模式
  + 用户补充方向
  → AppleSchemaPromptPlan
  → Ark
```
