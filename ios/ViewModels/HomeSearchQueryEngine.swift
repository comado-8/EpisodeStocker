import Foundation

enum HomeSearchField: String, CaseIterable {
    case tag
    case person
    case project
    case emotion
    case place
    case talkCount
    case lastTalkedAt
    case registeredDate
    case mediaType
    case reaction

    var label: String {
        switch self {
        case .tag:
            return "タグ"
        case .person:
            return "人物"
        case .project:
            return "企画名"
        case .emotion:
            return "感情"
        case .place:
            return "場所"
        case .talkCount:
            return "話した回数"
        case .lastTalkedAt:
            return "話した日"
        case .registeredDate:
            return "エピソード日付"
        case .mediaType:
            return "媒体"
        case .reaction:
            return "リアクション"
        }
    }

    var aliases: [String] {
        switch self {
        case .tag:
            return ["タグ", "tag", "#"]
        case .person:
            return ["人物", "who", "person"]
        case .project:
            return ["企画", "企画名", "project"]
        case .emotion:
            return ["感情", "emotion"]
        case .place:
            return ["場所", "where", "place"]
        case .talkCount:
            return ["話した回数", "回数", "talk count"]
        case .lastTalkedAt:
            return ["話した日", "トーク日", "最終トーク日", "最終", "last talked"]
        case .registeredDate:
            return ["エピソード日付", "登録日", "episode date", "date"]
        case .mediaType:
            return ["媒体", "メディア", "media"]
        case .reaction:
            return ["リアクション", "手応え", "reaction"]
        }
    }

    var symbolName: String {
        switch self {
        case .tag:
            return "tag"
        case .person:
            return "person"
        case .project:
            return "sparkles.rectangle.stack"
        case .emotion:
            return "face.smiling"
        case .place:
            return "mappin.and.ellipse"
        case .talkCount:
            return "number"
        case .lastTalkedAt:
            return "calendar"
        case .registeredDate:
            return "calendar.badge.clock"
        case .mediaType:
            return "tv"
        case .reaction:
            return "hand.thumbsup"
        }
    }

    func matchesAlias(_ query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        if label.lowercased().contains(normalized) {
            return true
        }
        return aliases.contains(where: { $0.lowercased().contains(normalized) })
    }
}

struct HomeSearchFilterToken: Identifiable, Hashable {
    let field: HomeSearchField
    let value: String

    init?(field: HomeSearchField, value: String) {
        let normalized = HomeSearchQueryEngine.normalizeTokenValue(value, field: field)
        guard !normalized.isEmpty else { return nil }
        self.field = field
        self.value = normalized
    }

    var id: String {
        "\(field.rawValue):\(canonicalValue)"
    }

    var displayText: String {
        "\(field.label):\(value)"
    }

    private var canonicalValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func == (lhs: HomeSearchFilterToken, rhs: HomeSearchFilterToken) -> Bool {
        lhs.field == rhs.field && lhs.canonicalValue == rhs.canonicalValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(field)
        hasher.combine(canonicalValue)
    }
}

struct HomeSearchQueryState {
    var freeText: String = ""
    var tokens: [HomeSearchFilterToken] = []
    var activeField: HomeSearchField? = nil

    var trimmedFreeText: String {
        freeText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasAnyCondition: Bool {
        !trimmedFreeText.isEmpty || !tokens.isEmpty
    }
}

enum HomeSearchSuggestionKind: Hashable {
    case selectField(HomeSearchField)
    case value(field: HomeSearchField, value: String)

    var field: HomeSearchField {
        switch self {
        case .selectField(let field):
            return field
        case .value(let field, _):
            return field
        }
    }
}

struct HomeSearchSuggestionItem: Identifiable, Hashable {
    let kind: HomeSearchSuggestionKind

    var id: String {
        switch kind {
        case .selectField(let field):
            return "select:\(field.rawValue)"
        case .value(let field, let value):
            return "value:\(field.rawValue):\(value.lowercased())"
        }
    }

    var title: String {
        switch kind {
        case .selectField(let field):
            return "\(field.label)で絞り込む"
        case .value(let field, let value):
            return "\(field.label): \(value)"
        }
    }

