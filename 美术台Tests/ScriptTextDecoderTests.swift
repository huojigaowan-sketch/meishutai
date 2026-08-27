import Foundation
import Testing
@testable import 美术台

struct ScriptTextDecoderTests {
    @Test("UTF-8 干扰字符逐字符保留")
    func utf8PreservesEveryCharacter() throws {
        let source = "第1章\u{FEFF}\r\n1-1 日/外\u{0000}\u{200B}🎬e\u{301}\n"
        let decoded = try ScriptTextDecoder.decode(Data(source.utf8))

        #expect(decoded.text == source)
    }

    @Test("带 BOM 的 UTF-16 中文剧本无损解码")
    func utf16BOM() throws {
        let source = "第十二集\r\n１２－１ 夜／内\n台词：‘别删我’"
        var data = Data([0xFF, 0xFE])
        data.append(try #require(source.data(using: .utf16LittleEndian)))

        let decoded = try ScriptTextDecoder.decode(data)

        #expect(decoded.text == source)
        #expect(decoded.encodingName == "UTF-16LE")
    }

    @Test("无 BOM 的 UTF-16 ASCII 不会被误当含 NUL 的 UTF-8")
    func bomlessUTF16UsesBytePositionEvidence() throws {
        let source = "Episode 12\r\n12-1 DAY INT\nDialogue"
        let data = try #require(source.data(using: .utf16LittleEndian))

        let decoded = try ScriptTextDecoder.decode(data)

        #expect(decoded.text == source)
        #expect(decoded.encodingName == "UTF-16LE")
    }

    @Test("无标记且多解的中文编码会明确拒绝而不猜测")
    func ambiguousLegacyEncodingIsRejected() {
        // GB18030 = "你好"，同一字节串在 Big5 中会成为另一段有效文本。
        let ambiguous = Data([0xC4, 0xE3, 0xBA, 0xC3])

        #expect(throws: ScriptTextDecodingError.self) {
            try ScriptTextDecoder.decode(ambiguous)
        }
    }

    @Test("非法字节不会被替换后静默导入")
    func invalidBytesAreRejected() {
        #expect(throws: ScriptTextDecodingError.self) {
            try ScriptTextDecoder.decode(Data([0xFF, 0xFF, 0xFF]))
        }
    }
}
