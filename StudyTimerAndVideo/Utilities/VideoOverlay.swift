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

    // もともと Pro のフォントか。交換所でジェムと交換したら、Pro でなくても使える
    var needsPro: Bool { self != .wide && self != .standard }
    var isPro: Bool { needsPro && !Rewards.isUnlocked("font.\(rawValue)") }

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
    case hidden

    static let storageKey = "overlay_layout"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: return L10n.string("時刻")
        case .elapsed: return L10n.string("経過時間")
        case .hourBlock: return L10n.string("1時間ごと")
        case .hidden: return L10n.string("出さない")
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
    // 色・飾り・置き場所・大きさ・自分の数字。呼び出し側で OverlayDecor.current(isPro:) を渡す
    var decor = OverlayDecor()
}

// 動画中央の文字。開始時刻は00分に切り捨て、そこから勉強した時間だけ進める
//  - 時刻：「09:12」（1分ごとに進む）
//  - 経過時間：「00:12:34」（動画の進みに合わせて1秒ごとに進む）
//  - 1時間ごと：「14:00 → 15:00 / 1時間目」
//  - 出さない：文字なし
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
        case .hidden:
            primary = ""
            secondary = nil
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
        let decor = style.decor

        let image = renderer.image { _ in
            let base = min(canvasSize.width, canvasSize.height)
            if !text.primary.isEmpty {
                drawTime(text, style: style, decor: decor, base: base, canvasSize: canvasSize)
            }

            if style.showsWatermark {
                let shadow = NSShadow()
                shadow.shadowColor = UIColor.black.withAlphaComponent(0.35)
                shadow.shadowBlurRadius = base * 0.018
                shadow.shadowOffset = .zero
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

    // 1文字ずつ並べる。自分の数字があれば、数字と「:」はその画像にする
    private enum Piece {
        case text(NSAttributedString)
        case glyph(UIImage)
    }

    private static func drawTime(_ text: OverlayText, style: VideoOverlayStyle, decor: OverlayDecor, base: CGFloat, canvasSize: CGSize) {
        let color = decor.color.uiColor
        let isLight = decor.color != .black
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(isLight ? 0.35 : 0.15)
        shadow.shadowBlurRadius = base * 0.018
        shadow.shadowOffset = .zero
        let usesShadow = decor.badge == .none || decor.badge == .outline

        let primarySize = (style.layout == .hourBlock ? base * 0.1 : base * 0.075) * decor.size.scale
        var primaryAttributes: [NSAttributedString.Key: Any] = [
            .font: style.font.uiFont(size: primarySize),
            .foregroundColor: color,
            .kern: style.font == .wide ? primarySize * 0.02 : 0
        ]
        if usesShadow { primaryAttributes[.shadow] = shadow }
        if decor.badge == .outline {
            primaryAttributes[.strokeColor] = isLight ? UIColor(white: 0.1, alpha: 0.85) : UIColor.white
            primaryAttributes[.strokeWidth] = -4
        }

        // 1行目を部品に分ける
        let glyphHeight = primarySize * 1.05
        var pieces: [Piece] = []
        for character in text.primary {
            if decor.usesCustomDigits, CustomDigits.glyphs.contains(character), var image = CustomDigits.image(character) {
                if CustomDigits.isTinted {
                    image = image.withTintColor(color, renderingMode: .alwaysOriginal)
                }
                pieces.append(.glyph(image))
            } else {
                pieces.append(.text(NSAttributedString(string: String(character), attributes: primaryAttributes)))
            }
        }
        let gap = decor.usesCustomDigits ? primarySize * 0.05 : 0
        let widths: [CGFloat] = pieces.map {
            switch $0 {
            case .text(let string): return string.size().width
            case .glyph(let image): return image.size.width / max(image.size.height, 1) * glyphHeight
            }
        }
        let primaryWidth = widths.reduce(0, +) + gap * CGFloat(max(pieces.count - 1, 0))
        let lineHeight = max(glyphHeight, NSAttributedString(string: "0", attributes: primaryAttributes).size().height)

        var secondary: NSAttributedString?
        if let secondaryText = text.secondary {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: style.font.uiFont(size: base * 0.045 * decor.size.scale),
                .foregroundColor: color.withAlphaComponent(0.92)
            ]
            if usesShadow { attributes[.shadow] = shadow }
            secondary = NSAttributedString(string: secondaryText, attributes: attributes)
        }
        let secondarySize = secondary?.size() ?? .zero
        let lineGap = secondary == nil ? 0 : base * 0.015
        let blockSize = CGSize(width: max(primaryWidth, secondarySize.width), height: lineHeight + lineGap + secondarySize.height)

        // 置き場所
        let margin = base * 0.07
        let padding = CGSize(width: decor.badge == .none || decor.badge == .outline ? 0 : primarySize * 0.45,
                             height: decor.badge == .none || decor.badge == .outline ? 0 : primarySize * 0.25)
        let outer = CGSize(width: blockSize.width + padding.width * 2, height: blockSize.height + padding.height * 2)
        let x: CGFloat
        let y: CGFloat
        switch decor.position {
        case .center, .top, .bottom: x = (canvasSize.width - outer.width) / 2
        case .topLeading, .bottomLeading: x = margin
        case .topTrailing, .bottomTrailing: x = canvasSize.width - outer.width - margin
        }
        switch decor.position {
        case .center: y = (canvasSize.height - outer.height) / 2
        case .top, .topLeading, .topTrailing: y = margin
        case .bottom, .bottomLeading, .bottomTrailing: y = canvasSize.height - outer.height - margin * 1.6
        }
        let box = CGRect(x: x, y: y, width: outer.width, height: outer.height)

        // 下に敷く飾り
        switch decor.badge {
        case .none, .outline:
            break
        case .pill:
            let fill = isLight ? UIColor.black.withAlphaComponent(0.42) : UIColor.white.withAlphaComponent(0.85)
            fill.setFill()
            UIBezierPath(roundedRect: box, cornerRadius: box.height / 2).fill()
        case .sticky:
            let path = UIBezierPath(roundedRect: box, cornerRadius: primarySize * 0.08)
            UIGraphicsGetCurrentContext()?.saveGState()
            UIGraphicsGetCurrentContext()?.setShadow(offset: CGSize(width: 0, height: primarySize * 0.06), blur: primarySize * 0.2,
                                                     color: UIColor.black.withAlphaComponent(0.25).cgColor)
            UIColor(red: 1, green: 0.95, blue: 0.68, alpha: 1).setFill()
            path.fill()
            UIGraphicsGetCurrentContext()?.restoreGState()
        case .tape:
            UIColor(red: 0.96, green: 0.80, blue: 0.83, alpha: 0.88).setFill()
            // 端をぎざぎざにしたマスキングテープ
            let path = UIBezierPath()
            let teeth = 6
            path.move(to: CGPoint(x: box.minX, y: box.minY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.minY))
            for index in 0...teeth {
                let t = CGFloat(index) / CGFloat(teeth)
                path.addLine(to: CGPoint(x: box.maxX - (index % 2 == 0 ? 0 : box.height * 0.05), y: box.minY + box.height * t))
            }
            path.addLine(to: CGPoint(x: box.minX, y: box.maxY))
            for index in 0...teeth {
                let t = CGFloat(index) / CGFloat(teeth)
                path.addLine(to: CGPoint(x: box.minX + (index % 2 == 0 ? 0 : box.height * 0.05), y: box.maxY - box.height * t))
            }
            path.close()
            path.fill()
        }

        // 1行目
        var cursor = box.minX + padding.width + (blockSize.width - primaryWidth) / 2
        let top = box.minY + padding.height
        for (piece, width) in zip(pieces, widths) {
            switch piece {
            case .text(let string):
                let size = string.size()
                string.draw(at: CGPoint(x: cursor, y: top + (lineHeight - size.height) / 2))
            case .glyph(let image):
                image.draw(in: CGRect(x: cursor, y: top + (lineHeight - glyphHeight) / 2, width: width, height: glyphHeight))
            }
            cursor += width + gap
        }

        // 2行目
        if let secondary {
            secondary.draw(at: CGPoint(x: box.minX + padding.width + (blockSize.width - secondarySize.width) / 2,
                                       y: top + lineHeight + lineGap))
        }
    }
}

private extension UIFont {
    func withSerifDesign() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.serif) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