    var subtitle: String {
        switch kind {
        case .selectField(let field):
            return "次の入力を\(field.label)として扱います"
        case .value:
            return "候補から追加"
        }
    }

    var symbolName: String {
        kind.field.symbolName
    }
}

enum HomeSearchQueryEngine {
    private static let talkCountSuggestionValues = ["0回", "1回以上", "3回以上"]
    private static let lastTalkedSuggestionValues = ["7日以内", "30日以内", "90日以内", "今年"]

    static func matches(
        episode: Episode,
        statusFilter: HomeStatusFilter,
        search: HomeSearchQueryState
    ) -> Bool {
        guard matchesStatus(episode: episode, statusFilter: statusFilter) else {
            return false
        }

        let trimmedFreeText = search.trimmedFreeText
        if !trimmedFreeText.isEmpty {
            let body = episode.body ?? ""
            let matchesFreeText = episode.title.localizedCaseInsensitiveContains(trimmedFreeText)
                || body.localizedCaseInsensitiveContains(trimmedFreeText)
            guard matchesFreeText else {
                return false
            }
        }

        guard !search.tokens.isEmpty else { return true }

        let grouped = Dictionary(grouping: search.tokens, by: \.field)
        for field in HomeSearchField.allCases {
            guard let fieldTokens = grouped[field], !fieldTokens.isEmpty else { continue }
            let matchedAny = fieldTokens.contains { token in
                matchesField(episode: episode, field: field, query: token.value)
            }
            if !matchedAny {
                return false
            }
        }
        return true
    }

    static func suggestions(
        for search: HomeSearchQueryState,
        episodes: [Episode],
        maxValuesPerField: Int = 3
    ) -> [HomeSearchSuggestionItem] {
        let trimmed = search.trimmedFreeText
        let valueCounts = buildValueCounts(episodes: episodes)

        if let activeField = search.activeField {
            return suggestionsForActiveField(
                activeField,
                query: trimmed,
                valueCounts: valueCounts,
                maxValuesPerField: maxValuesPerField
            )
        }

        guard !trimmed.isEmpty else { return [] }

        var items: [HomeSearchSuggestionItem] = []
        for field in HomeSearchField.allCases {
            let values = rankedValues(
                for: field,
                query: trimmed,
                valueCounts: valueCounts,
                maxCount: maxValuesPerField
            )
            items.append(
                contentsOf: values.map { HomeSearchSuggestionItem(kind: .value(field: field, value: $0)) })
        }

        return deduplicated(items)
    }

    static func normalizeTokenValue(_ raw: String, field: HomeSearchField) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        switch field {
        case .tag:
            trimmed = EpisodePersistence.normalizeTagName(trimmed)?.name ?? ""
        case .person:
            trimmed = stripPersonHonorific(trimmed)
        case .talkCount:
            trimmed = normalizeTalkCountToken(trimmed)
        case .lastTalkedAt:
            trimmed = normalizeLastTalkedAtToken(trimmed)
        case .registeredDate:
            trimmed = normalizeLastTalkedAtToken(trimmed)
        case .mediaType:
            trimmed = normalizeMediaTypeToken(trimmed)
        case .reaction:
            trimmed = normalizeReactionToken(trimmed)
        case .project, .emotion, .place:
            break
        }

        return trimmed
    }

    private static func suggestionsForActiveField(
        _ field: HomeSearchField,
        query: String,
        valueCounts: [HomeSearchField: [String: Int]],
        maxValuesPerField: Int
    ) -> [HomeSearchSuggestionItem] {
        let values = rankedValues(
            for: field,
            query: query,
            valueCounts: valueCounts,
            maxCount: maxValuesPerField
        )

        let items = values.map { HomeSearchSuggestionItem(kind: .value(field: field, value: $0)) }
        return deduplicated(items)
    }

    private static func matchesStatus(episode: Episode, statusFilter: HomeStatusFilter) -> Bool {
        switch statusFilter {
        case .ok:
            return episode.isUnlocked
        case .locked:
            return !episode.isUnlocked
        case .all:
            return true
        }
    }

