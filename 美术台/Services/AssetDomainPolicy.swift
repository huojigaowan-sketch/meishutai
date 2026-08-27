import Foundation

enum CharacterRolePolicy {
    private static let groupRoleNames: Set<String> = [
        "流民", "劫匪", "土匪", "壮汉", "庄稼汉", "庄稼汉子", "丫鬟",
        "护卫", "官兵", "路人", "赵家众人", "蒙面人", "孩子"
    ]

    static func canonicalName(for rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutCount = trimmed.replacingOccurrences(
            of: #"\s*\\?\*[0-9０-９]+\s*$"#,
            with: "",
            options: .regularExpression
        )
        let withoutIndex = withoutCount.replacingOccurrences(
            of: #"\s*[0-9０-９]+\s*$"#,
            with: "",
            options: .regularExpression
        )
        return groupRoleNames.contains(withoutIndex) ? withoutIndex : withoutCount
    }

    static func variantLabel(for rawName: String) -> String? {
        let canonical = canonicalName(for: rawName)
        guard canonical != rawName else { return nil }
        return rawName
    }
}

enum PropProductionPolicy {
    private static let heroTerms = [
        "电动车", "地图", "退烧药", "布洛芬", "感冒灵", "匕首", "钥匙"
    ]
    private static let consumableTerms = [
        "米", "面粉", "红薯", "土豆", "鸡蛋", "方便面", "盐焗鸡", "腊肉",
        "鱼干", "白糖", "盐巴", "水", "包子", "馒头", "湿纸巾", "卫生巾",
        "安睡裤", "药片"
    ]
    private static let featuredTerms = [
        "背篓", "钱袋", "碎银", "铜板", "玉扣", "火折子", "竹筒", "小木盒",
        "菜刀", "柴刀", "安全帽", "斗篷", "口罩"
    ]

    static func priority(name: String, storyFunction: String = "") -> ProductionAssetPriority {
        let source = name + " " + storyFunction
        if heroTerms.contains(where: source.contains) { return .hero }
        if featuredTerms.contains(where: source.contains) { return .featured }
        if consumableTerms.contains(where: source.contains) { return .consumable }
        return .setDressing
    }
}

