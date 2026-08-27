import Foundation

/// The photographic treatment family used by option click previews.
enum PromptPreviewFamily: String, CaseIterable, Hashable, Sendable {
    case aspectRatio
    case outputPurpose
    case detailLevel
    case visualStyle
    case realism
    case composition
    case shotSize
    case cameraAngle
    case perspective
    case focalLength
    case lensCharacter
    case depthOfField
    case focusStrategy
    case motionRendering
    case lightQuality
    case lightDirection
    case lightingSetup
    case exposureKey
    case colorTemperature
    case colorPalette
    case colorContrast
    case timeOfDay
    case weatherAtmosphere
    case nationality
    case historicalEra
    case subjectPresentation
    case poseDynamics
    case facialExpression
    case backgroundTreatment
    case materialDetail
    case finishing
}

/// A complete photographic preview for one prompt option. `variant`, the
/// recipe source ID and the compiler selection always describe the same row.
struct PromptPreviewSpec: Hashable, Sendable {
    let family: PromptPreviewFamily
    let variant: String
    let photoRecipe: PromptPhotoRecipe
}

struct PromptOption: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let promptToken: String
    let preview: PromptPreviewSpec
}

enum PromptParameterGroup: String, CaseIterable, Identifiable, Sendable {
    case output
    case artDirection
    case camera
    case lighting
    case color
    case environment
    case subject
    case finishing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .output: "输出规格"
        case .artDirection: "美术风格"
        case .camera: "摄影机与镜头"
        case .lighting: "光线与曝光"
        case .color: "色彩控制"
        case .environment: "时间与环境"
        case .subject: "主体呈现"
        case .finishing: "材质与后期"
        }
    }

    var systemImage: String {
        switch self {
        case .output: "aspectratio"
        case .artDirection: "paintpalette"
        case .camera: "camera.aperture"
        case .lighting: "light.max"
        case .color: "circle.lefthalf.filled"
        case .environment: "cloud.sun"
        case .subject: "person.crop.rectangle"
        case .finishing: "wand.and.stars"
        }
    }

}

enum PromptParameter: String, CaseIterable, Identifiable, Sendable {
    static let noneOptionID = "none"

    case aspectRatio
    case outputPurpose
    case detailLevel
    case visualStyle
    case realism
    case composition
    case shotSize
    case cameraAngle
    case perspective
    case focalLength
    case lensCharacter
    case depthOfField
    case focusStrategy
    case motionRendering
    case lightQuality
    case lightDirection
    case lightingSetup
    case exposureKey
    case colorTemperature
    case colorPalette
    case colorContrast
    case timeOfDay
    case weatherAtmosphere
    case nationality
    case historicalEra
    case subjectPresentation
    case poseDynamics
    case facialExpression
    case backgroundTreatment
    case materialDetail
    case finishing

    var id: String { rawValue }

    var group: PromptParameterGroup {
        switch self {
        case .aspectRatio, .outputPurpose, .detailLevel:
            .output
        case .visualStyle, .realism:
            .artDirection
        case .composition, .shotSize, .cameraAngle, .perspective, .focalLength,
             .lensCharacter, .depthOfField, .focusStrategy, .motionRendering:
            .camera
        case .lightQuality, .lightDirection, .lightingSetup, .exposureKey:
            .lighting
        case .colorTemperature, .colorPalette, .colorContrast:
            .color
        case .timeOfDay, .weatherAtmosphere, .historicalEra:
            .environment
        case .nationality, .subjectPresentation, .poseDynamics, .facialExpression, .backgroundTreatment:
            .subject
        case .materialDetail, .finishing:
            .finishing
        }
    }

    var title: String {
        switch self {
        case .aspectRatio: "画面比例"
        case .outputPurpose: "设计交付物"
        case .detailLevel: "细节等级"
        case .visualStyle: "视觉风格"
        case .realism: "写实程度"
        case .composition: "构图"
        case .shotSize: "景别"
        case .cameraAngle: "机位角度"
        case .perspective: "透视"
        case .focalLength: "焦距"
        case .lensCharacter: "镜头质感"
        case .depthOfField: "光圈 / 景深"
        case .focusStrategy: "对焦策略"
        case .motionRendering: "运动表现"
        case .lightQuality: "光质"
        case .lightDirection: "光向"
        case .lightingSetup: "布光方案"
        case .exposureKey: "曝光调性"
        case .colorTemperature: "色温"
        case .colorPalette: "色板"
        case .colorContrast: "色彩反差"
        case .timeOfDay: "时间"
        case .weatherAtmosphere: "天气氛围"
        case .nationality: "国籍 / 国家归属"
        case .historicalEra: "对应时代 / 文明"
        case .subjectPresentation: "人物设计页"
        case .poseDynamics: "姿态"
        case .facialExpression: "表情"
        case .backgroundTreatment: "背景处理"
        case .materialDetail: "材质状态"
        case .finishing: "成片质感"
        }
    }