    private static func matchesField(episode: Episode, field: HomeSearchField, query: String) -> Bool {
        let normalizedQuery = normalizeTokenValue(query, field: field)
        guard !normalizedQuery.isEmpty else { return false }

        switch field {
        case .tag:
            let lower = normalizedQuery.lowercased()
            return episode.tags
                .filter { !$0.isSoftDeleted }
                .contains(where: {
                    normalizeTokenValue($0.name, field: .tag).lowercased().contains(lower)
                })
        case .person:
            let lower = normalizedQuery.lowercased()
            return episode.persons
                .filter { !$0.isSoftDeleted }
                .contains(where: { $0.name.lowercased().contains(lower) })
        case .project:
            let lower = normalizedQuery.lowercased()
            return episode.projects
                .filter { !$0.isSoftDeleted }
                .contains(where: { $0.name.lowercased().contains(lower) })
        case .emotion:
            let lower = normalizedQuery.lowercased()
            return episode.emotions
                .filter { !$0.isSoftDeleted }
                .contains(where: { $0.name.lowercased().contains(lower) })
        case .place:
            let lower = normalizedQuery.lowercased()
            return episode.places
                .filter { !$0.isSoftDeleted }
                .contains(where: { $0.name.lowercased().contains(lower) })
        case .talkCount:
            guard let criteria = parseTalkCountCriteria(normalizedQuery) else { return false }
            return criteria.matches(episode.talkedCount)
        case .lastTalkedAt:
            guard let criteria = parseLastTalkedAtCriteria(normalizedQuery) else { return false }
            let now = Date()
            let calendar = Calendar(identifier: .gregorian)
            return episode.activeUnlockLogs.contains { log in
                criteria.contains(date: log.talkedAt, now: now, calendar: calendar)
            }
        case .registeredDate:
            guard let criteria = parseLastTalkedAtCriteria(normalizedQuery) else { return false }
            return criteria.contains(
                date: episode.date,
                now: Date(),
                calendar: Calendar(identifier: .gregorian)
            )
        case .mediaType:
            let lower = normalizedQuery.lowercased()
            return episode.activeUnlockLogs.contains { log in
                let value = normalizeMediaTypeToken(log.mediaType ?? "").lowercased()
                return !value.isEmpty && value.contains(lower)
            }
        case .reaction:
            let canonical = normalizeReactionToken(normalizedQuery)
            return episode.activeUnlockLogs.contains { log in
                normalizeReactionToken(log.reaction) == canonical
            }
        }
    }

    private static func buildValueCounts(episodes: [Episode]) -> [HomeSearchField: [String: Int]] {
        [
            .tag: countValues(in: episodes, field: .tag) { episode in
                episode.tags.map { (name: $0.name, isSoftDeleted: $0.isSoftDeleted) }
            },
            .person: countValues(in: episodes, field: .person) { episode in
                episode.persons.map { (name: $0.name, isSoftDeleted: $0.isSoftDeleted) }
            },
            .project: countValues(in: episodes, field: .project) { episode in
                episode.projects.map { (name: $0.name, isSoftDeleted: $0.isSoftDeleted) }
            },
            .emotion: countValues(in: episodes, field: .emotion) { episode in
                episode.emotions.map { (name: $0.name, isSoftDeleted: $0.isSoftDeleted) }
            },
            .place: countValues(in: episodes, field: .place) { episode in
                episode.places.map { (name: $0.name, isSoftDeleted: $0.isSoftDeleted) }
            },
            .talkCount: talkCountValueCounts(episodes: episodes),
            .lastTalkedAt: lastTalkedAtValueCounts(episodes: episodes),
            .registeredDate: registeredDateValueCounts(episodes: episodes),
            .mediaType: mergePresetValues(
                base: countLogValues(in: episodes, field: .mediaType) { episode in
                    episode.activeUnlockLogs.compactMap(\.mediaType)
                },
                presets: ReleaseLogMediaPreset.allCases.map(\.rawValue)
            ),
            .reaction: mergePresetValues(
                base: countLogValues(in: episodes, field: .reaction) { episode in
                    episode.activeUnlockLogs.map(\.reaction)
                },
                presets: ReleaseLogOutcome.allCases.map(\.rawValue)
            )
        ]
    }

