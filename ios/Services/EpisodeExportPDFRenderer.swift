import Foundation

struct EpisodeExportPayload {
    let title: String
    let body: String
    let episodeDateText: String
    let unlockDateText: String
    let statusText: String
}

enum EpisodeExportError: LocalizedError, Equatable {
    case missingAppIcon
    case fileWriteFailed
    case pdfRenderFailed
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .missingAppIcon:
            return "PDFヘッダー用アイコン画像が見つかりません。"
        case .fileWriteFailed:
            return "エクスポートファイルの保存に失敗しました。"
        case .pdfRenderFailed:
            return "PDFの生成に失敗しました。"
        case .unsupportedPlatform:
            return "この環境ではエクスポートに対応していません。"
        }
    }
}

#if canImport(UIKit)
import UIKit

final class EpisodeExportPDFRenderer {
    typealias IconProvider = () -> UIImage?

    private let iconProvider: IconProvider

    static var isSupported: Bool { true }

    init(iconProvider: @escaping IconProvider = { UIImage(named: "ExportAppIcon") }) {
        self.iconProvider = iconProvider
    }

    func render(payload: EpisodeExportPayload, outputURL: URL) throws {
        guard let appIcon = iconProvider() else {
            throw EpisodeExportError.missingAppIcon
        }

        let pageRect = CGRect(origin: .zero, size: Self.pageSizeA4)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let content = makeAttributedContent(payload: payload)
        let textArea = Self.makeTextArea(in: pageRect)
        let paginatedLayout = makePaginatedLayout(for: content, textAreaSize: textArea.size)

        guard !paginatedLayout.pageRanges.isEmpty else {
            throw EpisodeExportError.pdfRenderFailed
        }

        do {
            try renderer.writePDF(to: outputURL) { context in
                for (index, pageRange) in paginatedLayout.pageRanges.enumerated() {
                    context.beginPage()
                    drawHeader(in: context.cgContext, pageRect: pageRect, appIcon: appIcon)
                    paginatedLayout.layoutManager.drawBackground(
                        forGlyphRange: pageRange,
                        at: textArea.origin
                    )
                    paginatedLayout.layoutManager.drawGlyphs(forGlyphRange: pageRange, at: textArea.origin)
                    drawFooter(
                        page: index + 1,
                        totalPages: paginatedLayout.pageRanges.count,
                        pageRect: pageRect
                    )
                }
            }
        } catch {
            if Self.isFileWriteError(error) {
                throw EpisodeExportError.fileWriteFailed
            }
            throw EpisodeExportError.pdfRenderFailed
        }
    }

    private func makePaginatedLayout(
        for content: NSAttributedString,
        textAreaSize: CGSize
    ) -> PaginatedLayout {
        let textStorage = NSTextStorage(attributedString: content)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        var ranges: [NSRange] = []
        var safetyCounter = 0
        while true {
            let textContainer = NSTextContainer(size: textAreaSize)
            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = 0
            layoutManager.addTextContainer(textContainer)

            let range = layoutManager.glyphRange(for: textContainer)
            guard range.length > 0 else { break }
            ranges.append(range)

            if NSMaxRange(range) >= layoutManager.numberOfGlyphs {
                break
            }

            safetyCounter += 1
            if safetyCounter > 2_000 {
                break
            }
        }
        return PaginatedLayout(
            textStorage: textStorage,
            layoutManager: layoutManager,
            pageRanges: ranges
        )
    }

    private func drawHeader(in context: CGContext, pageRect: CGRect, appIcon: UIImage) {
        let margin = Self.margin
        let iconRect = CGRect(
            x: margin.left,
            y: margin.top,
            width: Self.headerIconSize,
            height: Self.headerIconSize
        )
        appIcon.draw(in: iconRect)

        let appNameRect = CGRect(
            x: iconRect.maxX + 8,
            y: margin.top + 2,
            width: pageRect.width - margin.left - margin.right - Self.headerIconSize - 8,
            height: Self.headerIconSize
        )
        ("EpisodeStocker" as NSString).draw(
            in: appNameRect,
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
        )

        let lineY = margin.top + Self.headerBlockHeight - 8
        context.saveGState()
        context.setStrokeColor(UIColor.systemGray4.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin.left, y: lineY))
        context.addLine(to: CGPoint(x: pageRect.width - margin.right, y: lineY))
        context.strokePath()
        context.restoreGState()
    }

    private func drawFooter(page: Int, totalPages: Int, pageRect: CGRect) {
        let text = "\(page) / \(totalPages)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let textSize = text.size(withAttributes: attributes)
        let origin = CGPoint(
            x: pageRect.width - Self.margin.right - textSize.width,
            y: pageRect.height - Self.margin.bottom - textSize.height
        )
        text.draw(at: origin, withAttributes: attributes)
    }

    private func makeAttributedContent(payload: EpisodeExportPayload) -> NSAttributedString {
        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.lineSpacing = 4

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = 5

        let metaParagraph = NSMutableParagraphStyle()
        metaParagraph.lineSpacing = 4

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.black,
            .paragraphStyle: titleParagraph
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.black,
            .paragraphStyle: bodyParagraph
        ]
        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: metaParagraph
        ]

        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: payload.title, attributes: titleAttributes))
        attributed.append(NSAttributedString(string: "\n\n", attributes: bodyAttributes))
        attributed.append(NSAttributedString(string: payload.body, attributes: bodyAttributes))
        attributed.append(NSAttributedString(string: "\n\n", attributes: bodyAttributes))
        attributed.append(
            NSAttributedString(
                string: "エピソード日付: \(payload.episodeDateText)\n"
                    + "解禁可能日: \(payload.unlockDateText)\n"
                    + "ステータス: \(payload.statusText)",
                attributes: metaAttributes
            )
        )
        return attributed
    }

    private static func makeTextArea(in pageRect: CGRect) -> CGRect {
        let x = margin.left
        let y = margin.top + headerBlockHeight + 8
        let width = pageRect.width - margin.left - margin.right
        let height = pageRect.height - y - margin.bottom - footerReservedHeight
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static let pageSizeA4 = CGSize(width: 595.2, height: 841.8)
    private static let margin = UIEdgeInsets(top: 42, left: 42, bottom: 42, right: 42)
    private static let headerIconSize: CGFloat = 20
    private static let headerBlockHeight: CGFloat = 28
    private static let footerReservedHeight: CGFloat = 24
    private static let fileWriteErrorCodes: Set<Int> = [
        NSFileWriteUnknownError,
        NSFileWriteNoPermissionError,
        NSFileWriteInvalidFileNameError,
        NSFileWriteFileExistsError,
        NSFileWriteInapplicableStringEncodingError,
        NSFileWriteUnsupportedSchemeError,
        NSFileWriteOutOfSpaceError,
        NSFileWriteVolumeReadOnlyError
    ]

    private static func isFileWriteError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && fileWriteErrorCodes.contains(nsError.code)
    }

    private struct PaginatedLayout {
        let textStorage: NSTextStorage
        let layoutManager: NSLayoutManager
        let pageRanges: [NSRange]
    }
}

#else

final class EpisodeExportPDFRenderer {
    static var isSupported: Bool { false }

    func render(payload: EpisodeExportPayload, outputURL: URL) throws {
        throw EpisodeExportError.unsupportedPlatform
    }
}

#endif
