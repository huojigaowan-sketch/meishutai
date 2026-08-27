import Foundation

struct CharacterDesignOption: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let promptToken: String

    static let none = CharacterDesignOption(
        id: "none",
        title: "无",
        promptToken: ""
    )
}

enum CharacterDesignParameterGroup: String, CaseIterable, Identifiable, Sendable {
    case foundation
    case face
    case silhouette
    case grooming
    case identifiers
    case wardrobe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundation: "基础身份"
        case .face: "脸部结构与表面"
        case .silhouette: "体型、比例与动作轮廓"
        case .grooming: "发型、胡须与妆容"
        case .identifiers: "身份辨识特征"
        case .wardrobe: "服装造型与材质"
        }
    }

    var systemImage: String {
        switch self {
        case .foundation: "person.text.rectangle"
        case .face: "face.smiling"
        case .silhouette: "figure.stand"
        case .grooming: "comb"
        case .identifiers: "person.crop.circle.badge.checkmark"
        case .wardrobe: "tshirt"
        }
    }

    var parameters: [CharacterDesignParameter] {
        CharacterDesignParameter.allCases.filter { $0.group == self }
    }
}

enum CharacterDesignParameter: String, CaseIterable, Identifiable, Sendable {
    case ageStage
    case genderPresentation
    case faceShape
    case facialStructure
    case eyeShape
    case eyebrowShape
    case noseShape
    case lipShape
    case skinTone
    case skinTexture
    case restingExpression
    case heightImpression
    case bodyBuild
    case bodyProportion
    case shoulderLine
    case posture
    case movementQuality
    case hairLength
    case hairTexture
    case hairStyle
    case hairColor
    case facialHair
    case makeup
    case facialMarking
    case scarOrInjury
    case eyewear
    case bodyModification
    case costumeStyle
    case garmentSilhouette
    case layering
    case outerwear
    case upperGarment
    case lowerGarment
    case onePieceGarment
    case footwear
    case dominantMaterial
    case colorPalette
    case garmentCondition
    case accessory

    var id: String { rawValue }

    var group: CharacterDesignParameterGroup {
        switch self {
        case .ageStage, .genderPresentation:
            .foundation
        case .faceShape, .facialStructure, .eyeShape, .eyebrowShape,
             .noseShape, .lipShape, .skinTone, .skinTexture, .restingExpression:
            .face
        case .heightImpression, .bodyBuild, .bodyProportion, .shoulderLine,
             .posture, .movementQuality:
            .silhouette
        case .hairLength, .hairTexture, .hairStyle, .hairColor, .facialHair, .makeup:
            .grooming
        case .facialMarking, .scarOrInjury, .eyewear, .bodyModification:
            .identifiers
        case .costumeStyle, .garmentSilhouette, .layering, .outerwear,
             .upperGarment, .lowerGarment, .onePieceGarment, .footwear,
             .dominantMaterial, .colorPalette, .garmentCondition, .accessory:
            .wardrobe
        }
    }

    var title: String {
        switch self {
        case .ageStage: "年龄阶段"
        case .genderPresentation: "性别呈现"
        case .faceShape: "脸型"
        case .facialStructure: "骨相"
        case .eyeShape: "眼型"
        case .eyebrowShape: "眉型"
        case .noseShape: "鼻型"
        case .lipShape: "唇型"
        case .skinTone: "肤色"
        case .skinTexture: "皮肤质感"
        case .restingExpression: "常态表情"
        case .heightImpression: "身高感"
        case .bodyBuild: "体格"
        case .bodyProportion: "身体比例"
        case .shoulderLine: "肩颈轮廓"
        case .posture: "姿态"
        case .movementQuality: "动作质感"
        case .hairLength: "头发长度"
        case .hairTexture: "发质"
        case .hairStyle: "发型"
        case .hairColor: "发色"
        case .facialHair: "胡须"
        case .makeup: "妆容"
        case .facialMarking: "面部标记"
        case .scarOrInjury: "伤疤与伤妆"
        case .eyewear: "眼部配件"
        case .bodyModification: "身体改造"
        case .costumeStyle: "服装类型"
        case .garmentSilhouette: "服装廓形"
        case .layering: "穿搭层次"
        case .outerwear: "外套"
        case .upperGarment: "上装"
        case .lowerGarment: "下装"
        case .onePieceGarment: "连体服装"
        case .footwear: "鞋履"
        case .dominantMaterial: "主材质"
        case .colorPalette: "服装配色"
        case .garmentCondition: "服装状态"
        case .accessory: "配饰"
        }
    }

