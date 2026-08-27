import Foundation
import Testing
@testable import 美术台

struct EpisodeScriptSplitterTests {
    @Test("Markdown 包裹和污染的集标题都能正确分集")
    func markdownAndContaminatedHeaders() {
        let script = """
        **第13集 17-**
        13-1 日/外 官道 人物：余思思
        第十三集正文

        **第14集**
        14-1 夜/内 客栈 人物：安安
        第十四集正文

        **第16集20-**
        16-1 日/外 城门 人物：流民
        第十六集正文
        """

        let episodes = EpisodeScriptSplitter.split(script)

        #expect(episodes.count == 3)
        #expect(episodes.compactMap(\.episodeNumber) == ["13", "14", "16"])
        #expect(episodes.map(\.title) == ["第 13 集", "第 14 集", "第 16 集"])
    }

    @Test("场号优先于损坏的集标题")
    func sceneNumbersRecoverBoundariesWhenHeadersAreUnreadable() {
        let script = """
        【第一部分标题已损坏】
        11-3 日/外 官道-路边土坡 人物：余思思 安安
        第一段正文

        OCR 污染标题：未知
        12-1 日/外 官道 人物：余思思 流民
        第二段正文
        """

        let episodes = EpisodeScriptSplitter.split(script)

        #expect(episodes.count == 2)
        #expect(episodes.compactMap(\.episodeNumber) == ["11", "12"])
        #expect(episodes[0].scriptText.contains("第一段正文"))
        #expect(episodes[1].scriptText.contains("第二段正文"))
    }

    @Test("目录中的重复集标题不会制造额外分集")
    func tableOfContentsDoesNotCreateDuplicateEpisodes() {
        let script = """
        目录
        **第1集**
        **第2集**

        **第1集**
        1-1 日/外 村口 人物：甲
        正文一

        **第2集**
        2-1 夜/内 祠堂 人物：乙
        正文二
        """

        let result = EpisodeScriptSplitter.splitWithDiagnostics(script)
        let episodes = result.episodes

        #expect(episodes.count == 2)
        #expect(episodes.compactMap(\.episodeNumber) == ["1", "2"])
        #expect(episodes[0].scriptText.contains("目录"))
        #expect(result.diagnostics.isEmpty)
    }

    @Test("72 集 Markdown 剧本不会再次合并成 38 个任务")
    func seventyTwoEpisodeRegression() {
        let script = (1...72).map { number in
            """
            **第\(number)集**
            \(number)-1 日/外 场景\(number) 人物：角色\(number)
            CONTENT_TOKEN_\(number)_END
            """
        }
        .joined(separator: "\n\n")

        let episodes = EpisodeScriptSplitter.split(script)
        let numbers = episodes.compactMap(\.episodeNumber)
        let recoveredText = episodes.map(\.scriptText).joined()

        #expect(episodes.count == 72)
        #expect(numbers == (1...72).map(String.init))
        #expect(Array(recoveredText.utf8) == Array(script.utf8))
        for number in 1...72 {
            let sentinel = "CONTENT_TOKEN_\(number)_END"
            #expect(recoveredText.components(separatedBy: sentinel).count == 2)
        }
    }

    @Test("分集只切原文范围并逐字节守恒")
    func splitPreservesOriginalRangesExactly() {
        let script = " \t序章\u{200B}\r\n第十二章 **第1集**\r\n1-1 日/外 河岸 😀\r\n正文\u{0000}控制符\r\n\r\n第十三章 **第2集**\r\n2-1 夜/内 屋内 👩🏽‍🎨\r\n尾部空白 \t\r\n"

        let episodes = EpisodeScriptSplitter.split(script)
        let recovered = episodes.map(\.scriptText).joined()
        let headings = EpisodeScriptSplitter.sceneHeadings(in: script)

        #expect(episodes.count == 2)
        #expect(Array(recovered.utf8) == Array(script.utf8))
        #expect(EpisodeScriptSplitter.sanitizeNovelChapterMarkers(in: script) == script)
        #expect(episodes[0].scriptText.contains("第十二章"))
        #expect(episodes[1].scriptText.contains("第十三章"))
        #expect(headings.map(\.sceneIdentifier) == ["1-1", "2-1"])
        #expect(headings.map(\.lineNumber) == [3, 7])
    }

