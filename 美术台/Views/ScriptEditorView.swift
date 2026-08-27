import SwiftUI

struct ScriptEditorView: View {
    @Bindable var store: WorkspaceStore
    let onImport: () -> Void

    @State private var isConfirmingEpisodeDeletion = false
    @State private var analysisReview: EpisodeAnalysisReview?

    private var normalizedText: String {
        store.scriptText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            episodeHeader
            notices
            editor
            ScriptAnalysisDock(
                store: store,
                analysisReview: $analysisReview,
                hasScript: !normalizedText.isEmpty,
                onImport: onImport
            )
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .task(id: store.currentEpisode?.updatedAt) {
            do {
                try await Task.sleep(for: .milliseconds(500))
                store.persistCurrentEpisode()
            } catch {
                return
            }
        }
        .confirmationDialog(
            "删除当前分集？",
            isPresented: $isConfirmingEpisodeDeletion
        ) {
            Button("删除分集", role: .destructive) {
                store.deleteCurrentEpisode()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该集剧本和提取快照会被删除；仍在其他分集出现的资产会继续保留。")
        }
        .sheet(item: $analysisReview) { review in
            EpisodeAnalysisConfirmationView(
                review: review,
                onCancel: {
                    analysisReview = nil
                },
                onConfirm: {
                    analysisReview = nil
                    store.startConfirmedEpisodeAnalysis(review)
                }
            )
        }
    }

    private var episodeHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Image(systemName: "pencil.line")
                        .foregroundStyle(.tertiary)

                    TextField(
                        "给这一集起个容易识别的名字",
                        text: $store.currentEpisodeTitle
                    )
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                    .disabled(store.isAnalyzing)
                }

                HStack(spacing: 7) {
                    Text(store.sourceFileName ?? "手动输入")
                    Text("·")
                    Text("\(normalizedText.count.formatted()) 字符")
                        .monospacedDigit()

                    if let extractedAt = store.currentEpisode?.extractedAt {
                        Text("·")
                        Text(
                            "上次提取 \(extractedAt.formatted(date: .abbreviated, time: .shortened))"
                        )
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            if let episode = store.currentEpisode {
                statusBadge(for: episode)
            }

            episodeControls
        }
    }

