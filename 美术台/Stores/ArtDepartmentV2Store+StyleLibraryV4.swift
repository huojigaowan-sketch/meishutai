import AppKit
import Foundation

@MainActor
extension ArtDepartmentV2Store {
    var styleTree: [StyleTreeNode] {
        StylePromptResolver.forest(
            from: document.styleCards,
            includeArchived: showsArchivedStyles,
            search: styleSearchText
        )
    }

    var visibleStyleNodeCount: Int {
        func count(_ nodes: [StyleTreeNode]) -> Int {
            nodes.reduce(0) { $0 + 1 + count($1.children ?? []) }
        }
        return count(styleTree)
    }

    var selectedStyleNode: StylePromptCard? {
        guard let selectedStyleNodeID else {
            return document.styleCards.first(where: { !$0.isArchived })
        }
        return document.styleCards.first { $0.id == selectedStyleNodeID }
    }

    func styleCard(_ id: UUID) -> StylePromptCard? {
        document.styleCards.first { $0.id == id }
    }

    func styleLineage(for id: UUID) -> [StylePromptCard] {
        StylePromptResolver.lineage(for: id, in: document.styleCards)
    }

    func resolvedPrompt(for id: UUID) -> String {
        StylePromptResolver.resolvedPrompt(for: id, in: document.styleCards)
    }

    func resolvedSampleMedia(for card: StylePromptCard) -> [StyleSampleMedia] {
        StylePromptResolver.resolvedSamples(for: card.id, in: document.styleCards)
    }

    func primaryStyleImage(for card: StylePromptCard) -> NSImage? {
        guard let sample = resolvedSampleMedia(for: card).first else { return nil }
        return styleImage(for: sample)
    }

    func styleImage(for sample: StyleSampleMedia) -> NSImage? {
        guard let path = sample.encryptedLocalPath,
              let data = styleImageDataByPath[path]
        else { return nil }
        return NSImage(data: data)
    }

    func sampleStatusText(for card: StylePromptCard) -> String {
        let own = card.styleSampleMedia.count
        let resolved = resolvedSampleMedia(for: card).count
        if own > 0 { return "本节点 \(own) 张加密样板" }
        if resolved > 0 { return "继承父节点 \(resolved) 张样板" }
        return card.isExperiment ? "持久化实验，等待样板" : "缺少样板"
    }

    func ensureStyleSamples(for cardID: UUID) async {
        guard !styleSampleLoadingIDs.contains(cardID),
              let index = document.styleCards.firstIndex(where: { $0.id == cardID })
        else { return }
        let media = document.styleCards[index].styleSampleMedia
        guard media.contains(where: {
            $0.encryptedLocalPath == nil && $0.remoteURLString != nil
        }) else { return }

        styleSampleLoadingIDs.insert(cardID)
        defer { styleSampleLoadingIDs.remove(cardID) }
        var changed = false
        for mediaIndex in document.styleCards[index].styleSampleMedia.indices {
            var sample = document.styleCards[index].styleSampleMedia[mediaIndex]
            guard sample.encryptedLocalPath == nil,
                  let raw = sample.remoteURLString,
                  let url = URL(string: raw),
                  url.scheme?.lowercased() == "https"
            else { continue }
            do {
                let cached = try await persistence.cacheRemoteStyleSample(
                    from: url,
                    cardID: cardID,
                    sampleID: sample.id
                )
                sample.encryptedLocalPath = cached.path
                sample.sha256 = cached.sha256
                document.styleCards[index].sampleMedia?[mediaIndex] = sample
                styleImageDataByPath[cached.path] = cached.data
                changed = true
            } catch {
                styleSampleFailedIDs.insert(sample.id)
            }
        }
        if changed {
            document.styleCards[index].updatedAt = .now
            await persist()
        }
    }