    var systemImage: String {
        switch self {
        case .aspectRatio: "aspectratio"
        case .outputPurpose: "doc.richtext"
        case .detailLevel: "sparkle.magnifyingglass"
        case .visualStyle: "paintbrush.pointed"
        case .realism: "camera.metering.matrix"
        case .composition: "rectangle.3.group"
        case .shotSize: "viewfinder.rectangular"
        case .cameraAngle: "camera.viewfinder"
        case .perspective: "lines.measurement.horizontal"
        case .focalLength: "camera.aperture"
        case .lensCharacter: "circle.hexagongrid"
        case .depthOfField: "camera.filters"
        case .focusStrategy: "scope"
        case .motionRendering: "figure.run"
        case .lightQuality: "sun.max"
        case .lightDirection: "arrow.down.right"
        case .lightingSetup: "lightbulb.2"
        case .exposureKey: "plusminus"
        case .colorTemperature: "thermometer.medium"
        case .colorPalette: "paintpalette"
        case .colorContrast: "circle.lefthalf.filled"
        case .timeOfDay: "clock"
        case .weatherAtmosphere: "cloud.sun"
        case .nationality: "globe.asia.australia"
        case .historicalEra: "building.columns"
        case .subjectPresentation: "person.crop.rectangle.stack"
        case .poseDynamics: "figure.stand"
        case .facialExpression: "face.smiling"
        case .backgroundTreatment: "rectangle.on.rectangle"
        case .materialDetail: "square.3.layers.3d"
        case .finishing: "wand.and.stars"
        }
    }

    var previewFamily: PromptPreviewFamily {
        switch self {
        case .aspectRatio: .aspectRatio
        case .outputPurpose: .outputPurpose
        case .detailLevel: .detailLevel
        case .visualStyle: .visualStyle
        case .realism: .realism
        case .composition: .composition
        case .shotSize: .shotSize
        case .cameraAngle: .cameraAngle
        case .perspective: .perspective
        case .focalLength: .focalLength
        case .lensCharacter: .lensCharacter
        case .depthOfField: .depthOfField
        case .focusStrategy: .focusStrategy
        case .motionRendering: .motionRendering
        case .lightQuality: .lightQuality
        case .lightDirection: .lightDirection
        case .lightingSetup: .lightingSetup
        case .exposureKey: .exposureKey
        case .colorTemperature: .colorTemperature
        case .colorPalette: .colorPalette
        case .colorContrast: .colorContrast
        case .timeOfDay: .timeOfDay
        case .weatherAtmosphere: .weatherAtmosphere
        case .nationality: .nationality
        case .historicalEra: .historicalEra
        case .subjectPresentation: .subjectPresentation
        case .poseDynamics: .poseDynamics
        case .facialExpression: .facialExpression
        case .backgroundTreatment: .backgroundTreatment
        case .materialDetail: .materialDetail
        case .finishing: .finishing
        }
    }

    func supports(_ kind: AssetKind) -> Bool {
        switch self {
        case .timeOfDay, .weatherAtmosphere:
            kind == .scene
        case .subjectPresentation, .poseDynamics, .facialExpression:
            kind == .character
        case .backgroundTreatment:
            kind == .character || kind == .prop
        default:
            true
        }
    }

    var isVisibleInControls: Bool {
        switch self {
        case .outputPurpose, .detailLevel, .lensCharacter, .focusStrategy, .motionRendering:
            false
        default:
            true
        }
    }

    var isIncludedInCompiledPrompt: Bool {
        switch self {
        case .outputPurpose, .lensCharacter, .focusStrategy, .motionRendering:
            false
        default:
            true
        }
    }

    func defaultOptionID(for kind: AssetKind) -> String {
        switch self {
        case .detailLevel:
            "production"
        default:
            Self.noneOptionID
        }
    }

    /// Applies one visible selection and any inseparable production constraints
    /// carried by a compound delivery specification.
    func applySelection(
        _ optionID: String,
        for kind: AssetKind,
        to selections: inout [String: String]
    ) {
        selections[rawValue] = optionID

        guard self == .outputPurpose, kind == .character else { return }

        switch optionID {
        case "orthographic-turnaround-sheet":
            selections[PromptParameter.aspectRatio.rawValue] = "16:9"
            selections[PromptParameter.subjectPresentation.rawValue] = "turnaround"
            applyNeutralStudioSelections(to: &selections)
        case "single-full-body-solid-background":
            selections[PromptParameter.subjectPresentation.rawValue] = "full-body"
            applyNeutralStudioSelections(to: &selections)
        default:
            break
        }
    }

    private func applyNeutralStudioSelections(
        to selections: inout [String: String]
    ) {
        selections[PromptParameter.poseDynamics.rawValue] = "neutral"
        selections[PromptParameter.facialExpression.rawValue] = "neutral"
        selections[PromptParameter.backgroundTreatment.rawValue] = "neutral-gray"
        selections[PromptParameter.lightQuality.rawValue] = "soft"
        selections[PromptParameter.lightDirection.rawValue] = "front"
        selections[PromptParameter.lightingSetup.rawValue] = "studio"
        selections[PromptParameter.exposureKey.rawValue] = "balanced"
        selections[PromptParameter.colorTemperature.rawValue] = "neutral"
    }

    func options(for kind: AssetKind) -> [PromptOption] {
        let noneOption = option(
            Self.noneOptionID,
            "无",
            "不额外指定，也不写入最终英文提示词",
            ""
        )
        let availableOptions = specificOptions(for: kind).filter {
            $0.id != "script" && $0.id != Self.noneOptionID
        }
        return [noneOption] + availableOptions
    }

