import Foundation

enum HomeSearchField: String, CaseIterable {
    case tag
    case person
    case project
    case emotion
    case place

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
        let matchingFields = HomeSearchField.allCases.filter { $0.matchesAlias(trimmed) }
        items.append(contentsOf: matchingFields.map { HomeSearchSuggestionItem(kind: .selectField($0)) })

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
        if field == .tag, trimmed.hasPrefix("#") {
            trimmed.removeFirst()
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if field == .person {
            trimmed = stripPersonHonorific(trimmed)
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
        let normalizedQuery = normalizeTokenValue(query, field: field).lowercased()
        guard !normalizedQuery.isEmpty else { return false }

        switch field {
        case .tag:
            return episode.tags
                .filter { !$0.isSoftDeleted }
                .contains(where: {
                    normalizeTokenValue($0.name, field: .tag).lowercased().contains(normalizedQuery)
                })
        case .person:
            return episode.persons
                .filter { !$0.isSoftDeleted }
                .contains(where: { $0.name.lowercased().contains(normalizedQuery) })
        case .project:
            return episode.projects
                .filter { !$0.isSoftDeleted }
                .contains(where: { $0.name.lowercased().contains(normalizedQuery) })
        case .emotion:
            return episode.emotions
                .filter { !$0.isSoftDeleted }
                .contains(where: { $0.name.lowercased().contains(normalizedQuery) })
        case .place:
            return episode.places
                .filter { !$0.isSoftDeleted }
                .contains(where: { $0.name.lowercased().contains(normalizedQuery) })
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
            }
        ]
    }

    private static func countValues(
        in episodes: [Episode],
        field: HomeSearchField,
        extractor: (Episode) -> [(name: String, isSoftDeleted: Bool)]
    ) -> [String: Int] {
        var counts: [String: Int] = [:]
        for episode in episodes {
            for value in extractor(episode) where !value.isSoftDeleted {
                let normalized = normalizeTokenValue(value.name, field: field)
                guard !normalized.isEmpty else { continue }
                counts[normalized, default: 0] += 1
            }
        }
        return counts
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

        let sorted = filtered.sorted { lhs, rhs in
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

    private static func normalizeSuggestionQuery(_ raw: String, for field: HomeSearchField) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard field == .person else { return trimmed }
        return stripPersonHonorific(trimmed)
    }

    private static func normalizeSuggestionValue(_ raw: String, for field: HomeSearchField) -> String {
        let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard field == .person else { return lowered }
        return stripPersonHonorific(lowered)
    }

    private static func stripPersonHonorific(_ value: String) -> String {
        let suffixes = ["さん", "くん", "ちゃん", "氏"]
        for suffix in suffixes where value.hasSuffix(suffix) {
            return String(value.dropLast(suffix.count))
        }
        return value
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