    private static func countValues(
        in episodes: [Episode],
        field: HomeSearchField,
        extractor: (Episode) -> [(name: String, isSoftDeleted: Bool)]
    ) -> [String: Int] {
        var countsByCanonical: [String: Int] = [:]
        var displayByCanonical: [String: String] = [:]
        for episode in episodes {
            for value in extractor(episode) where !value.isSoftDeleted {
                let normalized = normalizeTokenValue(value.name, field: field)
                guard !normalized.isEmpty else { continue }
                let canonical = normalized.lowercased()
                countsByCanonical[canonical, default: 0] += 1
                if displayByCanonical[canonical] == nil {
                    displayByCanonical[canonical] = normalized
                }
            }
        }

        var counts: [String: Int] = [:]
        for (canonical, count) in countsByCanonical {
            let displayValue = displayByCanonical[canonical] ?? canonical
            counts[displayValue] = count
        }
        return counts
    }

    private static func countLogValues(
        in episodes: [Episode],
        field: HomeSearchField,
        extractor: (Episode) -> [String]
    ) -> [String: Int] {
        var countsByCanonical: [String: Int] = [:]
        var displayByCanonical: [String: String] = [:]

        for episode in episodes {
            for raw in extractor(episode) {
                let normalized = normalizeTokenValue(raw, field: field)
                guard !normalized.isEmpty else { continue }
                let canonical = normalized.lowercased()
                countsByCanonical[canonical, default: 0] += 1
                if displayByCanonical[canonical] == nil {
                    displayByCanonical[canonical] = normalized
                }
            }
        }

        var result: [String: Int] = [:]
        for (canonical, count) in countsByCanonical {
            let displayValue = displayByCanonical[canonical] ?? canonical
            result[displayValue] = count
        }
        return result
    }

    private static func talkCountValueCounts(episodes: [Episode]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for value in talkCountSuggestionValues {
            counts[value] = 1
        }

        for episode in episodes {
            for value in talkCountSuggestionValues {
                guard let criteria = parseTalkCountCriteria(value), criteria.matches(episode.talkedCount) else {
                    continue
                }
                counts[value, default: 0] += 1
            }
        }
        return counts
    }

    private static func lastTalkedAtValueCounts(episodes: [Episode]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for value in lastTalkedSuggestionValues {
            counts[value] = 1
        }

        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        for episode in episodes {
            let talkedDates = episode.activeUnlockLogs.map(\.talkedAt)
            guard !talkedDates.isEmpty else { continue }
            for value in lastTalkedSuggestionValues {
                guard let criteria = parseLastTalkedAtCriteria(value) else { continue }
                if talkedDates.contains(where: { criteria.contains(date: $0, now: now, calendar: calendar) }) {
                    counts[value, default: 0] += 1
                }
            }
        }
        return counts
    }

    private static func registeredDateValueCounts(episodes: [Episode]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for value in lastTalkedSuggestionValues {
            counts[value] = 1
        }

        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        for episode in episodes {
            for value in lastTalkedSuggestionValues {
                guard let criteria = parseLastTalkedAtCriteria(value) else { continue }
                if criteria.contains(date: episode.date, now: now, calendar: calendar) {
                    counts[value, default: 0] += 1
                }
            }
        }
        return counts
    }

    private static func mergePresetValues(base: [String: Int], presets: [String]) -> [String: Int] {
        var merged = base
        for preset in presets {
            if merged[preset] == nil {
                merged[preset] = 1
            }
        }
        return merged
    }

