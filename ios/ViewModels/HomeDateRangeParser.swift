import Foundation

enum HomeDateRangeParser {
    private static let separators = ["~", "〜", ".."]

    static func parseDateRange(_ value: String) -> (start: Date?, end: Date?)? {
        for separator in separators where value.contains(separator) {
            let parts = value.components(separatedBy: separator)
            guard parts.count == 2 else { continue }
            let lhs = parseDate(parts[0])
            let rhs = parseDate(parts[1])
            if lhs == nil && rhs == nil {
                continue
            }

            if let lhs, let rhs {
                return (start: min(lhs, rhs), end: max(lhs, rhs))
            }
            return (start: lhs, end: rhs)
        }

        if let exact = parseDate(value) {
            return (start: exact, end: exact)
        }

        return nil
    }

    static func parseDate(_ value: String) -> Date? {
        let normalized = normalizeFullWidthToHalfWidth(value)
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for formatter in dateInputFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    private static func normalizeFullWidthToHalfWidth(_ value: String) -> String {
        value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
    }

    private static let dateInputFormatters: [DateFormatter] = {
        let formats = ["yyyy/MM/dd", "yyyy-M-d", "yyyy-MM-dd"]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            return formatter
        }
    }()
}
