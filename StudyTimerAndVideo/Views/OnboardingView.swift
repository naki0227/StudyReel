import SwiftUI

// 初めて開いたときの案内。「撮る → 整える → 残る」を見せてから、カメラの許可をお願いする
struct OnboardingView: View {
    static let storageKey = "has_seen_onboarding"

    var onFinish: () -> Void

    @StateObject private var permissionManager = PermissionManager()
    @State private var page = 0
    @State private var isRequesting = false

    private struct Page {
        let systemImage: String
        let step: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(
            systemImage: "camera",
            step: L10n.string("撮る"),
            title: L10n.string("机に置いて、始めるだけ"),
            body: L10n.string("勉強しているあいだ、数秒に1枚ずつ撮ってタイムラプスにします。")
        ),
        Page(
            systemImage: "wand.and.stars",
            step: L10n.string("整える"),
            title: L10n.string("顔はモザイクで隠せる"),
            body: L10n.string("終わったら見返して、カットやフィルター、音楽をつけられます。")
        ),
        Page(
            systemImage: "film.stack",
            step: L10n.string("残る"),
            title: L10n.string("勉強した時間がVlogになる"),
            body: L10n.string("毎日の記録がたまって、1週間分を1本の動画にまとめられます。")
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button(L10n.string("スキップ")) {
                        withAnimation { page = pages.count - 1 }
                    }
                    .font(ReelTheme.sans(14))
                    .foregroundColor(ReelTheme.secondary)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index], index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? ReelTheme.accentDeep : ReelTheme.line)
                        .frame(width: index == page ? 22 : 7, height: 7)
                }
            }
            .animation(.easeOut(duration: 0.2), value: page)
            .padding(.bottom, 26)

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    requestAndFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? L10n.string("次へ") : L10n.string("カメラを許可してはじめる"))
                    .font(ReelTheme.sans(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(ReelTheme.accentDeep))
            }
            .disabled(isRequesting)
            .padding(.horizontal, 24)

            Text(L10n.string("カメラの映像は端末の中だけで使い、外に送りません。"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .opacity(page == pages.count - 1 ? 1 : 0)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(ReelTheme.background.ignoresSafeArea())
    }

    private func pageView(_ item: Page, index: Int) -> some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(ReelTheme.accentSoft)
                    .frame(width: 200, height: 200)
                Circle()
                    .stroke(ReelTheme.accent, lineWidth: 1)
                    .frame(width: 240, height: 240)
                Image(systemName: item.systemImage)
                    .font(.system(size: 58, weight: .light))
                    .foregroundColor(ReelTheme.accentDeep)
            }
            .padding(.bottom, 44)

            Text("\(index + 1) · \(item.step)")
                .font(ReelTheme.sans(12, weight: .medium))
                .foregroundColor(ReelTheme.accentDeep)
                .padding(.bottom, 10)
            Text(item.title)
                .font(ReelTheme.serif(26))
                .foregroundColor(ReelTheme.ink)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
            Text(item.body)
                .font(ReelTheme.sans(14))
                .foregroundColor(ReelTheme.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 36)
            Spacer()
        }
    }

    private func requestAndFinish() {
        isRequesting = true
        Task {
            await permissionManager.requestRequiredPermissionsIfNeeded()
            isRequesting = false
            onFinish()
        }
    }
}
