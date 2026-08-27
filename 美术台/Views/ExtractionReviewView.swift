import SwiftUI

struct ExtractionReviewView: View {
    @Bindable var store: WorkspaceStore
    let onClose: () -> Void
    @State private var selectedCandidateIDs: Set<String> = []
    @State private var mergedCanonicalName = ""

    private var items: [ExtractionReviewItem] {
        store.projectExtractionReviewItems
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 760, idealWidth: 900, minHeight: 540, idealHeight: 680)
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checkmark.shield")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 5) {
                Text("人工复核存疑候选")
                    .font(.title2.weight(.semibold))
                Text("这些场景、人物或道具有原文证据，但两次独立判定未达成可靠共识。确认前不会写入资产库。")
                    .foregroundStyle(.secondary)
                Text("剩余 \(items.count) 项")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)

        if selectedCandidateIDs.count >= 2 {
            HStack(spacing: 10) {
                TextField("合并后的规范名称", text: $mergedCanonicalName)
                    .textFieldStyle(.roundedBorder)
                Button("合并所选 \(selectedCandidateIDs.count) 项") {
                    let selectedItems = items.filter {
                        selectedCandidateIDs.contains($0.candidateID)
                    }
                    store.mergeExtractionCandidates(
                        selectedItems,
                        canonicalName: mergedCanonicalName
                    )
                    selectedCandidateIDs.removeAll()
                    mergedCanonicalName = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(mergedCanonicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private var content: some View {
        if items.isEmpty {
            ContentUnavailableView(
                "复核完成",
                systemImage: "checkmark.seal.fill",
                description: Text("本集所有候选均已有明确结论，资产库已同步更新。")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        ExtractionReviewCard(
                            item: item,
                            isSelectedForMerge: selectedCandidateIDs.contains(item.candidateID),
                            onToggleMergeSelection: {
                                if selectedCandidateIDs.contains(item.candidateID) {
                                    selectedCandidateIDs.remove(item.candidateID)
                                } else {
                                    selectedCandidateIDs.insert(item.candidateID)
                                }
                            },
                            onAccept: { name in
                                store.resolveExtractionCandidate(
                                    episodeID: item.episodeID,
                                    candidateID: item.candidateID,
                                    disposition: .accepted,
                                    canonicalName: name
                                )
                            },
                            onReject: {
                                store.resolveExtractionCandidate(
                                    episodeID: item.episodeID,
                                    candidateID: item.candidateID,
                                    disposition: .rejected,
                                    canonicalName: item.rawName
                                )
                            }
                        )
                    }
                }
                .padding(20)
            }
            .background(.quaternary.opacity(0.16))
        }
    }

    private var footer: some View {
        HStack {
            Text("每次决定都会立即重建该集资产并持久化。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(items.isEmpty ? "完成" : "稍后继续", action: onClose)
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }
}

private struct ExtractionReviewCard: View {
    let item: ExtractionReviewItem
    let isSelectedForMerge: Bool
    let onToggleMergeSelection: () -> Void
    let onAccept: (String) -> Void
    let onReject: () -> Void

    @State private var canonicalName: String

    init(
        item: ExtractionReviewItem,
        isSelectedForMerge: Bool,
        onToggleMergeSelection: @escaping () -> Void,
        onAccept: @escaping (String) -> Void,
        onReject: @escaping () -> Void
    ) {
        self.item = item
        self.isSelectedForMerge = isSelectedForMerge
        self.onToggleMergeSelection = onToggleMergeSelection
        self.onAccept = onAccept
        self.onReject = onReject
        _canonicalName = State(
            initialValue: item.proposedCanonicalName.isEmpty
                ? item.rawName
                : item.proposedCanonicalName
        )
    }

    private var trimmedCanonicalName: String {
        canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Toggle("选择合并", isOn: Binding(
                    get: { isSelectedForMerge },
                    set: { _ in onToggleMergeSelection() }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .help("选择多个候选并合并为同一资产")
                Label(item.kind.title, systemImage: item.kind.systemImage)
                    .font(.callout.weight(.semibold))
                Text(item.rawName)
                    .font(.headline)
                Text(item.episodeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.confidence, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(item.evidence)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary.opacity(0.28), in: .rect(cornerRadius: 8))

            if !item.reason.isEmpty {
                Text(item.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                TextField("规范名称", text: $canonicalName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(accept)

                Button("不是资产", role: .destructive, action: onReject)
                    .buttonStyle(.bordered)

                Button("确认收录", action: accept)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedCanonicalName.isEmpty)
            }
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2))
        }
    }

    private func accept() {
        guard !trimmedCanonicalName.isEmpty else { return }
        onAccept(trimmedCanonicalName)
    }
}
