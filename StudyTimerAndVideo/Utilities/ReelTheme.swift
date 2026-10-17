import SwiftUI

// 参考デザインに合わせた、明るく透明感のある見た目。ダークモードには切り替えない
enum ReelTheme {
    static let background = Color(red: 0.953, green: 0.965, blue: 0.976)   // #F3F6F9
    static let card = Color.white
    static let ink = Color(red: 0.180, green: 0.227, blue: 0.275)          // #2E3A46
    static let secondary = Color(red: 0.557, green: 0.604, blue: 0.651)    // #8E9AA6
    static let line = Color(red: 0.890, green: 0.914, blue: 0.937)         // #E3E9EF
    static let accent = Color(red: 0.620, green: 0.765, blue: 0.886)       // #9EC3E2
    static let accentSoft = Color(red: 0.882, green: 0.929, blue: 0.965)   // #E1EDF6
    static let accentDeep = Color(red: 0.369, green: 0.553, blue: 0.722)   // #5E8DB8

    // タイトルや大きな数字に使う明朝・セリフ体
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static let cornerRadius: CGFloat = 12
}

// 白いカード
struct ReelCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous)
                    .fill(ReelTheme.card)
            )
    }
}

// 設定や編集画面で使う「アイコン・ラベル・値・>」の1行
struct ReelRow<Trailing: View>: View {
    let systemImage: String
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(ReelTheme.secondary)
                .frame(width: 22)
            Text(title)
                .font(ReelTheme.sans(14))
                .foregroundColor(ReelTheme.ink)
            Spacer()
            trailing
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
    }
}
