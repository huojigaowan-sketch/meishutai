import CryptoKit
import Foundation
import FoundationXML

actor ArtDepartmentPersistence {
    static let shared = ArtDepartmentPersistence()

    private let fileManager = FileManager.default
    private let rootURL: URL
    private let documentURL: URL
    private let styleImagesURL: URL
    private let generatedImagesURL: URL

    init() {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        rootURL = support.appending(path: "MeishutaiV2", directoryHint: .isDirectory)
        documentURL = rootURL.appending(path: "workspace-v2.json")
        styleImagesURL = rootURL.appending(path: "style-images", directoryHint: .isDirectory)
        generatedImagesURL = rootURL.appending(path: "generated-images", directoryHint: .isDirectory)
    }

    func load() throws -> ArtDepartmentWorkspaceDocument {
        try prepareDirectories()
        guard fileManager.fileExists(atPath: documentURL.path) else {
            return .empty
        }
        let data = try Data(contentsOf: documentURL)
        var document = try JSONDecoder.artDepartment.decode(ArtDepartmentWorkspaceDocument.self, from: data)
        let knownBuiltIns = Set(document.styleCards.filter(\.isBuiltIn).map(\.id))
        document.styleCards.append(contentsOf: BuiltInStylePromptCatalog.cards.filter { !knownBuiltIns.contains($0.id) })
        return document
    }

    func save(_ document: ArtDepartmentWorkspaceDocument) throws {
        try prepareDirectories()
        var document = document
        document.updatedAt = .now
        let data = try JSONEncoder.artDepartment.encode(document)
        let temporary = documentURL.appendingPathExtension("tmp")
        try data.write(to: temporary, options: .atomic)
        if fileManager.fileExists(atPath: documentURL.path) {
            _ = try fileManager.replaceItemAt(documentURL, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: documentURL)
        }
    }

    func importStyleImage(from sourceURL: URL, cardID: UUID) throws -> String {
        try prepareDirectories()
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension.lowercased()
        let relative = "style-images/\(cardID.uuidString).\(ext)"
        let destination = rootURL.appending(path: relative)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return relative
    }

    func saveGeneratedImage(_ data: Data, projectID: UUID, imageID: UUID, fileExtension: String = "png") throws -> String {
        try prepareDirectories()
        let projectFolder = generatedImagesURL.appending(path: projectID.uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: projectFolder, withIntermediateDirectories: true)
        let ext = fileExtension.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).lowercased()
        let safeExtension = ext.isEmpty ? "png" : ext
        let relative = "generated-images/\(projectID.uuidString)/\(imageID.uuidString).\(safeExtension)"
        try data.write(to: rootURL.appending(path: relative), options: .atomic)
        return relative
    }

    func absoluteURL(for relativePath: String?) -> URL? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        return rootURL.appending(path: relativePath)
    }

    func data(for relativePath: String?) throws -> Data? {
        guard let url = absoluteURL(for: relativePath), fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: styleImagesURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: generatedImagesURL, withIntermediateDirectories: true)
    }
}

nonisolated enum ScriptFileReader {
    static func read(_ url: URL) throws -> String {
        let ext = url.pathExtension.lowercased()
        if ext == "fdx" {
            return try FinalDraftImporter.fountain(from: Data(contentsOf: url))
        }
        let data = try Data(contentsOf: url)
        for encoding in [String.Encoding.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .utf32] {
            if let text = String(data: data, encoding: encoding), !text.isEmpty {
                return text
            }
        }
        throw ArtDepartmentV2Error.unsupportedFile
    }
}

