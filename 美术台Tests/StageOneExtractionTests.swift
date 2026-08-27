import Foundation
import Testing
@testable import 美术台

struct StageOneExtractionTests {
    private let episodeID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    private let goldenScript = """
    1-1 日/内 林宅·客厅
    林默拿起桌上的手机，把一枚黄铜钥匙交给苏晴。
    林默：门已经锁了。
    苏晴
    我会处理。

    1-2 夜/内 林宅客厅
    苏晴放下手机。
    林默
    钥匙还在你那里吗？
    """

    @Test("本地候选账本覆盖标准场景、说话人和常用道具且不误收标题")
    func localLedgerProducesDeterministicEvidenceBackedCandidates() {
        let first = ledger(for: goldenScript)
        let second = ledger(for: goldenScript)

        #expect(first.scenes.count == 2)
        #expect(first.scenes.map(\.canonicalLocationName) == ["林宅·客厅", "林宅客厅"])
        #expect(first.candidates.map(\.id) == second.candidates.map(\.id))
        #expect(first.scenes.map(\.id) == second.scenes.map(\.id))
        #expect(first.candidates.allSatisfy { $0.evidence.text(in: goldenScript) != nil })

        let characterNames = first.candidates
            .filter { $0.kind == .character }
            .map(\.rawName)
        let propNames = first.candidates
            .filter { $0.kind == .prop }
            .map(\.rawName)

        #expect(characterNames.contains("林默"))
        #expect(characterNames.contains("苏晴"))
        #expect(!characterNames.contains(where: { $0.contains("1-1") || $0.contains("1-2") }))
        #expect(propNames.contains("手机"))
        #expect(propNames.contains("钥匙"))
        #expect(!propNames.contains(where: { $0.contains("交给苏晴") }))
    }