    @Test("空字符串和纯空白也返回一个无损分片")
    func blankInputIsNeverSilentlyDiscarded() {
        let inputs = ["", " \t\r\n\u{200B}\r\n"]

        for input in inputs {
            let episodes = EpisodeScriptSplitter.split(input)

            #expect(episodes.count == 1)
            #expect(Array(episodes[0].scriptText.utf8) == Array(input.utf8))
        }
    }

    @Test("只有重复集标题时保守不拆且不生成重复分集")
    func duplicateHeadersWithoutSceneEvidenceStayUnsplit() {
        let script = """
        第1集
        第一段正文
        第1集
        标题被重复粘贴
        第2集
        第二段正文
        """

        let result = EpisodeScriptSplitter.splitWithDiagnostics(script)

        #expect(result.episodes.count == 1)
        #expect(result.episodes.map(\.scriptText).joined() == script)
        #expect(result.diagnostics.contains {
            $0.kind == .duplicateEpisodeNumber
                && $0.evidence == .episodeHeader
                && $0.episodeNumber == "1"
        })
    }

    @Test("场号集数回跳时保守不拆并返回诊断")
    func regressingSceneEpisodeNumbersStayUnsplit() {
        let script = """
        第3集
        3-1 日/外 场景三
        正文三
        第2集
        2-1 夜/内 场景二
        正文二
        """

        let result = EpisodeScriptSplitter.splitWithDiagnostics(script)

        #expect(result.episodes.count == 1)
        #expect(result.episodes.map(\.scriptText).joined() == script)
        #expect(result.diagnostics.contains {
            $0.kind == .episodeNumberRegression
                && $0.evidence == .sceneHeading
                && $0.episodeNumber == "2"
        })
    }

    @Test("全角场号和中文集数会被规范化")
    func fullwidthAndChineseNumbersAreNormalized() {
        let script = """
        **第十四集**
        １４－１ 日／外 官道 人物：余思思
        正文
        """

        let episodes = EpisodeScriptSplitter.split(script)
        let headings = EpisodeScriptSplitter.sceneHeadings(in: script)

        #expect(episodes.first?.episodeNumber == "14")
        #expect(headings.first?.sceneIdentifier == "14-1")
    }

    @Test("没有场号的日内标题仍作为场景且不吞掉第一场")
    func unnumberedDayInteriorHeadingIsRecognized() {
        let script = """
        **第1集 1章**
        **日/内 官道 人物：余思思 安安**
        一辆粉色电动车疾驰在官道上。

        **1-2夜/内 赵家-卧室 人物：余思思、安安（婴儿）**
        余思思躺在木板床上。
        """

        let headings = EpisodeScriptSplitter.sceneHeadings(in: script)

        #expect(headings.count == 2)
        #expect(headings[0].text.contains("日/内 官道"))
        #expect(headings[0].sceneIdentifier == nil)
        #expect(headings[1].sceneIdentifier == "1-2")
    }

    @Test("结构校验会阻止跨集混入和重复集号")
    func integrityValidatorRejectsAmbiguousEpisodes() {
        let first = preview(
            title: "第 11 集",
            headings: [heading(episode: "11", scene: "1")]
        )
        let mixed = preview(
            title: "第 12 集",
            headings: [
                heading(episode: "12", scene: "1"),
                heading(episode: "13", scene: "1", line: 2)
            ]
        )
        let duplicate = preview(
            title: "第 11 集",
            headings: [heading(episode: "11", scene: "2")]
        )

        let issues = EpisodeAnalysisIntegrityValidator.blockingIssues(
            in: [first, mixed, duplicate]
        )

        #expect(issues.contains { $0.contains("混入多个集号") })
        #expect(issues.contains { $0.contains("集号 11 同时出现") })
    }

    private func heading(
        episode: String,
        scene: String,
        line: Int = 1
    ) -> EpisodeSceneHeading {
        EpisodeSceneHeading(
            lineNumber: line,
            text: "\(episode)-\(scene) 日/外 场景",
            episodeNumber: episode,
            sceneNumber: scene
        )
    }

    private func preview(
        title: String,
        headings: [EpisodeSceneHeading]
    ) -> EpisodeAnalysisPreview {
        EpisodeAnalysisPreview(
            episodeID: UUID(),
            order: 1,
            title: title,
            sceneHeadings: headings,
            contentFingerprint: UUID().uuidString
        )
    }
}
