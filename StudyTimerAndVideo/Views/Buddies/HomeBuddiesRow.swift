import SwiftUI

// ホームの目標カードの下に出す、勉強仲間の1行。押すと勉強仲間の画面を開く
struct HomeBuddiesRow: View {
    @ObservedObject private var cloud = BuddyCloud.shared
    private let onOpen: () -> Void

    init(onOpen: @escaping () -> Void) {
        self.onOpen = onOpen
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: "person.2")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(ReelTheme.accentDeep)
                Text(summary)
                    .font(ReelTheme.sans(12))
                    .foregroundColor(studyingCount > 0 ? ReelTheme.accentDeep : ReelTheme.secondary)
                    .lineLimit(1)
                Spacer()
                if waitingCount > 0 {
                    Text(L10n.format("申請 %d", waitingCount))
                        .font(ReelTheme.sans(10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(ReelTheme.accentDeep))
                }
                Image(systemName: cloud.groups.isEmpty ? "plus" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ReelTheme.accentDeep)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ReelTheme.accent.opacity(cloud.groups.isEmpty ? 0.6 : 0), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cloud.groups.isEmpty ? Color.clear : Color.white))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.buddies")
        .task { await cloud.refresh() }
    }

    private var visibleMembers: [BuddyCloud.Member] {
        let blocked = cloud.blocked
        var seen = Set<String>()
        return cloud.groups.flatMap(\.members).filter { member in
            guard member.userRecordName != cloud.myRecordName, !blocked.contains(member.userRecordName) else { return false }
            return seen.insert(member.userRecordName).inserted
        }
    }

    private var studyingCount: Int { visibleMembers.filter(\.isStudyingNow).count }
    private var waitingCount: Int { cloud.requests.values.reduce(0) { $0 + $1.count } }

    private var summary: String {
        if cloud.groups.isEmpty {
            return cloud.pendingJoins.isEmpty ? L10n.string("勉強仲間と一緒にがんばる") : L10n.string("勉強仲間：オーナーの許可を待っています")
        }
        if studyingCount > 0 { return L10n.format("勉強仲間：いま%d人が勉強中", studyingCount) }
        return L10n.format("勉強仲間：%d人", visibleMembers.count)
    }
}
