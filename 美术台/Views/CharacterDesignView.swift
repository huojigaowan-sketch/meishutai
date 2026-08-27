import SwiftUI

struct CharacterDesignView: View {
    @Binding var profile: CharacterProfile
    @Binding var activeWardrobeID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            priorityHeader
            CharacterDesignOptionEditor(selections: designSelections)
            extractedDesignReference
            wardrobeSection
        }
    }

    private var priorityHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("人物设计档案", systemImage: "person.crop.rectangle.stack")
                .font(.headline)

            HStack {
                Picker("角色职能", selection: $profile.narrativeRole) {
                    ForEach(NarrativeRole.allCases) { role in
                        Text(role.title)
                            .tag(role)
                    }
                }

                Picker("重要级别", selection: $profile.importance) {
                    ForEach(CharacterImportance.allCases) { tier in
                        Text(tier.title)
                            .tag(tier)
                    }
                }
            }

            HStack {
                Text("家族 / 阵营")
                    .foregroundStyle(.secondary)
                TextField(
                    "例如：林氏家族、学生会、反派阵营",
                    text: $profile.affiliationName
                )
                .textFieldStyle(.roundedBorder)

                if profile.resolvedAppearanceCount > 0 {
                    Label(
                        "累计出镜 \(profile.resolvedAppearanceCount)",
                        systemImage: "eye"
                    )
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }

            HStack {
                LabeledContent("剧本年龄", value: profile.ageRange)
                LabeledContent("剧本性别呈现", value: profile.genderPresentation)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var extractedDesignReference: some View {
        DisclosureGroup("剧本提取的原始设计依据") {
            VStack(alignment: .leading, spacing: 10) {
                ExtractedDesignFact(title: "脸部", value: profile.facePrompt)
                ExtractedDesignFact(title: "体型", value: profile.physiquePrompt)
                ExtractedDesignFact(title: "发型妆造", value: profile.hairMakeupPrompt)
                ExtractedDesignFact(
                    title: "辨识特征",
                    value: profile.distinguishingFeaturesPrompt
                )
            }
            .padding(.top, 10)
        }
        .font(.subheadline)
    }

    private var wardrobeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("剧情服装方案", systemImage: "hanger")
                .font(.headline)

            Text("选择完整服装方案后，其英文服装设计词会与上方服装细项一起进入最终提示词。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if wardrobeChoices.isEmpty {
                Label(
                    "当前没有可选服装方案，请重新提取剧本。",
                    systemImage: "tshirt.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                WardrobeChoiceGrid(
                    choices: wardrobeChoices,
                    selection: $activeWardrobeID
                )
            }

            if let activeWardrobe {
                ActiveWardrobeMapping(look: activeWardrobe)
            }
        }
    }

    private var designSelections: Binding<[String: String]> {
        Binding(
            get: { profile.designOptionSelections ?? [:] },
            set: { updatedSelections in
                profile.designOptionSelections = updatedSelections.isEmpty
                    ? nil
                    : updatedSelections
            }
        )
    }

    private var wardrobeChoices: [WardrobeChoice] {
        profile.wardrobe.enumerated().map { index, look in
            WardrobeChoice(
                id: look.id,
                title: chineseWardrobeTitle(look.title, index: index),
                visualPrompt: look.visualPrompt
            )
        }
    }

    private var activeWardrobe: WardrobeLook? {
        guard let activeWardrobeID else { return nil }
        return profile.wardrobe.first(where: { $0.id == activeWardrobeID })
    }

    private func chineseWardrobeTitle(_ title: String, index: Int) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let containsChinese = trimmed.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
        return containsChinese ? trimmed : "服装方案 \(index + 1)"
    }
}

private struct CharacterDesignOptionEditor: View {
    @Binding var selections: [String: String]

