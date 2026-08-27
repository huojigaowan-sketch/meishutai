import Foundation
import Testing
@testable import 美术台

struct DataIntegrityTests {
    @Test("JSON 资产导出可往返解码且 CSV 正确转义")
    func assetDataExportsAreMachineReadable() throws {
        let asset = AssetItem(
            kind: .prop,
            name: "盐焗鸡,\"整只\"",
            summary: "油纸包装\n可食用",
            evidence: "一整只盐焗鸡",
            basePrompt: "wrapped salted chicken"
        )
        let episode = ScriptEpisode(order: 1, title: "第1集", scriptText: "测试")
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let json = try AssetDataExporter.data(
            format: .json,
            projectTitle: "逃荒",
            assets: [asset],
            episodes: [episode],
            exportedAt: date
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(AssetExportManifest.self, from: json)
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.assets.first?.name == asset.name)
        #expect(manifest.episodes.first?.order == 1)

        let csv = try AssetDataExporter.data(
            format: .csv,
            projectTitle: "逃荒",
            assets: [asset],
            episodes: [episode]
        )
        let csvText = String(decoding: csv, as: UTF8.self)
        #expect(csvText.contains("\"盐焗鸡,\"\"整只\"\"\""))
        #expect(csvText.contains("\"油纸包装\n可食用\""))
        #expect(csvText.hasSuffix("\r\n"))
    }

    @Test("提示词编译保留干扰字符周围的有效英文")
    func promptCompilationDoesNotDropWholeContaminatedFragments() {
        let original = "aged brass，élégant 林默\u{0} coat\r\nwith “silver” trim—damaged🙂"
        let asset = AssetItem(
            kind: .prop,
            name: "黄铜钥匙",
            summary: "",
            basePrompt: original
        )

        let compiled = PromptCompiler.compile(asset)

        #expect(compiled.contains("aged brass,elegant coat with \"silver\" trim-damaged"))
        #expect(PromptCompiler.english(compiled))
        #expect(!compiled.unicodeScalars.contains(where: { $0.value == 0 }))
        #expect(PromptCompiler.hasRejectedNonEnglishText(asset))
        #expect(asset.basePrompt == original)
    }

