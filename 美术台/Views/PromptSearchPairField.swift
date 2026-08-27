import SwiftUI

struct PromptSearchPairField: View {
    let title: String
    @Binding var text: String
    @Binding var searchKeywords: String?
    let minimumLines: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("EN 设计提示")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            TextField(title, text: $text, axis: .vertical)
                .lineLimit(minimumLines...10)

            if !text.isEmpty, !PromptCompiler.english(text) {
                Label(
                    "含有非英文字符，不会进入最终英文设计提示词。",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption2)
                .foregroundStyle(.red)
            }

            Divider()

            HStack(spacing: 8) {
                Label("对应中文参考图搜索词", systemImage: "photo.badge.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("中文搜图词")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                CopySearchKeywordsButton(keywords: normalizedSearchKeywords)
            }

            TextField(
                "例如：九十年代 上海弄堂 老旧石库门 生活化摄影",
                text: editableSearchKeywords,
                axis: .vertical
            )
            .lineLimit(2...5)

            if normalizedSearchKeywords.isEmpty {
                Text("用于 Pinterest、小红书等图片平台；重新提取可由大模型自动补齐，也可手动编辑。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if !SearchKeywordCompiler.containsChinese(normalizedSearchKeywords) {
                Label(
                    "建议补充中文视觉名词，搜索结果会更贴近国内图片平台。",
                    systemImage: "exclamationmark.magnifyingglass"
                )
                .font(.caption2)
                .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var editableSearchKeywords: Binding<String> {
        Binding(
            get: { searchKeywords ?? "" },
            set: { searchKeywords = $0 }
        )
    }

    private var normalizedSearchKeywords: String {
        searchKeywords?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

}

struct ReferenceSearchKeywordsView: View {
    let keywords: String

    var body: some View {
        GroupBox("中文参考图搜索词") {
            VStack(alignment: .leading, spacing: 10) {
                Text(keywords)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("已自动合并当前资产、人物设计或道具细节、当前服装和你明确选择的视觉参数，并去重控制长度。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    CopySearchKeywordsButton(keywords: keywords)
                }
            }
            .padding(.top, 4)
        }
    }
}

#Preview("中文参考图搜索词") {
    ReferenceSearchKeywordsView(
        keywords: "都市女性调查员 三十岁女性 椭圆脸 深灰长大衣 冬季调查员穿搭 电影真人写实 伦勃朗光"
    )
    .padding(24)
    .frame(width: 520)
}

private struct CopySearchKeywordsButton: View {
    let keywords: String
    var prominent = false

    @State private var copied = false

    var body: some View {
        Button {
            guard ClipboardService.copy(keywords) else {
                return
            }
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            Label(
                copied ? "已复制" : "复制搜索词",
                systemImage: copied ? "checkmark" : "doc.on.doc"
            )
        }
        .buttonStyle(.bordered)
        .controlSize(prominent ? .regular : .small)
        .tint(copied ? .green : nil)
        .disabled(keywords.isEmpty)
        .help("复制到剪贴板，可直接粘贴到 Pinterest 或小红书搜索")
        .accessibilityLabel(copied ? "中文搜索词已复制" : "复制中文搜索词")
    }
}