nonisolated enum SourceUnitBuilder {
    static func makeUnits(from text: String) -> [SourceUnit] {
        let nsText = text as NSString
        var units: [SourceUnit] = []
        var cursor = 0
        var index = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byParagraphs, .substringNotRequired]) { _, range, enclosingRange, _ in
            let location = text.utf16.distance(from: text.utf16.startIndex, to: range.lowerBound.samePosition(in: text.utf16) ?? text.utf16.startIndex)
            let length = text.utf16.distance(from: range.lowerBound.samePosition(in: text.utf16) ?? text.utf16.startIndex, to: range.upperBound.samePosition(in: text.utf16) ?? text.utf16.startIndex)
            let paragraph = nsText.substring(with: NSRange(location: location, length: length))
            let clean = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                index += 1
                units.append(SourceUnit(id: String(format: "U%06d", index), index: index - 1, text: clean, utf16Location: location, utf16Length: length))
            }
            cursor = max(cursor, text.utf16.distance(from: text.utf16.startIndex, to: enclosingRange.upperBound.samePosition(in: text.utf16) ?? text.utf16.startIndex))
        }
        if units.isEmpty, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            units = [SourceUnit(id: "U000001", index: 0, text: text, utf16Location: 0, utf16Length: text.utf16.count)]
        }
        _ = cursor
        return units
    }

    static func fingerprint(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated enum CanonicalFountainRenderer {
    static func render(scene: CanonicalScene) -> String {
        let heading = normalizedHeading(scene.heading)
        var lines = [heading, ""]
        for paragraph in scene.paragraphs where paragraph.element != .sceneHeading {
            let text = paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            switch paragraph.element {
            case .character:
                lines.append(text.hasPrefix("@") ? text : "@\(text)")
            case .parenthetical:
                lines.append(text.hasPrefix("（") || text.hasPrefix("(") ? text : "（\(text)）")
            case .transition:
                lines.append(text.uppercased().hasSuffix("TO:") ? text.uppercased() : "\(text.uppercased()) TO:")
            default:
                lines.append(text)
            }
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func render(scenes: [CanonicalScene]) -> String {
        scenes.sorted { $0.order < $1.order }.map(render).joined(separator: "\n\n") + "\n"
    }

    static func normalizedHeading(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "内. 未定地点 - 日" }
        let upper = value.uppercased()
        if upper.hasPrefix("INT.") || upper.hasPrefix("EXT.") || upper.hasPrefix("INT/EXT.") || value.hasPrefix("内.") || value.hasPrefix("外.") || value.hasPrefix("内外.") {
            return value
        }
        return "内. \(value) - 日"
    }
}

nonisolated enum CanonicalFountainParser {
    static func parse(_ fountain: String) -> [CanonicalScene] {
        let lines = fountain.components(separatedBy: .newlines)
        var scenes: [CanonicalScene] = []
        var heading = ""
        var paragraphs: [CanonicalParagraph] = []
        var dialogueExpected = false

        func flush() {
            guard !heading.isEmpty || !paragraphs.isEmpty else { return }
            let order = scenes.count
            scenes.append(CanonicalScene(order: order, heading: heading.isEmpty ? "内. 未定地点 - 日" : heading, sceneKey: "scene-\(order + 1)", paragraphs: paragraphs, sourceUnitIDs: []))
            paragraphs = []
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if isHeading(line) {
                flush()
                heading = line
                dialogueExpected = false
            } else if line.hasPrefix("@") {
                paragraphs.append(CanonicalParagraph(element: .character, text: String(line.dropFirst())))
                dialogueExpected = true
            } else if line.hasPrefix("（") || line.hasPrefix("(") {
                paragraphs.append(CanonicalParagraph(element: .parenthetical, text: line))
            } else if line.uppercased().hasSuffix("TO:") || line == "切至：" {
                paragraphs.append(CanonicalParagraph(element: .transition, text: line))
                dialogueExpected = false
            } else if dialogueExpected {
                paragraphs.append(CanonicalParagraph(element: .dialogue, text: line))
            } else {
                paragraphs.append(CanonicalParagraph(element: .action, text: line))
            }
        }
        flush()
        return scenes
    }

    static func isHeading(_ line: String) -> Bool {
        let upper = line.uppercased()
        return upper.hasPrefix("INT.") || upper.hasPrefix("EXT.") || upper.hasPrefix("INT/EXT.") || line.hasPrefix("内.") || line.hasPrefix("外.") || line.hasPrefix("内外.")
    }
}

nonisolated enum FinalDraftFDXExporter {
    static func data(scenes: [CanonicalScene], title: String) -> Data {
        let paragraphs = scenes.sorted { $0.order < $1.order }.flatMap { scene -> [String] in
            var values = [paragraph(type: .sceneHeading, text: CanonicalFountainRenderer.normalizedHeading(scene.heading))]
            values.append(contentsOf: scene.paragraphs.filter { $0.element != .sceneHeading }.map { paragraph(type: $0.element, text: $0.text) })
            return values
        }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <FinalDraft DocumentType="Script" Template="No" Version="3">
          <Content>
        \(paragraphs)
          </Content>
          <TitlePage><Content><Paragraph Type="Action"><Text>\(escape(title))</Text></Paragraph></Content></TitlePage>
        </FinalDraft>
        """
        return Data(xml.utf8)
    }

    private static func paragraph(type: ScreenplayElementKind, text: String) -> String {
        "    <Paragraph Type=\"\(type.rawValue)\"><Text>\(escape(text))</Text></Paragraph>"
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private final class FinalDraftXMLDelegate: NSObject, XMLParserDelegate {
    var paragraphs: [(String, String)] = []
    private var currentType = "Action"
    private var currentText = ""
    private var readingText = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "Paragraph" { currentType = attributeDict["Type"] ?? "Action" }
        if elementName == "Text" { readingText = true; currentText = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if readingText { currentText += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Text" { readingText = false }
        if elementName == "Paragraph", !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            paragraphs.append((currentType, currentText))
            currentText = ""
        }
    }
}

nonisolated enum FinalDraftImporter {
    static func fountain(from data: Data) throws -> String {
        let delegate = FinalDraftXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw ArtDepartmentV2Error.unsupportedFile }
        var lines: [String] = []
        for (rawType, text) in delegate.paragraphs {
            let type = ScreenplayElementKind(rawValue: rawType) ?? .action
            switch type {
            case .character: lines.append(text.hasPrefix("@") ? text : "@\(text)")
            case .transition: lines.append(text.uppercased())
            default: lines.append(text)
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

private extension JSONEncoder {
    static var artDepartment: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var artDepartment: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
