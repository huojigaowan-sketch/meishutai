import AppKit
import CryptoKit
import Foundation

nonisolated enum StyleLibraryVaultError: LocalizedError {
    case malformedContainer
    case missingCombinedRepresentation
    case invalidKeyMaterial

    var errorDescription: String? {
        switch self {
        case .malformedContainer: "风格图书馆加密容器无效或已损坏。"
        case .missingCombinedRepresentation: "无法创建完整的 AES-GCM 加密容器。"
        case .invalidKeyMaterial: "Keychain 中的风格图书馆密钥无效。"
        }
    }
}

nonisolated enum StyleLibraryVault {
    private static let magic = Data([0x4D, 0x53, 0x56, 0x34]) // MSV4

    static func seal(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key)
        guard let combined = box.combined else {
            throw StyleLibraryVaultError.missingCombinedRepresentation
        }
        var container = magic
        container.append(combined)
        return container
    }

    static func open(_ container: Data, using key: SymmetricKey) throws -> Data {
        guard container.count > magic.count,
              container.prefix(magic.count) == magic
        else { throw StyleLibraryVaultError.malformedContainer }
        let box = try AES.GCM.SealedBox(combined: container.dropFirst(magic.count))
        return try AES.GCM.open(box, using: key)
    }
}

actor ArtDepartmentPersistence {
    static let shared = ArtDepartmentPersistence()

    private let fileManager: FileManager
    private let rootURL: URL
    private let legacyDocumentURL: URL
    private let legacyVaultURL: URL
    private let vaultURL: URL
    private let backupsURL: URL
    private let styleImagesURL: URL
    private let styleSamplesURL: URL
    private let generatedImagesURL: URL

    init() {
        let manager = FileManager.default
        fileManager = manager
        let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? manager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        rootURL = support.appending(path: "MeishutaiV2", directoryHint: .isDirectory)
        legacyDocumentURL = rootURL.appending(path: "workspace-v2.json")
        legacyVaultURL = rootURL.appending(path: "workspace-v4.vault")
        vaultURL = rootURL.appending(path: "workspace-v5.vault")
        backupsURL = rootURL.appending(path: "vault-backups", directoryHint: .isDirectory)
        styleImagesURL = rootURL.appending(path: "style-images", directoryHint: .isDirectory)
        styleSamplesURL = rootURL.appending(path: "style-samples", directoryHint: .isDirectory)
        generatedImagesURL = rootURL.appending(path: "generated-images", directoryHint: .isDirectory)
    }

    func load() throws -> ArtDepartmentWorkspaceDocument {
        try prepareDirectories()
        let key = try vaultKey()
        var document: ArtDepartmentWorkspaceDocument
        var shouldPersistMigration = false

        if fileManager.fileExists(atPath: vaultURL.path) {
            let encrypted = try Data(contentsOf: vaultURL)
            let plaintext = try StyleLibraryVault.open(encrypted, using: key)
            document = try JSONDecoder.artDepartment.decode(ArtDepartmentWorkspaceDocument.self, from: plaintext)
        } else if fileManager.fileExists(atPath: legacyVaultURL.path) {
            let encrypted = try Data(contentsOf: legacyVaultURL)
            let plaintext = try StyleLibraryVault.open(encrypted, using: key)
            document = try JSONDecoder.artDepartment.decode(ArtDepartmentWorkspaceDocument.self, from: plaintext)
            shouldPersistMigration = true
        } else if fileManager.fileExists(atPath: legacyDocumentURL.path) {
            document = try JSONDecoder.artDepartment.decode(
                ArtDepartmentWorkspaceDocument.self,
                from: Data(contentsOf: legacyDocumentURL)
            )
            shouldPersistMigration = true
        } else {
            document = .empty
        }

        if mergePinnedBuiltIns(into: &document) {
            shouldPersistMigration = true
        }
        if sanitizeUserStyleCards(in: &document) {
            shouldPersistMigration = true
        }

        if try migratePlaintextStyleImages(in: &document, using: key) {
            shouldPersistMigration = true
        }
        document.schemaVersion = max(7, document.schemaVersion)

        if shouldPersistMigration {
            try save(document)
        }
        return document
    }

    func save(_ document: ArtDepartmentWorkspaceDocument) throws {
        try prepareDirectories()
        var document = document
        document.schemaVersion = max(7, document.schemaVersion)
        document.updatedAt = .now
        let plaintext = try JSONEncoder.artDepartment.encode(document)
        let encrypted = try StyleLibraryVault.seal(plaintext, using: vaultKey())
        try backupCurrentVault()
        try writeProtected(encrypted, to: vaultURL)
        if fileManager.fileExists(atPath: legacyDocumentURL.path) {
            try fileManager.removeItem(at: legacyDocumentURL)
        }
    }

    func importStyleImage(from sourceURL: URL, cardID: UUID) throws -> String {
        try prepareDirectories()
        let relative = "style-images/\(cardID.uuidString).vault"
        let destination = rootURL.appending(path: relative)
        let plaintext = try Data(contentsOf: sourceURL)
        let encrypted = try StyleLibraryVault.seal(plaintext, using: vaultKey())
        try writeProtected(encrypted, to: destination)
        return relative
    }

    func importStyleSample(
        data: Data,
        cardID: UUID,
        sampleID: UUID
    ) throws -> PersistedStyleSamplePayload {
        try prepareDirectories()
        try StyleSampleValidator.validate(data)
        let folder = styleSamplesURL.appending(path: cardID.uuidString, directoryHint: .isDirectory)
        try createProtectedDirectory(folder)
        let relative = "style-samples/\(cardID.uuidString)/\(sampleID.uuidString).vault"
        let destination = rootURL.appending(path: relative)
        let encrypted = try StyleLibraryVault.seal(data, using: vaultKey())
        try writeProtected(encrypted, to: destination)
        return PersistedStyleSamplePayload(
            path: relative,
            sha256: StyleSampleValidator.sha256(data),
            data: data
        )
    }

    func cacheRemoteStyleSample(
        from sourceURL: URL,
        cardID: UUID,
        sampleID: UUID
    ) async throws -> PersistedStyleSamplePayload {
        guard sourceURL.scheme?.lowercased() == "https" else {
            throw ArtDepartmentV2Error.remoteSampleUnavailable
        }
        var request = URLRequest(
            url: sourceURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 90
        )
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              data.count <= StyleSampleValidator.maximumBytes
        else { throw ArtDepartmentV2Error.remoteSampleUnavailable }
        try StyleSampleValidator.validate(data)
        return try importStyleSample(data: data, cardID: cardID, sampleID: sampleID)
    }

    func deleteStyleMedia(at relativePath: String?) throws {
        guard let relativePath,
              (relativePath.hasPrefix("style-samples/") || relativePath.hasPrefix("style-images/")),
              let url = absoluteURL(for: relativePath),
              fileManager.fileExists(atPath: url.path)
        else { return }
        try fileManager.removeItem(at: url)
    }

    func saveGeneratedImage(
        _ data: Data,
        projectID: UUID,
        imageID: UUID,
        fileExtension: String = "png"
    ) throws -> String {
        try prepareDirectories()
        let projectFolder = generatedImagesURL.appending(path: projectID.uuidString, directoryHint: .isDirectory)
        try createProtectedDirectory(projectFolder)
        let ext = fileExtension.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).lowercased()
        let safeExtension = ext.isEmpty ? "png" : ext
        let relative = "generated-images/\(projectID.uuidString)/\(imageID.uuidString).\(safeExtension)"
        let destination = rootURL.appending(path: relative)
        try data.write(to: destination, options: .atomic)
        try protectFile(destination)
        return relative
    }

    func absoluteURL(for relativePath: String?) -> URL? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        let root = rootURL.standardizedFileURL.path + "/"
        let candidate = rootURL.appending(path: relativePath).standardizedFileURL
        guard candidate.path.hasPrefix(root) else { return nil }
        return candidate
    }

    func deleteStyleImage(at relativePath: String?) throws {
        guard let relativePath,
              relativePath.hasPrefix("style-images/"),
              let url = absoluteURL(for: relativePath),
              fileManager.fileExists(atPath: url.path)
        else { return }
        try fileManager.removeItem(at: url)
    }

    func data(for relativePath: String?) throws -> Data? {
        guard let relativePath,
              let url = absoluteURL(for: relativePath),
              fileManager.fileExists(atPath: url.path)
        else { return nil }
        let data = try Data(contentsOf: url)
        if (relativePath.hasPrefix("style-images/") || relativePath.hasPrefix("style-samples/")) && url.pathExtension == "vault" {
            return try StyleLibraryVault.open(data, using: vaultKey())
        }
        return data
    }

    private func mergePinnedBuiltIns(
        into document: inout ArtDepartmentWorkspaceDocument
    ) -> Bool {
        var changed = false
        let pinned = Dictionary(uniqueKeysWithValues: BuiltInStylePromptCatalog.cards.map { ($0.id, $0) })
        let originalCount = document.styleCards.count
        document.styleCards.removeAll { card in
            card.isBuiltIn && pinned[card.id] == nil
        }
        changed = changed || originalCount != document.styleCards.count

        for pinnedCard in BuiltInStylePromptCatalog.cards {
            if let index = document.styleCards.firstIndex(where: { $0.id == pinnedCard.id }) {
                let cached = Dictionary(uniqueKeysWithValues: document.styleCards[index].styleSampleMedia.map {
                    ($0.id, $0)
                })
                var updated = pinnedCard
                updated.sampleMedia = pinnedCard.styleSampleMedia.map { sample in
                    guard let existing = cached[sample.id] else { return sample }
                    var merged = sample
                    merged.encryptedLocalPath = existing.encryptedLocalPath
                    merged.sha256 = existing.sha256
                    return merged
                }
                if document.styleCards[index] != updated {
                    document.styleCards[index] = updated
                    changed = true
                }
            } else {
                document.styleCards.append(pinnedCard)
                changed = true
            }
        }
        return changed
    }

    private func sanitizeUserStyleCards(
        in document: inout ArtDepartmentWorkspaceDocument
    ) -> Bool {
        var changed = false
        for index in document.styleCards.indices where !document.styleCards[index].isBuiltIn {
            let prompt = document.styleCards[index].prompt
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else { continue }
            var migrated = StyleOnlyPromptPolicy.migratedLegacyCard(
                document.styleCards[index],
                index: index
            )
            if migrated != document.styleCards[index] {
                migrated.updatedAt = .now
                document.styleCards[index] = migrated
                changed = true
            }
        }
        return changed
    }

    private func migratePlaintextStyleImages(
        in document: inout ArtDepartmentWorkspaceDocument,
        using key: SymmetricKey
    ) throws -> Bool {
        var changed = false
        for index in document.styleCards.indices {
            guard let relative = document.styleCards[index].referenceImagePath,
                  !relative.isEmpty,
                  !relative.hasSuffix(".vault")
            else { continue }
            let source = rootURL.appending(path: relative)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let destinationRelative = "style-images/\(document.styleCards[index].id.uuidString).vault"
            let destination = rootURL.appending(path: destinationRelative)
            let encrypted = try StyleLibraryVault.seal(Data(contentsOf: source), using: key)
            try writeProtected(encrypted, to: destination)
            try fileManager.removeItem(at: source)
            document.styleCards[index].referenceImagePath = destinationRelative
            document.styleCards[index].updatedAt = .now
            changed = true
        }
        return changed
    }

    private func vaultKey() throws -> SymmetricKey {
        let stored = ArtDepartmentKeychain.read(account: .styleVault)
        if !stored.isEmpty {
            guard let data = Data(base64Encoded: stored), data.count == 32 else {
                throw StyleLibraryVaultError.invalidKeyMaterial
            }
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        try ArtDepartmentKeychain.save(data.base64EncodedString(), account: .styleVault)
        return key
    }

    private func backupCurrentVault() throws {
        guard fileManager.fileExists(atPath: vaultURL.path) else { return }
        let stamp = Int(Date().timeIntervalSince1970 * 1_000)
        let backup = backupsURL.appending(path: "workspace-\(stamp).vault")
        try fileManager.copyItem(at: vaultURL, to: backup)
        try protectFile(backup)
        let backups = try fileManager.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "vault" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for obsolete in backups.dropLast(20) {
            try fileManager.removeItem(at: obsolete)
        }
    }

    private func prepareDirectories() throws {
        try createProtectedDirectory(rootURL)
        try createProtectedDirectory(backupsURL)
        try createProtectedDirectory(styleImagesURL)
        try createProtectedDirectory(styleSamplesURL)
        try createProtectedDirectory(generatedImagesURL)
    }

    private func createProtectedDirectory(_ url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    private func writeProtected(_ data: Data, to destination: URL) throws {
        let temporary = destination.appendingPathExtension("tmp")
        if fileManager.fileExists(atPath: temporary.path) {
            try fileManager.removeItem(at: temporary)
        }
        try data.write(to: temporary, options: .atomic)
        try protectFile(temporary)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
        try protectFile(destination)
    }

    private func protectFile(_ url: URL) throws {
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
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

nonisolated private final class FinalDraftXMLDelegate: NSObject, XMLParserDelegate {
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
    nonisolated static var artDepartment: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    nonisolated static var artDepartment: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
