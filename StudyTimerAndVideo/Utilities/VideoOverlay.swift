import CoreText
import SwiftUI
import UIKit

// 動画に焼き込む文字のフォント。ワイドと標準は無料、それ以外は Pro
enum OverlayFont: String, CaseIterable, Identifiable {
    case wide
    case standard
    case futura
    case avenir
    case typewriter
    case didot
    case handwritten

    static let storageKey = "overlay_font"
    static let defaultFont: OverlayFont = .wide

    var id: String { rawValue }

    var isPro: Bool { self != .wide && self != .standard }

    var displayName: String {
        switch self {
        case .wide: return L10n.string("ワイド")
        case .standard: return L10n.string("丸ゴシック")
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
        case .wide:
            // アプリに同梱した Unbounded（OFL）。読み込めなければ丸ゴシックで代わりにする
            FontRegistrar.registerBundledFonts()
            if let font = UIFont(name: "Unbounded-Bold", size: size) {
                return font
            }
            return OverlayFont.standard.uiFont(size: size)
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

    // Pro が切れたときは既定のフォントに戻す
    static func resolved(rawValue: String, isPro: Bool) -> OverlayFont {
        let font = OverlayFont(rawValue: rawValue) ?? defaultFont
        return font.isPro && !isPro ? defaultFont : font
    }
}

// 同梱フォントを一度だけ登録する
enum FontRegistrar {
    private static let lock = NSLock()
    private static var didRegister = false

    static func registerBundledFonts() {
        lock.lock()
        defer { lock.unlock() }
        guard !didRegister else { return }
        didRegister = true

        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Resources/Fonts") ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// 動画の真ん中に出す内容
enum OverlayLayout: String, CaseIterable, Identifiable {
    case clock
    case elapsed
    case hourBlock

    static let storageKey = "overlay_layout"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: return L10n.string("時刻")
        case .elapsed: return L10n.string("経過時間")
        case .hourBlock: return L10n.string("1時間ごと")
        }
    }

    static var current: OverlayLayout {
        OverlayLayout(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .clock
    }
}

struct VideoOverlayStyle {
    var font: OverlayFont
    var showsWatermark: Bool
    var layout: OverlayLayout = .current
}

// 動画中央の文字。開始時刻は00分に切り捨て、そこから勉強した時間だけ進める
//  - 時刻：「09:12」（1分ごとに進む）
//  - 経過時間：「00:12:34」（動画の進みに合わせて1秒ごとに進む）
//  - 1時間ごと：「14:00 → 15:00 / 1時間目」
// 全部録画のときは呼び出し側で30分単位に丸めて渡す
struct OverlayText: Equatable {
    let primary: String
    let secondary: String?

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    init(sessionStart: Date, elapsedSeconds: Int, layout: OverlayLayout = .current, calendar: Calendar = .current) {
        let hourStart = calendar.dateInterval(of: .hour, for: sessionStart)?.start ?? sessionStart
        let elapsed = max(0, elapsedSeconds)

        switch layout {
        case .clock:
            primary = Self.clockFormatter.string(from: hourStart.addingTimeInterval(TimeInterval(elapsed)))
            secondary = nil
        case .elapsed:
            primary = String(format: "%02d:%02d:%02d", elapsed / 3600, (elapsed % 3600) / 60, elapsed % 60)
            secondary = nil
        case .hourBlock:
            let block = elapsed / 3600
            let from = calendar.date(byAdding: .hour, value: block, to: hourStart) ?? hourStart
            let to = calendar.date(byAdding: .hour, value: 1, to: from) ?? from
            primary = "\(Self.hourFormatter.string(from: from)) → \(Self.hourFormatter.string(from: to))"
            secondary = L10n.format("%d時間目", block + 1)
        }
    }
}

enum VideoOverlayRenderer {
    // 背景が透明な、動画と同じサイズの画像を作る。文字が変わったときだけ作り直すよう呼び出し側でキャッシュする
    static func makeImage(text: OverlayText, style: VideoOverlayStyle, canvasSize: CGSize) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let image = renderer.image { _ in
            let base = min(canvasSize.width, canvasSize.height)
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.35)
            shadow.shadowBlurRadius = base * 0.018
            shadow.shadowOffset = .zero

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            // 時刻だけのときは、参考の Vlog のように小さめにすっきり置く
            let primarySize = style.layout == .hourBlock ? base * 0.1 : base * 0.075
            let primaryAttributes: [NSAttributedString.Key: Any] = [
                .font: style.font.uiFont(size: primarySize),
                .foregroundColor: UIColor.white,
                .shadow: shadow,
                .paragraphStyle: paragraph,
                .kern: style.font == .wide ? primarySize * 0.02 : 0
            ]
            let primary = NSAttributedString(string: text.primary, attributes: primaryAttributes)
            let primaryHeight = primary.boundingRect(with: canvasSize, options: .usesLineFragmentOrigin, context: nil).height

            if let secondaryText = text.secondary {
                let secondaryAttributes: [NSAttributedString.Key: Any] = [
                    .font: style.font.uiFont(size: base * 0.045),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                    .shadow: shadow,
                    .paragraphStyle: paragraph
                ]
                let secondary = NSAttributedString(string: secondaryText, attributes: secondaryAttributes)
                let secondaryHeight = secondary.boundingRect(with: canvasSize, options: .usesLineFragmentOrigin, context: nil).height
                let gap = base * 0.015
                let top = (canvasSize.height - primaryHeight - gap - secondaryHeight) / 2
                primary.draw(in: CGRect(x: 0, y: top, width: canvasSize.width, height: primaryHeight))
                secondary.draw(in: CGRect(x: 0, y: top + primaryHeight + gap, width: canvasSize.width, height: secondaryHeight))
            } else {
                primary.draw(in: CGRect(x: 0, y: (canvasSize.height - primaryHeight) / 2, width: canvasSize.width, height: primaryHeight))
            }

            if style.showsWatermark {
                let watermarkAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: base * 0.035, weight: .regular).withSerifDesign(),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.8),
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

private extension UIFont {
    func withSerifDesign() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.serif) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
