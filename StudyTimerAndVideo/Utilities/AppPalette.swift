import SwiftUI

enum AppPalette {
    // enludus.com と揃えたブランドカラー
    static let ink = Color(red: 0.03, green: 0.07, blue: 0.11)        // #08111c
    static let sky = Color(red: 0.57, green: 0.87, blue: 1.0)         // #92ddff
    static let skyDeep = Color(red: 0.18, green: 0.62, blue: 0.84)    // #2d9fd6
    static let orange = Color(red: 1.0, green: 0.61, blue: 0.38)      // #ff9b61

    static func homeGradient(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [
                    Color(red: 0.04, green: 0.09, blue: 0.15),
                    Color(red: 0.07, green: 0.20, blue: 0.30)
                ]
                : [
                    skyDeep,
                    Color(red: 0.12, green: 0.40, blue: 0.66)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func dashboardGradient(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.10, green: 0.15, blue: 0.22)
                ]
                : [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color(red: 0.90, green: 0.95, blue: 0.98),
                    Color(red: 0.85, green: 0.91, blue: 0.95)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func paywallGradient(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [
                    Color(red: 0.06, green: 0.07, blue: 0.11),
                    Color(red: 0.09, green: 0.12, blue: 0.18)
                ]
                : [
                    Color(red: 0.96, green: 0.98, blue: 1.0),
                    Color(red: 0.89, green: 0.94, blue: 0.98)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func cardFill(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.10, green: 0.14, blue: 0.20).opacity(0.92)
            : Color.white.opacity(0.82)
    }

    static func cardFillStrong(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.26, green: 0.34, blue: 0.50).opacity(0.96)
            : Color.white.opacity(0.90)
    }

    static func secondaryCardFill(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.65)
    }

    static func stroke(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.8)
    }

    static func accentText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.cyan.opacity(0.92) : Color.blue.opacity(0.9)
    }

    static func controlFill(for scheme: ColorScheme, selected: Bool = false) -> Color {
        if selected {
            return scheme == .dark ? Color.white.opacity(0.28) : Color.white.opacity(0.96)
        }
        return scheme == .dark ? Color.white.opacity(0.18) : Color.gray.opacity(0.22)
    }

    static func controlText(for scheme: ColorScheme, selected: Bool = false) -> Color {
        if selected {
            return scheme == .dark ? Color.white : Color.blue
        }
        return scheme == .dark ? Color.white.opacity(0.88) : Color.blue
    }

    static func sessionOverlay(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.50) : Color.black.opacity(0.38)
    }
}
