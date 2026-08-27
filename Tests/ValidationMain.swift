import Foundation

private var failureCount = 0

private func validateOpenAICompatibleEndpoints() {
    expect(
        OpenAICompatibleEndpoint.resolve("https://example.com/v1")?.absoluteString
            == "https://example.com/v1/chat/completions",
        "OpenAI 兼容基础 URL 必须自动补全 chat/completions"
    )
    expect(
        OpenAICompatibleEndpoint.resolve("https://example.com/v1/chat/completions/")?.absoluteString
            == "https://example.com/v1/chat/completions",
        "完整 chat/completions URL 不得重复追加路径"
    )
    expect(
        OpenAICompatibleEndpoint.resolve("not-a-url") == nil,
        "无效 OpenAI 兼容 URL 必须被拒绝"
    )
}

private func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String
) {
    guard !condition() else { return }
    failureCount += 1
    fputs("FAIL: \(message())\n", stderr)
}

private func makeAsset(
    kind: AssetKind,
    selections: [String: String]
) -> AssetItem {
    AssetItem(
        kind: kind,
        name: "Validation asset",
        summary: "Validation summary",
        basePrompt: "validation subject",
        parameterSelections: selections
    )
}

private func validateSummaryConsolidation() {
    let first = "14岁初三学生，毒舌傲娇，痞帅中二，爱吃草莓棒棒糖。"
    let second = "14岁初三男生，毒舌傲娇，痞帅，爱吃草莓味棒棒糖，后期追求苏一。"
    let third = "男主角，14岁左右，毒舌傲娇，中二少年，后期追求苏一。"
    let result = AssetSummaryConsolidator.consolidate(first, second, third, first)

    expect(result.contains(first), "摘要不得丢失只出现在第一段的信息；实际：\(result)")
    expect(result.contains(second), "摘要不得丢失只出现在第二段的信息；实际：\(result)")
    expect(result.contains(third), "摘要不得丢失只出现在第三段的信息；实际：\(result)")
    expect(
        result.components(separatedBy: .newlines).count == 3,
        "完全重复的摘要行只能保留一次；实际：\(result)"
    )
    expect(
        AssetSummaryConsolidator.consolidate(result, result) == result,
        "摘要合并必须幂等"
    )
}

private func validateCharacterDeliverySpecifications() {
    let options = PromptParameter.outputPurpose.options(for: .character)
    let turnaroundID = "orthographic-turnaround-sheet"
    let fullBodyID = "single-full-body-solid-background"
    guard let turnaround = options.first(where: { $0.id == turnaroundID }),
          let fullBody = options.first(where: { $0.id == fullBodyID })
    else {
        expect(false, "角色交付规格必须包含正交转面表与单人全身图")
        return
    }

    expect(
        turnaround.promptToken.contains("professional character turnaround sheet"),
        "正交角色转面表必须包含专业转面表约束"
    )
    expect(
        turnaround.promptToken.contains("full-body front, side, and back views"),
        "正交角色转面表必须包含正、侧、背全身视图"
    )
    expect(turnaround.promptToken.contains("16:9"), "正交角色转面表必须固定 16:9")
    expect(
        turnaround.preview.photoRecipe.assetName == "PromptPreviewTurnaroundSheet",
        "正交角色转面表必须使用专用真人预览图片"
    )
    expect(
        fullBody.promptToken.contains("single character full-body reference image"),
        "单人全身图必须明确为单一角色全身参考"
    )
    expect(
        fullBody.promptToken.contains("solid-color background"),
        "单人全身图必须使用纯色背景"
    )
    expect(
        fullBody.preview.photoRecipe.assetName == "PromptPreviewFullBodySolid",
        "单人全身图必须使用专用真人预览图片"
    )

    for option in [turnaround, fullBody] {
        var selections: [String: String] = [:]
        PromptParameter.outputPurpose.applySelection(
            option.id,
            for: .character,
            to: &selections
        )
        let asset = makeAsset(kind: .character, selections: selections)
        let compiled = PromptCompiler.compile(asset)
        expect(
            !compiled.contains(option.promptToken),
            "已隐藏的 legacy 交付物 token 不得污染最终提示词"
        )
        expect(
            selections[PromptParameter.backgroundTreatment.rawValue] == "neutral-gray",
            "\(option.id) 必须同步浅灰纯色背景"
        )
        expect(
            selections[PromptParameter.lightQuality.rawValue] == "soft"
                && selections[PromptParameter.lightingSetup.rawValue] == "studio",
            "\(option.id) 必须同步柔和摄影棚布光"
        )
        expect(
            compiled.contains("neutral gray studio background")
                && compiled.contains("soft diffused lighting")
                && compiled.contains("large-scale studio lighting"),
            "\(option.id) 的可见结构化约束必须进入最终提示词"
        )
    }

    var turnaroundSelections: [String: String] = [:]
    PromptParameter.outputPurpose.applySelection(
        turnaroundID,
        for: .character,
        to: &turnaroundSelections
    )
    expect(
        turnaroundSelections[PromptParameter.aspectRatio.rawValue] == "16:9",
        "正交角色转面表必须同步画面比例为 16:9"
    )
    expect(
        turnaroundSelections[PromptParameter.subjectPresentation.rawValue] == "turnaround",
        "正交角色转面表必须同步全身四视图"
    )

    let ordinaryAsset = makeAsset(
        kind: .character,
        selections: [PromptParameter.outputPurpose.rawValue: "face-bible"]
    )
    expect(
        !PromptCompiler.compile(ordinaryAsset).contains("professional character turnaround sheet"),
        "普通角色交付物不得再被无条件强制为转面表"
    )
}

