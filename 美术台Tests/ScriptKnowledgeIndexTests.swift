import Foundation
import Testing
@testable import 美术台

struct ScriptKnowledgeIndexTests {
    @Test("知识索引按集和场景稳定检索，并遵守来源集数")
    func searchesAssetOverviewWithinSourceEpisodes() {
        let first = ScriptEpisode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            order: 1,
            title: "第一集",
            scriptText: "1-1 林宅客厅 夜 内\n林默把黄铜钥匙放在桌上。\n1-2 码头 日 外\n海风很大。"
        )
        let second = ScriptEpisode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            order: 2,
            title: "第二集",
            scriptText: "2-1 旧仓库 夜 内\n黄铜钥匙打开暗门，林默进入仓库。"
        )
        let asset = AssetItem(
            kind: .prop,
            name: "黄铜钥匙",
            summary: "打开暗门的关键物件",
            evidence: "林默把黄铜钥匙放在桌上",
            sourceEpisodeIDs: [second.id]
        )

        let contexts = ScriptKnowledgeIndex(episodes: [second, first]).contexts(for: asset)

        #expect(contexts.count == 1)
        #expect(contexts[0].id == "script-context-00000000-0000-0000-0000-000000000002-0")
        #expect(contexts[0].episodeOrder == 2)
        #expect(contexts[0].sceneIdentifier == "2-1")
        #expect(contexts[0].heading.contains("旧仓库"))
    }

    @Test("知识索引限额、每场一个片段并截断短场景")
    func boundsContextsAndNeverSendsFullShortScene() {
        let repeated = String(repeating: "黄铜钥匙在雨夜闪光。", count: 30)
        let episodes = (1...8).map { order in
            ScriptEpisode(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", order))!,
                order: order,
                title: "第\(order)集",
                scriptText: "\(order)-1 走廊 夜 内\n\(repeated)\n\(order)-2 厨房 日 内\n黄铜钥匙被藏进抽屉。"
            )
        }
        let asset = AssetItem(kind: .prop, name: "黄铜钥匙", summary: "雨夜关键道具")
        let contexts = ScriptKnowledgeIndex(episodes: episodes).contexts(for: asset)

        #expect(contexts.count == 6)
        #expect(Set(contexts.map(\.id)).count == contexts.count)
        #expect(contexts.allSatisfy { $0.excerpt.count <= 420 })
        #expect(contexts.reduce(0) { $0 + $1.excerpt.count } <= 2_000)
        #expect(contexts.allSatisfy { context in context.truncated })

        let short = ScriptEpisode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            order: 9,
            title: "短场",
            scriptText: "9-1 书房 夜 内\n黄铜钥匙在桌上。"
        )
        let shortContexts = ScriptKnowledgeIndex(episodes: [short]).contexts(for: asset)
        #expect(shortContexts.count == 1)
        #expect(shortContexts[0].truncated)
        #expect(!shortContexts[0].excerpt.contains("黄铜钥匙在桌上。"))
    }

    @Test("单行场次标题不会被当作完整剧本外发")
    func oneLineScreenplaysDoNotLeakThroughHeading() {
        let numericText = "1-1 夜/内 书房 黄铜钥匙被藏进抽屉并且房门立即锁上。"
        let intText = "INT. STUDY - NIGHT - 黄铜钥匙被藏进抽屉。"
        let episodes = [
            ScriptEpisode(order: 1, title: "单行一", scriptText: numericText),
            ScriptEpisode(order: 2, title: "单行二", scriptText: intText)
        ]
        let asset = AssetItem(kind: .prop, name: "黄铜钥匙", summary: "藏在抽屉")

        let contexts = ScriptKnowledgeIndex(episodes: episodes).contexts(for: asset)

        #expect(contexts.isEmpty)
    }

    @Test("无场次标题的长文本只返回一个未标场次片段")
    func headinglessEpisodeReturnsOneContext() {
        let script = String(repeating: "林默用黄铜钥匙打开暗门，然后继续搜索。", count: 220)
        let episode = ScriptEpisode(order: 3, title: "无标题", scriptText: script)
        let asset = AssetItem(kind: .prop, name: "黄铜钥匙", summary: "打开暗门")

        let contexts = ScriptKnowledgeIndex(episodes: [episode]).contexts(for: asset)

        #expect(contexts.count == 1)
        #expect(contexts[0].sceneIdentifier == "3-未标场次")
        #expect(contexts[0].excerpt.count <= 420)
        #expect(contexts[0].truncated)
        #expect(contexts[0].excerpt != script)
    }

    @Test("设计选项只能精排身份命中场次，不会单独召回无关场次")
    func optionTermsCannotRetrieveUnrelatedScenes() {
        let episode = ScriptEpisode(
            order: 1,
            title: "第 1 集",
            scriptText: "1-1 夜/外 码头\n雨夜里只有无人的货箱和海浪。"
        )
        let asset = AssetItem(
            kind: .prop,
            name: "黄铜钥匙",
            summary: "打开暗门的道具",
            sourceEpisodeIDs: [episode.id]
        )

        let contexts = ScriptKnowledgeIndex(episodes: [episode]).contexts(
            for: asset,
            optionTerms: ["雨夜", "写实"]
        )

        #expect(contexts.isEmpty)
    }
}
