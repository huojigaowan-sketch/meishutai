import Foundation
import NaturalLanguage

struct ScreenplayInventoryParser: Sendable {
    private static let characterStopwords: Set<String> = [
        "他", "她", "它", "他们", "她们", "众人", "大家", "所有人",
        "镜头", "画面", "字幕", "声音", "电话", "手机", "此时", "随后",
        "这时", "突然", "旁边", "远处", "屋内", "屋外", "时间", "地点",
        "场景", "人物", "角色", "备注", "说明", "转场", "特写"
    ]

    private static let speakerMetadataPattern = #"(?:\s*[（(][^）)]{0,24}[）)])|(?:\s+(?:O\.S\.|OS|V\.O\.|VO|OFF))+$"#
    private static let colonSpeakerPattern = #"^\s*([\p{Han}A-Za-z][\p{Han}A-Za-z0-9·._\- ]{0,23}?)(?:\s*[（(][^）)]{0,24}[）)])?\s*[：:]"#
    private static let actionCharacterPattern = #"(?:^|[，。！？；：\s])([老小]?[\p{Han}]{2,5})(?=\s*(?:走进|跑进|冲进|出现|站在|坐在|起身|拿起|递给|看向|望向|说道|说|问|喊|回答|点头|摇头))"#
    private static let castListPattern = #"(?:人物|角色|出场人物)\s*[：:]\s*(.+?)\s*$"#
    private static let castTokenPattern = #"[\p{Han}A-Za-z][\p{Han}A-Za-z0-9·._\-]{0,23}(?:\s*[（(][^）)]{0,24}[）)])?(?:\s*\\?\*[0-9０-９]+)?"#
    private static let measuredPropPattern = #"(?:一|两|几|数)?(?:个|把|支|部|台|辆|封|张|本|只|枚|件|套|瓶|杯|盒|块|根|串|顶)\s*([\p{Han}A-Za-z0-9·]{1,8}?)(?=\s*(?:被|把|由|在|从|向|往|放|拿|握|递|交|摆|落|掉|穿|走|跑|冲|出现|站|坐|打开|关上|藏|塞|扔|砸|举|端|拎|提|[，。！？；：,.!?]|$))"#
    private static let standaloneSpeakerForbiddenPattern = #"(?:走|跑|冲|进入|进来|出去|出现|站|坐|起身|拿|握|递|交|看|望|问|说|喊|回答|点头|摇头|打开|关上|转身|离开|穿过|放下|旁白|镜头|画面|字幕|场景|日/|夜/|INT\.?|EXT\.?)"#

    private static let propLexicon: [String] = [
        "手机", "电话", "钥匙", "钥匙串", "手枪", "步枪", "枪", "匕首", "刀",
        "剑", "信", "信封", "照片", "相框", "文件", "档案", "合同", "证件",
        "身份证", "护照", "电脑", "笔记本电脑", "平板电脑", "相机", "摄像机",
        "录音笔", "耳机", "对讲机", "手表", "怀表", "眼镜", "墨镜", "雨伞",
        "背包", "手提包", "行李箱", "钱包", "杯子", "酒杯", "酒瓶", "药瓶",
        "药盒", "针筒", "轮椅", "拐杖", "手电筒", "蜡烛", "打火机", "香烟",
        "烟盒", "书", "日记", "笔记本", "报纸", "地图", "名片", "卡片",
        "戒指", "项链", "耳环", "皇冠", "面具", "头盔", "绳子", "锁链",
        "锤子", "斧头", "剪刀", "扳手", "螺丝刀", "汽车", "摩托车", "自行车",
        "电动车", "安全帽", "竹编背篓", "背篓", "布带", "斗篷", "粗布口罩",
        "木板床", "硬板床", "陶锅", "粗陶锅", "砂锅", "铁锅", "米缸", "陶罐",
        "汤碗", "菜盘", "案板", "菜刀", "锅铲", "面盆", "擀面杖", "蒸笼",
        "火折子", "竹筒", "小木盒", "钱袋", "碎银", "铜板", "玉扣",
        "首饰", "柴刀", "木勺", "毛巾", "被子", "襁褓", "雨衣",
        "矿泉水", "米袋", "面粉", "大米", "红薯", "土豆", "鸡蛋", "方便面",
        "盐焗鸡", "腊肉", "鱼干", "白糖", "盐巴", "感冒灵颗粒", "布洛芬",
        "退烧药", "药片", "睡衣", "安睡裤", "卫生巾", "湿纸巾", "抽纸"
    ]

