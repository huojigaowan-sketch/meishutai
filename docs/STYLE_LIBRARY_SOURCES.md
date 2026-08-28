# 风格图书馆开源来源

## 固定来源

- 仓库：`YouMind-OpenLab/ai-image-prompts-skill`
- 固定提交：`7c065c2b429bc75334239965768849cb00c8987d`
- 许可证：MIT
- 导入卡片：56 张
- 导入策略：每个来源文件选取前 7 条唯一、非空提示词；生成确定性 UUID；保留原始 ID、路径、提交和许可证。

## 来源文件

- `references/app-web-design.json`：7 张
- `references/comic-storyboard.json`：7 张
- `references/ecommerce-main-image.json`：7 张
- `references/game-asset.json`：7 张
- `references/infographic-edu-visual.json`：7 张
- `references/others.json`：7 张
- `references/poster-flyer.json`：7 张
- `references/profile-avatar.json`：7 张

## 维护规则

1. 不在运行时联网刷新，避免上游变化污染项目资产。
2. 不从许可证缺失、含糊或与项目分发方式不兼容的仓库复制内容。
3. 更新必须固定新提交、重新审阅许可证、运行重复 ID/空提示词/来源元数据测试。
4. 第三方提示词作为不可变内置卡片；用户自己的卡片单独存入加密风格库。
5. 未经用户明确选择，任何卡片都不会进入提示词规划或生图请求。