    private func specificOptions(for kind: AssetKind) -> [PromptOption] {
        switch self {
        case .aspectRatio:
            let ratios = [
                option("1:1", "1:1", "方形", "square 1:1 aspect ratio"),
                option("16:9", "16:9", "电影横屏", "widescreen 16:9 aspect ratio"),
                option("9:16", "9:16", "竖屏短视频", "vertical 9:16 aspect ratio"),
                option("21:9", "21:9", "超宽银幕", "ultrawide cinematic 21:9 aspect ratio"),
                option("9:21", "9:21", "超长竖屏", "tall vertical 9:21 aspect ratio"),
                option("3:2", "3:2", "全画幅摄影", "classic photographic 3:2 aspect ratio"),
                option("2:3", "2:3", "竖幅摄影", "vertical photographic 2:3 aspect ratio"),
                option("4:5", "4:5", "人物海报", "portrait 4:5 aspect ratio"),
                option("5:4", "5:4", "横幅画册", "landscape 5:4 aspect ratio")
            ]
            let preferred = switch kind {
            case .scene: "16:9"
            case .character: "4:5"
            case .prop: "1:1"
            }
            return ratios.filter { $0.id == preferred } + ratios.filter { $0.id != preferred }

        case .outputPurpose:
            switch kind {
            case .scene:
                return [
                    option("establishing-keyframe", "建立镜头", "空间与叙事关系", "cinematic establishing keyframe"),
                    option("environment-concept", "场景概念图", "整体美术方向", "environment concept art"),
                    option("set-design", "置景设计", "可执行的布景方案", "buildable set design visualization"),
                    option("mood-keyframe", "气氛关键帧", "情绪与光色优先", "atmospheric mood keyframe"),
                    option("location-survey", "空间勘景图", "尺度与动线清晰", "location design survey"),
                    option("lighting-study", "灯光测试", "光线方案优先", "cinematic lighting study"),
                    option("color-script", "色彩脚本", "场景色彩节奏", "color script frame")
                ]
            case .character:
                return [
                    option("face-bible", "脸部基准", "先锁定脸部身份", "identity-defining face design bible"),
                    option("character-sheet", "人物设定页", "脸、体型与服装", "complete character design sheet"),
                    option(
                        "orthographic-turnaround-sheet",
                        "正交角色转面表",
                        "左侧头像；右侧正、侧、背全身，16:9 浅灰纯色背景",
                        "soft studio lighting, clean light gray background, professional character turnaround sheet. "
                            + "Left: head-and-shoulders close-up. Right: full-body front, side, and back views, consistent "
                            + "character, outfit, hairstyle, proportions, and scale. All heads must be perfectly straight "
                            + "and upright, neutral head position, level eyes, no head tilt, no looking up or down, no head "
                            + "rotation. Orthographic-style views, full body visible, 16:9."
                    ),
                    option(
                        "single-full-body-solid-background",
                        "单人全身图",
                        "单人从头到脚完整呈现，浅灰纯色背景",
                        "soft studio lighting, clean light gray solid-color background, single character full-body reference image, "
                            + "one person only, complete body visible from head to toe, centered neutral upright standing pose, "
                            + "consistent character, outfit, hairstyle, and proportions, no crop, no props, no additional people"
                    ),
                    option("full-body", "全身定妆", "轮廓与比例", "full-body character concept"),
                    option("turnaround", "四视图转面", "正侧背一致性", "front side three-quarter and back turnaround sheet"),
                    option("expression-sheet", "表情表", "脸部表演范围", "facial expression model sheet"),
                    option("wardrobe-lineup", "服装阵列", "多套服装连续性", "costume continuity lineup"),
                    option("action-keyframe", "动作关键帧", "角色在剧情中的状态", "character action keyframe")
                ]
            case .prop:
                return [
                    option("hero-prop", "英雄道具页", "主视图与细节", "hero prop design sheet"),
                    option("orthographic", "正交三视图", "制作尺寸清晰", "orthographic front side and top views"),
                    option("exploded", "爆炸结构图", "构造关系", "exploded construction view"),
                    option("material-callout", "材质标注页", "表面与工艺", "material and finish callout sheet"),
                    option("scale-function", "比例功能页", "人机与使用方式", "scale and functional interaction sheet"),
                    option("in-context", "剧情使用图", "道具在场景中的状态", "prop in narrative context")
                ]
            }

        case .detailLevel:
            return [
                option("production", "制作级", "默认专业交付", "production-ready detail"),
                option("concept", "概念草案", "快速方向探索", "controlled concept sketch detail"),
                option("refined", "精修", "清晰材质与结构", "highly refined design detail"),
                option("micro", "微观细节", "表面与微结构", "extreme micro-detail"),
                option("model-sheet", "干净设定稿", "清晰无噪声", "clean model-sheet precision")
            ]

        case .visualStyle:
            return [
                option("cinematic-real", "电影真人写实", "叙事电影感", "cinematic live-action realism"),
                option("photographic", "真人摄影写实", "自然摄影质感", "high-end photographic realism"),
                option("film-still", "35mm 电影剧照", "胶片叙事帧", "authentic 35mm motion-picture still"),
                option("3d-anime", "3D 动漫", "高端三渲二", "premium 3D anime rendering"),
                option("stylized-3d", "风格化 3D", "动画电影质感", "stylized feature-animation 3D"),
                option(
                    "chibi-3d-card",
                    "Q 版 3D 角色卡",
                    "大头小身、精致数字建模与统一卡面质感",
                    "8K ultra-high-definition chibi character card, appealing oversized-head proportions, "
                        + "refined semi-realistic beauty styling, fully digitally modeled 3D rendering, "
                        + "delicate translucent porcelain-like skin with soft subsurface scattering, clean stylized 3D hair clumps, "
                        + "soft frontal diffused light, idealized elegant facial design, centered character on a seamless matte-white background, "
                        + "polished official game character-card quality, clearly CGI, not live-action photography, not hand-drawn 2D art"
                ),
                option(
                    "love-deepspace-key-art",
                    "恋与深空官方角色立绘",
                    "乙女游戏美型半写实角色卡面",
                    "8K ultra-high-definition official Love and Deepspace character key art, next-generation 3D game rendering, "
                        + "refined semi-realistic romantic-game beauty aesthetic, fully digitally modeled CGI, "
                        + "delicate translucent porcelain-like skin with natural luster and soft subsurface scattering, "
                        + "clean even facial surface with only extremely subtle native microtexture and natural retouching, "
                        + "orderly groomed 3D hair-clump structure with separated roots, airy volume and soft silky highlights, "
                        + "soft frontal beauty diffusion, low-contrast soft shadows, even facial illumination and clean premium color harmony, "
                        + "idealized elegant facial proportions with dimensional yet gentle bone structure, "
                        + "seamless matte-white background without objects or cast shadows, centered frontal chest-up portrait, "
                        + "cohesive premium official character-card finish, clearly a digital 3D model, not a live-action photograph, not 2D hand-drawn art"
                ),
                option(
                    "ue5-oriental-fantasy",
                    "UE5 古风玄幻国漫",
                    "冷艳极繁、电影级东方幻想特写",
                    "Unreal Engine 5 real-time rendering, Lumen global illumination, ray tracing, CG modeling, premium 3D Chinese animation aesthetic, "
                        + "ancient Chinese fantasy and classical East Asian beauty design, proud cold and ethereal presence, refined makeup and dimensional facial highlights, "
                        + "close macro portrait, polished faux-impasto rendering with precise flowing lines, divine mystery and cinematic depth, "
                        + "32K ultra-high-definition detail, ornate flowing historical-fantasy adornment, gilded silver jewelry, elaborate forehead ornament, long tassels, "
                        + "extremely long glossy black hair with wind-swept face-framing strands, intricately constructed braided updo, "
                        + "narrow phoenix eyes with deep star-filled irises and dark-gold lash line, BJD-like refined facial beauty, "
                        + "dynamic pose and camera angle, strong controlled light-dark contrast, pearlescent gauze costume with lavish accessories, "
                        + "cool dark tonal foundation with sparkling Eastern textiles, dreamy soft-focus atmosphere and cinematic fantasy finish"
                ),
                option(
                    "realistic-3d-cultivator",
                    "3D 写实东方修士",
                    "纯白棚拍的高精度修士数字资产",
                    "high-fidelity realistic 3D character modeling, premium East Asian cultivator character asset, physically based PBR materials, "
                        + "clearly a digital three-dimensional model rather than a live-action photograph or Chinese-animation illustration, "
                        + "front-facing chest-up portrait on a seamless pure-white background, centered composition, soft even flat studio lighting, "
                        + "no strong light-dark contrast, no additional glow or visual effects, neutral expression"
                ),
                option(
                    "virtual-idol-pbr",
                    "次世代虚拟偶像",
                    "UE5 离线质感数字人资产",
                    "next-generation high-fidelity 3D virtual-idol digital-human asset, PBR physical material rendering, "
                        + "soft skin subsurface scattering, Unreal Engine 5 offline-rendered quality, unmistakably a volumetric 3D modeled character, "
                        + "not live-action photography, not Chinese-animation illustration, not hand-drawn anime, without photographic human skin texture, "
                        + "front-facing chest-up portrait on a seamless solid pure-white background, centered composition, "
                        + "soft even flat studio lighting with smooth natural transitions, no harsh contrast, lens flare, halo or special-effect lighting, "
                        + "calm natural expression without an exaggerated smile"
                ),
                option(
                    "next-gen-pbr-portrait",
                    "次世代 PBR 游戏立绘",
                    "8K 白底游戏角色数字资产",
                    "8K ultra-high-definition Unreal Engine 5 real-time rendering, next-generation PBR 3D character asset and game character key art, "
                        + "single front-facing portrait on a seamless matte-white background, cool soft diffused studio light, low-contrast gentle shadows and smooth tonal transitions, "
                        + "delicate believable skin microtexture with natural subsurface scattering and translucent non-mask-like finish, "
                        + "3D groom hair with clearly layered root clumps, airy volume and restrained matte response, "
                        + "physically accurate garment materials and gravity-driven folds, cool matte metal accessories and transparent restrained gemstone reflections, "
                        + "direct gaze, calm cold expression, premium controlled atmosphere, realistic but unmistakably a digital 3D model with no live-action photographic quality"
                ),
                option(
                    "ue5-guoman-male",
                    "UE5 古风厚涂男角",
                    "白底、极繁古风、厚涂国漫数字模型",
                    "Unreal Engine 5 real-time rendering, Lumen global illumination, ray tracing, CG modeling and OC rendering, "
                        + "premium 3D Chinese animation and ancient fantasy aesthetic with polished faux-impasto digital painting, maximalist detail and 32K quality, "
                        + "dynamic yet natural photographic lighting with an evenly lit shadow-free face, no oily highlights, refined believable skin microtexture, "
                        + "individual naturally arranged glossy hair strands, extremely clear facial features, physically believable textile folds and embroidery, "
                        + "close macro front-facing eye-level chest-up portrait on a pure-white background, no effects, no atmospheric light, unobstructed face and neutral expression, "
                        + "realistic but unmistakably a 3D digital model rendered with thick-paint illustration finish, not live-action photography, "
                        + "23-year-old East Asian man with a tall muscular inverted-triangle build, angular Eastern facial structure, sword-like brows, narrow cool black eyes, "
                        + "hard sharp jawline, black hair bound in a high ponytail, fitted dark-red robe with subtle embroidered flame patterns, cold composed presence"
                ),
                option("anime-cel", "2D 日系动画", "赛璐璐线色", "hand-drawn anime cel style"),
                option("concept-art", "厚涂概念设计", "影视美术概念图", "painterly cinematic concept art"),
                option("graphic-novel", "图像小说", "强线条与块面", "graphic novel illustration"),
                option("ink-wash", "水墨电影感", "东方水墨空间", "cinematic Chinese ink-wash painting"),
                option("gouache", "水粉插画", "不透明手绘", "editorial gouache illustration"),
                option("retro-futurism", "复古未来主义", "时代化科幻设计", "retro-futurist production illustration"),
                option("stop-motion", "定格动画", "手工模型质感", "handcrafted stop-motion miniature style"),
                option("low-poly", "低多边形", "几何化 3D", "professional low-poly 3D art"),
                option("comic-book", "美式漫画", "墨线与网点", "cinematic comic-book art")
            ]

        case .realism:
            return [
                option("naturalistic", "自然写实", "可信但不过度锐化", "naturalistic realism"),
                option("photoreal", "照片级", "真实材质与肤质", "strict photorealism"),
                option("heightened", "强化现实", "现实基础上的戏剧化", "heightened cinematic realism"),
                option("stylized", "半风格化", "写实结构与设计夸张", "stylized realism"),
                option("graphic", "图形化", "轮廓与形状优先", "graphic abstraction")
            ]

        case .composition:
            return [
                option("thirds", "三分法", "稳定叙事构图", "rule-of-thirds composition"),
                option("centered", "居中", "主体强调", "centered hero composition"),
                option("symmetry", "对称", "秩序与压迫感", "precise symmetrical composition"),
                option("golden", "黄金分割", "自然视觉动线", "golden-ratio composition"),
                option("diagonal", "对角线", "动态张力", "dynamic diagonal composition"),
                option("leading-lines", "引导线", "空间纵深", "strong leading-line composition"),
                option("frame-within", "框中框", "层次与窥视感", "frame-within-a-frame composition"),
                option("negative-space", "留白", "孤独与尺度", "intentional negative space"),
                option("layered", "前中后景", "深度分层", "layered foreground midground and background"),
                option("fill-frame", "充满画面", "材质与压迫感", "subject filling the frame")
            ]

        case .shotSize:
            return [
                option("ews", "大远景", "环境尺度优先", "extreme wide shot"),
                option("ws", "远景", "完整环境与主体", "wide shot"),
                option("fs", "全景", "人物全身", "full shot"),
                option("mls", "中远景", "膝部以上", "medium long shot"),
                option("ms", "中景", "腰部以上", "medium shot"),
                option("mcu", "中近景", "胸部以上", "medium close-up"),
                option("cu", "近景", "脸部与情绪", "close-up shot"),
                option("ecu", "大特写", "眼睛或关键细节", "extreme close-up"),
                option("macro", "微距", "微小材质细节", "macro detail shot")
            ]

        case .cameraAngle:
            return [
                option("eye", "平视", "中性观察", "eye-level camera angle"),
                option("low", "低机位", "权力与尺度", "low camera angle"),
                option("high", "高机位", "脆弱与空间", "high camera angle"),
                option("overhead", "垂直俯拍", "图形化空间", "true overhead bird's-eye view"),
                option("worm", "贴地仰拍", "极端尺度", "ground-level worm's-eye view"),
                option("dutch", "荷兰角", "不稳定张力", "controlled Dutch camera angle"),
                option("three-quarter", "四分之三", "结构信息充分", "three-quarter camera angle"),
                option("profile", "正侧面", "轮廓优先", "strict profile camera angle")
            ]

        case .perspective:
            return [
                option("natural", "自然直线", "标准电影透视", "natural rectilinear perspective"),
                option("one-point", "一点透视", "强中心纵深", "one-point perspective"),
                option("two-point", "两点透视", "建筑空间", "two-point perspective"),
                option("three-point", "三点透视", "高低机位建筑", "three-point perspective"),
                option("isometric", "等距", "无消失点展示", "isometric projection"),
                option("orthographic", "正交", "无透视设计图", "orthographic projection"),
                option("wide-exaggerated", "广角夸张", "前后尺度强化", "exaggerated wide-angle perspective"),
                option("compressed", "长焦压缩", "压缩前后距离", "telephoto perspective compression"),
                option("fisheye", "鱼眼", "曲线变形", "fisheye projection"),
                option("anamorphic", "变形宽银幕", "横向电影空间", "anamorphic widescreen perspective")
            ]

        case .focalLength:
            return [
                option("14mm", "14 mm", "超广角", "14mm ultra-wide lens"),
                option("18mm", "18 mm", "强空间感", "18mm wide-angle lens"),
                option("24mm", "24 mm", "环境叙事", "24mm wide-angle cinema lens"),
                option("28mm", "28 mm", "自然广角", "28mm cinema lens"),
                option("35mm", "35 mm", "经典叙事", "35mm cinema lens"),
                option("50mm", "50 mm", "标准视野", "50mm normal lens"),
                option("65mm", "65 mm", "轻人像", "65mm portrait cinema lens"),
                option("85mm", "85 mm", "脸部人像", "85mm portrait lens"),
                option("105mm", "105 mm", "微距与美容", "105mm macro portrait lens"),
                option("135mm", "135 mm", "长焦压缩", "135mm telephoto lens"),
                option("200mm", "200 mm", "强压缩", "200mm telephoto lens")
            ]

        case .lensCharacter:
            return [
                option("clean", "现代球面", "干净中性", "clean modern spherical lens rendering"),
                option("vintage", "复古球面", "柔和低反差", "vintage spherical lens character"),
                option("anamorphic-2x", "2x 变形镜头", "椭圆散景与横向耀斑", "2x anamorphic lens character with oval bokeh"),
                option("diffusion", "柔光镜", "肤质柔化与高光晕", "subtle optical diffusion filter"),
                option("macro", "微距镜头", "近距离高解析", "true macro lens rendering"),
                option("tilt-shift", "移轴镜头", "焦平面控制", "tilt-shift lens character"),
                option("vintage-swirl", "旋转散景", "复古边缘旋转", "vintage swirled-bokeh lens character")
            ]

        case .depthOfField:
            return [
                option("f1.4", "f/1.4", "极浅景深", "f/1.4 aperture, extremely shallow depth of field"),
                option("f2", "f/2", "浅景深人像", "f/2 aperture, shallow depth of field"),
                option("f2.8", "f/2.8", "主体分离", "f/2.8 aperture, selective depth of field"),
                option("f4", "f/4", "适度环境信息", "f/4 aperture, moderate depth of field"),
                option("f5.6", "f/5.6", "平衡景深", "f/5.6 aperture, balanced depth of field"),
                option("f8", "f/8", "深景深", "f/8 aperture, deep focus"),
                option("f11", "f/11", "全景清晰", "f/11 aperture, extensive depth of field"),
                option("focus-stack", "焦点合成", "全物体锐利", "focus-stacked complete sharpness")
            ]

        case .focusStrategy:
            return [
                option("eyes", "眼睛对焦", "人物身份优先", "critical focus on the eyes"),
                option("face", "脸部对焦", "完整脸部清晰", "precise full-face focus"),
                option("subject", "主体选择对焦", "背景分离", "selective focus on the primary subject"),
                option("deep", "超焦距", "前后景清晰", "hyperfocal deep focus"),
                option("foreground", "前景焦点", "遮挡与悬念", "foreground-plane focus"),
                option("background", "背景焦点", "主体虚化", "background-plane focus"),
                option("split-diopter", "分光镜", "近远双焦点", "split-diopter dual-plane focus")
            ]

        case .motionRendering:
            return [
                option("natural", "自然运动", "电影运动模糊", "natural cinematic motion rendering"),
                option("freeze", "高速凝固", "动作完全清晰", "high-shutter frozen motion"),
                option("crisp", "清晰瞬间", "轻微运动感", "crisp short-exposure motion"),
                option("panning", "追随摇摄", "主体清晰背景拉丝", "panning motion blur"),
                option("long", "长曝光", "光轨与流动", "long-exposure motion trails"),
                option("intentional", "故意晃动", "表现性拖影", "intentional camera-movement blur")
            ]

        case .lightQuality:
            return [
                option("motivated", "剧情动机光", "默认可信光线", "motivated cinematic lighting"),
                option("soft", "柔光", "渐进阴影", "soft diffused lighting"),
                option("hard", "硬光", "清晰阴影", "hard directional lighting"),
                option("chiaroscuro", "明暗对照", "强戏剧反差", "chiaroscuro lighting"),
                option("high-key", "高调光", "明亮低阴影", "high-key lighting"),
                option("low-key", "低调光", "暗部主导", "low-key lighting"),
                option("silhouette", "剪影光", "轮廓优先", "silhouette lighting"),
                option("volumetric", "体积光", "可见光束", "volumetric lighting")
            ]

        case .lightDirection:
            return [
                option("three-quarter", "四分之三侧光", "立体自然", "three-quarter key light"),
                option("front", "正面光", "形色清晰", "frontal lighting"),
                option("side", "侧光", "纹理与深度", "side lighting"),
                option("back", "逆光", "轮廓与氛围", "backlighting"),
                option("rim", "轮廓光", "主体分离", "strong rim lighting"),
                option("top", "顶光", "眼窝与压迫", "top lighting"),
                option("under", "底光", "非自然惊悚", "underlighting")
            ]

        case .lightingSetup:
            return [
                option("available", "自然可用光", "现场真实感", "available-light setup"),
                option("window", "窗光", "大面积侧光", "motivated window-light setup"),
                option("three-point", "三点布光", "主填轮廓完整", "professional three-point lighting"),
                option("rembrandt", "伦勃朗光", "脸部三角光", "Rembrandt portrait lighting"),
                option("butterfly", "蝴蝶光", "正面美容光", "butterfly beauty lighting"),
                option("split", "分割光", "脸部一半入暗", "split portrait lighting"),
                option("practical", "实景灯", "画内光源", "motivated practical-light setup"),
                option("neon", "霓虹混光", "彩色城市光", "mixed neon practical lighting"),
                option("fire", "火光", "暖色跳动光", "motivated firelight"),
                option("moon", "月光", "冷色夜外景", "motivated moonlight"),
                option("studio", "大型摄影棚", "精确可控", "large-scale studio lighting")
            ]

        case .exposureKey:
            return [
                option("balanced", "平衡曝光", "保留高光与暗部", "balanced cinematic exposure"),
                option("high", "高调曝光", "明亮通透", "high-key exposure"),
                option("low", "低调曝光", "深暗部", "low-key exposure"),
                option("under", "轻微欠曝", "浓郁色彩", "slightly underexposed image"),
                option("highlight", "高光保护", "亮部细节", "highlight-protected exposure"),
                option("silhouette", "剪影曝光", "背景优先", "background-biased silhouette exposure"),
                option("hdr", "宽动态", "高反差环境保留", "wide-dynamic-range exposure")
            ]

        case .colorTemperature:
            return [
                option("neutral", "中性白平衡", "自然综合色", "neutral white balance"),
                option("daylight", "5600K 日光", "标准日光", "5600K daylight balance"),
                option("tungsten", "3200K 钨丝灯", "室内暖光基准", "3200K tungsten balance"),
                option("warm", "暖色 4300K", "温暖偏琥珀", "warm 4300K color temperature"),
                option("cool", "冷色 7000K", "冷蓝环境", "cool 7000K color temperature"),
                option("mixed", "混合色温", "冷暖光源并置", "intentional mixed color temperatures")
            ]

        case .colorPalette:
            return [
                option("cinematic", "自然电影色", "平衡叙事色板", "balanced cinematic color palette"),
                option("warm", "暖色板", "琥珀红棕", "warm amber color palette"),
                option("cool", "冷色板", "蓝青色系", "cool cyan-blue color palette"),
                option("muted", "低饱和", "克制现实", "muted low-saturation palette"),
                option("vibrant", "高饱和", "强烈商业视觉", "vibrant saturated palette"),
                option("monochrome", "单色", "单一色相", "restrained monochromatic palette"),
                option("complementary", "互补色", "对立色张力", "controlled complementary-color palette"),
                option("analogous", "邻近色", "和谐色域", "harmonious analogous-color palette"),
                option("earth", "大地色", "自然材料", "earth-tone palette"),
                option("pastel", "粉彩色", "轻柔低对比", "soft pastel palette"),
                option("teal-orange", "青橙电影色", "冷暖肤色分离", "restrained teal-and-orange palette")
            ]

        case .colorContrast:
            return [
                option("natural", "自然反差", "真实层次", "natural color contrast"),
                option("low", "低反差", "柔和灰阶", "low-contrast tonal range"),
                option("high", "高反差", "鲜明明暗", "high-contrast tonal range"),
                option("filmic", "胶片柔反差", "高光柔和", "filmic contrast with gentle highlight roll-off"),
                option("lifted", "抬黑", "柔和暗部", "lifted blacks"),
                option("crushed", "压黑", "深黑戏剧感", "rich crushed blacks")
            ]

        case .timeOfDay:
            return [
                option("none", "无", "不额外指定", ""),
                option("dawn", "黎明", "日出前后", "dawn atmosphere"),
                option("day", "白天", "明确日间", "daytime setting"),
                option("golden-hour", "黄金时刻", "低角度暖阳", "golden-hour setting"),
                option("dusk", "黄昏", "日落余晖", "dusk setting"),
                option("blue-hour", "蓝调时刻", "日落后冷蓝", "blue-hour setting"),
                option("night", "夜晚", "明确夜景", "nighttime setting"),
                option("midnight", "深夜", "极低环境光", "deep-midnight setting"),
                option("interior-unspecified", "室内不明", "无可见外部时间", "time-neutral interior")
            ]

        case .weatherAtmosphere:
            return [
                option("none", "无", "不额外指定", ""),
                option("clear", "晴朗", "高能见度", "clear weather"),
                option("overcast", "阴天", "天空柔光", "overcast weather"),
                option("rain", "雨", "湿润反光", "rainy atmosphere"),
                option("storm", "暴风雨", "强烈天气", "violent storm atmosphere"),
                option("snow", "雪", "雪粒与积雪", "snowy atmosphere"),
                option("fog", "浓雾", "低能见度", "dense fog"),
                option("mist", "薄雾", "空气层次", "light atmospheric mist"),
                option("dust", "尘沙", "颗粒空气", "dust-filled atmosphere"),
                option("after-rain", "雨后", "湿地与清透空气", "wet after-rain atmosphere")
            ]

        case .nationality:
            return Self.nationalityOptionRecords.map {
                option($0.id, $0.title, $0.detail, $0.promptToken)
            }

        case .historicalEra:
            return Self.historicalEraOptionRecords.map {
                option($0.id, $0.title, $0.detail, $0.promptToken)
            }

        case .subjectPresentation:
            return [
                option("face", "脸部主设计", "优先锁定身份", "identity-defining facial design close-up"),
                option("beauty", "美容肖像", "皮肤、发妆和五官", "high-resolution beauty portrait"),
                option("head-turnaround", "头部转面", "正侧与四分之三", "front profile and three-quarter head turnaround"),
                option("expression-sheet", "表情设定", "多表情一致脸型", "facial expression model sheet"),
                option("full-body", "全身设计", "比例与服装", "full-body character design"),
                option("turnaround", "全身四视图", "制作一致性", "full-body turnaround model sheet"),
                option("silhouette", "轮廓探索", "形体辨识度", "character silhouette exploration"),
                option("wardrobe", "服装阵列", "多造型连续性", "wardrobe continuity lineup"),
                option("action", "剧情动作帧", "性格与动作", "character action keyframe")
            ]

        case .poseDynamics:
            return [
                option("neutral", "自然站姿", "无夸张动作", "natural standing pose"),
                option("a-pose", "A-Pose", "建模设定", "clean A-pose"),
                option("contrapposto", "对立式站姿", "重心与性格", "contrapposto stance"),
                option("relaxed", "放松姿态", "生活化", "relaxed candid posture"),
                option("seated", "坐姿", "人物状态", "natural seated pose"),
                option("walking", "行走", "叙事动态", "mid-stride walking pose"),
                option("dynamic", "动态动作", "强运动线", "dynamic action pose"),
                option("profile", "侧身站姿", "轮廓设计", "strict profile stance")
            ]

        case .facialExpression:
            return [
                option("neutral", "中性", "身份基准", "neutral facial expression"),
                option("determined", "坚定", "主角意志", "determined facial expression"),
                option("joy", "喜悦", "自然笑意", "authentic joyful expression"),
                option("sorrow", "悲伤", "克制情绪", "restrained sorrowful expression"),
                option("anger", "愤怒", "紧张肌肉", "controlled angry expression"),
                option("fear", "恐惧", "眼神与呼吸", "fearful expression"),
                option("enigmatic", "神秘", "难以解读", "enigmatic expression"),
                option("grid", "表情九宫格", "多状态表演", "nine-expression facial performance grid")
            ]

        case .backgroundTreatment:
            return [
                option("neutral-gray", "中性灰", "设计审阅背景", "neutral gray studio background"),
                option("white", "无缝白", "干净产品页", "seamless white background"),
                option("black", "深黑", "轮廓与反光", "deep black studio background"),
                option("gradient", "柔和渐变", "轻微空间", "subtle tonal-gradient background"),
                option("isolated", "干净抠图感", "主体完全分离", "clean isolated-background treatment"),
                option("context", "剧情环境", "真实使用场景", "contextual narrative background"),
                option("minimal-set", "极简摄影棚", "少量地面与阴影", "minimal studio-set background")
            ]

        case .materialDetail:
            return [
                option("balanced", "自然材质", "可信不过度", "physically plausible material response"),
                option("microtexture", "微表面", "毛孔纤维划痕", "high-resolution surface microtexture"),
                option("tactile", "触感强化", "材料可触感", "tactile material definition"),
                option("worn", "使用磨损", "叙事性旧化", "story-driven wear and patina"),
                option("pristine", "全新洁净", "无磨损", "pristine new condition"),
                option("wet", "湿润", "水膜与反射", "wet reflective surfaces"),
                option("dusty", "积尘", "粉尘与旧化", "dusty aged surfaces"),
                option("glossy", "高光泽", "清晰镜面响应", "glossy polished finish"),
                option("matte", "哑光", "柔和反射", "matte low-reflectance finish")
            ]

        case .finishing:
            return [
                option("clean-digital", "干净数字成片", "中性高解析", "clean digital finishing"),
                option("cinematic-grade", "电影调色", "叙事成片", "cinematic color-grade finishing"),
                option("35mm", "35mm 细颗粒", "经典胶片", "fine 35mm film grain"),
                option("16mm", "16mm 粗颗粒", "纪录与年代感", "coarse 16mm film grain"),
                option("analog", "模拟胶片", "柔和高光与色偏", "analog film response"),
                option("halation", "高光晕染", "胶片光晕", "subtle highlight halation"),
                option("hdr", "HDR 清晰度", "宽动态与局部对比", "restrained HDR finishing"),
                option("monochrome", "档案黑白", "银盐质感", "archival monochrome finishing")
            ]
        }
    }

    private func option(
        _ id: String,
        _ title: String,
        _ detail: String,
        _ promptToken: String
    ) -> PromptOption {
        PromptOption(
            id: id,
            title: title,
            detail: detail,
            promptToken: promptToken,
            preview: PromptPreviewSpec(
                family: previewFamily,
                variant: id,
                photoRecipe: PromptPhotoRecipe.make(
                    family: previewFamily,
                    variant: id,
                    promptToken: promptToken
                )
            )
        )
    }
}
