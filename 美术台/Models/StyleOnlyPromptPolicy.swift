import Foundation

nonisolated struct StylePromptAssessment: Hashable, Sendable {
    var isStyleOnly: Bool
    var reasons: [String]
}

nonisolated enum GenerationReferenceRole: String, Codable, Sendable {
    case stylePreview
    case userContentReference
}

nonisolated enum GenerationReferencePolicy {
    static func shouldSendToProvider(_ role: GenerationReferenceRole) -> Bool {
        role == .userContentReference
    }
}

private nonisolated struct StyleTraitRule: Sendable {
    var label: String
    var needles: [String]
}

private nonisolated struct StyleVisualDescriptor: Sendable {
    var title: String
    var prompt: String
    var tags: [String]
}

nonisolated enum StyleOnlyPromptPolicy {
    private static let mediumRules: [StyleTraitRule] = [
        .init(label: "电影级写实摄影", needles: ["cinematic", "photorealistic", "photo-realistic", "realistic photography", "ultra-realistic"]),
        .init(label: "时尚编辑摄影", needles: ["fashion editorial", "editorial photography", "beauty editorial"]),
        .init(label: "商业产品视觉", needles: ["commercial photography", "product photography", "advertising visual", "ecommerce"]),
        .init(label: "三维体积渲染", needles: ["3d render", "3d illustration", "cgi", "octane", "ray tracing", "volumetric rendering"]),
        .init(label: "矢量插画", needles: ["vector illustration", "flat vector", "vector-like"]),
        .init(label: "数字绘画", needles: ["digital painting", "digital illustration", "concept art"]),
        .init(label: "水彩绘画", needles: ["watercolor", "watercolour"]),
        .init(label: "油画质感", needles: ["oil painting", "impasto"]),
        .init(label: "墨线与版画", needles: ["ink drawing", "engraving", "linocut", "printmaking", "etched"]),
        .init(label: "漫画与分镜", needles: ["comic", "manga", "storyboard", "graphic novel"]),
        .init(label: "像素艺术", needles: ["pixel art", "pixelated"]),
        .init(label: "低多边形", needles: ["low poly", "low-poly"]),
        .init(label: "黏土与微缩模型", needles: ["clay", "miniature", "diorama", "stop-motion"]),
        .init(label: "纸艺与剪纸", needles: ["paper cut", "papercut", "paper craft", "paper sculpture"]),
        .init(label: "ASCII 图形", needles: ["ascii"]),
        .init(label: "信息图形设计", needles: ["infographic", "diagrammatic", "data visualization"]),
        .init(label: "海报与平面设计", needles: ["poster", "flyer", "graphic design", "typographic"]),
    ]

    private static let shapeRules: [StyleTraitRule] = [
        .init(label: "简洁轮廓", needles: ["clean silhouette", "clean outlines", "clean linework", "crisp edges"]),
        .init(label: "几何化造型", needles: ["geometric", "angular shapes", "graphic planes"]),
        .init(label: "有机流线", needles: ["organic shapes", "flowing", "fluid", "curvilinear"]),
        .init(label: "精细线描", needles: ["fine line", "intricate line", "contour-line", "line art"]),
        .init(label: "柔和体积塑造", needles: ["softly sculpted", "smooth modeling", "soft volumetric"]),
        .init(label: "夸张图形语言", needles: ["exaggerated", "bold shapes", "graphic stylization"]),
        .init(label: "极简形体", needles: ["minimal", "minimalistic", "simplified forms"]),
    ]

    private static let paletteRules: [StyleTraitRule] = [
        .init(label: "低饱和色彩", needles: ["muted palette", "low saturation", "desaturated"]),
        .init(label: "高饱和色彩", needles: ["vibrant", "saturated color", "bold color"]),
        .init(label: "柔和粉彩", needles: ["pastel", "soft palette"]),
        .init(label: "单色体系", needles: ["monochrome", "grayscale", "black and white"]),
        .init(label: "冷色体系", needles: ["cool palette", "cyan", "teal", "blue tones"]),
        .init(label: "暖色体系", needles: ["warm palette", "golden", "amber", "coral", "orange tones"]),
        .init(label: "互补色对比", needles: ["complementary colors", "color contrast"]),
        .init(label: "霓虹色彩", needles: ["neon", "magenta", "electric blue"]),
        .init(label: "受控有限色盘", needles: ["limited palette", "restrained palette", "controlled color"]),
    ]

    private static let lightingRules: [StyleTraitRule] = [
        .init(label: "柔和漫射光", needles: ["soft diffused", "soft lighting", "gentle illumination"]),
        .init(label: "电影低调光", needles: ["low-key", "moody lighting", "dramatic shadows"]),
        .init(label: "明亮高调光", needles: ["high-key", "bright even lighting"]),
        .init(label: "轮廓逆光", needles: ["rim light", "backlit", "edge lighting"]),
        .init(label: "体积光", needles: ["volumetric light", "god rays", "atmospheric light"]),
        .init(label: "霓虹环境光", needles: ["neon lighting", "purple and magenta", "ambient glow"]),
        .init(label: "棚拍光效", needles: ["studio lighting", "softbox", "spotlight"]),
        .init(label: "自然金色光", needles: ["golden hour", "warm sunlight"]),
    ]

    private static let compositionRules: [StyleTraitRule] = [
        .init(label: "极简留白构图", needles: ["negative space", "uncluttered", "minimal composition"]),
        .init(label: "居中对称构图", needles: ["centered", "symmetrical", "symmetry"]),
        .init(label: "浅景深", needles: ["shallow depth of field", "creamy bokeh", "soft bokeh"]),
        .init(label: "层次化景深", needles: ["foreground", "midground", "background"]),
        .init(label: "平面海报构图", needles: ["poster-like", "flat composition", "graphic layout"]),
        .init(label: "微缩景观构图", needles: ["diorama", "miniature set", "tabletop"]),
        .init(label: "动态斜线构图", needles: ["dynamic composition", "diagonal"]),
        .init(label: "近距离细节构图", needles: ["close-up", "macro", "detail shot"]),
    ]

    private static let textureRules: [StyleTraitRule] = [
        .init(label: "细腻真实表面", needles: ["natural skin texture", "high detail", "realistic texture"]),
        .init(label: "光泽高光", needles: ["glossy", "specular", "polished highlights"]),
        .init(label: "哑光柔面", needles: ["matte", "soft surface"]),
        .init(label: "颗粒印刷质感", needles: ["grainy", "print texture", "paper grain"]),
        .init(label: "手绘笔触", needles: ["painterly", "brush strokes", "hand-drawn"]),
        .init(label: "触感材质", needles: ["tactile", "fabric texture", "surface detail"]),
        .init(label: "透明与半透明层", needles: ["translucent", "transparent", "iridescent"]),
    ]

    private static let moodRules: [StyleTraitRule] = [
        .init(label: "梦幻氛围", needles: ["dreamlike", "dreamy", "ethereal"]),
        .init(label: "宁静氛围", needles: ["serene", "tranquil", "calm"]),
        .init(label: "神秘氛围", needles: ["mystical", "mysterious", "enigmatic"]),
        .init(label: "未来复古", needles: ["retrofuturistic", "retro-futuristic"]),
        .init(label: "精致奢华", needles: ["luxurious", "premium", "sophisticated"]),
        .init(label: "轻快俏皮", needles: ["playful", "whimsical", "fun"]),
        .init(label: "克制现代", needles: ["modern", "contemporary", "clean"]),
        .init(label: "强烈戏剧感", needles: ["dramatic", "intense", "cinematic mood"]),
        .init(label: "浪漫柔美", needles: ["romantic", "feminine", "delicate"]),
    ]

    private static let styleCueWords = [
        "风格", "摄影", "插画", "绘画", "渲染", "媒介", "色彩", "配色", "光线", "灯光",
        "构图", "镜头", "景深", "线条", "轮廓", "质感", "纹理", "颗粒", "饱和", "对比",
        "氛围", "写实", "抽象", "极简", "电影感", "style", "photography", "illustration",
        "painting", "render", "palette", "color", "lighting", "composition", "texture",
        "grain", "contrast", "cinematic", "photorealistic", "vector", "watercolor", "3d",
    ]

    static func purifiedBuiltInCard(
        _ source: StylePromptCard,
        index: Int
    ) -> StylePromptCard {
        let descriptor = descriptor(
            from: source.prompt,
            category: source.category,
            index: index
        )
        var card = source
        card.title = descriptor.title
        card.prompt = descriptor.prompt
        card.tags = unique(
            ["纯风格", "主体中立"] + descriptor.tags
                + source.tags.filter { $0 == "开源风格" || $0 == "MIT" }
        )
        if !card.notes.contains("主体中立") {
            card.notes += "；上游原始提示已转换为主体中立视觉风格描述。样板仅用于风格预览，不作为具体人物、场景或道具内容参考。"
        }
        card.branchLabel = "纯风格根节点"
        return card
    }

    static func assessment(_ prompt: String) -> StylePromptAssessment {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return .init(isStyleOnly: false, reasons: ["风格提示词不能为空"])
        }
        var reasons = subjectSpecificFindings(in: clean)
        let lowered = clean.lowercased()
        if !styleCueWords.contains(where: lowered.contains) {
            reasons.append("没有描述媒介、色彩、光线、构图、质感或氛围")
        }
        return .init(isStyleOnly: reasons.isEmpty, reasons: unique(reasons))
    }

    static func validatedUserTitle(_ title: String) throws -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            throw ArtDepartmentV2Error.stylePromptMustDescribeVisualStyle
        }
        let findings = subjectSpecificFindings(in: clean)
        guard findings.isEmpty else {
            throw ArtDepartmentV2Error.stylePromptContainsSubject(findings)
        }
        return clean
    }

    static func validatedUserPrompt(_ prompt: String) throws -> String {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = assessment(clean)
        guard result.isStyleOnly else {
            if result.reasons == ["没有描述媒介、色彩、光线、构图、质感或氛围"]
                || result.reasons.contains("风格提示词不能为空")
            {
                throw ArtDepartmentV2Error.stylePromptMustDescribeVisualStyle
            }
            throw ArtDepartmentV2Error.stylePromptContainsSubject(result.reasons)
        }
        return clean
    }

    static func safeStyleFragment(
        _ prompt: String,
        category: StylePromptCategory
    ) -> String {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if assessment(clean).isStyleOnly {
            return stripEnvelope(clean)
        }
        return descriptor(from: clean, category: category, index: 0).prompt
    }

    static func subjectNeutralEnvelope(_ fragments: [String]) -> String {
        let body = fragments
            .map { stripEnvelope($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n【风格分支变化】\n")
        guard !body.isEmpty else { return "" }
        return """
        【视觉风格】
        \(body)

        【主体中立规则】
        只控制媒介、渲染、色彩、光线、构图、镜头、线条、表面质感与氛围；不得指定、替换或增加任何具体人物、场景、道具、动作、服装、年龄、性别、数量、时代、身份、文字内容或空间关系。资产设计事实始终优先。
        """
    }

    static func migratedLegacyCard(
        _ source: StylePromptCard,
        index: Int
    ) -> StylePromptCard {
        var card = source
        let promptAssessment = assessment(card.prompt)
        let titleFindings = subjectSpecificFindings(in: card.title)
        if promptAssessment.isStyleOnly {
            card.prompt = stripEnvelope(card.prompt)
        } else {
            let descriptor = descriptor(
                from: card.prompt,
                category: card.category,
                index: index
            )
            card.prompt = descriptor.prompt
            card.tags = unique(card.tags + ["主体中立迁移"] + descriptor.tags)
            if !card.notes.contains("主体中立迁移") {
                card.notes += "；主体中立迁移：已移除具体人物、场景和道具描述，仅保留可复用视觉风格。"
            }
        }
        if !titleFindings.isEmpty {
            card.title = descriptor(
                from: card.prompt,
                category: card.category,
                index: index
            ).title
        }
        return card
    }

    static func isSubjectNeutralTitle(_ title: String) -> Bool {
        subjectSpecificFindings(in: title).isEmpty
    }

    private static func descriptor(
        from source: String,
        category: StylePromptCategory,
        index: Int
    ) -> StyleVisualDescriptor {
        let lowered = source.lowercased()
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let media = labels(in: lowered, rules: mediumRules, limit: 3)
        let shapes = labels(in: lowered, rules: shapeRules, limit: 3)
        let palette = labels(in: lowered, rules: paletteRules, limit: 3)
        let lighting = labels(in: lowered, rules: lightingRules, limit: 3)
        let composition = labels(in: lowered, rules: compositionRules, limit: 3)
        let textures = labels(in: lowered, rules: textureRules, limit: 3)
        let moods = labels(in: lowered, rules: moodRules, limit: 3)

        let fallbackMedium: String
        switch category {
        case .character, .costume:
            fallbackMedium = "人物设计视觉"
        case .scene, .camera, .cleanup:
            fallbackMedium = "场景设计视觉"
        case .prop, .whiteModel, .repaint:
            fallbackMedium = "物件与材质设计视觉"
        case .general:
            fallbackMedium = "综合视觉设计"
        }

        let safeMedia = media.isEmpty ? [fallbackMedium] : media
        let safeShapes = shapes.isEmpty ? ["清晰可读的造型层次"] : shapes
        let safePalette = palette.isEmpty ? ["受控统一色彩"] : palette
        let safeLighting = lighting.isEmpty ? ["层次明确的受控光线"] : lighting
        let safeComposition = composition.isEmpty ? ["主体层级清楚、画面秩序稳定"] : composition
        let safeTextures = textures.isEmpty ? ["材质区分清晰、完成度高"] : textures
        let safeMoods = moods.isEmpty ? ["专业、统一、可复用"] : moods

        let titleCore = [safeMedia.first, safePalette.first ?? safeMoods.first]
            .compactMap { $0 }
            .joined(separator: " · ")
        let title = "\(titleCore) \(String(format: "%02d", index + 1))"
        let prompt = """
        媒介与渲染：\(safeMedia.joined(separator: "、"))。
        造型与线条：\(safeShapes.joined(separator: "、"))。
        色彩体系：\(safePalette.joined(separator: "、"))。
        光线处理：\(safeLighting.joined(separator: "、"))。
        构图与镜头：\(safeComposition.joined(separator: "、"))。
        表面质感：\(safeTextures.joined(separator: "、"))。
        整体氛围：\(safeMoods.joined(separator: "、"))。
        """
        return StyleVisualDescriptor(
            title: title,
            prompt: prompt,
            tags: unique(
                safeMedia + safeShapes + safePalette + safeLighting
                    + safeComposition + safeTextures + safeMoods
            )
        )
    }

    private static func labels(
        in source: String,
        rules: [StyleTraitRule],
        limit: Int
    ) -> [String] {
        Array(rules.compactMap { rule in
            rule.needles.contains(where: source.contains) ? rule.label : nil
        }.prefix(limit))
    }

    private static func stripEnvelope(_ prompt: String) -> String {
        guard let styleRange = prompt.range(of: "【视觉风格】") else {
            return prompt
        }
        let afterStyle = prompt[styleRange.upperBound...]
        if let ruleRange = afterStyle.range(of: "【主体中立规则】") {
            return String(afterStyle[..<ruleRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(afterStyle).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func subjectSpecificFindings(in text: String) -> [String] {
        let directPatterns: [(String, String)] = [
            (#"(?i)\b(subject|character|scene|prop|object)\s*[:=]"#, "包含具体主体字段"),
            (#"(?i)\b(a|an|the|one|two|three|ten|young|old)\s+(man|woman|girl|boy|person|train|car|logo|kitchen|bedroom|street|building|sword|gun|bottle|phone)\b"#, "包含具体人物、场景或物件"),
            (#"(?i)\b(wearing|holding|standing in|standing on|sitting in|sitting on|located in|overlooking|driving)\b"#, "包含具体主体动作或位置"),
            (#"(主体|人物|角色|场景|道具)\s*(是|为)"#, "直接指定了具体主体"),
            (#"(穿着|手持|拿着|站在|坐在|位于|俯瞰|驾驶|走进|打开)"#, "包含具体主体动作或位置"),
            (#"[一二两三四五六七八九十0-9]+(个|名|位|把|辆|本|间|座)[^，。；\n]{0,24}(男人|女人|女孩|男孩|人物|角色|火车|汽车|房间|厨房|卧室|街道|建筑|刀|剑|枪|瓶|手机|道具)"#, "包含可识别的具体资产描述"),
            (#"(?i)\b(kitchen|bedroom|living room|classroom|hospital room|train|car|logo|passport|phone|sword|gun|bottle|table|chair|cabinet|stove|mother|father|daughter|son|girl|boy|woman|man|doctor|police officer|soldier)\b"#, "包含具体人物、地点或物件名词"),
            (#"(厨房|卧室|客厅|教室|病房|楼道|火车|汽车|护照|手机|刀|剑|枪|瓶子|桌子|椅子|柜子|灶台|米缸|母亲|父亲|女儿|儿子|女孩|男孩|女人|男人|老人|医生|警察|士兵)"#, "包含具体人物、地点或物件名词"),
        ]
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return directPatterns.compactMap { pattern, reason in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return regex.firstMatch(in: text, range: range) == nil ? nil : reason
        }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return nil }
            let key = clean.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            return seen.insert(key).inserted ? clean : nil
        }
    }
}

nonisolated extension StylePromptCard {
    var isSubjectNeutralStyle: Bool {
        StyleOnlyPromptPolicy.assessment(prompt).isStyleOnly
    }
}