    func makeLedger(episode: ScriptEpisode) -> EpisodeExtractionLedger {
        makeLedger(
            episodeID: episode.id,
            sourceFingerprint: episode.contentFingerprint,
            script: episode.scriptText
        )
    }

    func makeLedger(
        episodeID: UUID,
        sourceFingerprint: String,
        script: String
    ) -> EpisodeExtractionLedger {
        let lines = sourceLines(in: script)
        let headings = EpisodeScriptSplitter.sceneHeadings(in: script)
        let scenes = makeScenes(
            episodeID: episodeID,
            sourceFingerprint: sourceFingerprint,
            script: script,
            lines: lines,
            headings: headings
        )
        var candidates: [StageOneCandidate] = []
        var decisions: [StageOneCandidateDecision] = []

        for scene in scenes {
            guard !scene.isPreamble else { continue }
            if let candidate = makeCandidate(
                kind: .scene,
                name: scene.canonicalLocationName,
                sceneID: scene.id,
                evidence: scene.headingSpan,
                origin: .sceneHeading,
                sourceFingerprint: sourceFingerprint
            ) {
                candidates.append(candidate)
                decisions.append(localAcceptance(
                    candidate: candidate,
                    canonicalName: scene.canonicalLocationName,
                    reason: "场景标题由本地格式解析器确定。"
                ))
            }

            let sceneLines = lines.filter {
                scene.sourceSpan.contains(utf16Offset: $0.utf16Location)
            }
            appendCastListCandidates(
                from: sceneLines,
                scene: scene,
                sourceFingerprint: sourceFingerprint,
                candidates: &candidates
            )
            appendCharacterCandidates(
                from: sceneLines,
                scene: scene,
                sourceFingerprint: sourceFingerprint,
                candidates: &candidates
            )
            appendPropCandidates(
                in: scene,
                script: script,
                sourceFingerprint: sourceFingerprint,
                candidates: &candidates
            )
            appendNamedEntities(
                in: scene,
                script: script,
                sourceFingerprint: sourceFingerprint,
                candidates: &candidates
            )
        }

        let uniqueCandidates = deduplicated(candidates)
        let validIDs = Set(uniqueCandidates.map(\.id))
        let uniqueDecisions = Dictionary(
            decisions.filter { validIDs.contains($0.candidateID) }.map {
                ($0.candidateID, $0)
            },
            uniquingKeysWith: { first, _ in first }
        ).values.sorted { $0.candidateID < $1.candidateID }

        return EpisodeExtractionLedger(
            episodeID: episodeID,
            sourceFingerprint: sourceFingerprint,
            scenes: scenes,
            candidates: uniqueCandidates,
            decisions: uniqueDecisions
        )
    }

    private struct SourceLine {
        let lineNumber: Int
        let utf16Location: Int
        let utf16LengthIncludingTerminator: Int
        let text: String
    }

