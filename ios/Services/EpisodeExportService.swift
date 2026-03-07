import Foundation

enum EpisodeExportFormat {
    case pdf
    case txt

    var fileExtension: String {
        switch self {
        case .pdf:
            return "pdf"
        case .txt:
            return "txt"
        }
    }
}

final class EpisodeExportService {
    private let fileManager: FileManager
    private let temporaryDirectory: URL
    private let now: () -> Date
    private let pdfRenderer: EpisodeExportPDFRenderer

    init(
        fileManager: FileManager = .default,
        temporaryDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init,
        pdfRenderer: EpisodeExportPDFRenderer = EpisodeExportPDFRenderer()
    ) {
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory ?? fileManager.temporaryDirectory
        self.now = now
        self.pdfRenderer = pdfRenderer
    }

    func export(format: EpisodeExportFormat, episode: Episode) throws -> URL {
        try export(
            format: format,
            payload: makePayload(from: episode),
            filenameTitle: episode.title
        )
    }

    func export(
        format: EpisodeExportFormat,
        payload: EpisodeExportPayload,
        filenameTitle: String
    ) throws -> URL {
        try fileManager.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        let filename = makeFilename(format: format, title: filenameTitle)
        let outputURL = temporaryDirectory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: outputURL.path) {
            do {
                try fileManager.removeItem(at: outputURL)
            } catch {
                NSLog("Failed to remove existing export file: \(error)")
                throw EpisodeExportError.fileWriteFailed
            }
        }

        switch format {
        case .txt:
            try writeTXT(payload: payload, to: outputURL)
        case .pdf:
            try pdfRenderer.render(payload: payload, outputURL: outputURL)
        }

        return outputURL
    }

    static func makePayload(
        title: String,
        body: String?,
        episodeDate: Date,
        unlockDate: Date?,
        isUnlocked: Bool
    ) -> EpisodeExportPayload {
        let formatter = makeDisplayDateFormatter()
        return EpisodeExportPayload(
            title: title,
            body: body ?? "",
            episodeDateText: formatter.string(from: episodeDate),
            unlockDateText: unlockDate.map { formatter.string(from: $0) } ?? "未設定",
            statusText: isUnlocked ? "解禁OK" : "解禁前"
        )
    }

    func makeFilename(format: EpisodeExportFormat, title: String) -> String {
        let dateString = Self.makeFilenameDateFormatter().string(from: now())
        let sanitizedTitle = Self.sanitizeFilenameTitle(title)
        return "Episode_\(dateString)_\(sanitizedTitle).\(format.fileExtension)"
    }

    static func sanitizeFilenameTitle(_ title: String) -> String {
        let forbiddenCharacterPattern = #"[\/\\:\*\?"<>\|]"#
        let range = NSRange(title.startIndex..<title.endIndex, in: title)
        let regex = try? NSRegularExpression(pattern: forbiddenCharacterPattern)
        let replacedForbidden = regex?.stringByReplacingMatches(
            in: title,
            options: [],
            range: range,
            withTemplate: "_"
        ) ?? title

        let singleLine = replacedForbidden
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let normalized = singleLine.isEmpty ? "untitled" : singleLine
        if normalized.count > 40 {
            return String(normalized.prefix(40))
        }
        return normalized
    }

    private func makePayload(from episode: Episode) -> EpisodeExportPayload {
        Self.makePayload(
            title: episode.title,
            body: episode.body,
            episodeDate: episode.date,
            unlockDate: episode.unlockDate,
            isUnlocked: episode.isUnlocked
        )
    }

    private func writeTXT(payload: EpisodeExportPayload, to outputURL: URL) throws {
        let text = """
        # \(payload.title)

        \(payload.body)

        ---

        エピソード日付: \(payload.episodeDateText)
        解禁可能日: \(payload.unlockDateText)
        ステータス: \(payload.statusText)

        ---
        """

        guard let data = text.data(using: .utf8) else {
            throw EpisodeExportError.fileWriteFailed
        }
        do {
            try data.write(to: outputURL, options: .atomic)
        } catch {
            throw EpisodeExportError.fileWriteFailed
        }
    }

    private static func makeDisplayDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }

    private static func makeFilenameDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }
}