    private static func rankedValues(
        for field: HomeSearchField,
        query: String,
        valueCounts: [HomeSearchField: [String: Int]],
        maxCount: Int
    ) -> [String] {
        let values = valueCounts[field] ?? [:]
        let normalizedQuery = normalizeSuggestionQuery(query, for: field)

        let filtered: [String]
        if normalizedQuery.isEmpty {
            filtered = Array(values.keys)
        } else {
            filtered = values.keys.filter {
                normalizeSuggestionValue($0, for: field).contains(normalizedQuery)
            }
        }

        let preferredOrder = preferredValueOrder(for: field)
        let sorted = filtered.sorted { lhs, rhs in
            if let preferredOrder {
                let lhsOrder = preferredOrder.firstIndex(of: lhs) ?? Int.max
                let rhsOrder = preferredOrder.firstIndex(of: rhs) ?? Int.max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
            }

            let lhsLower = normalizeSuggestionValue(lhs, for: field)
            let rhsLower = normalizeSuggestionValue(rhs, for: field)
            let lhsPrefix = !normalizedQuery.isEmpty && lhsLower.hasPrefix(normalizedQuery)
            let rhsPrefix = !normalizedQuery.isEmpty && rhsLower.hasPrefix(normalizedQuery)
            if lhsPrefix != rhsPrefix {
                return lhsPrefix
            }

            let lhsCount = values[lhs, default: 0]
            let rhsCount = values[rhs, default: 0]
            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }

            return lhs < rhs
        }