    private func sourceLines(in script: String) -> [SourceLine] {
        let source = script as NSString
        guard source.length > 0 else { return [] }
        var result: [SourceLine] = []
        var location = 0
        var lineNumber = 1
        while location < source.length {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            source.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: location, length: 0)
            )
            result.append(SourceLine(
                lineNumber: lineNumber,
                utf16Location: lineStart,
                utf16LengthIncludingTerminator: lineEnd - lineStart,
                text: source.substring(
                    with: NSRange(location: lineStart, length: contentsEnd - lineStart)
                )
            ))
            guard lineEnd > location else { break }
            location = lineEnd
            lineNumber += 1
        }
        return result
    }

    private func makeScenes(
        episodeID: UUID,
        sourceFingerprint: String,
        script: String,
        lines: [SourceLine],
        headings: [EpisodeSceneHeading]
    ) -> [ScreenplaySceneUnit] {
        let source = script as NSString
        let headingLines = headings.compactMap { heading -> (EpisodeSceneHeading, SourceLine)? in
            guard let line = lines.first(where: { $0.lineNumber == heading.lineNumber }) else {
                return nil
            }
            return (heading, line)
        }
        var scenes: [ScreenplaySceneUnit] = []

        if let first = headingLines.first, first.1.utf16Location > 0 {
            let range = NSRange(location: 0, length: first.1.utf16Location)
            let text = source.substring(with: range)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let id = StableExtractionIdentity.sceneID(
                    sourceFingerprint: sourceFingerprint,
                    episodeID: episodeID,
                    utf16Location: 0,
                    heading: "片头/场次前文本"
                )
                let emptyHeading = SourceTextSpan(utf16Location: 0, text: "")
                scenes.append(ScreenplaySceneUnit(
                    id: id,
                    episodeID: episodeID,
                    order: 0,
                    sceneIdentifier: "preamble",
                    heading: "",
                    canonicalLocationName: "",
                    locationGroup: nil,
                    timeOfDayID: PromptParameter.noneOptionID,
                    interiorExterior: nil,
                    headingSpan: emptyHeading,
                    sourceSpan: SourceTextSpan(utf16Location: 0, text: text),
                    isPreamble: true
                ))
            }
        }

        for (index, pair) in headingLines.enumerated() {
            let heading = pair.0
            let line = pair.1
            let nextLocation = index + 1 < headingLines.count
                ? headingLines[index + 1].1.utf16Location
                : source.length
            guard nextLocation >= line.utf16Location else { continue }
            let sceneText = source.substring(with: NSRange(
                location: line.utf16Location,
                length: nextLocation - line.utf16Location
            ))
            let headingText = line.text
            let parsed = parseHeading(headingText)
            let locationName = parsed.location.isEmpty
                ? "未命名场景 \(index + 1)"
                : parsed.location
            let id = StableExtractionIdentity.sceneID(
                sourceFingerprint: sourceFingerprint,
                episodeID: episodeID,
                utf16Location: line.utf16Location,
                heading: headingText
            )
            scenes.append(ScreenplaySceneUnit(
                id: id,
                episodeID: episodeID,
                order: index + 1,
                sceneIdentifier: heading.sceneIdentifier ?? "\(episodeID.uuidString)-\(index + 1)",
                heading: headingText,
                canonicalLocationName: locationName,
                locationGroup: locationGroup(from: locationName),
                timeOfDayID: parsed.timeOfDayID,
                interiorExterior: parsed.interiorExterior,
                headingSpan: SourceTextSpan(
                    utf16Location: line.utf16Location,
                    text: headingText
                ),
                sourceSpan: SourceTextSpan(
                    utf16Location: line.utf16Location,
                    text: sceneText,
                    excerptLimit: 360
                ),
                isPreamble: false
            ))
        }
        return scenes
    }

    private func parseHeading(
        _ heading: String
    ) -> (location: String, timeOfDayID: String, interiorExterior: String?) {
        var value = heading
            .replacingOccurrences(
                of: #"^\s*(?:>\s*)?(?:[-+]\s+)?(?:#{1,6}\s*)?(?:\*{1,3}|_{1,3})?\s*"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"^\s*(?:[0-9０-９]{1,4}\s*[-—–－]\s*[0-9０-９]{1,3}[A-Za-z]?|(?:场|場|SCENE)\s*[0-9０-９一二三四五六七八九十百零〇两]+)\s*[\.、:：\-—–－]?\s*"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )

        let upper = value.uppercased()
        let interiorExterior: String?
        if upper.contains("INT.") || upper.hasPrefix("INT ") || value.contains("内") {
            interiorExterior = "interior"
        } else if upper.contains("EXT.") || upper.hasPrefix("EXT ") || value.contains("外") {
            interiorExterior = "exterior"
        } else {
            interiorExterior = nil
        }

        let timeOfDayID: String
        if value.range(of: "凌晨|午夜|MIDNIGHT", options: [.regularExpression, .caseInsensitive]) != nil {
            timeOfDayID = "midnight"
        } else if value.range(of: "清晨|黎明|拂晓|DAWN", options: [.regularExpression, .caseInsensitive]) != nil {
            timeOfDayID = "dawn"
        } else if value.range(of: "黄昏|傍晚|DUSK|SUNSET", options: [.regularExpression, .caseInsensitive]) != nil {
            timeOfDayID = "dusk"
        } else if value.range(of: "夜|晚|NIGHT", options: [.regularExpression, .caseInsensitive]) != nil {
            timeOfDayID = "night"
        } else if value.range(of: "日|昼|白天|DAY", options: [.regularExpression, .caseInsensitive]) != nil {
            timeOfDayID = "day"
        } else {
            timeOfDayID = PromptParameter.noneOptionID
        }

        value = value.replacingOccurrences(
            of: #"\s+(?:人物|角色|出场人物)\s*[：:].*$"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"(?:^|[\s/·\-—–－])(?:INT\.?|EXT\.?|I/E\.?|内|外|内景|外景|日|夜|晨|午|晚|昼|清晨|凌晨|午夜|黄昏|傍晚|DAY|NIGHT|DAWN|DUSK|SUNSET)(?=$|[\s/·\-—–－])"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        value = value.replacingOccurrences(
            of: #"[\s/]+"#,
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value, timeOfDayID, interiorExterior)
    }

    private func locationGroup(from location: String) -> String? {
        let separators = ["·", "-", "—", "/"]
        for separator in separators {
            if let first = location.components(separatedBy: separator).first,
               first != location {
                let value = first.trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    private func appendCharacterCandidates(
        from lines: [SourceLine],
        scene: ScreenplaySceneUnit,
        sourceFingerprint: String,
        candidates: inout [StageOneCandidate]
    ) {
        for (index, line) in lines.enumerated() {
            guard line.utf16Location != scene.headingSpan.utf16Location else {
                continue
            }
            if let match = firstMatch(pattern: Self.colonSpeakerPattern, in: line.text),
               let nameRange = Range(match.range(at: 1), in: line.text) {
                let rawName = cleanedCharacterName(String(line.text[nameRange]))
                let localLocation = NSRange(
                    line.text.startIndex..<nameRange.lowerBound,
                    in: line.text
                ).length
                if let candidate = makeCandidate(
                    kind: .character,
                    name: rawName,
                    sceneID: scene.id,
                    evidence: SourceTextSpan(
                        utf16Location: line.utf16Location + localLocation,
                        text: String(line.text[nameRange])
                    ),
                    origin: .speakerCue,
                    sourceFingerprint: sourceFingerprint
                ) {
                    candidates.append(candidate)
                }
            } else if isStandaloneSpeakerLine(line.text),
                      hasLikelyDialogue(after: index, in: lines) {
                let rawName = cleanedCharacterName(line.text)
                if let candidate = makeCandidate(
                    kind: .character,
                    name: rawName,
                    sceneID: scene.id,
                    evidence: SourceTextSpan(
                        utf16Location: line.utf16Location,
                        text: line.text
                    ),
                    origin: .speakerCue,
                    sourceFingerprint: sourceFingerprint
                ) {
                    candidates.append(candidate)
                }
            }

            for match in matches(pattern: Self.actionCharacterPattern, in: line.text) {
                guard let range = Range(match.range(at: 1), in: line.text) else { continue }
                let rawName = cleanedCharacterName(String(line.text[range]))
                let prefixRange = NSRange(line.text.startIndex..<range.lowerBound, in: line.text)
                if let candidate = makeCandidate(
                    kind: .character,
                    name: rawName,
                    sceneID: scene.id,
                    evidence: SourceTextSpan(
                        utf16Location: line.utf16Location + prefixRange.length,
                        text: String(line.text[range])
                    ),
                    origin: .actionName,
                    sourceFingerprint: sourceFingerprint
                ) {
                    candidates.append(candidate)
                }
            }
        }
    }

    private func appendCastListCandidates(
        from lines: [SourceLine],
        scene: ScreenplaySceneUnit,
        sourceFingerprint: String,
        candidates: inout [StageOneCandidate]
    ) {
        guard let headingLine = lines.first(where: {
            $0.utf16Location == scene.headingSpan.utf16Location
        }),
        let listMatch = firstMatch(pattern: Self.castListPattern, in: headingLine.text),
        let listRange = Range(listMatch.range(at: 1), in: headingLine.text)
        else {
            return
        }

        let castList = String(headingLine.text[listRange])
        let listPrefixLength = NSRange(
            headingLine.text.startIndex..<listRange.lowerBound,
            in: headingLine.text
        ).length
        for tokenMatch in matches(pattern: Self.castTokenPattern, in: castList) {
            guard let tokenRange = Range(tokenMatch.range, in: castList) else { continue }
            let sourceToken = String(castList[tokenRange])
            let rawName = cleanedCharacterName(
                sourceToken.replacingOccurrences(
                    of: #"\s*\\?\*[0-9０-９]+\s*$"#,
                    with: "",
                    options: .regularExpression
                )
            )
            let tokenPrefixLength = NSRange(
                castList.startIndex..<tokenRange.lowerBound,
                in: castList
            ).length
            guard let candidate = makeCandidate(
                kind: .character,
                name: rawName,
                sceneID: scene.id,
                evidence: SourceTextSpan(
                    utf16Location: headingLine.utf16Location
                        + listPrefixLength
                        + tokenPrefixLength,
                    text: sourceToken
                ),
                origin: .castList,
                sourceFingerprint: sourceFingerprint
            ) else {
                continue
            }
            candidates.append(candidate)
        }
    }

    private func appendPropCandidates(
        in scene: ScreenplaySceneUnit,
        script: String,
        sourceFingerprint: String,
        candidates: inout [StageOneCandidate]
    ) {
        guard let sceneText = scene.sourceSpan.text(in: script) else { return }
        let sceneNSString = sceneText as NSString
        var occupiedLexiconRanges: [NSRange] = []
        for prop in Self.propLexicon.sorted(by: { $0.utf16.count > $1.utf16.count }) {
            var searchRange = NSRange(location: 0, length: sceneNSString.length)
            while searchRange.length > 0 {
                let found = sceneNSString.range(of: prop, options: [], range: searchRange)
                guard found.location != NSNotFound else { break }
                let overlapsLongerMatch = occupiedLexiconRanges.contains {
                    NSIntersectionRange($0, found).length > 0
                }
                if !overlapsLongerMatch, let candidate = makeCandidate(
                    kind: .prop,
                    name: prop,
                    sceneID: scene.id,
                    evidence: SourceTextSpan(
                        utf16Location: scene.sourceSpan.utf16Location + found.location,
                        text: sceneNSString.substring(with: found)
                    ),
                    origin: .propLexicon,
                    sourceFingerprint: sourceFingerprint
                ) {
                    candidates.append(candidate)
                    occupiedLexiconRanges.append(found)
                }
                let nextLocation = found.location + max(found.length, 1)
                guard nextLocation < sceneNSString.length else { break }
                searchRange = NSRange(
                    location: nextLocation,
                    length: sceneNSString.length - nextLocation
                )
            }
        }

        for match in matches(pattern: Self.measuredPropPattern, in: sceneText) {
            guard let range = Range(match.range(at: 1), in: sceneText) else { continue }
            let rawName = String(sceneText[range])
            let prefix = NSRange(sceneText.startIndex..<range.lowerBound, in: sceneText)
            let measuredRange = NSRange(location: prefix.length, length: rawName.utf16.count)
            guard !occupiedLexiconRanges.contains(where: {
                NSIntersectionRange($0, measuredRange).length > 0
            }) else {
                continue
            }
            if let candidate = makeCandidate(
                kind: .prop,
                name: rawName,
                sceneID: scene.id,
                evidence: SourceTextSpan(
                    utf16Location: scene.sourceSpan.utf16Location + prefix.length,
                    text: rawName
                ),
                origin: .propPattern,
                sourceFingerprint: sourceFingerprint
            ) {
                candidates.append(candidate)
            }
        }
    }

    private func appendNamedEntities(
        in scene: ScreenplaySceneUnit,
        script: String,
        sourceFingerprint: String,
        candidates: inout [StageOneCandidate]
    ) {
        guard NLTagger.availableTagSchemes(
            for: .word,
            language: .simplifiedChinese
        ).contains(.nameType),
        let sceneText = scene.sourceSpan.text(in: script),
        !sceneText.isEmpty else {
            return
        }

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = sceneText
        tagger.setLanguage(.simplifiedChinese, range: sceneText.startIndex..<sceneText.endIndex)
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        tagger.enumerateTags(
            in: sceneText.startIndex..<sceneText.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, range in
            guard tag == .personalName else { return true }
            let rawName = String(sceneText[range])
            let prefix = NSRange(sceneText.startIndex..<range.lowerBound, in: sceneText)
            if let candidate = makeCandidate(
                kind: .character,
                name: rawName,
                sceneID: scene.id,
                evidence: SourceTextSpan(
                    utf16Location: scene.sourceSpan.utf16Location + prefix.length,
                    text: rawName
                ),
                origin: .namedEntity,
                sourceFingerprint: sourceFingerprint
            ) {
                candidates.append(candidate)
            }
            return true
        }
    }

    private func makeCandidate(
        kind: AssetKind,
        name: String,
        sceneID: String,
        evidence: SourceTextSpan,
        origin: CandidateOrigin,
        sourceFingerprint: String
    ) -> StageOneCandidate? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = CanonicalAssetIdentity.normalizedName(cleaned, kind: kind)
        guard !cleaned.isEmpty,
              !normalized.isEmpty,
              !(kind == .character && Self.characterStopwords.contains(cleaned))
        else {
            return nil
        }
        return StageOneCandidate(
            id: StableExtractionIdentity.candidateID(
                sourceFingerprint: sourceFingerprint,
                kind: kind,
                normalizedName: normalized,
                sceneID: sceneID,
                utf16Location: evidence.utf16Location,
                origin: origin
            ),
            kind: kind,
            rawName: cleaned,
            normalizedName: normalized,
            sceneID: sceneID,
            evidence: evidence,
            origin: origin
        )
    }

    private func localAcceptance(
        candidate: StageOneCandidate,
        canonicalName: String,
        reason: String
    ) -> StageOneCandidateDecision {
        StageOneCandidateDecision(
            candidateID: candidate.id,
            disposition: .accepted,
            canonicalName: canonicalName,
            identityQualifier: nil,
            variantLabel: nil,
            reason: reason,
            confidence: 1
        )
    }

    private func deduplicated(
        _ candidates: [StageOneCandidate]
    ) -> [StageOneCandidate] {
        var seen = Set<String>()
        return candidates.sorted {
            if $0.evidence.utf16Location != $1.evidence.utf16Location {
                return $0.evidence.utf16Location < $1.evidence.utf16Location
            }
            if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
            if originPriority($0.origin) != originPriority($1.origin) {
                return originPriority($0.origin) < originPriority($1.origin)
            }
            return $0.id < $1.id
        }.filter { candidate in
            let key = [
                candidate.kind.rawValue,
                candidate.sceneID,
                candidate.normalizedName,
                String(candidate.evidence.utf16Location)
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    private func originPriority(_ origin: CandidateOrigin) -> Int {
        switch origin {
        case .sceneHeading: 0
        case .castList: 1
        case .speakerCue: 2
        case .propLexicon: 3
        case .actionName: 4
        case .namedEntity: 5
        case .propPattern: 6
        case .modelGapScan: 7
        }
    }

    private func cleanedCharacterName(_ rawValue: String) -> String {
        rawValue.replacingOccurrences(
            of: Self.speakerMetadataPattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isStandaloneSpeakerLine(_ rawValue: String) -> Bool {
        let value = cleanedCharacterName(rawValue)
        guard !value.isEmpty,
              value.count <= 12,
              !Self.characterStopwords.contains(value),
              value.range(of: #"[，。！？；：,:!?。\[\]{}<>]"#, options: .regularExpression) == nil,
              value.range(
                of: Self.standaloneSpeakerForbiddenPattern,
                options: [.regularExpression, .caseInsensitive]
              ) == nil
        else {
            return false
        }
        let containsHan = value.unicodeScalars.contains {
            (0x4E00...0x9FFF).contains($0.value)
        }
        let isUppercaseLatin = value.rangeOfCharacter(
            from: CharacterSet.letters
        ) != nil && value == value.uppercased()
        return containsHan || isUppercaseLatin
    }

    private func hasLikelyDialogue(
        after index: Int,
        in lines: [SourceLine]
    ) -> Bool {
        for next in lines.dropFirst(index + 1).prefix(3) {
            let trimmed = next.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            return EpisodeScriptSplitter.sceneHeadings(in: next.text).isEmpty
                && trimmed.count >= 2
        }
        return false
    }

    private func firstMatch(
        pattern: String,
        in text: String
    ) -> NSTextCheckingResult? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }
        return expression.firstMatch(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        )
    }

    private func matches(
        pattern: String,
        in text: String
    ) -> [NSTextCheckingResult] {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return []
        }
        return expression.matches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        )
    }
}
