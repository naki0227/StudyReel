import SwiftUI
import UIKit
import CoreImage
import Vision

// 動画の真ん中の時刻の飾り（色・飾り・置き場所・大きさ）と、自分で書いた／撮った数字。
// 白・黒と「飾りなし・縁取り」は無料。ほかは Pro か、交換所のジェムと交換すると使える
enum OverlayColor: String, CaseIterable, Identifiable {
    case white, black, theme, pink, mint, butter, lavender

    static let storageKey = "overlay_color"
    var id: String { rawValue }

    var needsPro: Bool { self != .white && self != .black }
    var isPro: Bool { needsPro && !Rewards.isUnlocked("color.\(rawValue)") }

    var title: String {
        switch self {
        case .white: return L10n.string("白")
        case .black: return L10n.string("黒")
        case .theme: return L10n.string("テーマの色")
        case .pink: return L10n.string("ピンク")
        case .mint: return L10n.string("ミント")
        case .butter: return L10n.string("バター")
        case .lavender: return L10n.string("ラベンダー")
        }
    }

    var uiColor: UIColor {
        switch self {
        case .white: return .white
        case .black: return UIColor(white: 0.12, alpha: 1)
        case .theme: return UIColor(ThemeColor.active.accentDeep)
        case .pink: return UIColor(red: 0.96, green: 0.62, blue: 0.70, alpha: 1)
        case .mint: return UIColor(red: 0.55, green: 0.85, blue: 0.75, alpha: 1)
        case .butter: return UIColor(red: 0.98, green: 0.86, blue: 0.48, alpha: 1)
        case .lavender: return UIColor(red: 0.76, green: 0.70, blue: 0.95, alpha: 1)
        }
    }
}

enum OverlayBadge: String, CaseIterable, Identifiable {
    case none, outline, tape, sticky, pill

    static let storageKey = "overlay_badge"
    var id: String { rawValue }

    var needsPro: Bool { self == .tape || self == .sticky || self == .pill }
    var isPro: Bool { needsPro && !Rewards.isUnlocked("badge.\(rawValue)") }

    var title: String {
        switch self {
        case .none: return L10n.string("なし")
        case .outline: return L10n.string("縁取り")
        case .tape: return L10n.string("マスキングテープ")
        case .sticky: return L10n.string("付箋")
        case .pill: return L10n.string("まるいラベル")
        }
    }
}

enum OverlayPosition: String, CaseIterable, Identifiable {
    case center, top, bottom, topLeading, topTrailing, bottomLeading, bottomTrailing

    static let storageKey = "overlay_position"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .center: return L10n.string("真ん中")
        case .top: return L10n.string("上")
        case .bottom: return L10n.string("下")
        case .topLeading: return L10n.string("左上")
        case .topTrailing: return L10n.string("右上")
        case .bottomLeading: return L10n.string("左下")
        case .bottomTrailing: return L10n.string("右下")
        }
    }
}

enum OverlaySize: String, CaseIterable, Identifiable {
    case small, medium, large

    static let storageKey = "overlay_size"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return L10n.string("小")
        case .medium: return L10n.string("中")
        case .large: return L10n.string("大")
        }
    }

    var scale: CGFloat {
        switch self {
        case .small: return 0.7
        case .medium: return 1
        case .large: return 1.4
        }
    }
}

// 時刻の飾りをまとめたもの。書き出しとプレビューで同じものを使う
struct OverlayDecor: Equatable {
    var color: OverlayColor = .white
    var badge: OverlayBadge = .none
    var position: OverlayPosition = .center
    var size: OverlaySize = .medium
    // 自分の数字（Pro）。11文字そろっているときだけ使う
    var usesCustomDigits = false

    static let customDigitsKey = "overlay_custom_digits"

    // 保存してある設定。Pro が切れたら、Pro の色と飾りは白・なしに戻す
    static func current(isPro: Bool) -> OverlayDecor {
        let defaults = UserDefaults.standard
        var decor = OverlayDecor()
        let color = OverlayColor(rawValue: defaults.string(forKey: OverlayColor.storageKey) ?? "") ?? .white
        decor.color = color.isPro && !isPro ? .white : color
        let badge = OverlayBadge(rawValue: defaults.string(forKey: OverlayBadge.storageKey) ?? "") ?? .none
        decor.badge = badge.isPro && !isPro ? .none : badge
        decor.position = OverlayPosition(rawValue: defaults.string(forKey: OverlayPosition.storageKey) ?? "") ?? .center
        decor.size = OverlaySize(rawValue: defaults.string(forKey: OverlaySize.storageKey) ?? "") ?? .medium
        let digitsUnlocked = isPro || Rewards.isUnlocked("digits")
        decor.usesCustomDigits = digitsUnlocked && defaults.bool(forKey: customDigitsKey) && CustomDigits.isComplete
        return decor
    }
}

// 自分で書いた・撮った「0〜9」と「:」。アプリの中（Application Support）に PNG で置く
enum CustomDigits {
    static let glyphs: [Character] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":"]
    // 手書きは文字の色で塗り直す。写真はそのままの色で使う
    static let tintKey = "overlay_custom_digits_tint"

    private static let lock = NSLock()
    private static var cache: [Character: UIImage] = [:]

    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("OverlayDigits", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func fileName(_ glyph: Character) -> String {
        glyph == ":" ? "colon.png" : "\(glyph).png"
    }

    static func image(_ glyph: Character) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[glyph] { return cached }
        let url = folder.appendingPathComponent(fileName(glyph))
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        cache[glyph] = image
        return image
    }

    static var isComplete: Bool {
        glyphs.allSatisfy { FileManager.default.fileExists(atPath: folder.appendingPathComponent(fileName($0)).path) }
    }

    static var isTinted: Bool {
        UserDefaults.standard.object(forKey: tintKey) as? Bool ?? true
    }

    // 透明なところを切り落としてから保存する
    static func save(_ image: UIImage, for glyph: Character) {
        let trimmed = trim(image) ?? image
        guard let data = trimmed.pngData() else { return }
        try? data.write(to: folder.appendingPathComponent(fileName(glyph)), options: .atomic)
        lock.lock()
        cache[glyph] = trimmed
        lock.unlock()
    }

    static func removeAll() {
        for glyph in glyphs {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(fileName(glyph)))
        }
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    // 写真から、写っているもの（紙に書いた字・シールなど）だけを切り抜く。切り抜けなければ写真のまま
    static func liftSubject(from image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation(image.imageOrientation))
        guard (try? handler.perform([request])) != nil,
              let result = request.results?.first,
              let buffer = try? result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true) else {
            return image
        }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let output = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return image }
        return UIImage(cgImage: output)
    }

    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private static func trim(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width, height = cgImage.height
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 10 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let pad = 4
        let rect = CGRect(x: max(0, minX - pad), y: max(0, minY - pad),
                          width: min(width, maxX + pad + 1) - max(0, minX - pad),
                          height: min(height, maxY + pad + 1) - max(0, minY - pad))
        guard let cropped = context.makeImage()?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped)
    }
}
