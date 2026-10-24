import SwiftUI

// 「保護者に共有」を作るか決めるための案内。押した数を開発者が数える（まだ機能はない）
struct ParentShareTeaser: View {
    @ObservedObject private var cloud = BuddyCloud.shared
    private let source: String
    @AppStorage("parent_share_answer") private var answer = ""
    @State private var sending = false

    init(source: String) {
        self.source = source
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "figure.2.and.child.holdinghands")
                    .foregroundColor(ReelTheme.accentDeep)
                Text(L10n.string("保護者に共有（準備中）"))
                    .font(ReelTheme.sans(14, weight: .semibold))
                    .foregroundColor(ReelTheme.ink)
                Spacer()
            }
            if answer.isEmpty {
                Text(L10n.string("勉強時間と、いま勉強中かどうかだけを、おうちの人のスマホに見せられる機能を考えています。動画や写真は見せません。始めるのも止めるのも、あなたが決められます。使ってみたいですか？"))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
                HStack(spacing: 10) {
                    Button(L10n.string("いまはいい")) { send(false) }
                        .font(ReelTheme.sans(13))
                        .foregroundColor(ReelTheme.secondary)
                    Spacer()
                    Button {
                        send(true)
                    } label: {
                        Text(L10n.string("使ってみたい"))
                            .font(ReelTheme.sans(13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 36)
                            .background(Capsule().fill(ReelTheme.accentDeep))
                    }
                    .accessibilityIdentifier("parentShare.yes")
                }
                .disabled(sending)
            } else {
                Text(answer == "yes"
                     ? L10n.string("ありがとうございます。作るときの参考にします。")
                     : L10n.string("答えてくれてありがとうございます。"))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
    }

    private func send(_ wants: Bool) {
        sending = true
        Task {
            if await cloud.recordInterest(feature: "parent", wants: wants, source: source) {
                answer = wants ? "yes" : "no"
            }
            sending = false
        }
    }
}
