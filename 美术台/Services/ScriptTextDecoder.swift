import CoreFoundation
import Foundation

/// Strictly decodes screenplay files without replacement characters or lossy
/// conversion. The caller can safely persist the returned string verbatim.
enum ScriptTextDecoder {
    struct DecodedText: Sendable {
        let text: String
        let encodingName: String
    }

    static func decode(_ data: Data) throws -> DecodedText {
        if data.isEmpty {
            return DecodedText(text: "", encodingName: "UTF-8")
        }

        for candidate in bomCandidates where data.starts(with: candidate.bom) {
            guard let text = String(data: data, encoding: candidate.encoding) else {
                throw ScriptTextDecodingError.invalidData(candidate.name)
            }
            return DecodedText(
                text: removingEncodingSignature(from: text),
                encodingName: candidate.name
            )
        }

        let decodings = strictCandidates.compactMap { candidate -> (Candidate, String)? in
            guard let text = String(data: data, encoding: candidate.encoding),
                  roundTrips(text, to: data, using: candidate.encoding)
            else {
                return nil
            }
            return (candidate, text)
        }

        if let indicatedName = stronglyIndicatedUnicodeEncoding(in: data),
           let indicated = decodings.first(where: { $0.0.name == indicatedName }) {
            return DecodedText(text: indicated.1, encodingName: indicated.0.name)
        }

        // Valid UTF-8 is self-identifying unless byte-position evidence strongly
        // indicates BOM-less UTF-16/32 (handled above).
        if let utf8 = decodings.first(where: { $0.0.name == "UTF-8" }) {
            return DecodedText(text: utf8.1, encodingName: utf8.0.name)
        }

        let legacyDecodings = decodings.filter {
            $0.0.name == "GB18030" || $0.0.name == "Big5"
        }
        let legacyTexts = Dictionary(grouping: legacyDecodings, by: { $0.1 })
        guard legacyTexts.count <= 1 else {
            throw ScriptTextDecodingError.ambiguousEncoding(
                legacyDecodings.map { $0.0.name }
            )
        }
        if let decoded = legacyDecodings.first {
            return DecodedText(text: decoded.1, encodingName: decoded.0.name)
        }

        let unicodeDecodings = decodings.filter { $0.0.name.hasPrefix("UTF-") }
        let unicodeTexts = Dictionary(grouping: unicodeDecodings, by: { $0.1 })
        guard unicodeTexts.count <= 1 else {
            throw ScriptTextDecodingError.ambiguousEncoding(
                unicodeDecodings.map { $0.0.name }
            )
        }
        if let decoded = unicodeDecodings.first {
            return DecodedText(text: decoded.1, encodingName: decoded.0.name)
        }

        throw ScriptTextDecodingError.unsupportedEncoding
    }

    private struct Candidate {
        let name: String
        let encoding: String.Encoding
        let bom: Data

        init(_ name: String, _ encoding: String.Encoding, bom: [UInt8] = []) {
            self.name = name
            self.encoding = encoding
            self.bom = Data(bom)
        }
    }

    private static let bomCandidates: [Candidate] = [
        Candidate("UTF-32BE", .utf32BigEndian, bom: [0x00, 0x00, 0xFE, 0xFF]),
        Candidate("UTF-32LE", .utf32LittleEndian, bom: [0xFF, 0xFE, 0x00, 0x00]),
        Candidate("UTF-8", .utf8, bom: [0xEF, 0xBB, 0xBF]),
        Candidate("UTF-16BE", .utf16BigEndian, bom: [0xFE, 0xFF]),
        Candidate("UTF-16LE", .utf16LittleEndian, bom: [0xFF, 0xFE])
    ]

    private static let strictCandidates: [Candidate] = [
        Candidate("UTF-8", .utf8),
        Candidate("UTF-16LE", .utf16LittleEndian),
        Candidate("UTF-16BE", .utf16BigEndian),
        Candidate("UTF-32LE", .utf32LittleEndian),
        Candidate("UTF-32BE", .utf32BigEndian),
        Candidate("GB18030", foundationEncoding(.GB_18030_2000)),
        Candidate("Big5", foundationEncoding(.big5))
    ]

    private static func foundationEncoding(
        _ encoding: CFStringEncodings
    ) -> String.Encoding {
        String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(encoding.rawValue)
            )
        )
    }

    private static func roundTrips(
        _ text: String,
        to source: Data,
        using encoding: String.Encoding
    ) -> Bool {
        text.data(using: encoding, allowLossyConversion: false) == source
    }

    private static func stronglyIndicatedUnicodeEncoding(in data: Data) -> String? {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { return nil }

        func zeroRatio(modulo: Int, remainder: Int) -> Double {
            let positions = stride(from: remainder, to: bytes.count, by: modulo)
            var total = 0
            var zeros = 0
            for index in positions {
                total += 1
                if bytes[index] == 0 { zeros += 1 }
            }
            return total == 0 ? 0 : Double(zeros) / Double(total)
        }

        if bytes.count.isMultiple(of: 4) {
            let r0 = zeroRatio(modulo: 4, remainder: 0)
            let r1 = zeroRatio(modulo: 4, remainder: 1)
            let r2 = zeroRatio(modulo: 4, remainder: 2)
            let r3 = zeroRatio(modulo: 4, remainder: 3)
            if r2 >= 0.8, r3 >= 0.8, r0 < 0.5 {
                return "UTF-32LE"
            }
            if r0 >= 0.8, r1 >= 0.8, r3 < 0.5 {
                return "UTF-32BE"
            }
        }

        guard bytes.count.isMultiple(of: 2) else { return nil }
        let even = zeroRatio(modulo: 2, remainder: 0)
        let odd = zeroRatio(modulo: 2, remainder: 1)
        if odd >= 0.6, even < 0.2 {
            return "UTF-16LE"
        }
        if even >= 0.6, odd < 0.2 {
            return "UTF-16BE"
        }
        return nil
    }

    private static func removingEncodingSignature(from text: String) -> String {
        guard text.unicodeScalars.first?.value == 0xFEFF else { return text }
        return String(text.unicodeScalars.dropFirst())
    }

}

enum ScriptTextDecodingError: LocalizedError {
    case invalidData(String)
    case ambiguousEncoding([String])
    case unsupportedEncoding

    var errorDescription: String? {
        switch self {
        case .invalidData(let encoding):
            "文件声明为 \(encoding)，但内容已经损坏；为避免替换或丢字，未导入任何文本。"
        case .ambiguousEncoding(let names):
            "文件可被多种编码解读且结果不同（\(names.joined(separator: " / "))；为避免静默乱码，未导入任何文本。请另存为带编码标记的 UTF-8 后重试。"
        case .unsupportedEncoding:
            "无法无损识别文本编码。请另存为 UTF-8、UTF-16、UTF-32、GB18030 或 Big5 后重试。"
        }
    }
}
