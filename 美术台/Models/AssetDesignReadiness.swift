import Foundation

nonisolated enum AssetDesignReadiness {
    static func isReady(_ asset: ProductionAsset) -> Bool {
        let kinds = Set(asset.verifiedDesignFacts.map(\.kind))
        switch asset.kind {
        case .scene:
            let hasEnvironment = kinds.contains(.environmentType)
                || kinds.contains(.architecture)
            let hasPurposeOrLayout = kinds.contains(.functionalPurpose)
                || kinds.contains(.spatialLayout)
                || kinds.contains(.distinctiveFeature)
            return hasEnvironment && hasPurposeOrLayout
        case .character:
            let hasIdentityContext = kinds.contains(.identityRole)
                || kinds.contains(.relationship)
                || !asset.canonicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasDesignDetail = kinds.contains(.ageRange)
                || kinds.contains(.genderPresentation)
                || kinds.contains(.physique)
                || kinds.contains(.faceHair)
                || kinds.contains(.costume)
                || kinds.contains(.accessory)
                || kinds.contains(.characterState)
                || kinds.contains(.distinctiveFeature)
            return hasIdentityContext && hasDesignDetail
        case .prop:
            let hasType = kinds.contains(.objectType)
            let hasDesignDetail = kinds.contains(.objectFunction)
                || kinds.contains(.quantityScale)
                || kinds.contains(.material)
                || kinds.contains(.colorPattern)
                || kinds.contains(.condition)
                || kinds.contains(.eraCulture)
                || kinds.contains(.distinctiveFeature)
            return hasType && hasDesignDetail
        }
    }

    static func missingReason(_ asset: ProductionAsset) -> String {
        guard !isReady(asset) else { return "" }
        switch asset.kind {
        case .scene:
            return "场景只有名称，尚缺环境类型以及功能、布局或可见特征。"
        case .character:
            return "人物只有姓名或身份，尚缺剧本明确的年龄、性别、体貌、服装或状态特征。"
        case .prop:
            return "道具只有名称，尚缺用途、尺度、材质、颜色、新旧状态或识别特征。"
        }
    }
}