    private var episodeControls: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(store.episodes) { episode in
                    Button {
                        store.selectEpisode(episode.id)
                    } label: {
                        Label(
                            pickerTitle(for: episode),
                            systemImage: episode.effectiveStatus.systemImage
                        )
                    }
                }
            } label: {
                Label(
                    store.currentEpisode.map(pickerTitle) ?? "选择分集",
                    systemImage: "square.stack.3d.up"
                )
            }
            .help("切换分集")

            Button {
                store.addEpisode()
            } label: {
                Label("新建分集", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("新建分集")
            .disabled(store.isAnalyzing)

            Menu {
                Button {
                    onImport()
                } label: {
                    Label("导入到本集", systemImage: "doc.badge.plus")
                }

                Button {
                    store.loadExampleScript()
                } label: {
                    Label("载入示例", systemImage: "text.badge.star")
                }

                Divider()

                Button(role: .destructive) {
                    isConfirmingEpisodeDeletion = true
                } label: {
                    Label("删除本集", systemImage: "trash")
                }
                .disabled(store.episodes.count <= 1 || store.isAnalyzing)
            } label: {
                Label("分集选项", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("更多分集操作")
        }
    }

    @ViewBuilder
    private var notices: some View {
        if let storageNotice = store.storageNotice {
            noticeRow(
                storageNotice,
                systemImage: "externaldrive.badge.exclamationmark",
                color: .red
            )
        }

        if let analysisNotice = store.analysisNotice {
            noticeRow(
                analysisNotice,
                systemImage: "info.circle.fill",
                color: .secondary
            )
        }

        if let overview = store.projectExtractionOverview {
            ProjectExtractionOverviewNotice(overview: overview)
        }

        if let coverage = store.currentExtractionCoverage {
            noticeRow(
                "本集证据账本：\(coverage.summaryLine)",
                systemImage: coverage.invalidEvidenceCount == 0
                    ? "checkmark.shield.fill"
                    : "exclamationmark.shield.fill",
                color: coverage.invalidEvidenceCount == 0 ? .secondary : .orange
            )
        }

        if let lastError = store.currentEpisode?.lastError,
           store.currentEpisode?.effectiveStatus == .failed {
            noticeRow(
                "本集上次没有提取成功：\(lastError)。之前保存的结果没有被删除。",
                systemImage: "xmark.circle.fill",
                color: .red
            )
        }

        if let warnings = store.currentEpisode?.extractionWarnings,
           !warnings.isEmpty {
            noticeRow(
                "本集完整性复核：\(warnings.joined(separator: "；"))",
                systemImage: "exclamationmark.triangle.fill",
                color: .orange
            )
        }

    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $store.scriptText)
                .font(.body.monospaced())
                .textEditorStyle(.plain)
                .padding(16)
                .disabled(store.isAnalyzing)

            if normalizedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("从这一集开始", systemImage: "text.cursor")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("可以粘贴单集或整部剧本；整部剧本会先在本地自动识别分集。也可以从右上角导入 TXT / Markdown。")
                        .foregroundStyle(.tertiary)
                }
                .padding(22)
                .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 320, maxHeight: .infinity)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary)
        }
    }

    private func pickerTitle(for episode: ScriptEpisode) -> String {
        let defaultTitle = "第 \(episode.order) 集"
        return episode.displayTitle == defaultTitle
            ? defaultTitle
            : "\(episode.order) · \(episode.displayTitle)"
    }

    private func statusBadge(for episode: ScriptEpisode) -> some View {
        let status = episode.effectiveStatus
        return Label(status.title, systemImage: status.systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(statusColor(status).opacity(0.1), in: .capsule)
    }

    private func statusColor(_ status: EpisodeExtractionStatus) -> Color {
        switch status {
        case .notExtracted:
            .secondary
        case .extracting:
            .blue
        case .completed:
            .green
        case .completedWithWarnings:
            .orange
        case .stale:
            .orange
        case .failed:
            .red
        }
    }

    private func noticeRow(
        _ message: String,
        systemImage: String,
        color: Color
    ) -> some View {
        Label(message, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(color)
            .textSelection(.enabled)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ExtractionReviewNotice: View {
    let count: Int
    let onReview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label(
                "项目有 \(count) 项场景/人物/道具候选有原文证据但身份存疑，尚未写入资产库。",
                systemImage: "person.crop.circle.badge.questionmark"
            )
            .font(.callout)
            .foregroundStyle(.orange)

            Spacer(minLength: 8)

            Button("逐项复核", action: onReview)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .padding(.vertical, 4)
    }
}

private struct ScriptAnalysisDock: View {
    @AppStorage("llm.provider") private var providerRawValue = LLMProvider.deepSeek.rawValue
    @Bindable var store: WorkspaceStore
    @Binding var analysisReview: EpisodeAnalysisReview?
    let hasScript: Bool
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            AnalysisDockSummary(title: title, detail: detail)

            Spacer(minLength: 12)

            AnalysisDockControls(
                store: store,
                analysisReview: $analysisReview,
                hasScript: hasScript,
                onImport: onImport
            )
        }
        .padding(14)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private var title: String {
        guard store.isAnalyzing else {
            return hasScript ? "第一阶段 · 提取资产与概览" : "放入单集或整部剧本"
        }

        let episodeTitle = store.currentAnalyzingEpisodeTitle ?? "正在准备"
        guard store.analysisTotalEpisodeCount > 1 else {
            return "第一阶段 · \(episodeTitle)"
        }
        let current = max(1, store.analysisCurrentEpisodeIndex)
        return "第一阶段 · 第 \(current) / \(store.analysisTotalEpisodeCount) 集 · \(episodeTitle)"
    }

    private var detail: String {
        if store.isAnalyzing {
            let provider = store.analysisProviderName
                ?? (LLMProvider(rawValue: providerRawValue) ?? .deepSeek).title
            let completed = store.analysisCompletedEpisodeCount
            let total = store.analysisTotalEpisodeCount
            let batchProgress = total > 1 ? " · 已完成 \(completed) / \(total) 集" : ""
            return "\(provider) · \(phaseDescription)\(batchProgress)"
        }
        if !hasScript {
            return "整部剧本会先在本地识别分集，也可以直接导入单集文本。"
        }
        if let metrics = store.currentEpisode?.analysisMetrics {
            let usage = metrics.usageSummary.map { " · \($0)" } ?? ""
            switch metrics.route {
            case .deepSeekChunked:
                return "上次按本地证据账本分 \(metrics.segmentCount ?? 1) 个语义批次提取；结果已立即保存\(usage)。"
            case .deepSeekOnly:
                return "上次由本地证据账本与模型完成，并已立即保存\(usage)。"
            case .hybrid, .deepSeekFallback:
                return "上次结果来自旧版分析流程；重新提取后会改用当前逐集流程。"
            }
        }
        return "先在本地识别场次和候选，再由模型分类并按原文证据校验。"
    }

    private var phaseDescription: String {
        let progress = store.analysisProgress
            ?? EpisodeAnalysisProgress(stage: .preparing)
        let stageDescription: String
        switch progress.stage {
        case .preparing:
            stageDescription = "正在准备当前集请求"
        case .extractingSegment(let current, let total):
            stageDescription = "正在双重核验语义批次 \(current) / \(total)"
        case .auditingSegment(let current, let total):
            stageDescription = "正在独立审计分段 \(current) / \(total)"
        case .repairingSegment(let current, let total, let round, let totalRounds):
            stageDescription = "正在补齐遗漏 \(round) / \(totalRounds) · 分段 \(current) / \(total)"
        case .organizing(let segmentCount):
            stageDescription = "正在整理 \(segmentCount) 个分段的资产别名"
        case .saving:
            stageDescription = "正在保存当前集结果"
        }

        guard let retry = progress.retry else { return stageDescription }
        if let delay = retry.delay, delay >= 1 {
            return "\(stageDescription) · 重试 \(retry.attempt) / \(retry.maximumAttempts)（等待 \(Int(ceil(delay))) 秒）"
        }
        return "\(stageDescription) · 重试 \(retry.attempt) / \(retry.maximumAttempts)"
    }
}

private struct AnalysisDockSummary: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct AnalysisDockControls: View {
    @Bindable var store: WorkspaceStore
    @Binding var analysisReview: EpisodeAnalysisReview?
    let hasScript: Bool
    let onImport: () -> Void

    var body: some View {
        if store.isAnalyzing {
            AnalysisRunningControls(
                startedAt: store.analysisStartedAt ?? .now,
                isCancelling: store.isCancellingAnalysis,
                onCancel: store.cancelAnalysis
            )
        } else {
            Menu {
                Button(action: onImport) {
                    Label("导入文本", systemImage: "doc.badge.plus")
                }

                Button {
                    store.loadExampleScript()
                } label: {
                    Label("载入示例", systemImage: "text.badge.star")
                }

                if store.pendingEpisodeCount > 0 {
                    Divider()

                    Button {
                        analysisReview = store.preparePendingEpisodeAnalysis()
                    } label: {
                        Label(
                            "确认所有待提取分集",
                            systemImage: "square.stack.3d.up"
                        )
                    }
                }


                if store.episodes.contains(where: { $0.effectiveStatus == .failed }) {
                    Divider()
                    Button {
                        analysisReview = store.prepareFailedEpisodeAnalysis()
                    } label: {
                        Label("重试失败分集", systemImage: "arrow.clockwise.circle")
                    }
                }
            } label: {
                Label("更多", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .disabled(store.isAIJobRunning)

            Button {
                analysisReview = store.prepareCurrentEpisodeAnalysis()
            } label: {
                Label(primaryActionTitle, systemImage: "checklist.checked")
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(store.isAIJobRunning || !hasScript)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
        }
    }

    private var primaryActionTitle: String {
        switch store.currentEpisode?.effectiveStatus {
        case .completed, .completedWithWarnings, .stale, .failed:
            "确认分集并重新提取"
        default:
            "确认初始分集并开始提取"
        }
    }
}

private struct AnalysisRunningControls: View {
    let startedAt: Date
    let isCancelling: Bool
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)
                Text("已用时")
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let seconds = max(0, Int(context.date.timeIntervalSince(startedAt)))
                    Text(
                        Duration.seconds(seconds),
                        format: .time(
                            pattern: .hourMinuteSecond(
                                padHourToLength: 1,
                                fractionalSecondsLength: 0
                            )
                        )
                    )
                    .monospacedDigit()
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Button(role: .destructive, action: onCancel) {
                Label(
                    isCancelling ? "正在取消" : "取消提取",
                    systemImage: isCancelling ? "hourglass" : "stop.circle"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isCancelling)
        }
    }
}

private struct EpisodeAnalysisConfirmationView: View {
    let review: EpisodeAnalysisReview
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            EpisodeAnalysisConfirmationHeader(
                episodeCount: review.episodes.count,
                sceneCount: review.episodes.reduce(0) {
                    $0 + $1.sceneHeadings.count
                },
                missingEpisodeCount: review.episodes.count(where: {
                    $0.sceneHeadings.isEmpty
                }),
                blockingIssues: review.blockingIssues
            )

            Divider()

            EpisodeAnalysisConfirmationList(
                episodes: review.episodes
            )

            Divider()

            EpisodeAnalysisConfirmationFooter(
                canStart: review.canAnalyze,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
        .frame(minWidth: 860, idealWidth: 980, minHeight: 620, idealHeight: 700)
    }
}

private struct EpisodeAnalysisConfirmationHeader: View {
    let episodeCount: Int
    let sceneCount: Int
    let missingEpisodeCount: Int
    let blockingIssues: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checklist.checked")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 5) {
                Text("第一阶段 · 确认初始分集")
                    .font(.title2.weight(.semibold))

                Text("请先核对本地识别的集数与场次；确认后每集都会建立逐字可验证的证据账本，人物与道具再经两次独立判定。本页不显示剧情正文。")
                    .foregroundStyle(.secondary)

                Text("共 \(episodeCount) 集 · \(sceneCount) 场")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                if missingEpisodeCount > 0 {
                    Label(
                        "有 \(missingEpisodeCount) 集未识别到场景标题，请返回修正场号。",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.orange)
                }

                if !blockingIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(
                            "检测到 \(blockingIssues.count) 项分集结构异常，已禁止启动模型。",
                            systemImage: "xmark.octagon.fill"
                        )
                        .font(.callout.weight(.semibold))

                        Text(
                            blockingIssues
                                .prefix(8)
                                .map { "• \($0)" }
                                .joined(separator: "\n")
                        )
                        .font(.caption)
                        .textSelection(.enabled)
                    }
                    .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }
}