    @Test("摘要合并保留互补事实、去除完全重复并保持幂等")
    func summaryConsolidationIsLosslessAndIdempotent() {
        let identity = "银色手提箱，箱角有明显撞痕。"
        let function = "用于运送机密胶片，第二幕被调包。"
        let continuity = "雨夜出场时沾有泥水。"

        let consolidated = AssetSummaryConsolidator.consolidate(
            identity,
            function,
            "\(continuity)\n\(identity)"
        )

        #expect(consolidated.components(separatedBy: .newlines) == [
            identity,
            function,
            continuity
        ])
        #expect(
            AssetSummaryConsolidator.consolidate(consolidated, consolidated)
                == consolidated
        )
    }

    @Test("合并身份只依赖规范实体，不受生成描述与连续性状态影响")
    func mergeIdentityIsConservative() {
        let scene = makeScene(
            name: "林宅·客厅",
            time: "night",
            weather: "rain",
            season: "冬季",
            period: "1990年代",
            locationType: "内景"
        )
        let differentWeather = makeScene(
            name: "林宅·客厅",
            time: "night",
            weather: "clear",
            season: "冬季",
            period: "1990年代",
            locationType: "内景"
        )
        let differentType = makeScene(
            name: "林宅·客厅",
            time: "night",
            weather: "rain",
            season: "冬季",
            period: "1990年代",
            locationType: "外景"
        )
        let dimensionVariants = [
            makeScene(
                name: "林宅·客厅",
                location: "林家别院",
                time: "night",
                weather: "rain",
                season: "冬季",
                period: "1990年代",
                locationType: "内景"
            ),
            makeScene(
                name: "林宅·客厅",
                time: "day",
                weather: "rain",
                season: "冬季",
                period: "1990年代",
                locationType: "内景"
            ),
            differentWeather,
            makeScene(
                name: "林宅·客厅",
                time: "night",
                weather: "rain",
                season: "夏季",
                period: "1990年代",
                locationType: "内景"
            ),
            makeScene(
                name: "林宅·客厅",
                time: "night",
                weather: "rain",
                season: "冬季",
                period: "现代",
                locationType: "内景"
            ),
            differentType
        ]

        for variant in dimensionVariants {
            #expect(AssetMergeIdentity.key(for: scene) == AssetMergeIdentity.key(for: variant))
        }

        let hyphenated = AssetItem(kind: .character, name: "守卫-甲", summary: "")
        let plain = AssetItem(kind: .character, name: "守卫甲", summary: "")
        let asciiPunctuation = AssetItem(kind: .character, name: "守卫!", summary: "")
        let fullwidthPunctuation = AssetItem(kind: .character, name: "守卫！", summary: "")
        let crowned = AssetItem(kind: .character, name: "王👑", summary: "")
        let armed = AssetItem(kind: .character, name: "王⚔️", summary: "")
        #expect(AssetMergeIdentity.key(for: hyphenated) == AssetMergeIdentity.key(for: plain))
        #expect(AssetMergeIdentity.key(for: asciiPunctuation) == AssetMergeIdentity.key(for: fullwidthPunctuation))
        #expect(AssetMergeIdentity.key(for: crowned) == AssetMergeIdentity.key(for: armed))

        let young = makeCharacter(name: "林默", age: "early thirties")
        let aged = makeCharacter(name: "林默", age: "late seventies")
        #expect(AssetMergeIdentity.key(for: young) == AssetMergeIdentity.key(for: aged))

        let intact = makeProp(name: "黄铜钥匙", state: "完好")
        let broken = makeProp(name: "黄铜钥匙", state: "折断")
        #expect(AssetMergeIdentity.key(for: intact) == AssetMergeIdentity.key(for: broken))

        var ownerA = intact
        var ownerB = broken
        ownerA.canonicalKey = CanonicalAssetIdentity.key(
            kind: .prop,
            canonicalName: "黄铜钥匙",
            identityQualifier: "林默所有"
        )
        ownerB.canonicalKey = CanonicalAssetIdentity.key(
            kind: .prop,
            canonicalName: "黄铜钥匙",
            identityQualifier: "苏晴所有"
        )
        #expect(AssetMergeIdentity.key(for: ownerA) != AssetMergeIdentity.key(for: ownerB))
    }

    @Test("XLSX 导出容忍重复 UUID 并保留所有资产行")
    func workbookExportToleratesDuplicateUUIDs() throws {
        let duplicateAssetID = UUID()
        let first = AssetItem(
            id: duplicateAssetID,
            kind: .prop,
            name: "重复编号道具甲",
            summary: "第一条必须保留"
        )
        let second = AssetItem(
            id: duplicateAssetID,
            kind: .prop,
            name: "重复编号道具乙",
            summary: "第二条也必须保留"
        )
        let duplicateEpisodeID = UUID()
        let episodes = [
            ScriptEpisode(id: duplicateEpisodeID, order: 1, title: "第 1 集"),
            ScriptEpisode(id: duplicateEpisodeID, order: 2, title: "第 2 集")
        ]

        let workbook = try AssetWorkbookExporter.makeWorkbook(
            projectTitle: "重复 UUID 回归",
            assets: [first, second],
            episodes: episodes
        )
        let archiveText = String(decoding: workbook, as: UTF8.self)

        #expect(!workbook.isEmpty)
        #expect(archiveText.contains("重复编号道具甲"))
        #expect(archiveText.contains("重复编号道具乙"))
    }

    @Test("表格1保留资产库排序，表格2按场景在剧本中的首次出现排序")
    func workbookTemplatesUseTheirExpectedSceneOrder() throws {
        let episode1ID = UUID()
        let episode2ID = UUID()
        let episode1 = ScriptEpisode(
            id: episode1ID,
            order: 1,
            title: "第 1 集",
            scriptText: """
            1-1 日/外 庭院
            人物穿过庭院，并讨论下一场前往码头。
            1-2 夜/外 码头
            人物抵达码头。
            """
        )
        let episode2 = ScriptEpisode(
            id: episode2ID,
            order: 2,
            title: "第 2 集",
            scriptText: """
            2-1 夜/外 塔楼
            人物登上塔楼。
            2-2 夜/内 仓库
            人物进入仓库。
            """
        )
        let assets = [
            makeExportScene(
                name: "仓库",
                location: "M地点",
                sourceEpisodeIDs: [episode2ID]
            ),
            makeExportScene(
                name: "塔楼",
                location: "N地点",
                sourceEpisodeIDs: [episode1ID, episode2ID]
            ),
            makeExportScene(
                name: "庭院",
                location: "Z地点",
                sourceEpisodeIDs: [episode1ID]
            ),
            makeExportScene(
                name: "手工场景",
                location: "B地点",
                sourceEpisodeIDs: nil
            ),
            makeExportScene(
                name: "码头",
                location: "A地点",
                sourceEpisodeIDs: [episode1ID]
            )
        ]
        let episodes = [episode2, episode1]

        let table1Names = AssetWorkbookExporter.orderedSceneAssets(
            assets,
            episodes: episodes,
            template: .table1
        ).map(\.name)
        let table2Names = AssetWorkbookExporter.orderedSceneAssets(
            assets,
            episodes: episodes,
            template: .table2
        ).map(\.name)

        #expect(table1Names == ["码头", "手工场景", "仓库", "塔楼", "庭院"])
        #expect(table2Names == ["庭院", "码头", "塔楼", "仓库", "手工场景"])

        let workbook = try AssetWorkbookExporter.makeWorkbook(
            projectTitle: "表格2顺序测试",
            assets: assets,
            episodes: episodes,
            template: .table2
        )
        let archiveText = String(decoding: workbook, as: UTF8.self)
        let courtyardIndex = try #require(archiveText.range(of: "庭院")?.lowerBound)
        let dockIndex = try #require(archiveText.range(of: "码头")?.lowerBound)
        let towerIndex = try #require(archiveText.range(of: "塔楼")?.lowerBound)
        let warehouseIndex = try #require(archiveText.range(of: "仓库")?.lowerBound)
        let manualIndex = try #require(archiveText.range(of: "手工场景")?.lowerBound)
        #expect(courtyardIndex < dockIndex)
        #expect(dockIndex < towerIndex)
        #expect(towerIndex < warehouseIndex)
        #expect(warehouseIndex < manualIndex)
    }

    @Test("表格2只按 AI 明确分组合并，本地同名候选不会自行合并")
    func table2OnlyMergesAIVerifiedRepeatedScenes() throws {
        let episode1ID = UUID()
        let episode2ID = UUID()
        let episodes = [
            ScriptEpisode(
                id: episode2ID,
                order: 2,
                title: "第 2 集",
                scriptText: "2-3 夜/内 林宅客厅\n林默再次回到客厅。"
            ),
            ScriptEpisode(
                id: episode1ID,
                order: 1,
                title: "第 1 集",
                scriptText: "1-2 日/内 林宅·客厅\n林默第一次进入客厅。"
            )
        ]
        let laterAppearance = makeExportScene(
            name: "林宅客厅",
            location: "林家宅院",
            sourceEpisodeIDs: [episode2ID]
        )
        let earliestAppearance = makeExportScene(
            name: "林宅·客厅",
            location: "林家宅院",
            sourceEpisodeIDs: [episode1ID]
        )
        let nightVariant = makeExportScene(
            name: "林宅客厅",
            location: "林家宅院",
            timeOfDayID: "night",
            sourceEpisodeIDs: [episode2ID]
        )
        let differentMainLocation = makeExportScene(
            name: "林宅客厅",
            location: "王家宅院",
            sourceEpisodeIDs: [episode2ID]
        )
        let hyphenatedRoom = makeExportScene(
            name: "A-1室",
            location: "林家宅院",
            sourceEpisodeIDs: [episode2ID]
        )
        let unhyphenatedRoom = makeExportScene(
            name: "A1室",
            location: "林家宅院",
            sourceEpisodeIDs: [episode2ID]
        )
        let assets = [
            laterAppearance,
            earliestAppearance,
            nightVariant,
            differentMainLocation,
            hyphenatedRoom,
            unhyphenatedRoom
        ]

        let table1 = AssetWorkbookExporter.orderedSceneAssets(
            assets,
            episodes: episodes,
            template: .table1
        )
        let unverifiedTable2 = AssetWorkbookExporter.orderedSceneAssets(
            assets,
            episodes: episodes,
            template: .table2
        )
        let candidateGroup = try #require(
            AssetWorkbookExporter.table2SceneCandidateGroups(
                assets,
                episodes: episodes
            ).first
        )
        let verifiedCandidateIDs = candidateGroup.candidates
            .filter { $0.locationGroup == "林家宅院" }
            .map(\.id)
        let table2 = AssetWorkbookExporter.orderedSceneAssets(
            assets,
            episodes: episodes,
            template: .table2,
            table2MergeGroups: [
                Table2SceneMergeGroup(candidateIDs: verifiedCandidateIDs)
            ]
        )

        #expect(table1.count == 6)
        #expect(unverifiedTable2.count == 6)
        #expect(candidateGroup.candidates.count == 4)
        #expect(verifiedCandidateIDs.count == 3)
        #expect(table2.count == 4)
        #expect(table2.first?.name == "林宅·客厅")
        #expect(table2.first?.sourceEpisodeIDs == [episode1ID, episode2ID])
        #expect(table2.first?.sceneProfile?.timeOfDayID == "day")
        #expect(
            table2.first.map {
                AssetWorkbookExporter.sceneReferenceList(
                    for: $0,
                    episodes: episodes
                )
            } == "1-2、2-3"
        )
        #expect(
            table2.contains {
                $0.sceneProfile?.locationGroup == "王家宅院"
            }
        )
    }

    @Test("同中文名候选只携带命中场景的限量片段，不包含同集其他场景")
    func table2CandidatePayloadIsLocallyScopedAndBounded() throws {
        let episodeID = UUID()
        let unrelatedMarker = "绝不能发送的仓库机密标记"
        let longBody = String(repeating: "客厅内人物核对陈设。", count: 120)
        let episode = ScriptEpisode(
            id: episodeID,
            order: 1,
            title: "第 1 集",
            scriptText: """
            1-1 日/内 林宅客厅
            \(longBody)
            1-2 夜/内 仓库
            \(unrelatedMarker)
            """
        )
        let assets = [
            makeExportScene(
                name: "林宅·客厅",
                location: "林家宅院",
                sourceEpisodeIDs: [episodeID]
            ),
            makeExportScene(
                name: "林宅客厅",
                location: "另一份候选记录",
                sourceEpisodeIDs: [episodeID]
            ),
            makeExportScene(
                name: "英文 Studio",
                location: "不参与中文同名候选",
                sourceEpisodeIDs: [episodeID]
            )
        ]

        let groups = AssetWorkbookExporter.table2SceneCandidateGroups(
            assets,
            episodes: [episode]
        )
        let group = try #require(groups.first)
        let occurrences = group.candidates.flatMap(\.occurrences)
        let transmittedScriptText = occurrences
            .map { "\($0.heading)\n\($0.excerpt)" }
            .joined(separator: "\n")

        #expect(groups.count == 1)
        #expect(group.candidates.count == 2)
        #expect(!occurrences.isEmpty)
        #expect(!transmittedScriptText.contains(unrelatedMarker))
        #expect(occurrences.count <= AssetWorkbookExporter.maximumSceneInvestigationOccurrencesPerGroup)
        #expect(
            occurrences.allSatisfy {
                $0.heading.count + $0.excerpt.count
                    <= AssetWorkbookExporter.maximumSceneInvestigationCharactersPerOccurrence
            }
        )
        #expect(
            occurrences.reduce(0) { $0 + $1.heading.count + $1.excerpt.count }
                <= AssetWorkbookExporter.maximumSceneInvestigationCharactersPerGroup
        )
        #expect(occurrences.contains { $0.truncated })
    }

    @Test("单场短剧本也只发送片段，不能被候选请求完整还原")
    func singleSceneEpisodeIsStillPrivacyTruncated() throws {
        let episodeID = UUID()
        let fullBody = "人物确认这是林宅原来的客厅并锁门离开。"
        let episode = ScriptEpisode(
            id: episodeID,
            order: 1,
            title: "第 1 集",
            scriptText: "1-1 日/内 林宅客厅\n\(fullBody)"
        )
        let assets = [
            makeExportScene(
                name: "林宅客厅",
                location: "林家宅院",
                sourceEpisodeIDs: [episodeID]
            ),
            makeExportScene(
                name: "林宅·客厅",
                location: "待核验记录",
                sourceEpisodeIDs: [episodeID]
            )
        ]

        let group = try #require(
            AssetWorkbookExporter.table2SceneCandidateGroups(
                assets,
                episodes: [episode]
            ).first
        )
        let occurrences = group.candidates.flatMap(\.occurrences)

        #expect(!occurrences.isEmpty)
        #expect(occurrences.allSatisfy { $0.truncated })
        #expect(occurrences.allSatisfy { $0.excerpt != fullBody })
        #expect(occurrences.allSatisfy { !$0.excerpt.hasSuffix("锁门离开。") })
    }

    @Test("XML 1.0 过滤只作用于导出副本")
    func xmlSanitizationRemovesOnlyIllegalScalars() {
        let original = "开头\u{1}\u{8}\t保留制表\n保留换行\r保留回车\u{B}\u{1F}结尾😀"
        let sanitized = AssetWorkbookExporter.sanitizedXML10Text(original)

        #expect(sanitized == "开头\t保留制表\n保留换行\r保留回车结尾😀")
        #expect(original.unicodeScalars.contains(where: { $0.value == 0x1 }))
    }

    @MainActor
    @Test("资产库按规范实体合并跨集同一场景并保留来源")
    func globalLibraryMergesCanonicalScenesAcrossEpisodes() throws {
        let repository = try WorkspaceRepository(isStoredInMemoryOnly: true)
        let store = WorkspaceStore(
            repository: repository,
            legacySnapshotURL: URL(fileURLWithPath: "/tmp/assetdesk-no-scene-merge-legacy")
        )
        let episode1ID = UUID()
        let episode2ID = UUID()
        let disposableEpisodeID = UUID()
        let firstScene = makeExportScene(
            name: "林宅客厅",
            location: "林家宅院",
            sourceEpisodeIDs: nil
        )
        let secondScene = makeExportScene(
            name: "林宅客厅",
            location: "林家宅院",
            sourceEpisodeIDs: nil
        )
        let manualScene = makeExportScene(
            name: "林宅客厅",
            location: "林家宅院",
            sourceEpisodeIDs: nil
        )
        var historicalLocallyMergedScene = firstScene
        historicalLocallyMergedScene.summary = "旧版本合并行上的人工备注"
        historicalLocallyMergedScene.sourceEpisodeIDs = [episode1ID, episode2ID]
        store.episodes = [
            ScriptEpisode(
                id: episode1ID,
                order: 1,
                title: "第 1 集",
                extractedAssets: [firstScene]
            ),
            ScriptEpisode(
                id: episode2ID,
                order: 2,
                title: "第 2 集",
                extractedAssets: [secondScene]
            ),
            ScriptEpisode(
                id: disposableEpisodeID,
                order: 3,
                title: "待删除空集"
            )
        ]
        store.assets = [historicalLocallyMergedScene, manualScene]
        store.selectedEpisodeID = disposableEpisodeID

        store.deleteCurrentEpisode()

        #expect(store.assets.count == 1)
        #expect(store.assets.first?.sourceEpisodeIDs == [episode1ID, episode2ID])
        #expect(store.assets.first?.summary == "旧版本合并行上的人工备注")
    }

    @MainActor
    @Test("同一规范场景的重复 UUID 会合并，删除时同步移除所有来源")
    func duplicateCanonicalScenesMergeBeforeDeletion() throws {
        let repository = try WorkspaceRepository(isStoredInMemoryOnly: true)
        let store = WorkspaceStore(
            repository: repository,
            legacySnapshotURL: URL(fileURLWithPath: "/tmp/assetdesk-no-duplicate-scene-legacy")
        )
        let duplicateID = UUID()
        let episode1ID = UUID()
        let episode2ID = UUID()
        let disposableEpisodeID = UUID()
        var firstScene = makeExportScene(
            name: "林宅客厅",
            location: "林家宅院",
            sourceEpisodeIDs: nil
        )
        var secondScene = makeExportScene(
            name: "林宅客厅",
            location: "林家宅院",
            sourceEpisodeIDs: nil
        )
        firstScene.id = duplicateID
        secondScene.id = duplicateID
        store.episodes = [
            ScriptEpisode(
                id: episode1ID,
                order: 1,
                title: "第 1 集",
                extractedAssets: [firstScene]
            ),
            ScriptEpisode(
                id: episode2ID,
                order: 2,
                title: "第 2 集",
                extractedAssets: [secondScene]
            ),
            ScriptEpisode(
                id: disposableEpisodeID,
                order: 3,
                title: "待删除空集"
            )
        ]
        store.assets = []
        store.selectedEpisodeID = disposableEpisodeID

        store.deleteCurrentEpisode()

        #expect(store.assets.count == 1)
        #expect(store.assets.first?.sourceEpisodeIDs == [episode1ID, episode2ID])
        let canonicalSceneID = try #require(store.assets.first?.id)
        store.deleteAsset(id: canonicalSceneID)

        #expect(store.assets.isEmpty)
        #expect(
            store.episodes.first(where: { $0.id == episode1ID })?
                .extractedAssets.isEmpty == true
        )
        #expect(
            store.episodes.first(where: { $0.id == episode2ID })?
                .extractedAssets.isEmpty == true
        )
    }

    @MainActor
    @Test("手工场景的重复或冲突 UUID 也会修复为可精准删除的独立行")
    func duplicateManualSceneIDsAreRepairedBeforeDeletion() throws {
        let repository = try WorkspaceRepository(isStoredInMemoryOnly: true)
        let store = WorkspaceStore(
            repository: repository,
            legacySnapshotURL: URL(fileURLWithPath: "/tmp/assetdesk-no-manual-duplicate-legacy")
        )
        let duplicateID = UUID()
        var firstManual = makeExportScene(
            name: "手工客厅甲",
            location: "手工场景",
            sourceEpisodeIDs: nil
        )
        var secondManual = makeExportScene(
            name: "手工客厅乙",
            location: "手工场景",
            sourceEpisodeIDs: nil
        )
        firstManual.id = duplicateID
        secondManual.id = duplicateID
        let retainedEpisode = ScriptEpisode(order: 1, title: "保留空集")
        let disposableEpisode = ScriptEpisode(order: 2, title: "待删除空集")
        store.episodes = [retainedEpisode, disposableEpisode]
        store.assets = [firstManual, secondManual]
        store.selectedEpisodeID = disposableEpisode.id

        store.deleteCurrentEpisode()

        #expect(store.assets.count == 2)
        #expect(Set(store.assets.map(\.id)).count == 2)
        let firstID = try #require(
            store.assets.first(where: { $0.name == "手工客厅甲" })?.id
        )
        store.deleteAsset(id: firstID)

        #expect(store.assets.count == 1)
        #expect(store.assets.first?.name == "手工客厅乙")
    }

    @MainActor
    @Test("警告状态与分段 checkpoint 经过 Repository 和 Store 加载后保持不变")
    func warningAndCheckpointRoundTrip() throws {
        let repository = try WorkspaceRepository(isStoredInMemoryOnly: true)
        let project = try repository.createProject(title: "完整性测试")
        let episodeID = UUID()
        let script = "1-1 日/外 场景\n原始剧本文字"
        let ledger = ScreenplayInventoryParser().makeLedger(
            episodeID: episodeID,
            sourceFingerprint: StableExtractionIdentity.sha256(script),
            script: script
        )
        let checkpoint = DeepSeekSegmentCheckpoint(
            sourceFingerprint: "source-fingerprint",
            segmentID: "segment-001",
            segmentIndex: 0,
            segmentTotal: 2,
            coveredSourceUnitIDs: ["scene-1"],
            assets: ExtractedAssets(scenes: [], characters: [], props: []),
            responseMetadata: [],
            completedAt: Date(timeIntervalSince1970: 1_000)
        )
        let episode = ScriptEpisode(
            id: episodeID,
            order: 1,
            title: "第 1 集",
            scriptText: script,
            extractionStatus: .completedWithWarnings,
            extractionWarnings: ["片段 2 返回了可恢复警告"],
            extractionCheckpoints: [checkpoint],
            extractionLedger: ledger
        )
        try repository.saveAll(
            projectID: project.id,
            episodes: [episode],
            assets: [],
            selectedEpisodeID: episode.id,
            seriesDesignBlueprint: nil
        )

        let loaded = try repository.load(projectID: project.id)
        #expect(loaded.episodes.first?.extractionStatus == .completedWithWarnings)
        #expect(loaded.episodes.first?.extractionWarnings == episode.extractionWarnings)
        #expect(loaded.episodes.first?.extractionCheckpoints.first?.segmentID == "segment-001")
        let loadedLedger = try #require(loaded.episodes.first?.extractionLedger)
        #expect(loadedLedger.schemaVersion == ledger.schemaVersion)
        #expect(loadedLedger.episodeID == ledger.episodeID)
        #expect(loadedLedger.sourceFingerprint == ledger.sourceFingerprint)
        #expect(loadedLedger.scenes == ledger.scenes)
        #expect(loadedLedger.candidates == ledger.candidates)
        #expect(loadedLedger.decisions == ledger.decisions)
        #expect(abs(loadedLedger.generatedAt.timeIntervalSince(ledger.generatedAt)) < 1)
        #expect(loaded.episodes.first?.scriptText == episode.scriptText)

        let store = WorkspaceStore(
            repository: repository,
            legacySnapshotURL: URL(fileURLWithPath: "/tmp/assetdesk-no-legacy-snapshot")
        )
        #expect(store.episodes.first?.extractionStatus == .completedWithWarnings)
        #expect(store.episodes.first?.effectiveStatus == .completedWithWarnings)
        #expect(store.episodes.first?.extractionWarnings == episode.extractionWarnings)
        #expect(store.episodes.first?.extractionCheckpoints.first?.segmentID == "segment-001")
        let storedLedger = try #require(store.episodes.first?.extractionLedger)
        #expect(storedLedger.scenes == ledger.scenes)
        #expect(storedLedger.candidates == ledger.candidates)
        #expect(storedLedger.decisions == ledger.decisions)
        #expect(store.episodes.first?.scriptText == episode.scriptText)
    }

    @Test("项目提取概览只采用指纹新鲜的已完成分集，并按集数排序")
    func projectExtractionOverviewIncludesOnlyFreshCompletedEpisodesInOrder() throws {
        let earlierExtractedAt = Date(timeIntervalSince1970: 1_000)
        let laterExtractedAt = Date(timeIntervalSince1970: 2_000)
        let freshLaterScript = "2-1 日/内 后到的场景\n人物进入房间。"
        var freshLater = ScriptEpisode(
            order: 2,
            title: "第 2 集",
            scriptText: freshLaterScript,
            extractionStatus: .completed,
            extractedAssets: [
                AssetItem(kind: .scene, name: "后到的场景", summary: "第 2 集场景")
            ],
            extractedAt: laterExtractedAt
        )
        freshLater.lastExtractedFingerprint = freshLater.contentFingerprint

        let freshEarlierScript = "1-1 夜/外 先到的场景\n人物抵达街口。"
        var freshEarlier = ScriptEpisode(
            order: 1,
            title: "第 1 集",
            scriptText: freshEarlierScript,
            extractionStatus: .completed,
            extractedAssets: [
                AssetItem(kind: .character, name: "林默", summary: "主角")
            ],
            extractedAt: earlierExtractedAt
        )
        freshEarlier.lastExtractedFingerprint = freshEarlier.contentFingerprint

        var stale = ScriptEpisode(
            order: 3,
            title: "第 3 集",
            scriptText: "已经改过的剧本",
            extractionStatus: .completed,
            extractedAssets: [AssetItem(kind: .prop, name: "旧道具", summary: "不应出现")]
        )
        stale.lastExtractedFingerprint = "old-fingerprint"

        let unfinished = ScriptEpisode(
            order: 4,
            title: "第 4 集",
            scriptText: "尚未提取",
            extractionStatus: .extracting,
            extractedAssets: [AssetItem(kind: .scene, name: "未完成场景", summary: "不应出现")]
        )

        let overview = try #require(
            ProjectExtractionOverview.make(
                from: [freshLater, stale, unfinished, freshEarlier]
            )
        )

        #expect(overview.episodes.map(\.order) == [1, 2])
        #expect(overview.episodes.map(\.title) == ["第 1 集", "第 2 集"])
        #expect(overview.episodes.map(\.generatedAt) == [earlierExtractedAt, laterExtractedAt])
        #expect(overview.sceneCount == 1)
        #expect(overview.characterCount == 1)
        #expect(overview.propCount == 0)
    }

    @MainActor
    @Test("设计草稿在资产 JSON 往返中保留，旧版 JSON 可缺省该字段")
    func assetDesignDraftCodableRoundTripAndLegacyDecoding() throws {
        let createdAt = Date(timeIntervalSince1970: 3_000)
        let appliedAt = Date(timeIntervalSince1970: 3_100)
        let draft = AssetDesignDraft(
            inputFingerprint: "design-input-v1",
            createdAt: createdAt,
            appliedAt: appliedAt,
            designSummary: "以雨夜的湿润反光强调空间层次。",
            evidenceDigest: "第 1 集 1-2：雨水沿窗框流下。",
            assumptions: ["未明确的陈设按九十年代城市住宅处理"],
            usedContextIDs: ["episode-1:scene-2"],
            basePrompt: "rainy apartment interior",
            searchKeywords: "1990s apartment rain window"
        )
        let asset = AssetItem(
            kind: .scene,
            name: "林宅客厅",
            summary: "雨夜会面",
            designDraft: draft
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let encoded = try encoder.encode(asset)
        let decoded = try decoder.decode(AssetItem.self, from: encoded)

        #expect(decoded.designDraft == draft)

        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "designDraft")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyDecoded = try decoder.decode(AssetItem.self, from: legacyData)

        #expect(legacyDecoded.designDraft == nil)
        #expect(legacyDecoded.id == asset.id)
        #expect(legacyDecoded.name == asset.name)
    }

    @Test("设计选项快照覆盖可见控件，并与提示词编译使用同一选项解析")
    func designOptionSnapshotsCoverVisibleControlsAndCharacterDesign() {
        for kind in AssetKind.allCases {
            var selections: [String: String] = [:]
            for parameter in PromptParameter.allCases where parameter.supports(kind) {
                if let selected = parameter.options(for: kind).first(where: {
                    $0.id != PromptParameter.noneOptionID
                }) {
                    selections[parameter.rawValue] = selected.id
                }
            }
            let asset = AssetItem(
                kind: kind,
                name: "\(kind.title)测试",
                summary: "",
                basePrompt: "base design",
                parameterSelections: selections
            )
            let snapshots = PromptCompiler.designOptionSnapshots(for: asset)
            let visibleParameters = PromptParameter.allCases.filter {
                $0.supports(kind) && $0.isVisibleInControls
            }

            #expect(
                Set(snapshots.filter {
                    $0.key.hasPrefix("prompt.")
                }.map(\.key)) == Set(visibleParameters.map {
                    "prompt.\($0.rawValue)"
                })
            )

            let compiled = PromptCompiler.compile(asset)
            for parameter in visibleParameters {
                let snapshot = snapshots.first(where: {
                    $0.key == "prompt.\(parameter.rawValue)"
                })
                let expected = PromptCompiler.resolvedOption(
                    for: parameter,
                    kind: kind,
                    selections: selections
                )
                #expect(snapshot?.selectedValue == expected?.title)
                #expect(snapshot?.promptToken == expected?.promptToken)
                if let token = expected?.promptToken, !token.isEmpty {
                    #expect(compiled.contains(token))
                }
            }
        }

        let wardrobe = WardrobeLook(
            title: "雨夜大衣",
            visualPrompt: "dark wool overcoat"
        )
        var character = CharacterProfile.empty
        character.wardrobe = [wardrobe]
        character.designOptionSelections = Dictionary(
            uniqueKeysWithValues: CharacterDesignParameter.allCases.compactMap { parameter in
                parameter.options.first(where: { $0.id != CharacterDesignOption.none.id })
                    .map { (parameter.rawValue, $0.id) }
            }
        )
        let characterAsset = AssetItem(
            kind: .character,
            name: "林默",
            summary: "",
            basePrompt: "lead character",
            characterProfile: character,
            activeWardrobeID: wardrobe.id
        )
        let characterSnapshots = PromptCompiler.designOptionSnapshots(for: characterAsset)
        let characterCompiled = PromptCompiler.compile(characterAsset)

        for parameter in CharacterDesignParameter.allCases {
            let expected = parameter.resolvedOption(in: character.designOptionSelections)
            let snapshot = characterSnapshots.first(where: {
                $0.key == "character.\(parameter.rawValue)"
            })
            #expect(snapshot?.selectedValue == expected.title)
            #expect(snapshot?.promptToken == expected.promptToken)
            if !expected.promptToken.isEmpty {
                #expect(characterCompiled.contains(expected.promptToken))
            }
        }
        let wardrobeSnapshot = characterSnapshots.first(where: {
            $0.key == "character.activeWardrobe"
        })
        #expect(wardrobeSnapshot?.selectedValue == wardrobe.title)
        #expect(wardrobeSnapshot?.promptToken == wardrobe.visualPrompt)
        #expect(characterCompiled.contains(wardrobe.visualPrompt))

        let profilelessCharacter = AssetItem(
            kind: .character,
            name: "待补全人物",
            summary: ""
        )
        let profilelessSnapshots = PromptCompiler.designOptionSnapshots(
            for: profilelessCharacter
        )
        #expect(
            CharacterDesignParameter.allCases.allSatisfy { parameter in
                profilelessSnapshots.contains {
                    $0.key == "character.\(parameter.rawValue)"
                        && $0.selectedValue == CharacterDesignOption.none.title
                }
            }
        )
        #expect(
            profilelessSnapshots.contains {
                $0.key == "character.activeWardrobe"
                    && $0.selectedValue == "不指定服装"
            }
        )
    }

    @MainActor
    @Test("设计选项变化后旧草案不能覆盖新选择，重新生成后才能采用")
    func staleDesignDraftCannotOverwriteNewSelections() throws {
        let repository = try WorkspaceRepository(isStoredInMemoryOnly: true)
        let store = WorkspaceStore(
            repository: repository,
            legacySnapshotURL: URL(
                fileURLWithPath: "/tmp/assetdesk-design-draft-stale-legacy"
            )
        )
        let episodeID = UUID()
        let assetID = UUID()
        store.episodes = [
            ScriptEpisode(
                id: episodeID,
                order: 1,
                title: "第 1 集",
                scriptText: "1-1 夜/内 林宅客厅\n雨水沿窗框流下，桌上只亮着一盏旧台灯。"
            )
        ]
        store.assets = [
            AssetItem(
                id: assetID,
                kind: .scene,
                name: "林宅客厅",
                summary: "雨夜会面的客厅",
                basePrompt: "existing prompt",
                searchKeywords: "existing keywords",
                sourceEpisodeIDs: [episodeID]
            )
        ]

        let originalFingerprint = try #require(
            store.designInputFingerprint(for: assetID)
        )
        store.assets[0].designDraft = AssetDesignDraft(
            inputFingerprint: originalFingerprint,
            createdAt: .now,
            designSummary: "过期草案",
            evidenceDigest: "旧证据",
            assumptions: [],
            usedContextIDs: [],
            basePrompt: "stale generated prompt",
            searchKeywords: "stale generated keywords"
        )
        let parameter = PromptParameter.visualStyle
        let changedOption = try #require(
            parameter.options(for: .scene).first(where: {
                $0.id != parameter.defaultOptionID(for: .scene)
            })
        )
        store.assets[0].parameterSelections[parameter.rawValue] = changedOption.id

        store.applyDesignDraft(for: assetID)

        #expect(store.assets[0].basePrompt == "existing prompt")
        #expect(store.assets[0].searchKeywords == "existing keywords")
        #expect(store.assets[0].designDraft?.appliedAt == nil)
        #expect(store.errorMessage?.contains("设计选项已经变化") == true)

        let refreshedFingerprint = try #require(
            store.designInputFingerprint(for: assetID)
        )
        store.assets[0].designDraft = AssetDesignDraft(
            inputFingerprint: refreshedFingerprint,
            createdAt: .now,
            designSummary: "新草案",
            evidenceDigest: "新证据",
            assumptions: [],
            usedContextIDs: [],
            basePrompt: "fresh generated prompt",
            searchKeywords: "fresh generated keywords"
        )

        store.applyDesignDraft(for: assetID)

        #expect(store.assets[0].basePrompt == "fresh generated prompt")
        #expect(store.assets[0].searchKeywords == "fresh generated keywords")
        #expect(store.assets[0].designDraft?.appliedAt != nil)
    }

    @MainActor
    @Test("第一阶段必须先生成分集确认，确认期间剧本变化会拒绝启动")
    func stageOneConfirmationIsFingerprintBound() async throws {
        let repository = try WorkspaceRepository(isStoredInMemoryOnly: true)
        let store = WorkspaceStore(
            repository: repository,
            legacySnapshotURL: URL(
                fileURLWithPath: "/tmp/assetdesk-stage-one-confirmation-legacy"
            )
        )
        store.episodes = [
            ScriptEpisode(
                order: 1,
                title: "第 1 集",
                scriptText: "1-1 夜/内 林宅客厅\n林默把黄铜钥匙放在桌上。"
            )
        ]
        store.selectedEpisodeID = store.episodes[0].id

        let review = try #require(store.prepareCurrentEpisodeAnalysis())

        #expect(review.canAnalyze)
        #expect(!store.isAnalyzing)
        #expect(store.episodes[0].extractionStatus == .notExtracted)

        store.episodes[0].scriptText += "\n确认后新增的剧本内容。"
        await store.analyzeConfirmedEpisodes(review)

        #expect(!store.isAnalyzing)
        #expect(store.episodes[0].extractionStatus == .notExtracted)
        #expect(store.errorMessage?.contains("确认期间剧本内容已经变化") == true)
    }

    @MainActor
    @Test("第二阶段确认绑定当前资产和选项，变化后不启动设计")
    func stageTwoConfirmationIsFingerprintBound() async throws {
        let repository = try WorkspaceRepository(isStoredInMemoryOnly: true)
        let store = WorkspaceStore(
            repository: repository,
            legacySnapshotURL: URL(
                fileURLWithPath: "/tmp/assetdesk-stage-two-confirmation-legacy"
            )
        )
        let episodeID = UUID()
        let assetID = UUID()
        store.episodes = [
            ScriptEpisode(
                id: episodeID,
                order: 1,
                title: "第 1 集",
                scriptText: "1-1 夜/内 林宅客厅\n雨水沿窗框流下。"
            )
        ]
        store.assets = [
            AssetItem(
                id: assetID,
                kind: .scene,
                name: "林宅客厅",
                summary: "雨夜会面的客厅",
                basePrompt: "existing scene prompt",
                sourceEpisodeIDs: [episodeID]
            )
        ]

        let review = try #require(store.prepareDesignStart(for: assetID))
        #expect(review.assetID == assetID)
        #expect(review.assetName == "林宅客厅")
        #expect(review.designOptionCount > 0)

        let parameter = PromptParameter.visualStyle
        let changedOption = try #require(
            parameter.options(for: .scene).first(where: {
                $0.id != parameter.defaultOptionID(for: .scene)
            })
        )
        store.assets[0].parameterSelections[parameter.rawValue] = changedOption.id

        await store.generateConfirmedDesignDraft(review)

        #expect(store.designingAssetID == nil)
        #expect(store.assets[0].designDraft == nil)
        #expect(store.assets[0].basePrompt == "existing scene prompt")
        #expect(store.errorMessage?.contains("请重新确认当前资产") == true)
    }

    @MainActor
    @Test("提取与设计互斥，DS 一次只能执行一个阶段")
    func extractionAndDesignAreMutuallyExclusive() throws {
        let repository = try WorkspaceRepository(isStoredInMemoryOnly: true)
        let store = WorkspaceStore(
            repository: repository,
            legacySnapshotURL: URL(
                fileURLWithPath: "/tmp/assetdesk-ai-stage-exclusion-legacy"
            )
        )
        let asset = AssetItem(
            kind: .prop,
            name: "黄铜钥匙",
            summary: "开启暗门"
        )
        store.assets = [asset]
        store.episodes = [
            ScriptEpisode(
                order: 1,
                title: "第 1 集",
                scriptText: "1-1 夜/内 书房\n黄铜钥匙在桌上。"
            )
        ]
        store.selectedEpisodeID = store.episodes[0].id

        store.designingAssetID = asset.id
        #expect(store.isAIJobRunning)
        #expect(store.prepareCurrentEpisodeAnalysis() == nil)
        #expect(store.analysisNotice?.contains("资产设计完成后") == true)

        store.designingAssetID = nil
        store.isAnalyzing = true
        #expect(store.isAIJobRunning)
        #expect(store.prepareDesignStart(for: asset.id) == nil)
        #expect(store.designNotice?.contains("第一阶段提取完成") == true)
    }

    private func makeScene(
        name: String,
        location: String = "林家宅院",
        time: String,
        weather: String,
        season: String,
        period: String,
        locationType: String
    ) -> AssetItem {
        AssetItem(
            kind: .scene,
            name: name,
            summary: "",
            sceneProfile: SceneProfile(
                locationGroup: location,
                timeOfDayID: time,
                weatherID: weather,
                season: season,
                period: period,
                locationType: locationType,
                productionNotes: ""
            )
        )
    }

    private func makeCharacter(name: String, age: String) -> AssetItem {
        var profile = CharacterProfile.empty
        profile.ageRange = age
        return AssetItem(
            kind: .character,
            name: name,
            summary: "",
            characterProfile: profile
        )
    }

    private func makeProp(name: String, state: String) -> AssetItem {
        AssetItem(
            kind: .prop,
            name: name,
            summary: "",
            propProfile: PropProfile(
                category: "钥匙",
                storyFunction: "",
                materialPrompt: "aged brass",
                constructionPrompt: "cast metal",
                stateChanges: state
            )
        )
    }

    private func makeExportScene(
        name: String,
        location: String,
        timeOfDayID: String = "day",
        sourceEpisodeIDs: [UUID]?
    ) -> AssetItem {
        AssetItem(
            kind: .scene,
            name: name,
            summary: "",
            sceneProfile: SceneProfile(
                locationGroup: location,
                timeOfDayID: timeOfDayID,
                weatherID: "script",
                season: "script",
                period: "script",
                locationType: "外景",
                productionNotes: ""
            ),
            sourceEpisodeIDs: sourceEpisodeIDs
        )
    }
}
