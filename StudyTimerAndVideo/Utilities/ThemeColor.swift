import SwiftUI

// アプリ全体の主役の色。空色はだれでも、ほかの色は Pro で選べる。
// Pro が終わっても、選んでいた色はそのまま使える（変えると Pro に入るまで戻せない）
enum ThemeColor: String, CaseIterable, Identifiable {
    case sky
    case mint
    case butter
    case lavender
    case peach
    case milktea
    case sakura
    case matcha

    static let storageKey = "theme_color"

    // いま画面に使っている色。ホームと設定が、保存してある色から決める
    private(set) static var active: ThemeColor = .sky

    @discardableResult
    static func apply(rawValue: String) -> ThemeColor {
        active = ThemeColor(rawValue: rawValue) ?? .sky
        return active
    }

    var id: String { rawValue }
    var isPro: Bool { self != .sky }

    var title: String {
        switch self {
        case .sky: return L10n.string("空色")
        case .mint: return L10n.string("ミント")
        case .butter: return L10n.string("バター")
        case .lavender: return L10n.string("ラベンダー")
        case .peach: return L10n.string("ピーチ")
        case .milktea: return L10n.string("ミルクティー")
        case .sakura: return L10n.string("さくら")
        case .matcha: return L10n.string("抹茶")
        }
    }

    // 主役の色（メーター・トグル・テープ）
    var accent: Color {
        switch self {
        case .sky: return Color(rgb: 0x9EC3E2)
        case .mint: return Color(rgb: 0xA8DCCB)
        case .butter: return Color(rgb: 0xF1D98A)
        case .lavender: return Color(rgb: 0xC9BFEA)
        case .peach: return Color(rgb: 0xF4BBA4)
        case .milktea: return Color(rgb: 0xD7C1AA)
        case .sakura: return Color(rgb: 0xF1BFCB)
        case .matcha: return Color(rgb: 0xBFD0A9)
        }
    }

    // 薄い面（ボタンの地・メーターの残り）
    var accentSoft: Color {
        switch self {
        case .sky: return Color(rgb: 0xE1EDF6)
        case .mint: return Color(rgb: 0xDDF0E8)
        case .butter: return Color(rgb: 0xF8EFCF)
        case .lavender: return Color(rgb: 0xECE8F7)
        case .peach: return Color(rgb: 0xFBE6DD)
        case .milktea: return Color(rgb: 0xEFE5DA)
        case .sakura: return Color(rgb: 0xF9E4E9)
        case .matcha: return Color(rgb: 0xE6ECDB)
        }
    }

    // 文字と、白い文字をのせるボタンに使う濃い色。白の上でも読める濃さにしてある
    var accentDeep: Color {
        switch self {
        case .sky: return Color(rgb: 0x5E8DB8)
        case .mint: return Color(rgb: 0x3F8C76)
        case .butter: return Color(rgb: 0x9A7520)
        case .lavender: return Color(rgb: 0x6C5DB0)
        case .peach: return Color(rgb: 0xBB5E3E)
        case .milktea: return Color(rgb: 0x87644A)
        case .sakura: return Color(rgb: 0xB85A74)
        case .matcha: return Color(rgb: 0x5E7A45)
        }
    }

    // 共有カードの紙の地
    var paper: Color {
        switch self {
        case .sky: return Color(rgb: 0xF7F8FA)
        case .mint: return Color(rgb: 0xF5F9F7)
        case .butter: return Color(rgb: 0xFBF9F2)
        case .lavender: return Color(rgb: 0xF8F7FB)
        case .peach: return Color(rgb: 0xFCF8F6)
        case .milktea: return Color(rgb: 0xF8F5F1)
        case .sakura: return Color(rgb: 0xFCF7F8)
        case .matcha: return Color(rgb: 0xF7F8F3)
        }
    }

    // 主役の色と並べる、2本目のテープの色
    var tape: Color {
        switch self {
        case .sky, .lavender, .milktea: return Color(rgb: 0xF2CBD0)
        case .mint, .matcha: return Color(rgb: 0xF6E2A8)
        case .butter, .peach: return Color(rgb: 0xC9DCEC)
        case .sakura: return Color(rgb: 0xDDF0E8)
        }
    }
}

extension Color {
    init(rgb hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
