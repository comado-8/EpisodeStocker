import Foundation

struct HomeAdvancedFilterDraft: Equatable {
    enum TalkCountPreset: String, CaseIterable, Equatable {
        case zero = "0回"
        case atLeastOne = "1回以上"
        case atLeastThree = "3回以上"
    }

    var talkCountPreset: TalkCountPreset? = nil
    var startDate: Date? = nil
    var endDate: Date? = nil
    var episodeDateStart: Date? = nil
    var episodeDateEnd: Date? = nil
    var mediaTypes: Set<String> = []
    var reactions: Set<ReleaseLogOutcome> = []

    init(
        talkCountPreset: TalkCountPreset? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        episodeDateStart: Date? = nil,
        episodeDateEnd: Date? = nil,
        mediaTypes: Set<String> = [],
        reactions: Set<ReleaseLogOutcome> = []
    ) {
        self.talkCountPreset = talkCountPreset
        self.startDate = startDate
        self.endDate = endDate
        self.episodeDateStart = episodeDateStart
        self.episodeDateEnd = episodeDateEnd
        self.mediaTypes = mediaTypes
        self.reactions = reactions
    }

    init(tokens: [HomeSearchFilterToken]) {
        for token in tokens {
            switch token.field {
            case .talkCount:
                if let preset = Self.talkCountPreset(from: token.value) {
                    talkCountPreset = preset
                }
            case .lastTalkedAt:
                if let range = Self.parseDateRange(token.value) {
                    startDate = range.start
                    endDate = range.end
                }
            case .registeredDate:
                if let range = Self.parseDateRange(token.value) {
                    episodeDateStart = range.start
                    episodeDateEnd = range.end
                }
            case .mediaType:
                mediaTypes.insert(token.value)
            case .reaction:
                if let reaction = ReleaseLogOutcome(rawValue: token.value) {
                    reactions.insert(reaction)
                }
            case .tag, .person, .project, .emotion, .place:
                continue
            }
        }
    }

    var hasAnyCondition: Bool {
        talkCountPreset != nil
            || startDate != nil
            || endDate != nil
            || episodeDateStart != nil
            || episodeDateEnd != nil
            || !mediaTypes.isEmpty
            || !reactions.isEmpty
    }

    mutating func clearHistoryConditions() {
        talkCountPreset = nil
        startDate = nil
        endDate = nil
        episodeDateStart = nil
        episodeDateEnd = nil
        mediaTypes.removeAll()
        reactions.removeAll()
    }

    func toHistoryTokens() -> [HomeSearchFilterToken] {
        var tokens: [HomeSearchFilterToken] = []

        if let talkCountPreset,
           let token = HomeSearchFilterToken(field: .talkCount, value: talkCountPreset.rawValue)
        {
            tokens.append(token)
        }

        if let value = Self.makeDateRangeTokenValue(start: startDate, end: endDate) {
            if let token = HomeSearchFilterToken(field: .lastTalkedAt, value: value) {
                tokens.append(token)
            }
        }

        if let value = Self.makeDateRangeTokenValue(start: episodeDateStart, end: episodeDateEnd) {
            if let token = HomeSearchFilterToken(field: .registeredDate, value: value) {
                tokens.append(token)
            }
        }

        for mediaType in sortedMediaTypes() {
            if let token = HomeSearchFilterToken(field: .mediaType, value: mediaType) {
                tokens.append(token)
            }
        }

        for outcome in ReleaseLogOutcome.allCases where reactions.contains(outcome) {
            if let token = HomeSearchFilterToken(field: .reaction, value: outcome.rawValue) {
                tokens.append(token)
            }
        }

        return tokens
    }

    static func removingHistoryTokens(from tokens: [HomeSearchFilterToken]) -> [HomeSearchFilterToken] {
        tokens.filter { !isHistoryField($0.field) }
    }

    static func isHistoryField(_ field: HomeSearchField) -> Bool {
        historyFields.contains(field)
    }

    private func sortedMediaTypes() -> [String] {
        let presetOrder = ReleaseLogMediaPreset.allCases.map(\.rawValue)
        let values = Array(mediaTypes)
        return values.sorted { lhs, rhs in
            let lhsIndex = presetOrder.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = presetOrder.firstIndex(of: rhs) ?? Int.max
            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }
            return lhs < rhs
        }
    }

    private static func talkCountPreset(from raw: String) -> TalkCountPreset? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
        case TalkCountPreset.zero.rawValue:
            return .zero
        case TalkCountPreset.atLeastOne.rawValue:
            return .atLeastOne
        case TalkCountPreset.atLeastThree.rawValue:
            return .atLeastThree
        default:
            return nil
        }
    }

    private static func parseDateRange(_ raw: String) -> (start: Date?, end: Date?)? {
        HomeDateRangeParser.parseDateRange(raw)
    }

    private static func parseDate(_ raw: String) -> Date? {
        HomeDateRangeParser.parseDate(raw)
    }

    private static let historyFields: Set<HomeSearchField> = [
        .talkCount, .lastTalkedAt, .registeredDate, .mediaType, .reaction
    ]

    private static func makeDateRangeTokenValue(start: Date?, end: Date?) -> String? {
        guard start != nil || end != nil else { return nil }
        if let start, let end {
            let normalizedStart = min(start, end)
            let normalizedEnd = max(start, end)
            return "\(dateFormatter.string(from: normalizedStart))~\(dateFormatter.string(from: normalizedEnd))"
        }
        if let start {
            return "\(dateFormatter.string(from: start))~"
        }
        guard let end else { return nil }
        return "~\(dateFormatter.string(from: end))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
}