private struct EpisodeAnalysisConfirmationList: View {
    let episodes: [EpisodeAnalysisPreview]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(episodes) { episode in
                    EpisodeAnalysisConfirmationCard(
                        order: episode.order,
                        title: episode.title,
                        sceneHeadings: episode.sceneHeadings
                    )
                }
            }
            .padding(20)
        }
        .background(.quaternary.opacity(0.18))
    }
}

private struct EpisodeAnalysisConfirmationCard: View {
    let order: Int
    let title: String
    let sceneHeadings: [EpisodeSceneHeading]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.headline)

                Text("\(sceneHeadings.count) 场")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            if sceneHeadings.isEmpty {
                Label(
                    "未识别到场景标题行。场号应类似“\(order)-1 日/外 场景名 人物：角色名”。",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sceneHeadings) { heading in
                        Text(heading.text)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2))
        }
    }
}

private struct EpisodeAnalysisConfirmationFooter: View {
    let canStart: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Spacer()

            Button("返回修改分集", action: onCancel)
                .buttonStyle(.bordered)

            Button("确认初始分集并开始提取", action: onConfirm)
                .buttonStyle(.glassProminent)
                .disabled(!canStart)
                .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(16)
    }
}

private struct ProjectExtractionOverviewNotice: View {
    let overview: ProjectExtractionOverview

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(overview.episodes) { episode in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("\(episode.order). \(episode.title)")
                                .font(.callout.weight(.semibold))
                            Spacer()
                            Text(episode.summaryLine)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        let highlights = Array(
                            (episode.sceneSummaries
                                + episode.characterSummaries
                                + episode.propSummaries).prefix(6)
                        )
                        if !highlights.isEmpty {
                            Text(highlights.map { "• \($0)" }.joined(separator: "\n"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(12)
                        }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.25), in: .rect(cornerRadius: 8))
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 8) {
                Label("第一阶段概览", systemImage: "doc.text.magnifyingglass")
                    .font(.callout.weight(.medium))
                Spacer()
                Text(overview.summaryLine)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ScriptEditorView(store: WorkspaceStore(), onImport: {})
        .frame(width: 920, height: 720)
}