    func createStyleNode(
        parentID: UUID?,
        title: String,
        prompt: String,
        category: StylePromptCategory,
        tags: [String],
        notes: String,
        imageURLs: [URL],
        publish: Bool
    ) async {
        errorMessage = nil
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanPrompt.isEmpty else { return }
        if parentID == nil && imageURLs.isEmpty {
            errorMessage = ArtDepartmentV2Error.styleSampleRequired.localizedDescription
            return
        }
        var card = StylePromptCard(
            title: cleanTitle,
            prompt: cleanPrompt,
            category: category,
            tags: tags,
            notes: notes,
            isPromptLocked: false,
            parentID: parentID,
            lifecycleRawValue: (publish ? StylePromptLifecycle.library : .experiment).rawValue,
            branchLabel: parentID == nil ? "根风格" : "变化分支",
            branchOrder: nextBranchOrder(parentID: parentID),
            revisionNumber: 1,
            sampleMedia: []
        )
        do {
            for url in imageURLs {
                let sample = try await importSample(url, cardID: card.id, label: "用户完整样板")
                card.sampleMedia?.append(sample)
            }
            document.styleCards.insert(card, at: 0)
            selectedStyleNodeID = card.id
            if publish { selectedStyleCardIDs = [card.id] }
            noticeMessage = publish
                ? "风格节点与样板已加密保存。"
                : "实验分支已持久化；生成或上传样板后可以发布。"
            await persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func editStyleNode(
        _ cardID: UUID,
        title: String,
        prompt: String,
        category: StylePromptCategory,
        tags: [String],
        notes: String,
        imageURLs: [URL]
    ) async {
        errorMessage = nil
        guard let index = document.styleCards.firstIndex(where: { $0.id == cardID }),
              !document.styleCards[index].isBuiltIn
        else {
            errorMessage = ArtDepartmentV2Error.cannotModifyBuiltIn.localizedDescription
            return
        }
        do {
            document.styleCards[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            document.styleCards[index].prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            document.styleCards[index].category = category
            document.styleCards[index].tags = tags
            document.styleCards[index].notes = notes
            document.styleCards[index].revisionNumber = document.styleCards[index].revisionValue + 1
            for url in imageURLs {
                let sample = try await importSample(url, cardID: cardID, label: "用户新增样板")
                document.styleCards[index].sampleMedia = document.styleCards[index].styleSampleMedia + [sample]
            }
            document.styleCards[index].updatedAt = .now
            noticeMessage = "风格节点已更新；后代分支会动态继承新的父提示词。"
            await persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addSampleImages(_ urls: [URL], to cardID: UUID) async {
        errorMessage = nil
        guard let index = document.styleCards.firstIndex(where: { $0.id == cardID }),
              !document.styleCards[index].isBuiltIn
        else {
            errorMessage = ArtDepartmentV2Error.cannotModifyBuiltIn.localizedDescription
            return
        }
        do {
            var media = document.styleCards[index].styleSampleMedia
            for url in urls {
                media.append(try await importSample(url, cardID: cardID, label: "用户完整样板"))
            }
            document.styleCards[index].sampleMedia = media
            document.styleCards[index].updatedAt = .now
            if !media.isEmpty, document.styleCards[index].isExperiment {
                document.styleCards[index].lifecycle = .library
            }
            noticeMessage = "样板已加密加入风格节点。"
            await persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeSample(_ sampleID: UUID, from cardID: UUID) {
        guard let index = document.styleCards.firstIndex(where: { $0.id == cardID }),
              !document.styleCards[index].isBuiltIn,
              let sample = document.styleCards[index].styleSampleMedia.first(where: {
                  $0.id == sampleID
              })
        else { return }
        document.styleCards[index].sampleMedia?.removeAll { $0.id == sampleID }
        document.styleCards[index].updatedAt = .now
        if document.styleCards[index].styleSampleMedia.isEmpty {
            document.styleCards[index].lifecycle = .experiment
            selectedStyleCardIDs.removeAll { $0 == cardID }
        }
        if let path = sample.encryptedLocalPath {
            styleImageDataByPath.removeValue(forKey: path)
        }
        Task {
            try? await persistence.deleteStyleMedia(at: sample.encryptedLocalPath)
            await persist()
        }
    }

    func toggleStyleArchive(_ cardID: UUID) {
        guard let index = document.styleCards.firstIndex(where: { $0.id == cardID }),
              !document.styleCards[index].isBuiltIn
        else { return }
        if document.styleCards[index].isArchived {
            document.styleCards[index].lifecycle = document.styleCards[index].styleSampleMedia.isEmpty
                ? .experiment
                : .library
            document.styleCards[index].archivedAt = nil
        } else {
            document.styleCards[index].lifecycle = .archived
            document.styleCards[index].archivedAt = .now
            selectedStyleCardIDs.removeAll { $0 == cardID }
        }
        document.styleCards[index].updatedAt = .now
        Task { await persist() }
    }

    func deleteStyleSubtree(_ cardID: UUID) {
        guard let root = styleCard(cardID), !root.isBuiltIn else {
            errorMessage = ArtDepartmentV2Error.cannotModifyBuiltIn.localizedDescription
            return
        }
        let ids = StylePromptResolver.descendants(of: cardID, in: document.styleCards)
        let deleting = document.styleCards.filter { ids.contains($0.id) && !$0.isBuiltIn }
        let paths = deleting.flatMap { $0.styleSampleMedia.compactMap(\.encryptedLocalPath) }
        document.styleCards.removeAll { ids.contains($0.id) && !$0.isBuiltIn }
        selectedStyleCardIDs.removeAll { ids.contains($0) }
        if selectedStyleNodeID.map(ids.contains) == true {
            selectedStyleNodeID = root.parentID
        }
        for path in paths { styleImageDataByPath.removeValue(forKey: path) }
        Task {
            for path in paths { try? await persistence.deleteStyleMedia(at: path) }
            await persist()
        }
    }

    func persistExternalStyleDraft() {
        let clean = externalStylePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            guard let id = activeExternalStyleDraftID,
                  let index = document.styleCards.firstIndex(where: { $0.id == id })
            else { return }
            document.styleCards[index].prompt = ""
            document.styleCards[index].updatedAt = .now
            Task { await persist() }
            return
        }
        let title = externalStyleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = activeExternalStyleDraftID,
           let index = document.styleCards.firstIndex(where: { $0.id == id })
        {
            document.styleCards[index].title = title.isEmpty ? "外部风格实验" : title
            document.styleCards[index].prompt = clean
            document.styleCards[index].category = externalStyleCategory
            document.styleCards[index].updatedAt = .now
            document.styleCards[index].lifecycle = .experiment
        } else {
            let card = StylePromptCard(
                title: title.isEmpty ? "外部风格实验" : title,
                prompt: clean,
                category: externalStyleCategory,
                tags: ["自动保存", "外部实验"],
                notes: "输入即持久化；测试结果会自动成为加密样板。",
                isPromptLocked: false,
                lifecycleRawValue: StylePromptLifecycle.experiment.rawValue,
                branchLabel: "外部实验",
                revisionNumber: 1,
                sampleMedia: []
            )
            document.styleCards.insert(card, at: 0)
            activeExternalStyleDraftID = card.id
        }
        Task { await persist() }
    }

    func restoreExternalStyleDraft() {
        let draft = document.styleCards
            .filter { $0.isExperiment && $0.tags.contains("外部实验") }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
        activeExternalStyleDraftID = draft?.id
        externalStyleTitle = draft?.title ?? ""
        externalStylePrompt = draft?.prompt ?? ""
        externalStyleCategory = draft?.category ?? .general
        selectedStyleNodeID = selectedStyleNodeID
            ?? document.styleCards.first(where: { !$0.isArchived })?.id
    }

    func promoteExternalStyleDraft() {
        guard let id = activeExternalStyleDraftID,
              let index = document.styleCards.firstIndex(where: { $0.id == id })
        else {
            errorMessage = ArtDepartmentV2Error.noSelectedStyle.localizedDescription
            return
        }
        guard !document.styleCards[index].styleSampleMedia.isEmpty else {
            errorMessage = ArtDepartmentV2Error.styleSampleRequired.localizedDescription
            return
        }
        document.styleCards[index].lifecycle = .library
        document.styleCards[index].tags = Array(Set(
            document.styleCards[index].tags + ["用户发布", "外部风格"]
        )).sorted()
        document.styleCards[index].updatedAt = .now
        selectedStyleCardIDs = [id]
        activeExternalStyleDraftID = nil
        externalStyleTitle = ""
        externalStylePrompt = ""
        noticeMessage = "外部实验已发布为可管理的正式风格节点。"
        Task { await persist() }
    }

    func attachGeneratedSampleToActiveExperiment(_ data: Data) async {
        guard let id = activeExternalStyleDraftID,
              let index = document.styleCards.firstIndex(where: { $0.id == id })
        else { return }
        do {
            let sampleID = UUID()
            let imported = try await persistence.importStyleSample(
                data: data,
                cardID: id,
                sampleID: sampleID
            )
            let sample = StyleSampleMedia(
                id: sampleID,
                encryptedLocalPath: imported.path,
                sha256: imported.sha256,
                sourceLabel: "本轮生成测试样板"
            )
            document.styleCards[index].sampleMedia = document.styleCards[index].styleSampleMedia + [sample]
            document.styleCards[index].updatedAt = .now
            styleImageDataByPath[imported.path] = data
            noticeMessage = "外部风格实验和生成样板已自动持久化。"
            await persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importSample(
        _ url: URL,
        cardID: UUID,
        label: String
    ) async throws -> StyleSampleMedia {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        try StyleSampleValidator.validate(data)
        if let duplicate = try await nearestDuplicateV4(data) {
            noticeMessage = "样板与“\(duplicate.title)”高度相似，但仍按当前节点保存，避免替用户改变分支关系。"
        }
        let sampleID = UUID()
        let imported = try await persistence.importStyleSample(
            data: data,
            cardID: cardID,
            sampleID: sampleID
        )
        styleImageDataByPath[imported.path] = data
        return StyleSampleMedia(
            id: sampleID,
            encryptedLocalPath: imported.path,
            sha256: imported.sha256,
            sourceLabel: label
        )
    }

    private func nearestDuplicateV4(_ imageData: Data) async throws -> StylePromptCard? {
        var best: (StylePromptCard, Double)?
        for card in document.styleCards {
            for sample in card.styleSampleMedia {
                guard let path = sample.encryptedLocalPath,
                      let existing = try await persistence.data(for: path)
                else { continue }
                guard let distance = try? await AppleVisionAnalyzer.shared.distance(
                    between: imageData,
                    and: existing
                ) else { continue }
                if best == nil || distance < best!.1 { best = (card, distance) }
            }
        }
        guard let best, best.1 < 0.035 else { return nil }
        return best.0
    }

    private func nextBranchOrder(parentID: UUID?) -> Int {
        let siblings = document.styleCards.filter { $0.parentID == parentID }
        return (siblings.map(\.branchOrderValue).max() ?? -1) + 1
    }
}