    @Test("金标准决策组装后同一场景、人物和道具各保留一个规范实体")
    func acceptedGoldenLedgerAssemblesCanonicalInventoryWithoutDuplicates() {
        var ledger = ledger(for: goldenScript)
        let decidedIDs = Set(ledger.decisions.map(\.candidateID))
        for candidate in ledger.candidates where !decidedIDs.contains(candidate.id) {
            ledger.decisions.append(StageOneCandidateDecision(
                candidateID: candidate.id,
                disposition: .accepted,
                canonicalName: candidate.rawName,
                identityQualifier: nil,
                variantLabel: nil,
                reason: "金标准人工标注",
                confidence: 1
            ))
        }

        let coverage = ledger.coverage(in: goldenScript)
        let assets = StageOneAssetAssembler.extractedAssets(
            from: ledger,
            source: goldenScript
        )
        let occurrences = StageOneAssetAssembler.occurrences(
            from: ledger,
            source: goldenScript
        )

        #expect(coverage.isComplete)
        #expect(assets.scenes.map(\.name) == ["林宅·客厅"])
        #expect(Set(assets.characters.map(\.name)) == ["林默", "苏晴"])
        #expect(Set(assets.props.map(\.name)) == ["手机", "钥匙"])
        #expect(occurrences.values.flatMap { $0 }.allSatisfy {
            $0.evidence.text(in: goldenScript) != nil
        })
        let sceneKey = CanonicalAssetIdentity.key(
            kind: .scene,
            canonicalName: "林宅客厅"
        )
        #expect(occurrences[sceneKey]?.count == 2)
    }

    @Test("UTF-16 证据跨度支持 emoji，原文发生任何变化都会失效")
    func sourceEvidenceRejectsMutatedText() throws {
        let source = "前😀缀 黄铜钥匙 后缀"
        let sourceNSString = source as NSString
        let range = sourceNSString.range(of: "黄铜钥匙")
        let evidence = SourceTextSpan(
            utf16Location: range.location,
            text: sourceNSString.substring(with: range)
        )

        #expect(evidence.text(in: source) == "黄铜钥匙")
        #expect(evidence.text(in: source.replacingOccurrences(of: "黄铜", with: "白银")) == nil)
    }

    @Test("真实短剧格式从标题人物表提取角色并移除场景名污染")
    func shortDramaCastListsAndHistoricalPropsAreGrounded() {
        let script = """
        **日/内 官道 人物：余思思 安安**
        一辆粉色电动车疾驰在尘土飞扬的古代官道上。
        余思思怀里用布带绑着安安，车后座绑着一个竹编背篓。

        **1-2夜/内 赵家-卧室 人物：余思思、安安（婴儿）**
        余思思躺在冰冷的木板床上。

        **1-4夜/内 赵家-卧室 人物：余思思（昏迷）、安安（婴儿）赵母、赵青山、柳氏、赵家众人**
        赵母拉紧柳氏的手。
        """

        let ledger = ledger(for: script)
        let scenes = ledger.scenes.filter { !$0.isPreamble }
        let castCandidates = ledger.candidates.filter { $0.origin == .castList }
        let propNames = Set(ledger.candidates.filter { $0.kind == .prop }.map(\.rawName))

        #expect(scenes.count == 3)
        #expect(scenes.map(\.canonicalLocationName) == ["官道", "赵家-卧室", "赵家-卧室"])
        #expect(Set(castCandidates.map(\.rawName)).isSuperset(of: [
            "余思思", "安安", "赵母", "赵青山", "柳氏", "赵家众人"
        ]))
        #expect(castCandidates.allSatisfy { $0.evidence.text(in: script) != nil })
        #expect(propNames.isSuperset(of: ["电动车", "布带", "竹编背篓", "木板床"]))
        #expect(ledger.coverage(in: script).groundingRate == 1)
    }

    @Test("21 集金标准按类别计算别名感知的 Precision Recall F1")
    func twentyOneEpisodeGoldStandardMetrics() {
        let labels = Self.twentyOneEpisodeGoldLabels
        var predictions = labels.map { label in
            AssetItem(
                kind: label.kind,
                name: label.aliases.sorted().first ?? label.canonicalName,
                summary: "金标准预测"
            )
        }
        predictions.removeAll(where: { $0.kind == .prop && $0.name == "地图" })
        predictions.append(AssetItem(kind: .prop, name: "普通灰尘", summary: "误报"))

        let report = ExtractionEvaluator.evaluate(
            assets: predictions,
            goldLabels: labels
        )
        let props = report.metrics.first(where: { $0.kind == .prop })

        #expect(labels.filter { $0.kind == .character }.count >= 24)
        #expect(labels.filter { $0.kind == .scene }.count >= 18)
        #expect(labels.filter { $0.kind == .prop }.count >= 24)
        #expect(props?.falsePositive == 1)
        #expect(props?.falseNegative == 1)
        #expect(report.microF1 > 0 && report.microF1 < 1)
    }

    @Test("群体角色按生产身份归并且道具获得制作优先级")
    func groupRolesAndPropPrioritiesAreDeterministic() {
        #expect(CharacterRolePolicy.canonicalName(for: "流民1") == "流民")
        #expect(CharacterRolePolicy.canonicalName(for: "流民\\*10") == "流民")
        #expect(CharacterRolePolicy.canonicalName(for: "丫鬟2") == "丫鬟")
        #expect(CharacterRolePolicy.canonicalName(for: "余思思") == "余思思")
        #expect(PropProductionPolicy.priority(name: "粉色电动车") == .hero)
        #expect(PropProductionPolicy.priority(name: "十升装矿泉水") == .consumable)
        #expect(PropProductionPolicy.priority(name: "竹编背篓") == .featured)
        #expect(PropProductionPolicy.priority(name: "普通粗瓷菜盘") == .setDressing)
    }

    @Test("规范键生成稳定 UUID，连续性描述变化不产生重复资产")
    func canonicalIdentityIsStableAcrossRerunsAndOccurrenceStates() {
        let key = CanonicalAssetIdentity.key(
            kind: .prop,
            canonicalName: "黄铜钥匙"
        )
        let sameKey = CanonicalAssetIdentity.key(
            kind: .prop,
            canonicalName: "黄 铜-钥匙"
        )

        #expect(key == sameKey)
        #expect(
            CanonicalAssetIdentity.stableUUID(for: key)
                == CanonicalAssetIdentity.stableUUID(for: sameKey)
        )
        #expect(
            CanonicalAssetIdentity.key(
                kind: .prop,
                canonicalName: "黄铜钥匙",
                identityQualifier: "另一把"
            ) != key
        )
    }

    @Test("Apple 本地模型输入会分批且每个候选恰好保留一次")
    func onDeviceCandidateBatchesAreBoundedAndComplete() {
        let candidates = (0..<17).map { index in
            OnDeviceInventoryCandidate(
                candidateID: "candidate-\(index)",
                rawName: "候选\(index)",
                sceneID: "scene-1",
                evidence: String(repeating: "剧", count: 700),
                origin: "actionLine"
            )
        }

        let batches = OnDeviceInventoryBatchPlanner.batches(for: candidates)
        let flattened = batches.flatMap { $0 }

        #expect(batches.count > 1)
        #expect(batches.allSatisfy {
            $0.count <= OnDeviceInventoryBatchPlanner.maximumCandidatesPerBatch
        })
        #expect(flattened.map(\.candidateID) == candidates.map(\.candidateID))
        #expect(flattened.allSatisfy { $0.evidence.count <= 520 })
    }

    @Test("Apple 本地模型回执必须无重复地覆盖全部候选")
    func onDeviceDecisionValidationRejectsMissingCandidate() {
        let incomplete = [
            OnDeviceInventoryDecision(
                candidateID: "candidate-1",
                disposition: .accepted,
                canonicalName: "林默",
                identityQualifier: nil,
                variantLabel: nil,
                reason: "说话人",
                confidence: 0.9
            )
        ]

        #expect(throws: AppleFoundationModelAdjudicationError.self) {
            try OnDeviceInventoryDecisionValidator.validate(
                incomplete,
                expectedCandidateIDs: ["candidate-1", "candidate-2"]
            )
        }
    }

    @Test("Apple 本地模型能力探针始终返回可解释状态")
    func onDeviceAvailabilityIsExplicit() async {
        let availability = await AppleFoundationModelInventoryAdjudicator.shared
            .availability()

        switch availability {
        case .available(let contextSize):
            #expect(contextSize > 0)
        case .unavailable(let reason):
            #expect(!reason.isEmpty)
        case .unsupportedChinese:
            #expect(!availability.canAdjudicate)
        }
    }

    @MainActor
    @Test("存疑候选经人工确认后才进入资产库并立即清空复核项")
    func manualReviewMaterializesOnlyConfirmedCandidate() throws {
        let repository = try WorkspaceRepository(isStoredInMemoryOnly: true)
        let store = WorkspaceStore(
            repository: repository,
            legacySnapshotURL: URL(fileURLWithPath: "/tmp/assetdesk-stage-one-review")
        )
        var ledger = ledger(for: goldenScript)
        var decidedIDs = Set(ledger.decisions.map(\.candidateID))
        for undecided in ledger.candidates where !decidedIDs.contains(undecided.id) {
            ledger.decisions.append(StageOneCandidateDecision(
                candidateID: undecided.id,
                disposition: .rejected,
                canonicalName: undecided.rawName,
                identityQualifier: nil,
                variantLabel: nil,
                reason: "金标准预置排除",
                confidence: 1
            ))
            decidedIDs.insert(undecided.id)
        }
        let candidate = try #require(
            ledger.candidates.first(where: {
                $0.kind == .prop && $0.rawName == "钥匙"
            })
        )
        ledger.decisions.removeAll(where: { $0.candidateID == candidate.id })
        ledger.decisions.append(StageOneCandidateDecision(
            candidateID: candidate.id,
            disposition: .uncertain,
            canonicalName: "黄铜钥匙",
            identityQualifier: nil,
            variantLabel: nil,
            reason: "需确认是否为制作道具",
            confidence: 0.5
        ))
        let episode = ScriptEpisode(
            id: episodeID,
            order: 1,
            title: "金标准集",
            scriptText: goldenScript,
            extractionStatus: .completedWithWarnings,
            extractionLedger: ledger
        )
        store.episodes = [episode]
        store.selectedEpisodeID = episodeID

        #expect(store.currentExtractionReviewItems.count == 1)
        #expect(store.assets.allSatisfy { $0.name != "黄铜钥匙" })

        store.resolveExtractionCandidate(
            episodeID: episodeID,
            candidateID: candidate.id,
            disposition: .accepted,
            canonicalName: "黄铜钥匙"
        )

        #expect(store.currentExtractionReviewItems.isEmpty)
        #expect(store.assets.contains(where: { $0.name == "黄铜钥匙" }))
        #expect(store.currentEpisode?.effectiveStatus == .completed)
    }

    @MainActor
    @Test("多项人工合并回写账本并保留各自原文 occurrence")
    func manualMergePreservesOccurrences() throws {
        let repository = try WorkspaceRepository(isStoredInMemoryOnly: true)
        let store = WorkspaceStore(
            repository: repository,
            legacySnapshotURL: URL(fileURLWithPath: "/tmp/assetdesk-stage-one-merge")
        )
        let script = """
        1-1 日/外 官道
        流民1：快走。
        流民2：跟上。
        """
        var ledger = ledger(for: script)
        let candidates = ledger.candidates.filter {
            $0.kind == .character && $0.rawName.hasPrefix("流民")
        }
        for candidate in candidates {
            ledger.decisions.append(StageOneCandidateDecision(
                candidateID: candidate.id,
                disposition: .uncertain,
                canonicalName: candidate.rawName,
                identityQualifier: nil,
                variantLabel: nil,
                reason: "等待群体归并",
                confidence: 0.5
            ))
        }
        let episode = ScriptEpisode(
            id: episodeID,
            order: 1,
            title: "第 1 集",
            scriptText: script,
            extractionStatus: .completedWithWarnings,
            extractionLedger: ledger
        )
        store.episodes = [episode]
        store.selectedEpisodeID = episodeID

        store.mergeExtractionCandidates(
            store.projectExtractionReviewItems,
            canonicalName: "流民"
        )

        let merged = try #require(store.assets.first(where: { $0.name == "流民" }))
        #expect(merged.occurrences?.count == 2)
        #expect(store.projectExtractionReviewItems.isEmpty)
    }

    private func ledger(for script: String) -> EpisodeExtractionLedger {
        ScreenplayInventoryParser().makeLedger(
            episodeID: episodeID,
            sourceFingerprint: StableExtractionIdentity.sha256(script),
            script: script
        )
    }

    private static let twentyOneEpisodeGoldLabels: [ExtractionGoldLabel] = {
        let characters = [
            ("余思思", ["思思", "余姑娘", "思思妹子"]),
            ("余安安", ["安安"]), ("陆夫人", ["白姐姐", "陆家少奶奶"]),
            ("恒儿", ["小少爷", "孩子"]), ("赵母", []), ("赵青山", []),
            ("柳氏", []), ("赵家众人", []), ("流民", ["流民群体"]),
            ("逃荒妇人", ["妇人"]), ("老奶奶", []), ("老爷爷", []),
            ("老婆婆", []), ("庄稼汉", ["庄稼汉子"]), ("壮汉", []),
            ("官兵", ["守门官兵"]), ("路人", []), ("大嫂", []),
            ("掌柜", []), ("小二", []), ("丫鬟", []), ("护卫", []),
            ("劫匪", ["蒙面人", "土匪"]), ("员外", ["张员外"])
        ].map { name, aliases in
            ExtractionGoldLabel(kind: .character, canonicalName: name, aliases: Set(aliases))
        }
        let scenes = [
            "官道", "赵家-卧室", "现代马路", "意识空间", "赵家-灶房",
            "赵家-院子", "镇子大街", "员外府-正门", "员外府-后巷",
            "员外府-院子", "员外府-灶房", "员外府-后院", "员外府-书房",
            "员外府-书房密室", "树林-边缘", "树林-深处", "县城-城门外",
            "县城-街边", "客栈-柜台", "客栈-客房", "官道-路边",
            "马车-车厢", "迎客楼门前", "迎客楼客房", "客栈-走廊"
        ].map { ExtractionGoldLabel(kind: .scene, canonicalName: $0) }
        let props = [
            "粉色电动车", "竹编背篓", "布带", "超市购物袋", "木板床",
            "旧锁", "陶锅", "枯枝", "小木勺", "湿纸巾", "安睡裤",
            "矿泉水", "大米", "面粉", "红薯", "土豆", "鸡蛋", "方便面",
            "盐焗鸡", "感冒灵颗粒", "布洛芬", "纯棉睡衣", "地图",
            "匕首", "碎银", "铜板", "玉扣", "火折子", "竹筒", "钱袋",
            "退烧药", "小木盒", "菜刀", "铁锅", "蒸笼"
        ].map { ExtractionGoldLabel(kind: .prop, canonicalName: $0) }
        return characters + scenes + props
    }()
}