    var options: [CharacterDesignOption] {
        [.none] + specificOptions
    }

    func resolvedOption(in selections: [String: String]?) -> CharacterDesignOption {
        let selectedID = selections?[rawValue] ?? CharacterDesignOption.none.id
        return options.first(where: { $0.id == selectedID }) ?? .none
    }

    private var specificOptions: [CharacterDesignOption] {
        switch self {
        case .ageStage:
            [
                option("infant", "婴幼儿", "infant"),
                option("child", "儿童", "child"),
                option("preteen", "少年", "preteen"),
                option("teenager", "青少年", "teenage"),
                option("young-adult", "青年", "young adult"),
                option("adult", "壮年", "adult in their thirties"),
                option("middle-aged", "中年", "middle-aged"),
                option("older-adult", "老年", "older adult"),
                option("elderly", "高龄", "elderly")
            ]
        case .genderPresentation:
            [
                option("masculine", "男性化", "masculine-presenting"),
                option("feminine", "女性化", "feminine-presenting"),
                option("androgynous", "中性化", "androgynous-presenting"),
                option("gender-neutral", "无性别倾向", "gender-neutral presentation")
            ]
        case .faceShape:
            [
                option("oval", "椭圆脸", "oval face"),
                option("round", "圆脸", "round face"),
                option("square", "方脸", "square face"),
                option("oblong", "长脸", "oblong face"),
                option("heart", "心形脸", "heart-shaped face"),
                option("diamond", "菱形脸", "diamond-shaped face"),
                option("triangle", "三角脸", "triangular face"),
                option("inverted-triangle", "倒三角脸", "inverted-triangle face")
            ]
        case .facialStructure:
            [
                option("soft", "柔和骨相", "soft facial structure"),
                option("defined", "轮廓分明", "defined facial planes"),
                option("high-cheekbones", "高颧骨", "high prominent cheekbones"),
                option("strong-jaw", "强下颌", "strong angular jawline"),
                option("delicate-jaw", "窄下颌", "delicate narrow jawline"),
                option("broad", "宽阔骨相", "broad facial structure"),
                option("gaunt", "清瘦骨相", "gaunt face with pronounced planes")
            ]
        case .eyeShape:
            [
                option("almond", "杏眼", "almond-shaped eyes"),
                option("round", "圆眼", "round eyes"),
                option("hooded", "内双眼", "hooded eyes"),
                option("deep-set", "深陷眼", "deep-set eyes"),
                option("upturned", "上挑眼", "upturned eyes"),
                option("downturned", "下垂眼", "downturned eyes"),
                option("monolid", "单眼皮", "monolid eyes"),
                option("wide-set", "宽眼距", "wide-set eyes"),
                option("close-set", "窄眼距", "close-set eyes")
            ]
        case .eyebrowShape:
            [
                option("straight", "平直眉", "straight eyebrows"),
                option("soft-arch", "柔弧眉", "softly arched eyebrows"),
                option("high-arch", "高挑眉", "high-arched eyebrows"),
                option("thick", "浓眉", "thick defined eyebrows"),
                option("fine", "细眉", "fine delicate eyebrows"),
                option("bushy", "自然野生眉", "full bushy eyebrows")
            ]
        case .noseShape:
            [
                option("straight", "直鼻", "straight nose"),
                option("aquiline", "鹰钩鼻", "aquiline nose"),
                option("button", "小巧圆鼻", "small button nose"),
                option("broad", "宽鼻", "broad nose"),
                option("narrow", "窄鼻", "narrow nose"),
                option("upturned", "翘鼻", "upturned nose"),
                option("low-bridge", "低鼻梁", "low-bridged nose")
            ]
        case .lipShape:
            [
                option("balanced", "自然唇", "balanced natural lips"),
                option("full", "丰唇", "full lips"),
                option("thin", "薄唇", "thin lips"),
                option("cupid-bow", "丘比特弓唇", "defined cupid's-bow lips"),
                option("wide", "宽嘴型", "wide mouth"),
                option("downturned", "下垂嘴角", "slightly downturned lips")
            ]
        case .skinTone:
            [
                option("very-fair", "冷白肤色", "very fair skin tone"),
                option("fair", "浅肤色", "fair skin tone"),
                option("light-medium", "浅中肤色", "light-medium skin tone"),
                option("olive", "橄榄肤色", "olive skin tone"),
                option("tan", "小麦肤色", "tan skin tone"),
                option("medium-brown", "中棕肤色", "medium brown skin tone"),
                option("deep-brown", "深棕肤色", "deep brown skin tone"),
                option("very-deep", "浓深肤色", "very deep skin tone")
            ]
        case .skinTexture:
            [
                option("natural", "自然毛孔", "realistic skin texture with visible pores"),
                option("smooth", "细腻皮肤", "smooth even skin texture"),
                option("freckled", "雀斑皮肤", "freckled skin"),
                option("weathered", "风霜皮肤", "weathered skin texture"),
                option("sun-damaged", "日晒痕迹", "subtle sun-damaged skin"),
                option("mature", "成熟纹理", "mature skin with fine lines"),
                option("acne-scarred", "痘印皮肤", "realistic acne marks and light scarring")
            ]
        case .restingExpression:
            [
                option("calm", "平静克制", "calm restrained resting expression"),
                option("stern", "严肃冷峻", "stern resting expression"),
                option("warm", "温和亲切", "warm open resting expression"),
                option("guarded", "戒备疏离", "guarded distant resting expression"),
                option("intense", "专注锐利", "intense focused gaze"),
                option("weary", "疲惫沧桑", "world-weary resting expression"),
                option("mischievous", "机敏顽皮", "subtly mischievous expression")
            ]
        case .heightImpression:
            [
                option("petite", "娇小", "petite stature"),
                option("short", "偏矮", "short stature"),
                option("average", "中等身高", "average-height silhouette"),
                option("tall", "高挑", "tall stature"),
                option("very-tall", "极高挑", "very tall imposing stature")
            ]
        case .bodyBuild:
            [
                option("slender", "纤细", "slender build"),
                option("lean", "精瘦", "lean build"),
                option("lean-athletic", "精瘦健体", "lean athletic build"),
                option("athletic", "运动型", "athletic build"),
                option("muscular", "肌肉型", "muscular build"),
                option("broad-heavy", "宽厚", "broad heavy build"),
                option("stocky", "敦实", "compact stocky build"),
                option("soft-rounded", "柔软圆润", "soft rounded build"),
                option("curvy", "曲线型", "curvy build")
            ]
        case .bodyProportion:
            [
                option("balanced", "均衡比例", "balanced body proportions"),
                option("long-limbed", "修长四肢", "long-limbed proportions"),
                option("long-legs", "腿长腰短", "long legs and a short torso"),
                option("long-torso", "腰长腿短", "long torso and shorter legs"),
                option("compact", "紧凑比例", "compact body proportions"),
                option("top-heavy", "上宽下窄", "broad upper body and narrow hips"),
                option("bottom-heavy", "上窄下宽", "narrow shoulders and wider hips")
            ]
        case .shoulderLine:
            [
                option("narrow", "窄肩", "narrow shoulder line"),
                option("sloping", "溜肩", "gently sloping shoulders"),
                option("balanced", "平衡肩线", "balanced shoulder line"),
                option("broad", "宽肩", "broad shoulders"),
                option("square", "平直方肩", "square structured shoulders"),
                option("rounded", "圆肩", "rounded shoulders")
            ]
        case .posture:
            [
                option("upright", "挺拔", "upright posture"),
                option("relaxed", "松弛", "relaxed open posture"),
                option("guarded", "戒备", "guarded closed posture"),
                option("stooped", "微驼", "slightly stooped posture"),
                option("poised", "优雅端正", "poised elegant posture"),
                option("military", "军姿", "disciplined military posture"),
                option("asymmetrical", "随性偏重心", "casual asymmetrical stance")
            ]
        case .movementQuality:
            [
                option("economical", "克制利落", "economical precise movement"),
                option("graceful", "流畅优雅", "graceful fluid movement"),
                option("energetic", "敏捷有力", "energetic agile movement"),
                option("heavy", "沉重稳健", "heavy deliberate movement"),
                option("restless", "紧张多动", "restless fidgeting movement"),
                option("cautious", "谨慎试探", "cautious measured movement"),
                option("commanding", "强势压迫", "commanding expansive movement")
            ]
        case .hairLength:
            [
                option("shaved", "剃光", "shaved head"),
                option("buzzed", "寸头", "buzz-cut hair"),
                option("short", "短发", "short hair"),
                option("ear-length", "齐耳发", "ear-length hair"),
                option("shoulder", "中长发", "shoulder-length hair"),
                option("long", "长发", "long hair"),
                option("waist", "及腰长发", "waist-length hair")
            ]
        case .hairTexture:
            [
                option("straight", "直发", "straight hair texture"),
                option("wavy", "波浪发", "wavy hair texture"),
                option("curly", "卷发", "curly hair texture"),
                option("coiled", "紧密卷发", "tightly coiled hair texture"),
                option("coarse", "粗硬发质", "coarse hair texture"),
                option("fine", "细软发质", "fine soft hair texture")
            ]
        case .hairStyle:
            [
                option("center-part", "中分", "center-parted hairstyle"),
                option("side-part", "侧分", "side-parted hairstyle"),
                option("slicked-back", "背头", "slicked-back hairstyle"),
                option("bob", "波波头", "structured bob haircut"),
                option("pixie", "精灵短发", "pixie haircut"),
                option("ponytail", "马尾", "practical ponytail"),
                option("braided", "编发", "braided hairstyle"),
                option("bun", "盘发", "neat hair bun"),
                option("messy-layered", "凌乱层次", "messy layered hairstyle")
            ]
        case .hairColor:
            [
                option("black", "黑发", "black hair"),
                option("dark-brown", "深棕发", "dark brown hair"),
                option("brown", "棕发", "brown hair"),
                option("light-brown", "浅棕发", "light brown hair"),
                option("blonde", "金发", "blonde hair"),
                option("red", "红发", "red hair"),
                option("auburn", "赤褐发", "auburn hair"),
                option("gray", "灰发", "gray hair"),
                option("white", "白发", "white hair"),
                option("vivid-dyed", "高彩染发", "vividly dyed hair")
            ]
        case .facialHair:
            [
                option("clean-shaven", "无胡须", "clean-shaven face"),
                option("stubble", "短胡茬", "short facial stubble"),
                option("mustache", "小胡子", "defined mustache"),
                option("goatee", "山羊胡", "trimmed goatee"),
                option("short-beard", "短络腮胡", "short trimmed beard"),
                option("full-beard", "浓密络腮胡", "full beard"),
                option("sideburns", "明显鬓角", "prominent sideburns")
            ]
        case .makeup:
            [
                option("none", "素颜", "no visible makeup"),
                option("natural", "自然妆", "restrained natural makeup"),
                option("editorial", "时尚编辑妆", "graphic editorial makeup"),
                option("glamorous", "精致浓妆", "polished glamorous makeup"),
                option("smoky", "烟熏妆", "smoky eye makeup"),
                option("period", "年代妆", "period-appropriate makeup"),
                option("stage", "舞台妆", "theatrical stage makeup"),
                option("distressed", "疲态伤妆", "distressed makeup with subtle fatigue")
            ]
        case .facialMarking:
            [
                option("freckles", "雀斑", "distinctive facial freckles"),
                option("beauty-mark", "美人痣", "distinctive facial beauty mark"),
                option("birthmark", "胎记", "visible facial birthmark"),
                option("vitiligo", "白癜风斑", "distinctive facial vitiligo pattern"),
                option("under-eye", "明显眼下疲态", "pronounced natural under-eye circles"),
                option("sunspots", "晒斑", "visible natural sunspots")
            ]
        case .scarOrInjury:
            [
                option("eyebrow-scar", "眉部疤痕", "distinctive scar through one eyebrow"),
                option("facial-scar", "面部线性疤痕", "healed linear facial scar"),
                option("burn-scar", "烧伤疤痕", "realistic healed burn scar"),
                option("surgical-scar", "手术疤痕", "subtle healed surgical scar"),
                option("fresh-bruise", "新鲜淤伤", "fresh realistic facial bruising"),
                option("wound-makeup", "伤口特效妆", "realistic practical wound makeup")
            ]
        case .eyewear:
            [
                option("round-glasses", "圆框眼镜", "round-frame glasses"),
                option("rectangular-glasses", "方框眼镜", "rectangular-frame glasses"),
                option("wireframe-glasses", "金属细框眼镜", "thin wireframe glasses"),
                option("sunglasses", "墨镜", "character-specific sunglasses"),
                option("monocle", "单片眼镜", "monocle"),
                option("eyepatch", "眼罩", "functional eyepatch"),
                option("goggles", "护目镜", "protective goggles")
            ]
        case .bodyModification:
            [
                option("ear-piercings", "耳部穿孔", "distinctive ear piercings"),
                option("facial-piercing", "面部穿孔", "subtle facial piercing"),
                option("tattoo", "可见纹身", "story-specific visible tattoo"),
                option("ceremonial-marking", "仪式纹样", "story-specific ceremonial body markings"),
                option("prosthetic", "义肢", "functional prosthetic limb"),
                option("cybernetic", "机械植入", "integrated cybernetic implant")
            ]
        case .costumeStyle:
            [
                option("tailored-formal", "正式礼服", "tailored formal costume"),
                option("business", "职业正装", "professional business attire"),
                option("smart-casual", "精致休闲", "smart-casual costume"),
                option("workwear", "功能工装", "utilitarian workwear"),
                option("streetwear", "都市街头", "layered urban streetwear"),
                option("athletic", "运动服装", "functional athletic wear"),
                option("military", "军装战术", "military-inspired tactical uniform"),
                option("academic", "学院制服", "structured academic uniform"),
                option("ceremonial", "典礼服装", "ceremonial costume"),
                option("evening", "晚宴礼服", "elegant evening wear"),
                option("rural", "乡野实用", "practical rural clothing"),
                option("fantasy", "幻想长袍", "fantasy robe ensemble"),
                option("historical", "历史服饰", "period-authentic historical costume")
            ]
        case .garmentSilhouette:
            [
                option("fitted", "修身", "fitted garment silhouette"),
                option("relaxed", "宽松", "relaxed garment silhouette"),
                option("oversized", "超宽松", "oversized garment silhouette"),
                option("structured", "硬朗结构", "structured angular garment silhouette"),
                option("a-line", "A字廓形", "A-line silhouette"),
                option("columnar", "直筒廓形", "long columnar silhouette"),
                option("voluminous", "蓬松体量", "layered voluminous silhouette"),
                option("cinched", "收腰", "defined cinched waist"),
                option("top-heavy", "上重下轻", "top-heavy costume silhouette"),
                option("bottom-heavy", "下重上轻", "bottom-heavy costume silhouette")
            ]
        case .layering:
            [
                option("single", "单层简洁", "clean single-layer dressing"),
                option("minimal", "少量叠穿", "minimal two-layer styling"),
                option("multi", "丰富叠穿", "functional multi-layer styling"),
                option("asymmetrical", "不对称叠穿", "asymmetrical layered styling"),
                option("wrapped", "缠裹垂坠", "wrapped and draped garment construction")
            ]
        case .outerwear:
            [
                option("trench", "风衣", "tailored trench coat"),
                option("overcoat", "长大衣", "structured long overcoat"),
                option("blazer", "西装外套", "tailored blazer"),
                option("leather-jacket", "皮夹克", "constructed leather jacket"),
                option("bomber", "飞行夹克", "bomber jacket"),
                option("denim-jacket", "牛仔夹克", "denim jacket"),
                option("parka", "派克大衣", "weatherproof parka"),
                option("cloak", "斗篷", "full-length cloak or cape"),
                option("cardigan", "针织开衫", "knitted cardigan"),
                option("utility-vest", "功能背心", "pocketed utility vest")
            ]
        case .upperGarment:
            [
                option("shirt", "衬衫", "constructed collared shirt"),
                option("blouse", "女式衬衫", "soft structured blouse"),
                option("t-shirt", "T恤", "plain fitted T-shirt"),
                option("sweater", "针织衫", "textured knit sweater"),
                option("turtleneck", "高领衫", "fitted turtleneck"),
                option("tunic", "束腰外衣", "long tunic"),
                option("bodice", "紧身胸衣", "structured bodice"),
                option("armor", "护甲上装", "functional layered torso armor"),
                option("uniform-jacket", "制服上衣", "structured uniform jacket")
            ]
        case .lowerGarment:
            [
                option("trousers", "西装长裤", "tailored trousers"),
                option("jeans", "牛仔裤", "constructed denim jeans"),
                option("cargo", "工装裤", "functional cargo trousers"),
                option("wide-leg", "阔腿裤", "wide-leg trousers"),
                option("pencil-skirt", "铅笔裙", "structured pencil skirt"),
                option("pleated-skirt", "百褶裙", "constructed pleated skirt"),
                option("shorts", "短裤", "tailored shorts"),
                option("leggings", "紧身裤", "fitted leggings")
            ]
        case .onePieceGarment:
            [
                option("dress", "连衣裙", "constructed dress"),
                option("jumpsuit", "连体裤", "functional jumpsuit"),
                option("robe", "长袍", "full-length robe"),
                option("gown", "礼服长裙", "formal full-length gown"),
                option("coveralls", "连体工装", "utilitarian coveralls")
            ]
        case .footwear:
            [
                option("dress-shoes", "正装鞋", "polished dress shoes"),
                option("boots", "长靴", "constructed tall boots"),
                option("combat-boots", "战术靴", "functional combat boots"),
                option("sneakers", "运动鞋", "practical sneakers"),
                option("heels", "高跟鞋", "structured high-heeled shoes"),
                option("flats", "平底鞋", "practical flat shoes"),
                option("sandals", "凉鞋", "constructed sandals"),
                option("barefoot", "赤足", "bare feet"),
                option("period", "年代鞋履", "period-authentic footwear")
            ]
        case .dominantMaterial:
            [
                option("cotton", "棉", "natural cotton fabric"),
                option("linen", "亚麻", "textured linen fabric"),
                option("wool", "羊毛", "dense wool fabric"),
                option("silk", "丝绸", "lustrous silk fabric"),
                option("leather", "皮革", "constructed natural leather"),
                option("denim", "牛仔布", "structured denim"),
                option("technical", "机能面料", "matte technical fabric"),
                option("velvet", "天鹅绒", "deep-pile velvet"),
                option("brocade", "织锦", "patterned brocade"),
                option("mixed-natural", "天然混纺", "layered natural-fiber textiles")
            ]
        case .colorPalette:
            [
                option("neutral", "中性色", "restrained neutral costume palette"),
                option("black", "黑色单色", "monochrome black costume palette"),
                option("earth", "大地色", "earth-tone costume palette"),
                option("cool-muted", "低饱和冷色", "muted cool costume palette"),
                option("warm-muted", "低饱和暖色", "muted warm costume palette"),
                option("jewel", "宝石色", "deep jewel-tone costume palette"),
                option("pastel", "柔和浅色", "soft pastel costume palette"),
                option("high-contrast", "高对比色", "controlled high-contrast costume palette"),
                option("uniform", "统一制式色", "cohesive institutional uniform palette")
            ]
        case .garmentCondition:
            [
                option("pristine", "全新挺括", "pristine freshly pressed garments"),
                option("maintained", "保养良好", "well-maintained garments"),
                option("lived-in", "自然穿着感", "subtle lived-in garment wear"),
                option("worn", "明显磨损", "visibly worn garments"),
                option("weathered", "风化褪色", "weathered faded garments"),
                option("distressed", "破旧做旧", "heavily distressed garments"),
                option("dirty", "沾污", "story-specific dirt and staining"),
                option("battle-damaged", "战损", "battle-damaged garments with plausible tears")
            ]
        case .accessory:
            [
                option("minimal-jewelry", "极简首饰", "minimal character-specific jewelry"),
                option("statement-jewelry", "醒目首饰", "one statement jewelry piece"),
                option("scarf", "围巾", "character-specific scarf"),
                option("belt-harness", "腰带挂具", "functional belt and harness system"),
                option("gloves", "手套", "purpose-built gloves"),
                option("headwear", "帽饰", "character-specific headwear"),
                option("bag", "随身包", "functional satchel or shoulder bag"),
                option("insignia", "徽章标识", "story-specific badge or insignia"),
                option("protective", "防护装备", "functional protective equipment")
            ]
        }
    }

    private func option(
        _ id: String,
        _ title: String,
        _ promptToken: String
    ) -> CharacterDesignOption {
        CharacterDesignOption(
            id: id,
            title: title,
            promptToken: promptToken
        )
    }
}
