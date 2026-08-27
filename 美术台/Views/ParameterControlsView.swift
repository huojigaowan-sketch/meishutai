import SwiftUI

struct ParameterControlsView: View {
    @Binding var asset: AssetItem

    @State private var expandedGroups: Set<PromptParameterGroup> = []

    private var availableGroups: [PromptParameterGroup] {
        PromptParameterGroup.allCases.filter { group in
            PromptParameter.allCases.contains { parameter in
                parameter.group == group
                    && parameter.supports(asset.kind)
                    && parameter.isVisibleInControls
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("专业美术摄影参数", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Text("\(availableParameterCount) 项")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text("点击任一规格可选择该项，并在选项旁查看对应的彩色效果预览。")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(availableGroups) { group in
                DisclosureGroup(
                    isExpanded: expansionBinding(for: group)
                ) {
                    if expandedGroups.contains(group) {
                        ParameterGroupView(
                            group: group,
                            kind: asset.kind,
                            selections: $asset.parameterSelections
                        )
                        .padding(.top, 12)
                    }
                } label: {
                    Label(group.title, systemImage: group.systemImage)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var availableParameterCount: Int {
        PromptParameter.allCases.count(where: {
            $0.supports(asset.kind) && $0.isVisibleInControls
        })
    }

    private func expansionBinding(for group: PromptParameterGroup) -> Binding<Bool> {
        Binding(
            get: { expandedGroups.contains(group) },
            set: { isExpanded in
                if isExpanded {
                    expandedGroups.insert(group)
                } else {
                    expandedGroups.remove(group)
                }
            }
        )
    }
}

private struct ParameterGroupView: View {
    let group: PromptParameterGroup
    let kind: AssetKind
    @Binding var selections: [String: String]

    private var parameters: [PromptParameter] {
        PromptParameter.allCases.filter {
            $0.group == group && $0.supports(kind) && $0.isVisibleInControls
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(parameters) { parameter in
                ParameterOptionChoices(
                    parameter: parameter,
                    kind: kind,
                    selection: selectionBinding(for: parameter)
                )
            }
        }
    }

    private func selectionBinding(for parameter: PromptParameter) -> Binding<String> {
        Binding(
            get: {
                let options = parameter.options(for: kind)
                let persisted = selections[parameter.rawValue]
                if let persisted, options.contains(where: { $0.id == persisted }) {
                    return persisted
                }
                let defaultID = parameter.defaultOptionID(for: kind)
                return options.first(where: { $0.id == defaultID })?.id
                    ?? options.first?.id
                    ?? defaultID
            },
            set: { newValue in
                parameter.applySelection(
                    newValue,
                    for: kind,
                    to: &selections
                )
            }
        )
    }
}

private struct ParameterOptionChoices: View {
    let parameter: PromptParameter
    let kind: AssetKind
    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(parameter.title, systemImage: parameter.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(parameter.options(for: kind)) { option in
                    PromptOptionChoiceButton(
                        parameter: parameter,
                        option: option,
                        isSelected: selection == option.id
                    ) {
                        selection = option.id
                    }
                }
            }
        }
    }
}

private struct PromptOptionChoiceButton: View {
    let parameter: PromptParameter
    let option: PromptOption
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isPreviewPresented = false

    private var context: PromptOptionPreviewContext {
        PromptOptionPreviewContext(parameter: parameter, option: option)
    }

    var body: some View {
        Button {
            isPreviewPresented = true
            onSelect()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .imageScale(.small)
                Text(option.title)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(isSelected ? .accentColor : .secondary)
        .help(option.detail)
        .popover(
            isPresented: $isPreviewPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .leading
        ) {
            PromptPhotoPreviewPopover(context: context)
        }
        .accessibilityLabel("\(parameter.title)：\(option.title)")
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier("prompt-option.\(parameter.rawValue).\(option.id)")
    }

    private var accessibilityHint: String {
        let prompt = option.promptToken.isEmpty
            ? "无，不写入最终英文提示词"
            : "最终提示词：\(option.promptToken)"
        return "\(option.detail)。\(prompt)"
    }

}