    @State private var expandedGroups: Set<CharacterDesignParameterGroup> = [
        .foundation,
        .face
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("结构化人物设计", systemImage: "square.grid.3x3.fill")
                    .font(.headline)
                Spacer()
                Text("\(selectedOptionCount) 项已覆盖")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text("所有选项均为中文按钮；选择具体项后会映射为英文提示词。选择“无”时，该项不写入最终英文提示词。")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(CharacterDesignParameterGroup.allCases) { group in
                DisclosureGroup(
                    isExpanded: expansionBinding(for: group)
                ) {
                    if expandedGroups.contains(group) {
                        CharacterDesignGroupView(
                            group: group,
                            selections: $selections
                        )
                        .padding(.top, 12)
                    }
                } label: {
                    HStack {
                        Label(group.title, systemImage: group.systemImage)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        let count = selectedCount(in: group)
                        if count > 0 {
                            Text("\(count) 项")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }

            if !selectedPromptTokens.isEmpty {
                GroupBox("当前结构化英文映射") {
                    Text(selectedPromptTokens.joined(separator: ", "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private var selectedPromptTokens: [String] {
        CharacterDesignParameter.allCases.compactMap { parameter in
            let option = parameter.resolvedOption(in: selections)
            return option.promptToken.isEmpty ? nil : option.promptToken
        }
    }

    private var selectedOptionCount: Int {
        selectedPromptTokens.count
    }

    private func selectedCount(in group: CharacterDesignParameterGroup) -> Int {
        group.parameters.count { parameter in
            !parameter.resolvedOption(in: selections).promptToken.isEmpty
        }
    }

    private func expansionBinding(
        for group: CharacterDesignParameterGroup
    ) -> Binding<Bool> {
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

private struct CharacterDesignGroupView: View {
    let group: CharacterDesignParameterGroup
    @Binding var selections: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(group.parameters) { parameter in
                CharacterDesignParameterChoices(
                    parameter: parameter,
                    selections: $selections
                )
            }
        }
    }
}

private struct CharacterDesignParameterChoices: View {
    let parameter: CharacterDesignParameter
    @Binding var selections: [String: String]

    private let columns = [
        GridItem(.adaptive(minimum: 104), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(parameter.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(parameter.options) { option in
                    CharacterDesignChoiceButton(
                        parameter: parameter,
                        option: option,
                        isSelected: selectedID == option.id
                    ) {
                        apply(option)
                    }
                }
            }
        }
    }

    private var selectedID: String {
        parameter.resolvedOption(in: selections).id
    }

    private func apply(_ option: CharacterDesignOption) {
        var updatedSelections = selections
        if option.id == CharacterDesignOption.none.id {
            updatedSelections.removeValue(forKey: parameter.rawValue)
        } else {
            updatedSelections[parameter.rawValue] = option.id
        }
        selections = updatedSelections
    }
}

private struct CharacterDesignChoiceButton: View {
    let parameter: CharacterDesignParameter
    let option: CharacterDesignOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
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
        .help(helpText)
        .accessibilityLabel("\(parameter.title)：\(option.title)")
        .accessibilityHint(helpText)
        .accessibilityIdentifier(
            "character-design.\(parameter.rawValue).\(option.id)"
        )
    }

    private var helpText: String {
        option.promptToken.isEmpty
            ? "无，不写入最终英文提示词"
            : "英文提示词：\(option.promptToken)"
    }
}

private struct ExtractedDesignFact: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title) {
            Text(value.isEmpty ? "未提取" : value)
                .foregroundStyle(value.isEmpty ? .tertiary : .secondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }
}

private struct WardrobeChoice: Identifiable {
    let id: UUID
    let title: String
    let visualPrompt: String
}

private struct WardrobeChoiceGrid: View {
    let choices: [WardrobeChoice]
    @Binding var selection: UUID?

    private let columns = [
        GridItem(.adaptive(minimum: 124), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            Button {
                selection = nil
            } label: {
                wardrobeLabel(
                    title: "不指定服装",
                    isSelected: selection == nil
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(selection == nil ? .accentColor : .secondary)
            .accessibilityIdentifier("wardrobe.none")

            ForEach(choices) { choice in
                Button {
                    selection = choice.id
                } label: {
                    wardrobeLabel(
                        title: choice.title,
                        isSelected: selection == choice.id
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(selection == choice.id ? .accentColor : .secondary)
                .help(
                    choice.visualPrompt.isEmpty
                        ? "当前方案没有英文服装词"
                        : "英文提示词：\(choice.visualPrompt)"
                )
                .accessibilityIdentifier("wardrobe.\(choice.id.uuidString)")
            }
        }
    }

    private func wardrobeLabel(
        title: String,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .imageScale(.small)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActiveWardrobeMapping: View {
    let look: WardrobeLook

    var body: some View {
        GroupBox("当前服装英文映射") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    LabeledContent("季节", value: look.season)
                    LabeledContent("场合", value: look.occasion)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !look.storyBeat.isEmpty {
                    LabeledContent("剧情节点", value: look.storyBeat)
                        .font(.caption)
                }

                Text(
                    look.visualPrompt.isEmpty
                        ? "当前方案没有英文提示词，请重新提取剧本。"
                        : look.visualPrompt
                )
                .font(.caption.monospaced())
                .foregroundStyle(
                    look.visualPrompt.isEmpty ? .orange : .secondary
                )
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
    }
}