private func validateCatalogAndCompiler() -> (optionCount: Int, recipeKeys: Set<String>, assetNames: Set<String>) {
    var optionCount = 0
    var recipeKeys = Set<String>()
    var assetNames = Set<String>()

    for kind in AssetKind.allCases {
        for parameter in PromptParameter.allCases where parameter.supports(kind) {
            let options = parameter.options(for: kind)
            expect(!options.isEmpty, "\(kind.rawValue).\(parameter.rawValue) 不得没有选项")
            expect(
                Set(options.map(\.id)).count == options.count,
                "\(kind.rawValue).\(parameter.rawValue) 的 option ID 必须唯一"
            )

            let defaultID = parameter.defaultOptionID(for: kind)
            expect(
                options.contains(where: { $0.id == defaultID }),
                "\(kind.rawValue).\(parameter.rawValue) 的默认 ID \(defaultID) 必须存在"
            )

            for option in options {
                optionCount += 1
                let key = "\(parameter.rawValue).\(option.id)"
                expect(!option.id.isEmpty, "\(key) 的 ID 不能为空")
                expect(!option.title.isEmpty, "\(key) 的标题不能为空")
                expect(!option.detail.isEmpty, "\(key) 的说明不能为空")
                expect(option.preview.family == parameter.previewFamily, "\(key) 的图例 family 必须与参数一致")
                expect(option.preview.variant == option.id, "\(key) 的图例 variant 必须与 option ID 一一同步")
                let recipe = option.preview.photoRecipe
                expect(!recipe.assetName.isEmpty, "\(key) 的真人图片资源名不能为空")
                expect(recipe.sourceOptionID == option.id, "\(key) 的真人图片 recipe 必须引用同一 option ID")
                expect(recipe.sourcePromptToken == option.promptToken, "\(key) 的真人图片 recipe 必须引用同一提示词 token")
                expect(
                    recipe.imageKey == "\(parameter.previewFamily.rawValue).\(option.id)",
                    "\(key) 的真人图片 imageKey 必须由 preview family 和 option ID 同源生成"
                )
                recipeKeys.insert(recipe.imageKey)
                assetNames.insert(recipe.assetName)
                expect(
                    !option.promptToken.isEmpty
                        || option.id == PromptParameter.noneOptionID,
                    "\(key) 只有 none 选项可以为空提示词"
                )

                let asset = makeAsset(kind: kind, selections: [parameter.rawValue: option.id])
                let prompt = PromptCompiler.compile(asset)
                if !option.promptToken.isEmpty {
                    if !parameter.isIncludedInCompiledPrompt {
                        expect(
                            !prompt.contains(option.promptToken),
                            "\(key) 已从编译器排除，不应进入输出"
                        )
                    } else if parameter == .detailLevel {
                        let expected = parameter.options(for: kind).first {
                            $0.id == parameter.defaultOptionID(for: kind)
                        }?.promptToken ?? ""
                        expect(
                            prompt.contains(expected),
                            "\(key) 必须固定回退到制作级细节"
                        )
                    } else {
                        expect(
                            prompt.contains(option.promptToken),
                            "\(key) 的提示词未进入 PromptCompiler 输出"
                        )
                    }
                }
            }

            let invalidID = "invalid-validation-option"
            let resolved = PromptCompiler.resolvedOption(
                for: parameter,
                kind: kind,
                selections: [parameter.rawValue: invalidID]
            )
            expect(resolved?.id == defaultID, "\(kind.rawValue).\(parameter.rawValue) 无效 ID 必须回退默认值")
            let invalidPrompt = PromptCompiler.compile(
                makeAsset(kind: kind, selections: [parameter.rawValue: invalidID])
            )
            if parameter.isIncludedInCompiledPrompt,
               let defaultToken = resolved?.promptToken,
               !defaultToken.isEmpty {
                expect(invalidPrompt.contains(defaultToken), "\(kind.rawValue).\(parameter.rawValue) 无效 ID 回退后默认提示词必须进入输出")
            }
        }
    }

    expect(optionCount > 0, "参数目录不应为空")
    return (optionCount, recipeKeys, assetNames)
}