        if sorted.count <= maxCount {
            return sorted
        }
        return Array(sorted.prefix(maxCount))
    }

    private static func preferredValueOrder(for field: HomeSearchField) -> [String]? {
        switch field {
        case .talkCount:
            return talkCountSuggestionValues
        case .lastTalkedAt:
            return lastTalkedSuggestionValues
        case .registeredDate:
            return lastTalkedSuggestionValues
        case .mediaType:
            return ReleaseLogMediaPreset.allCases.map(\.rawValue)
        case .reaction:
            return ReleaseLogOutcome.allCases.map(\.rawValue)
        case .tag, .person, .project, .emotion, .place:
            return nil
        }
    }

    private static func normalizeSuggestionQuery(_ raw: String, for field: HomeSearchField) -> String {
        normalizeTokenValue(raw, field: field).lowercased()
    }

    private static func normalizeSuggestionValue(_ raw: String, for field: HomeSearchField) -> String {
        normalizeTokenValue(raw, field: field).lowercased()
    }

    private static func stripPersonHonorific(_ value: String) -> String {
        let suffixes = ["さん", "くん", "ちゃん", "氏"]
        for suffix in suffixes where value.hasSuffix(suffix) {
            return String(value.dropLast(suffix.count))
        }
        return value
    }

    private static func normalizeTalkCountToken(_ value: String) -> String {
        guard let criteria = parseTalkCountCriteria(value) else { return value }
        switch criteria {
        case .exact(let count):
            return "\(count)回"
        case .atLeast(let count):
            return "\(count)回以上"
        }
    }

    private static func parseTalkCountCriteria(_ value: String) -> TalkCountCriteria? {
        var normalized = normalizeFullWidthNumerics(value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        normalized = normalized.replacingOccurrences(of: "回", with: "")

        if normalized.hasSuffix("以上") {
            let digits = String(normalized.dropLast(2))
            guard let threshold = Int(digits), threshold >= 0 else { return nil }
            return .atLeast(threshold)
        }

        if normalized.hasSuffix("+") {
            let digits = String(normalized.dropLast())
            guard let threshold = Int(digits), threshold >= 0 else { return nil }
            return .atLeast(threshold)
        }

        guard let exact = Int(normalized), exact >= 0 else { return nil }
        return .exact(exact)
    }

    private static func normalizeLastTalkedAtToken(_ value: String) -> String {
        guard let criteria = parseLastTalkedAtCriteria(value) else {
            return normalizeFullWidthNumerics(value).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return criteria.displayText
    }

    private static func parseLastTalkedAtCriteria(_ value: String) -> LastTalkedAtCriteria? {
        let normalized = normalizeFullWidthNumerics(value)
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch trimmed.lowercased() {
        case "7日以内", "7d", "1週間", "一週間":
            return .withinDays(7)
        case "30日以内", "30d", "1ヶ月", "1か月":
            return .withinDays(30)
        case "90日以内", "90d", "3ヶ月", "3か月":
            return .withinDays(90)
        case "今年", "当年":
            return .thisYear
        default:
            if let range = parseDateRange(trimmed) {
                return .range(start: range.start, end: range.end)
            }
            return nil
        }
    }

    private static func parseDateRange(_ value: String) -> (start: Date?, end: Date?)? {
        HomeDateRangeParser.parseDateRange(value)
    }

    private static func parseDate(_ value: String) -> Date? {
        HomeDateRangeParser.parseDate(value)
    }

    private static func normalizeFullWidthNumerics(_ value: String) -> String {
        value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
    }

    private static func normalizeMediaTypeToken(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        switch lower {
        case "tv", "テレビ":
            return ReleaseLogMediaPreset.tv.rawValue
        case "配信", "stream", "streaming":
            return ReleaseLogMediaPreset.streaming.rawValue
        case "radio", "ラジオ":
            return ReleaseLogMediaPreset.radio.rawValue
        case "雑誌", "magazine":
            return ReleaseLogMediaPreset.magazine.rawValue
        case "イベント", "event":
            return ReleaseLogMediaPreset.event.rawValue
        case "sns":
            return ReleaseLogMediaPreset.sns.rawValue
        case "その他", "other":
            return ReleaseLogMediaPreset.other.rawValue
        default:
            return trimmed
        }
    }

    private static func normalizeReactionToken(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if trimmed.contains("○") || trimmed.localizedCaseInsensitiveContains("ウケ") {
            return ReleaseLogOutcome.hit.rawValue
        }
        if trimmed.contains("△") || trimmed.localizedCaseInsensitiveContains("イマ") {
            return ReleaseLogOutcome.soSo.rawValue
        }
        if trimmed.contains("×") || trimmed.localizedCaseInsensitiveContains("お蔵") {
            return ReleaseLogOutcome.shelved.rawValue
        }
        return trimmed
    }

    private static func deduplicated(_ items: [HomeSearchSuggestionItem]) -> [HomeSearchSuggestionItem] {
        var seen = Set<String>()
        var result: [HomeSearchSuggestionItem] = []
        for item in items {
            if seen.contains(item.id) {
                continue
            }
            seen.insert(item.id)
            result.append(item)
        }
        return result
    }
}

private enum TalkCountCriteria {
    case exact(Int)
    case atLeast(Int)

    func matches(_ value: Int) -> Bool {
        switch self {
        case .exact(let count):
            return value == count
        case .atLeast(let threshold):
            return value >= threshold
        }
    }
}

private enum LastTalkedAtCriteria {
    case withinDays(Int)
    case thisYear
    case range(start: Date?, end: Date?)

    var displayText: String {
        switch self {
        case .withinDays(let days):
            return "\(days)日以内"
        case .thisYear:
            return "今年"
        case .range(let start, let end):
            if let start, let end, start == end {
                return Self.formatDate(start)
            }
            let startText = start.map(Self.formatDate) ?? ""
            let endText = end.map(Self.formatDate) ?? ""
            return "\(startText)~\(endText)"
        }
    }

    func contains(date: Date, now: Date, calendar: Calendar) -> Bool {
        switch self {
        case .withinDays(let days):
            guard days > 0 else { return false }
            let nowStart = calendar.startOfDay(for: now)
            guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: nowStart) else {
                return false
            }
            guard let end = calendar.date(byAdding: .day, value: 1, to: nowStart) else {
                return false
            }
            return date >= start && date < end
        case .thisYear:
            return calendar.component(.year, from: date) == calendar.component(.year, from: now)
        case .range(let start, let end):
            let startOfStart = start.map { calendar.startOfDay(for: $0) }
            let startOfEndExclusive = end.flatMap {
                calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))
            }

            if let startOfStart, let startOfEndExclusive {
                return date >= startOfStart && date < startOfEndExclusive
            }
            if let startOfStart {
                return date >= startOfStart
            }
            if let startOfEndExclusive {
                return date < startOfEndExclusive
            }
            return false
        }
    }

    private static func formatDate(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: value)
    }
}
