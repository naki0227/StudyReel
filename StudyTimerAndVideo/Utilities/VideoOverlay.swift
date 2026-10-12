import SwiftUI
import UIKit

// 動画に焼き込む文字のフォント。standard 以外は Pro
enum OverlayFont: String, CaseIterable, Identifiable {
    case standard
    case futura
    case avenir
    case typewriter
    case didot
    case handwritten

    static let storageKey = "overlay_font"

    var id: String { rawValue }

    var isPro: Bool { self != .standard }

    var displayName: String {
        switch self {
        case .standard: return L10n.string("標準")
        case .futura: return "Futura"
        case .avenir: return "Avenir Next"
        case .typewriter: return L10n.string("タイプライター")
        case .didot: return "Didot"
        case .handwritten: return L10n.string("手書き風")
        }
    }

    func uiFont(size: CGFloat) -> UIFont {
        let name: String
        switch self {
        case .standard:
            let base = UIFont.systemFont(ofSize: size, weight: .bold)
            if let descriptor = base.fontDescriptor.withDesign(.rounded) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return base
        case .futura: name = "Futura-Bold"
        case .avenir: name = "AvenirNext-Heavy"
        case .typewriter: name = "AmericanTypewriter-Bold"
        case .didot: name = "Didot-Bold"
        case .handwritten: name = "Noteworthy-Bold"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .bold)
    }

    func font(size: CGFloat) -> Font {
        Font(uiFont(size: size) as CTFont)
    }

    // Pro が切れたときは標準に戻す
    static func resolved(rawValue: String, isPro: Bool) -> OverlayFont {
        let font = OverlayFont(rawValue: rawValue) ?? .standard
        return font.isPro && !isPro ? .standard : font
    }
}

struct VideoOverlayStyle {
    var font: OverlayFont
    var showsWatermark: Bool
}

// 動画中央の「14:00 → 15:00 / 1時間目」を組み立てる
struct HourBlockText: Equatable {
    let range: String
    let caption: String

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    // 開始時刻は00分に切り捨て、勉強時間が1時間経つごとに次の枠へ進む
    init(sessionStart: Date, elapsedSeconds: Int, calendar: Calendar = .current) {
        let hourStart = calendar.dateInterval(of: .hour, for: sessionStart)?.start ?? sessionStart
        let block = max(0, elapsedSeconds) / 3600
        let from = calendar.date(byAdding: .hour, value: block, to: hourStart) ?? hourStart
        let to = calendar.date(byAdding: .hour, value: 1, to: from) ?? from

        let formatter = Self.formatter
        range = "\(formatter.string(from: from)) → \(formatter.string(from: to))"
        caption = L10n.format("%d時間目", block + 1)
    }
}

enum VideoOverlayRenderer {
    // 背景が透明な、動画と同じサイズの画像を作る。文字は1時間ごとにしか変わらないので呼び出し側でキャッシュする
    static func makeImage(text: HourBlockText, style: VideoOverlayStyle, canvasSize: CGSize) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let image = renderer.image { _ in
            let base = min(canvasSize.width, canvasSize.height)
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.45)
            shadow.shadowBlurRadius = base * 0.02
            shadow.shadowOffset = .zero

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let rangeAttributes: [NSAttributedString.Key: Any] = [
                .font: style.font.uiFont(size: base * 0.1),
                .foregroundColor: UIColor.white,
                .shadow: shadow,
                .paragraphStyle: paragraph
            ]
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: style.font.uiFont(size: base * 0.05),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                .shadow: shadow,
                .paragraphStyle: paragraph
            ]

            let rangeString = NSAttributedString(string: text.range, attributes: rangeAttributes)
            let captionString = NSAttributedString(string: text.caption, attributes: captionAttributes)
            let rangeHeight = rangeString.boundingRect(with: canvasSize, options: .usesLineFragmentOrigin, context: nil).height
            let captionHeight = captionString.boundingRect(with: canvasSize, options: .usesLineFragmentOrigin, context: nil).height
            let gap = base * 0.015
            let top = (canvasSize.height - rangeHeight - gap - captionHeight) / 2

            rangeString.draw(in: CGRect(x: 0, y: top, width: canvasSize.width, height: rangeHeight))
            captionString.draw(in: CGRect(x: 0, y: top + rangeHeight + gap, width: canvasSize.width, height: captionHeight))

            if style.showsWatermark {
                let watermarkAttributes: [NSAttributedString.Key: Any] = [
                    .font: OverlayFont.standard.uiFont(size: base * 0.04),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.75),
                    .shadow: shadow
                ]
                let watermark = NSAttributedString(string: "StudyReel", attributes: watermarkAttributes)
                let size = watermark.size()
                let margin = base * 0.05
                watermark.draw(at: CGPoint(x: canvasSize.width - size.width - margin, y: canvasSize.height - size.height - margin))
            }
        }

        return image.cgImage
    }
}