private func validatePhotoResources(
    assetNames: Set<String>,
    assetsCatalog: URL
) {
    struct ImageSet: Decodable {
        struct Image: Decodable {
            let filename: String?
        }

        let images: [Image]
    }

    expect(!assetNames.isEmpty, "真人图片资源目录不能为空")
    for assetName in assetNames {
        let imageSet = assetsCatalog.appendingPathComponent("\(assetName).imageset")
        let contentsURL = imageSet.appendingPathComponent("Contents.json")
        expect(FileManager.default.fileExists(atPath: contentsURL.path), "真人图片资源 \(assetName) 缺少 Contents.json")
        guard let data = try? Data(contentsOf: contentsURL),
              let imageSetContents = try? JSONDecoder().decode(ImageSet.self, from: data)
        else {
            expect(false, "真人图片资源 \(assetName) 的 Contents.json 无法读取")
            continue
        }
        let filenames = imageSetContents.images.compactMap(\.filename)
        expect(!filenames.isEmpty, "真人图片资源 \(assetName) 必须声明至少一个图片文件")
        for filename in filenames {
            expect(
                FileManager.default.fileExists(atPath: imageSet.appendingPathComponent(filename).path),
                "真人图片资源 \(assetName) 声明的图片 \(filename) 不存在"
            )
        }
    }
}

@main
private struct ValidationMain {
    static func main() {
        validateOpenAICompatibleEndpoints()
        validateSummaryConsolidation()
        validateCharacterDeliverySpecifications()
        let catalog = validateCatalogAndCompiler()
        guard CommandLine.arguments.count == 2 else {
            fputs("Usage: validate <Assets.xcassets path>\n", stderr)
            exit(EXIT_FAILURE)
        }
        validatePhotoResources(
            assetNames: catalog.assetNames,
            assetsCatalog: URL(fileURLWithPath: CommandLine.arguments[1])
        )
        print("Validated \(catalog.optionCount) supported prompt options, \(catalog.recipeKeys.count) unique photo recipes, and \(catalog.assetNames.count)真人图片资源.")

        if failureCount == 0 {
            print("Validation passed.")
            return
        }

        fputs("Validation failed: \(failureCount) assertion(s).\n", stderr)
        exit(EXIT_FAILURE)
    }
}
